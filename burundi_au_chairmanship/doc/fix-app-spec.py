#!/usr/bin/env python3
"""Apply the four App Platform spec corrections to a freshly exported spec.

    doctl apps spec get <app-id> > /tmp/spec-now.yaml
    python3 doc/fix-app-spec.py /tmp/spec-now.yaml > /tmp/spec-fixed.yaml
    doctl apps propose --spec /tmp/spec-fixed.yaml     # validates, changes nothing
    doctl apps update <app-id> --spec /tmp/spec-fixed.yaml

Always run it against a fresh export. A saved copy carries the encrypted
secret values as they were at export time, so applying a stale one silently
rolls back any secret rotated since — the app comes back up with the previous
database password.

Idempotent: run it on an already-corrected spec and it reports no changes.

What it changes and why:

1. Adds a PRE_DEPLOY job that runs migrate, and sets SKIP_ENTRYPOINT_MIGRATE=1
   on the web service. entrypoint.sh runs migrate unless that flag is set, and
   the service runs two instances, so without this both containers migrate at
   the same time on every deploy. The duplicate 0133 row in django_migrations
   is that race having already happened; Django holds no cross-process lock.

2. SITE_URL -> https://burundi4africa.com. api.burundi4africa.com answers 404.
   Every absolute URL the backend builds used it, the unsubscribe link in
   every newsletter included (core/tasks.py).

3. EMAIL_BACKEND -> core.email_backend.LoggingEmailBackend. Django's stock SMTP
   backend writes no EmailLog row, so Admin -> Email Logs is empty by
   construction, and it never consults the FALLBACK_EMAIL_* vars in the spec.

4. Removes the duplicate SENTRY_PROJECT on the web service. It was declared
   twice, b4africa-backend then b4africa-frontend; the later wins, so backend
   errors were filed under the frontend project.

It also marks SENTRY_AUTH_TOKEN as type: SECRET if it is not already. That
encrypts the value at rest — it does not un-leak a value already exposed, so
rotate the token in Sentry as well.
"""
import copy
import sys

import yaml

WEB = 'burundi-au-chairmanship-2026'
GOOD_SITE_URL = 'https://burundi4africa.com'
GOOD_EMAIL_BACKEND = 'core.email_backend.LoggingEmailBackend'
JOB_KEYS = ['DATABASE_URL', 'DJANGO_SECRET_KEY', 'DJANGO_DEBUG',
            'DJANGO_ALLOWED_HOSTS', 'SITE_URL', 'DO_SPACES_KEY',
            'DO_SPACES_SECRET', 'DO_SPACES_BUCKET', 'DO_SPACES_ENDPOINT']


def envs(component):
    return component.setdefault('envs', [])


def find(component, key):
    return [e for e in envs(component) if e.get('key') == key]


def main(path):
    spec = yaml.safe_load(open(path))
    changed = []

    components = list(spec.get('services', [])) + list(spec.get('workers', []))
    if not components:
        sys.exit('No services or workers in that file — is it a full app spec?')

    web = next((c for c in spec.get('services', []) if c.get('name') == WEB),
               (spec.get('services') or [None])[0])

    for comp in components:
        name = comp.get('name', '?')

        for e in find(comp, 'SITE_URL'):
            if e.get('value') != GOOD_SITE_URL:
                changed.append(f'{name}: SITE_URL {e.get("value")} -> {GOOD_SITE_URL}')
                e['value'] = GOOD_SITE_URL

        for e in find(comp, 'EMAIL_BACKEND'):
            if e.get('value') != GOOD_EMAIL_BACKEND:
                changed.append(f'{name}: EMAIL_BACKEND {e.get("value")} -> {GOOD_EMAIL_BACKEND}')
                e['value'] = GOOD_EMAIL_BACKEND

        for e in find(comp, 'SENTRY_AUTH_TOKEN'):
            if e.get('type') != 'SECRET':
                e['type'] = 'SECRET'
                changed.append(f'{name}: SENTRY_AUTH_TOKEN marked SECRET (rotate it too)')

        # Later duplicates win on App Platform, so keep the first and drop the rest.
        seen = {}
        for e in list(envs(comp)):
            key = e.get('key')
            if key in seen:
                envs(comp).remove(e)
                changed.append(f'{name}: removed duplicate {key}={e.get("value")}')
            else:
                seen[key] = e

    if web is not None and not find(web, 'SKIP_ENTRYPOINT_MIGRATE'):
        envs(web).append({'key': 'SKIP_ENTRYPOINT_MIGRATE',
                          'scope': 'RUN_AND_BUILD_TIME', 'value': '1'})
        changed.append(f'{web.get("name")}: SKIP_ENTRYPOINT_MIGRATE=1')

    if not spec.get('jobs') and web is not None:
        job_envs = [copy.deepcopy(find(web, k)[0]) for k in JOB_KEYS if find(web, k)]
        job = {
            'name': 'migrate',
            'kind': 'PRE_DEPLOY',
            'instance_count': 1,
            'instance_size_slug': web.get('instance_size_slug', 'apps-s-1vcpu-1gb'),
            'run_command': ('python manage.py migrate --noinput'
                            ' && python manage.py collectstatic --noinput'),
            'envs': job_envs,
        }
        for k in ('dockerfile_path', 'source_dir', 'github', 'image', 'git'):
            if k in web:
                job[k] = copy.deepcopy(web[k])
        spec['jobs'] = [job]
        changed.append('added PRE_DEPLOY job "migrate" — runs once, before any web container')

    if not changed:
        print('# already correct — nothing to change', file=sys.stderr)
    else:
        print('\n'.join(f'# {c}' for c in changed), file=sys.stderr)

    yaml.safe_dump(spec, sys.stdout, sort_keys=False,
                   default_flow_style=False, width=10 ** 6)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
