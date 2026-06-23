import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, TEST_USER_EMAIL, TEST_USER_PASSWORD, THINK_TIME_MIN, THINK_TIME_MAX } from '../config.js';
import { jwtLogin, authHeaders } from '../helpers/auth.js';
import { checkOk, checkPaginated, check2xx } from '../helpers/checks.js';

/**
 * Simulates an authenticated user:
 *   login → profile → notifications → bookmarks → likes → support tickets →
 *   discussions → polls → search
 */
export default function authenticatedFlow() {
  // --- Login ---
  const tokens = jwtLogin(TEST_USER_EMAIL, TEST_USER_PASSWORD);
  if (!tokens) return; // skip iteration if login fails

  const hdrs = { headers: authHeaders(tokens.accessToken) };
  sleep(randomThinkTime());

  // Profile
  let res = http.get(`${BASE_URL}/auth/profile/`, hdrs);
  checkOk(res, 'profile');
  sleep(randomThinkTime());

  // Notifications
  res = http.get(`${BASE_URL}/notifications/`, hdrs);
  checkPaginated(res, 'notifications');
  sleep(randomThinkTime());

  // Notification preferences
  res = http.get(`${BASE_URL}/notification-preferences/`, hdrs);
  checkOk(res, 'notification-prefs');
  sleep(randomThinkTime());

  // Bookmarks
  res = http.get(`${BASE_URL}/bookmarks/`, hdrs);
  checkPaginated(res, 'bookmarks');
  sleep(randomThinkTime());

  // Support tickets
  res = http.get(`${BASE_URL}/support/tickets/`, hdrs);
  checkPaginated(res, 'support-tickets');
  sleep(randomThinkTime());

  // Support unread count
  res = http.get(`${BASE_URL}/support/unread-count/`, hdrs);
  checkOk(res, 'support-unread');
  sleep(randomThinkTime());

  // Discussions
  res = http.get(`${BASE_URL}/discussions/`, hdrs);
  checkPaginated(res, 'discussions');
  sleep(randomThinkTime());

  // Polls
  res = http.get(`${BASE_URL}/polls/`, hdrs);
  checkPaginated(res, 'polls');
  sleep(randomThinkTime());

  // My event registrations
  res = http.get(`${BASE_URL}/my-registrations/`, hdrs);
  checkOk(res, 'my-registrations');
  sleep(randomThinkTime());

  // Event reminders
  res = http.get(`${BASE_URL}/event-reminders/`, hdrs);
  checkPaginated(res, 'event-reminders');
  sleep(randomThinkTime());

  // Conversations
  res = http.get(`${BASE_URL}/conversations/`, hdrs);
  checkPaginated(res, 'conversations');
  sleep(randomThinkTime());

  // Search articles
  res = http.get(`${BASE_URL}/search/articles/?q=burundi`, hdrs);
  checkOk(res, 'search-articles');
  sleep(randomThinkTime());

  // Search magazines
  res = http.get(`${BASE_URL}/search/magazines/?q=chairmanship`, hdrs);
  checkOk(res, 'search-magazines');
  sleep(randomThinkTime());

  // Profile completion
  res = http.get(`${BASE_URL}/profile-completion/`, hdrs);
  checkOk(res, 'profile-completion');
  sleep(randomThinkTime());

  // What's new
  res = http.get(`${BASE_URL}/whats-new/`, hdrs);
  checkOk(res, 'whats-new');
  sleep(randomThinkTime());

  // Login history
  res = http.get(`${BASE_URL}/auth/login-history/`, hdrs);
  checkOk(res, 'login-history');
  sleep(randomThinkTime());

  // Active sessions
  res = http.get(`${BASE_URL}/auth/active-sessions/`, hdrs);
  checkOk(res, 'active-sessions');
  sleep(randomThinkTime());
}

function randomThinkTime() {
  return THINK_TIME_MIN + Math.random() * (THINK_TIME_MAX - THINK_TIME_MIN);
}
