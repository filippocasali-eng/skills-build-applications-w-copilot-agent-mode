/** Ambient arcade background: soft glows plus a few floating particles. Purely decorative. */
const PARTICLES = Array.from({ length: 18 }, (_, i) => ({
  left: (i * 37) % 100,
  top: (i * 53 + 11) % 100,
  size: 2 + (i % 3),
  delay: (i % 6) * 1.3,
  color: i % 3 === 0 ? "#fbbf24" : i % 2 === 0 ? "#06b6d4" : "#a78bfa",
}));

export function BackgroundFx() {
  return (
    <div aria-hidden="true" className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
      <div className="absolute -left-40 -top-40 h-[32rem] w-[32rem] rounded-full bg-primary/25 blur-[120px]" />
      <div className="absolute -right-40 top-1/3 h-[28rem] w-[28rem] rounded-full bg-secondary/20 blur-[120px]" />
      <div className="absolute bottom-[-12rem] left-1/4 h-[24rem] w-[24rem] rounded-full bg-gold/10 blur-[120px]" />
      <div
        className="absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage: "linear-gradient(#ffffff 1px, transparent 1px), linear-gradient(90deg, #ffffff 1px, transparent 1px)",
          backgroundSize: "44px 44px",
          maskImage: "radial-gradient(ellipse at center, black 30%, transparent 75%)",
        }}
      />
      {PARTICLES.map((p, i) => (
        <span
          key={i}
          className="absolute rounded-full animate-float"
          style={{
            left: `${p.left}%`,
            top: `${p.top}%`,
            width: p.size,
            height: p.size,
            background: p.color,
            boxShadow: `0 0 10px ${p.color}`,
            animationDelay: `${p.delay}s`,
          }}
        />
      ))}
    </div>
  );
}
