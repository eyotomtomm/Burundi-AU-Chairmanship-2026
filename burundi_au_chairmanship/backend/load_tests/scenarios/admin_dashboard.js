import http from 'k6/http';
import { sleep } from 'k6';
import {
  BASE_URL, ADMIN_BASE_URL,
  ADMIN_EMAIL, ADMIN_PASSWORD,
  THINK_TIME_MIN, THINK_TIME_MAX,
} from '../config.js';
import { jwtLogin, authHeaders } from '../helpers/auth.js';
import { checkOk, check2xx } from '../helpers/checks.js';

/**
 * Simulates an admin user:
 *   login → dashboard pages → content management → users → notifications →
 *   email → analytics → support → system health
 */
export default function adminFlow() {
  // --- API auth (for REST endpoints) ---
  const tokens = jwtLogin(ADMIN_EMAIL, ADMIN_PASSWORD);
  if (!tokens) return;

  const hdrs = { headers: authHeaders(tokens.accessToken) };
  sleep(randomThinkTime());

  // --- Admin REST endpoints ---

  // Audit log
  let res = http.get(`${BASE_URL}/admin/audit-log/`, hdrs);
  check2xx(res, 'admin-audit-log');
  sleep(randomThinkTime());

  // Translation entries
  res = http.get(`${BASE_URL}/admin/translations/`, hdrs);
  check2xx(res, 'admin-translations');
  sleep(randomThinkTime());

  // Article drafts
  res = http.get(`${BASE_URL}/admin/drafts/`, hdrs);
  check2xx(res, 'admin-drafts');
  sleep(randomThinkTime());

  // Content versions
  res = http.get(`${BASE_URL}/admin/content-versions/`, hdrs);
  check2xx(res, 'admin-content-versions');
  sleep(randomThinkTime());

  // Translation queue
  res = http.get(`${BASE_URL}/admin/translation-queue/`, hdrs);
  check2xx(res, 'admin-translation-queue');
  sleep(randomThinkTime());

  // Analytics overview
  res = http.get(`${BASE_URL}/analytics/overview/`, hdrs);
  check2xx(res, 'analytics-overview');
  sleep(randomThinkTime());

  // Analytics user growth
  res = http.get(`${BASE_URL}/analytics/user-growth/`, hdrs);
  check2xx(res, 'analytics-user-growth');
  sleep(randomThinkTime());

  // Analytics countries
  res = http.get(`${BASE_URL}/analytics/countries/`, hdrs);
  check2xx(res, 'analytics-countries');
  sleep(randomThinkTime());

  // Analytics content engagement
  res = http.get(`${BASE_URL}/analytics/content-engagement/`, hdrs);
  check2xx(res, 'analytics-content-engagement');
  sleep(randomThinkTime());

  // Notification target count
  res = http.get(`${BASE_URL}/notifications/target-count/`, hdrs);
  check2xx(res, 'notification-target-count');
  sleep(randomThinkTime());

  // Maintenance status
  res = http.get(`${BASE_URL}/maintenance/`, hdrs);
  checkOk(res, 'maintenance-status');
  sleep(randomThinkTime());

  // App update check
  res = http.get(`${BASE_URL}/app-update/`, hdrs);
  checkOk(res, 'app-update');
  sleep(randomThinkTime());

  // Health check
  res = http.get(`${BASE_URL}/health/`, hdrs);
  checkOk(res, 'health');
  sleep(randomThinkTime());

  // --- Django admin HTML pages ---
  res = http.get(`${ADMIN_BASE_URL}/admin/`, hdrs);
  check2xx(res, 'admin-index');
  sleep(randomThinkTime());
}

function randomThinkTime() {
  return THINK_TIME_MIN + Math.random() * (THINK_TIME_MAX - THINK_TIME_MIN);
}
