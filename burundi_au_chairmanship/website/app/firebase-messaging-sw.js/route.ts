import { FIREBASE_SDK, firebaseWeb } from "@/lib/firebase-web";

/** The push service worker. Firebase shows each push and opens its webpush link on click. */
export function GET() {
  const fb = firebaseWeb();
  if (!fb) return new Response("Not found", { status: 404 });
  const base = `https://www.gstatic.com/firebasejs/${FIREBASE_SDK}`;
  const js = `importScripts("${base}/firebase-app-compat.js", "${base}/firebase-messaging-compat.js");
firebase.initializeApp(${JSON.stringify(fb.config)});
firebase.messaging();
`;
  return new Response(js, { headers: { "Content-Type": "text/javascript; charset=utf-8", "Cache-Control": "no-cache" } });
}
