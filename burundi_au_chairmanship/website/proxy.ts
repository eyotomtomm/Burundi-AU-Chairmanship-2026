import { NextResponse, type NextRequest } from "next/server";

/** Exposes the request path to server components (the header's language toggle returns to it). */
export function proxy(req: NextRequest) {
  const headers = new Headers(req.headers);
  headers.set("x-pathname", req.nextUrl.pathname + req.nextUrl.search);
  return NextResponse.next({ request: { headers } });
}

export const config = { matcher: ["/((?!_next|img|favicon.ico).*)"] };
