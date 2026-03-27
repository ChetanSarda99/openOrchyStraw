import { ImageResponse } from "next/og";

export const dynamic = "force-static";
export const alt = "OrchyStraw — Multi-Agent AI Coding Orchestration";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function OGImage() {
  return new ImageResponse(
    (
      <div
        style={{
          background: "#0a0a0a",
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          padding: "60px 80px",
        }}
      >
        {/* Top accent line */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            height: "4px",
            background: "#f97316",
          }}
        />

        {/* Terminal window */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            background: "#141414",
            borderRadius: "16px",
            border: "1px solid #262626",
            width: "100%",
            maxWidth: "900px",
            overflow: "hidden",
          }}
        >
          {/* Title bar */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              padding: "16px 20px",
              borderBottom: "1px solid #262626",
            }}
          >
            <div
              style={{
                width: "12px",
                height: "12px",
                borderRadius: "50%",
                background: "#ff5f57",
              }}
            />
            <div
              style={{
                width: "12px",
                height: "12px",
                borderRadius: "50%",
                background: "#febc2e",
              }}
            />
            <div
              style={{
                width: "12px",
                height: "12px",
                borderRadius: "50%",
                background: "#28c840",
              }}
            />
            <span
              style={{
                marginLeft: "8px",
                fontSize: "13px",
                color: "#a1a1aa",
                fontFamily: "monospace",
              }}
            >
              terminal
            </span>
          </div>

          {/* Terminal content */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              padding: "24px",
              gap: "6px",
              fontFamily: "monospace",
              fontSize: "16px",
              lineHeight: "1.6",
            }}
          >
            <div style={{ display: "flex", color: "#a1a1aa" }}>
              <span style={{ color: "#f97316" }}>$</span>
              <span style={{ marginLeft: "8px" }}>./auto-agent.sh</span>
            </div>
            <div style={{ color: "#a1a1aa", opacity: 0.7 }}>
              ── OrchyStraw v0.1.0 ──────────────────
            </div>
            <div style={{ display: "flex", color: "#ededed" }}>
              <span style={{ color: "#4ade80" }}>✓</span>
              <span style={{ marginLeft: "8px" }}>
                Loaded 11 agents from agents.conf
              </span>
            </div>
            <div style={{ display: "flex", color: "#ededed" }}>
              <span style={{ color: "#60a5fa" }}>→</span>
              <span style={{ marginLeft: "8px" }}>06-backend</span>
              <span style={{ marginLeft: "8px", color: "#a1a1aa", opacity: 0.5 }}>
                hardening orchestrator...
              </span>
            </div>
            <div style={{ display: "flex", color: "#ededed" }}>
              <span style={{ color: "#60a5fa" }}>→</span>
              <span style={{ marginLeft: "8px" }}>05-tauri-ui</span>
              <span style={{ marginLeft: "8px", color: "#a1a1aa", opacity: 0.5 }}>
                scaffolding dashboard...
              </span>
            </div>
            <div style={{ display: "flex", color: "#ededed" }}>
              <span style={{ color: "#4ade80" }}>✓</span>
              <span style={{ marginLeft: "8px" }}>
                4 agents ran, 12 files changed, 0 conflicts
              </span>
            </div>
          </div>
        </div>

        {/* Brand text below terminal */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            marginTop: "40px",
            gap: "8px",
          }}
        >
          <div
            style={{
              fontFamily: "monospace",
              fontSize: "32px",
              fontWeight: 700,
              color: "#f97316",
            }}
          >
            orchystraw
          </div>
          <div
            style={{
              fontSize: "18px",
              color: "#a1a1aa",
            }}
          >
            Multi-agent AI coding orchestration. No framework. No dependencies.
          </div>
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
