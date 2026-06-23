import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL, ADMIN_BASE_URL } from '../config.js';

/**
 * Obtain a JWT access token via the legacy login endpoint.
 * Returns { accessToken, refreshToken } or null on failure.
 */
export function jwtLogin(email, password) {
  const res = http.post(
    `${BASE_URL}/auth/login/`,
    JSON.stringify({ email, password }),
    { headers: { 'Content-Type': 'application/json' } },
  );

  const ok = check(res, {
    'JWT login status 200': (r) => r.status === 200,
  });

  if (!ok) return null;

  const body = res.json();
  return {
    accessToken:  body.access  || body.token,
    refreshToken: body.refresh || null,
  };
}

/**
 * Build Authorization headers from a JWT token.
 */
export function authHeaders(accessToken) {
  return {
    'Content-Type':  'application/json',
    Authorization:   `Bearer ${accessToken}`,
  };
}

/**
 * Obtain a Django admin session + CSRF token.
 * Returns { cookies, csrfToken } or null on failure.
 */
export function adminLogin(email, password) {
  // GET the login page to obtain the CSRF cookie
  const loginPage = http.get(`${ADMIN_BASE_URL}/admin/login/`);
  const csrfCookie = loginPage.cookies['csrftoken'];
  if (!csrfCookie) return null;

  const csrfToken = csrfCookie[0].value;

  const res = http.post(
    `${ADMIN_BASE_URL}/admin/login/`,
    {
      username: email,
      password: password,
      csrfmiddlewaretoken: csrfToken,
      next: '/admin/',
    },
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Referer: `${ADMIN_BASE_URL}/admin/login/`,
      },
      redirects: 0,  // Don't follow — we just need the session cookie
    },
  );

  const ok = check(res, {
    'Admin login redirected': (r) => r.status === 302 || r.status === 200,
  });

  if (!ok) return null;

  return { csrfToken };
}
