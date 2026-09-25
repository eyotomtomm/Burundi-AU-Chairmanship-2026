import { proxyToBackend } from "@/lib/backend-proxy";

/** /articles/5/share/ etc. — the Django share-card page (Open Graph + deep link into the app). */
export async function GET(req: Request, ctx: { params: Promise<{ kind: string; pk: string }> }) {
  const { kind, pk } = await ctx.params;
  return proxyToBackend(req, `/${kind}/${pk}/share/`);
}
