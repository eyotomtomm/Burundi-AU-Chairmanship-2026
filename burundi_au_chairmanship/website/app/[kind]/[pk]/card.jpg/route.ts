import { proxyToBackend } from "@/lib/backend-proxy";

/** /articles/5/card.jpg — the rendered 1200×630 preview image the share page references. */
export async function GET(req: Request, ctx: { params: Promise<{ kind: string; pk: string }> }) {
  const { kind, pk } = await ctx.params;
  return proxyToBackend(req, `/${kind}/${pk}/card.jpg`);
}
