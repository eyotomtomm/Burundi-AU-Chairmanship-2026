/** Keep in step with the `firebase` version in package.json; the service worker loads the same SDK from gstatic. */
export const FIREBASE_SDK = "12.19.0";

export type FirebaseWeb = { config: Record<string, string>; vapidKey: string };

// The "B4Africa website" web app in Firebase project b4africa-700f7. Public by design:
// every visitor's browser receives these values.
const CONFIG = {
  apiKey: "AIzaSyD1r5bm8jNJsFrw5X9AjyEoyPZTIPMVfMM",
  authDomain: "b4africa-700f7.firebaseapp.com",
  projectId: "b4africa-700f7",
  storageBucket: "b4africa-700f7.firebasestorage.app",
  messagingSenderId: "55634991225",
  appId: "1:55634991225:web:da55526f5e36601e645ca8",
};

// Cloud Messaging → Web Push certificates → public key pair. Empty → no notification button.
const VAPID_KEY = "BLvvScdBHlHvwN6BaA6Bn3usG-n6rfzfVN0Rkk_4qz_HxsGUlqneRF1SsVtG2tgipD5Vi089zFh7ilZmDLTZl60";

export function firebaseWeb(): FirebaseWeb | null {
  return VAPID_KEY ? { config: CONFIG, vapidKey: VAPID_KEY } : null;
}
