import { check } from 'k6';

/**
 * Assert response is 200 and has JSON body.
 */
export function checkOk(res, name) {
  check(res, {
    [`${name} status 200`]: (r) => r.status === 200,
    [`${name} has body`]:   (r) => r.body && r.body.length > 0,
  });
}

/**
 * Assert paginated DRF response: has count, results array.
 */
export function checkPaginated(res, name) {
  check(res, {
    [`${name} status 200`]:    (r) => r.status === 200,
    [`${name} has count`]:     (r) => r.json('count') !== undefined,
    [`${name} has results`]:   (r) => Array.isArray(r.json('results')),
  });
}

/**
 * Assert response is a JSON array (non-paginated endpoint).
 */
export function checkArray(res, name) {
  check(res, {
    [`${name} status 200`]: (r) => r.status === 200,
    [`${name} is array`]:   (r) => {
      try { return Array.isArray(r.json()); }
      catch (e) { return false; }
    },
  });
}

/**
 * Assert any 2xx response.
 */
export function check2xx(res, name) {
  check(res, {
    [`${name} status 2xx`]: (r) => r.status >= 200 && r.status < 300,
  });
}
