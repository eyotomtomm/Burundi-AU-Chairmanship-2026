import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, THINK_TIME_MIN, THINK_TIME_MAX } from '../config.js';
import { checkOk, checkPaginated, checkArray } from '../helpers/checks.js';

const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

/**
 * Simulates an anonymous user browsing the app:
 *   home feed → articles → events → gallery → videos → magazines → static endpoints
 */
export default function anonymousFlow() {
  // Home feed
  let res = http.get(`${BASE_URL}/home-feed/`, JSON_HEADERS);
  checkOk(res, 'home-feed');
  sleep(randomThinkTime());

  // Articles (paginated)
  res = http.get(`${BASE_URL}/articles/`, JSON_HEADERS);
  checkPaginated(res, 'articles');
  sleep(randomThinkTime());

  // Article detail — pick page 1, first item
  try {
    const articles = res.json('results');
    if (articles && articles.length > 0) {
      const articleId = articles[0].id;
      res = http.get(`${BASE_URL}/articles/${articleId}/`, JSON_HEADERS);
      checkOk(res, 'article-detail');
      sleep(randomThinkTime());

      // Article comments
      res = http.get(`${BASE_URL}/articles/${articleId}/comments/`, JSON_HEADERS);
      checkOk(res, 'article-comments');
    }
  } catch (_) {}
  sleep(randomThinkTime());

  // Events (paginated)
  res = http.get(`${BASE_URL}/events/`, JSON_HEADERS);
  checkPaginated(res, 'events');
  sleep(randomThinkTime());

  // Event speakers (now paginated)
  res = http.get(`${BASE_URL}/event-speakers/`, JSON_HEADERS);
  checkPaginated(res, 'event-speakers');
  sleep(randomThinkTime());

  // Gallery albums (paginated)
  res = http.get(`${BASE_URL}/gallery/`, JSON_HEADERS);
  checkPaginated(res, 'gallery');
  sleep(randomThinkTime());

  // Videos (paginated)
  res = http.get(`${BASE_URL}/videos/`, JSON_HEADERS);
  checkPaginated(res, 'videos');
  sleep(randomThinkTime());

  // Magazines (paginated)
  res = http.get(`${BASE_URL}/magazines/`, JSON_HEADERS);
  checkPaginated(res, 'magazines');
  sleep(randomThinkTime());

  // Article series (now paginated)
  res = http.get(`${BASE_URL}/article-series/`, JSON_HEADERS);
  checkPaginated(res, 'article-series');
  sleep(randomThinkTime());

  // Announcement banners (now paginated)
  res = http.get(`${BASE_URL}/announcement-banners/`, JSON_HEADERS);
  checkPaginated(res, 'announcement-banners');
  sleep(randomThinkTime());

  // Static / small endpoints (remain unpaginated)
  res = http.get(`${BASE_URL}/hero-slides/`, JSON_HEADERS);
  checkArray(res, 'hero-slides');

  res = http.get(`${BASE_URL}/categories/`, JSON_HEADERS);
  checkArray(res, 'categories');

  res = http.get(`${BASE_URL}/feature-cards/`, JSON_HEADERS);
  checkArray(res, 'feature-cards');

  res = http.get(`${BASE_URL}/priority-agendas/`, JSON_HEADERS);
  checkArray(res, 'priority-agendas');

  res = http.get(`${BASE_URL}/social-media/`, JSON_HEADERS);
  checkArray(res, 'social-media');

  res = http.get(`${BASE_URL}/weather-cities/`, JSON_HEADERS);
  checkArray(res, 'weather-cities');

  res = http.get(`${BASE_URL}/onboarding-steps/`, JSON_HEADERS);
  checkArray(res, 'onboarding-steps');

  // Trending content
  res = http.get(`${BASE_URL}/trending/`, JSON_HEADERS);
  checkOk(res, 'trending');

  // Health check
  res = http.get(`${BASE_URL}/health/`, JSON_HEADERS);
  checkOk(res, 'health');

  sleep(randomThinkTime());
}

function randomThinkTime() {
  return THINK_TIME_MIN + Math.random() * (THINK_TIME_MAX - THINK_TIME_MIN);
}
