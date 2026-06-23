/**
 * k6 API Load Test — Burundi AU Chairmanship 2026
 *
 * Target: 50,000 concurrent users (40K anonymous + 10K authenticated)
 *
 * Usage:
 *   # Smoke test (1 VU, 1 iteration)
 *   k6 run --vus 1 --iterations 1 k6_api_test.js
 *
 *   # Small-scale (100 VUs, 1 minute)
 *   k6 run --vus 100 --duration 1m k6_api_test.js
 *
 *   # Full load (uses stages below)
 *   k6 run k6_api_test.js
 *
 *   # Override base URL
 *   k6 run -e BASE_URL=https://staging.burundi4africa.com/api/v1 k6_api_test.js
 */

import { DEFAULT_THRESHOLDS } from './config.js';
import anonymousFlow from './scenarios/api_anonymous.js';
import authenticatedFlow from './scenarios/api_authenticated.js';

export const options = {
  scenarios: {
    anonymous: {
      executor: 'ramping-vus',
      exec: 'anonymous',
      startVUs: 0,
      stages: [
        { duration: '2m',  target: 1000  },  // warm-up
        { duration: '3m',  target: 10000 },  // ramp to 10K
        { duration: '5m',  target: 40000 },  // ramp to 40K
        { duration: '10m', target: 40000 },  // hold at 40K
        { duration: '3m',  target: 0     },  // ramp down
      ],
    },
    authenticated: {
      executor: 'ramping-vus',
      exec: 'authenticated',
      startVUs: 0,
      stages: [
        { duration: '2m',  target: 500   },  // warm-up
        { duration: '3m',  target: 2500  },  // ramp
        { duration: '5m',  target: 10000 },  // ramp to 10K
        { duration: '10m', target: 10000 },  // hold at 10K
        { duration: '3m',  target: 0     },  // ramp down
      ],
    },
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export function anonymous()     { anonymousFlow();     }
export function authenticated() { authenticatedFlow(); }
