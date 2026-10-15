"use client";

import { useEffect, useState } from "react";
import type { Lang } from "@/lib/types";
import type { FirebaseWeb } from "@/lib/firebase-web";

type State = "hidden" | "idle" | "busy" | "on" | "blocked";

/** Subscribes this browser to the same push notifications the app sends (anonymous device token). */
async function subscribe({ config, vapidKey }: FirebaseWeb, lang: Lang) {
  const [{ initializeApp, getApps }, { getMessaging, getToken, isSupported }] = await Promise.all([
    import("firebase/app"),
    import("firebase/messaging"),
  ]);
  if (!(await isSupported())) throw new Error("unsupported");
  const app = getApps()[0] ?? initializeApp(config);
  const token = await getToken(getMessaging(app), { vapidKey });
  const res = await fetch("/api/register-fcm-token/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ fcm_token: token, device_type: "Browser", device_os: "Web", preferred_language: lang }),
  });
  if (!res.ok) throw new Error(`register ${res.status}`);
}

export function NotifyButton({ lang, fb }: { lang: Lang; fb: FirebaseWeb }) {
  const [state, setState] = useState<State>("hidden");
  const fr = lang === "fr";

  useEffect(() => {
    // iOS Safari only exposes Notification once the site is added to the home screen.
    if (!("Notification" in window) || !("serviceWorker" in navigator)) return;
    const p = Notification.permission;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- browser-only state, unknown at render
    setState(p === "granted" ? "on" : p === "denied" ? "blocked" : "idle");
    // Already allowed: refresh the token and its language (the reader may have switched EN/FR).
    if (p === "granted") subscribe(fb, lang).catch(() => {});
  }, [fb, lang]);

  if (state === "hidden") return null;

  async function onClick() {
    setState("busy");
    try {
      const p = await Notification.requestPermission();
      if (p !== "granted") return setState(p === "denied" ? "blocked" : "idle");
      await subscribe(fb, lang);
      setState("on");
    } catch {
      setState("idle");
    }
  }

  const label = {
    idle: fr ? "Recevoir les notifications" : "Get notifications",
    busy: "…",
    on: fr ? "Notifications activées ✓" : "Notifications on ✓",
    blocked: fr ? "Notifications bloquées dans le navigateur" : "Notifications blocked in browser settings",
  }[state];

  return (
    <button type="button" className="btn btn--ghost" onClick={onClick} disabled={state !== "idle"}>
      {label}
    </button>
  );
}
