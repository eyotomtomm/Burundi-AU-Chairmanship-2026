/**
 * k6 Admin Dashboard Load Test — Burundi AU Chairmanship 2026
 *
 * Target: 100 concurrent admin users
 *
 * Usage:
 *   # Smoke test
 *   k6 run --vus 1 --iterations 1 k6_admin_test.js
 *
 *   # Full load (uses stages below)
 *   k6 run k6_admin_test.js
 */

import { DEFAULT_THRESHOLDS } from './config.js';
import adminFlow from './scenarios/admin_dashboard.js';

export const options = {
  scenarios: {
    admin: {
      executor: 'ramping-vus',
      exec: 'admin',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 20  },  // warm-up
        { duration: '2m', target: 100 },  // ramp to 100
        { duration: '5m', target: 100 },  // hold at 100
        { duration: '1m', target: 0   },  // ramp down
      ],
    },
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export function admin() { adminFlow(); }
