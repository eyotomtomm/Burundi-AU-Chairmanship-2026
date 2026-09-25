/** The drum-name band: an endless marquee of the four royal drums (decorative). */
export function Band({ text = "Karyenda · Amashako · Ibishikiso · Ikiranya" }: { text?: string }) {
  const parts = text.split(" · ");
  const line = (
    <>
      {parts.map((p, i) => (
        <span key={i} className={p === "Amashako" ? "band-hi" : undefined}>{p} · </span>
      ))}
    </>
  );
  return (
    <div className="band" aria-hidden="true">
      <div className="band-track">
        <span className="band-run">{line}{line}</span>
        <span className="band-run">{line}{line}</span>
      </div>
    </div>
  );
}
