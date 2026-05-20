"use client";

/**
 * Soft animated radial gradient blobs behind hero.
 * Pure CSS keyframes  -  no JS, no IO. Pointer-events:none, absolute.
 */
export function GradientBlobs({
  className = "",
  blobs,
}: {
  className?: string;
  blobs?: { color: string; size: number; top: string; left: string; delay?: number }[];
}) {
  const items =
    blobs ??
    [
      { color: "rgba(139, 92, 246, 0.35)", size: 520, top: "-10%", left: "-5%", delay: 0 },
      { color: "rgba(236, 72, 153, 0.25)", size: 460, top: "30%", left: "70%", delay: 4 },
      { color: "rgba(59, 130, 246, 0.22)", size: 600, top: "60%", left: "10%", delay: 8 },
    ];

  return (
    <div
      aria-hidden
      className={className}
      style={{
        position: "absolute",
        inset: 0,
        overflow: "hidden",
        pointerEvents: "none",
        zIndex: 0,
      }}
    >
      <style>{`
        @keyframes blob-drift {
          0%, 100% { transform: translate3d(0, 0, 0) scale(1); }
          33%      { transform: translate3d(40px, -30px, 0) scale(1.08); }
          66%      { transform: translate3d(-30px, 20px, 0) scale(0.96); }
        }
      `}</style>
      {items.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            top: b.top,
            left: b.left,
            width: b.size,
            height: b.size,
            background: `radial-gradient(circle, ${b.color} 0%, transparent 60%)`,
            filter: "blur(60px)",
            animation: `blob-drift 18s ease-in-out infinite`,
            animationDelay: `${b.delay ?? 0}s`,
            willChange: "transform",
          }}
        />
      ))}
    </div>
  );
}
