/**
 * Shared configuration for k6 load tests.
 *
 * Override BASE_URL at runtime:
 *   k6 run -e BASE_URL=https://staging.burundi4africa.com/api/v1 k6_api_test.js
 */

export const BASE_URL = __ENV.BASE_URL || 'https://burundi4africa.com/api/v1';

// Test user credentials (override via environment variables)
export const TEST_USER_EMAIL    = __ENV.TEST_USER_EMAIL    || 'loadtest@example.com';
export const TEST_USER_PASSWORD = __ENV.TEST_USER_PASSWORD || 'LoadTest2026!';

export const ADMIN_EMAIL    = __ENV.ADMIN_EMAIL    || 'admin@example.com';
export const ADMIN_PASSWORD = __ENV.ADMIN_PASSWORD || 'AdminTest2026!';

// Admin panel base URL (Django admin / custom dashboard)
export const ADMIN_BASE_URL = __ENV.ADMIN_BASE_URL || 'https://burundi4africa.com';

// Default thresholds — every scenario should import these
export const DEFAULT_THRESHOLDS = {
  http_req_duration: ['p(95)<2000', 'p(99)<5000'],  // 95th < 2s, 99th < 5s
  http_req_failed:   ['rate<0.01'],                   // <1% error rate
  http_reqs:         ['rate>100'],                     // >100 RPS sustained
};

// Sleep range between requests (seconds) to simulate think-time
export const THINK_TIME_MIN = 1;
export const THINK_TIME_MAX = 3;
