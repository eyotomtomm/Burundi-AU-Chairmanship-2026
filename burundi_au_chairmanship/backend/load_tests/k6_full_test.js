/**
 * k6 Full Combined Load Test — Burundi AU Chairmanship 2026
 *
 * Target: 50,020 concurrent users (40K anon + 10K auth + 20 admin)
 *
 * Usage:
 *   # Smoke test
 *   k6 run --vus 1 --iterations 1 k6_full_test.js
 *
 *   # Full load (uses stages below)
 *   k6 run k6_full_test.js
 */

import { DEFAULT_THRESHOLDS } from './config.js';
import anonymousFlow from './scenarios/api_anonymous.js';
import authenticatedFlow from './scenarios/api_authenticated.js';
import adminFlow from './scenarios/admin_dashboard.js';

export const options = {
  scenarios: {
    anonymous: {
      executor: 'ramping-vus',
      exec: 'anonymous',
      startVUs: 0,
      stages: [
        { duration: '2m',  target: 1000  },
        { duration: '3m',  target: 10000 },
        { duration: '5m',  target: 40000 },
        { duration: '10m', target: 40000 },
        { duration: '3m',  target: 0     },
      ],
    },
    authenticated: {
      executor: 'ramping-vus',
      exec: 'authenticated',
      startVUs: 0,
      stages: [
        { duration: '2m',  target: 500   },
        { duration: '3m',  target: 2500  },
        { duration: '5m',  target: 10000 },
        { duration: '10m', target: 10000 },
        { duration: '3m',  target: 0     },
      ],
    },
    admin: {
      executor: 'ramping-vus',
      exec: 'admin',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 5  },
        { duration: '2m', target: 20 },
        { duration: '5m', target: 20 },
        { duration: '2m', target: 0  },
      ],
    },
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export function anonymous()     { anonymousFlow();     }
export function authenticated() { authenticatedFlow(); }
export function admin()         { adminFlow();         }
