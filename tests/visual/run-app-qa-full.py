#!/usr/bin/env python3
"""
Comprehensive visual QA test for OrchyStraw app.
Clicks every button, tests every page transition in multiple orders,
captures screenshots, reports failures.
"""

import asyncio
import base64
import json
import sys
import urllib.request
from pathlib import Path

try:
    import websockets
except ImportError:
    print("ERROR: pip install websockets")
    sys.exit(1)

OUTPUT_DIR = Path("/tmp/orchystraw-qa-full")
OUTPUT_DIR.mkdir(exist_ok=True)

# Clean previous screenshots
for f in OUTPUT_DIR.glob("*.png"):
    f.unlink()

CHROME_DEBUG_URL = "http://localhost:9222/json"
APP_URL = "http://127.0.0.1:4321"


def get_ws_url():
    try:
        with urllib.request.urlopen(CHROME_DEBUG_URL) as r:
            return json.loads(r.read())[0]["webSocketDebuggerUrl"]
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)


class QA:
    def __init__(self, ws):
        self.ws = ws
        self.msg_id = 0
        self.results = []
        self.shot_num = 0

    async def cmd(self, method, params=None):
        self.msg_id += 1
        await self.ws.send(json.dumps({
            "id": self.msg_id, "method": method, "params": params or {},
        }))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("id") == self.msg_id:
                return msg

    async def js(self, expression):
        msg = await self.cmd("Runtime.evaluate", {
            "expression": expression, "returnByValue": True,
        })
        return msg.get("result", {}).get("result", {}).get("value")

    async def navigate(self, url):
        await self.cmd("Page.navigate", {"url": url})
        await asyncio.sleep(2)

    async def shot(self, label):
        self.shot_num += 1
        msg = await self.cmd("Page.captureScreenshot", {"format": "png"})
        path = OUTPUT_DIR / f"{self.shot_num:03d}-{label}.png"
        path.write_bytes(base64.b64decode(msg["result"]["data"]))
        return path

    async def click_text(self, text, container="body"):
        """Click first element with matching text."""
        return await self.js(f"""
            (() => {{
                const els = Array.from(document.querySelectorAll('{container} button, {container} a'));
                const el = els.find(e => e.textContent.trim() === '{text}' || e.textContent.includes('{text}'));
                if (el) {{ el.click(); return true; }}
                return false;
            }})()
        """)

    async def click_nth_button(self, container, n):
        return await self.js(f"""
            document.querySelectorAll('{container} button')[{n}]?.click() ?? null,
            true
        """)

    async def viewport(self, w=1440, h=900):
        await self.cmd("Emulation.setDeviceMetricsOverride", {
            "width": w, "height": h, "deviceScaleFactor": 2, "mobile": False,
        })

    def record(self, name, ok, note=""):
        self.results.append({"test": name, "ok": ok, "note": note})
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {name}" + (f" — {note}" if note else ""))

    async def assert_no_console_errors(self, name):
        # Check for ErrorBoundary trigger or runtime crash markers only
        # Don't match log content (historical errors are not UI bugs)
        has_error = await self.js("""
            !!document.querySelector('[role="alert"]') ||
            document.body.textContent.includes('Something went wrong') ||
            document.body.textContent.includes('Reload app') ||
            !document.querySelector('aside') /* sidebar gone = crash */
        """)
        self.record(f"{name}_no_error", not has_error)

    async def page_loads(self, name, must_contain):
        text = await self.js("document.body.textContent")
        ok = any(s in (text or "") for s in must_contain)
        self.record(f"{name}_loaded", ok, f"missing: {must_contain[0]}" if not ok else "")
        return ok


async def main():
    ws_url = get_ws_url()
    print(f"Connected: {ws_url}")
    print(f"Output: {OUTPUT_DIR}/")
    print()

    async with websockets.connect(ws_url, max_size=50_000_000) as ws:
        qa = QA(ws)
        await qa.viewport()

        # ─── PHASE 1: Cold load ───
        print("=== PHASE 1: Cold load ===")
        await qa.navigate(APP_URL)
        await qa.shot("01-cold-dashboard")
        await qa.page_loads("dashboard", ["Cycle", "Agents", "Live Activity"])
        await qa.assert_no_console_errors("dashboard_cold")

        # ─── PHASE 2: Click every nav item in order ───
        print("\n=== PHASE 2: Nav items ===")
        for nav in ["Dashboard", "Agents", "Chat", "Logs", "Config", "Settings"]:
            ok = await qa.click_text(nav, container="aside")
            await asyncio.sleep(1)
            await qa.shot(f"nav-{nav.lower()}")
            await qa.assert_no_console_errors(f"nav_{nav.lower()}")

        # ─── PHASE 3: Reverse nav order ───
        print("\n=== PHASE 3: Reverse nav ===")
        for nav in ["Settings", "Config", "Logs", "Chat", "Agents", "Dashboard"]:
            await qa.click_text(nav, container="aside")
            await asyncio.sleep(0.5)
        await qa.shot("after-reverse-nav")
        await qa.assert_no_console_errors("reverse_nav")

        # ─── PHASE 4: Click every Agent card ───
        print("\n=== PHASE 4: Agent cards ===")
        await qa.click_text("Dashboard", container="aside")
        await asyncio.sleep(1)
        agent_count = await qa.js("document.querySelectorAll('main button.bg-bg-secondary').length")
        qa.record("dashboard_has_agents", (agent_count or 0) > 0, f"count={agent_count}")

        for i in range(min(3, agent_count or 0)):
            # Click agent card
            clicked = await qa.js(f"""
                (() => {{
                    const cards = document.querySelectorAll('main button.bg-bg-secondary');
                    if (cards[{i}]) {{ cards[{i}].click(); return true; }}
                    return false;
                }})()
            """)
            await asyncio.sleep(1)
            await qa.shot(f"agent-detail-{i}")
            # Verify NOT showing "Agent not found"
            text = await qa.js("document.body.textContent")
            not_found = "Agent not found" in (text or "")
            qa.record(f"agent_{i}_loads", not not_found, "Agent not found!" if not_found else "")
            await qa.assert_no_console_errors(f"agent_{i}")

            # Click "Back to all agents"
            await qa.click_text("Back to all agents")
            await asyncio.sleep(0.5)

        # ─── PHASE 5: Agents page → click each agent in list ───
        print("\n=== PHASE 5: Agents list ===")
        await qa.click_text("Agents", container="aside")
        await asyncio.sleep(1)
        await qa.shot("agents-list")
        list_count = await qa.js("document.querySelectorAll('main .divide-y > button').length")
        qa.record("agents_list", (list_count or 0) > 5, f"count={list_count}")

        # Click 2 agents
        for i in range(min(2, list_count or 0)):
            await qa.js(f"document.querySelectorAll('main .divide-y > button')[{i}]?.click()")
            await asyncio.sleep(1)
            await qa.shot(f"agents-list-detail-{i}")
            await qa.click_text("Back to all agents")
            await asyncio.sleep(0.5)

        # ─── PHASE 6: Chat page ───
        print("\n=== PHASE 6: Chat ===")
        await qa.click_text("Chat", container="aside")
        await asyncio.sleep(1)
        await qa.shot("chat-default")
        # Chat is now hard-routed to cofounder (no dropdown). Verify the header text mentions Co-Founder.
        chat_header = await qa.js("document.querySelector('main h2')?.textContent || ''")
        qa.record("chat_cofounder_default", "Co-Founder" in (chat_header or ""), f"header={chat_header}")

        # Chat no longer has agent switcher — all messages go to cofounder by design

        # Type a message
        await qa.js("""
            const input = document.querySelector('textarea, input[type=text]');
            if (input) {
                const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value')?.set ||
                              Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
                setter.call(input, 'Test message from QA');
                input.dispatchEvent(new Event('input', { bubbles: true }));
            }
        """)
        await asyncio.sleep(0.3)
        await qa.shot("chat-typed")

        # ─── PHASE 7: Logs page ───
        print("\n=== PHASE 7: Logs ===")
        await qa.click_text("Logs", container="aside")
        await asyncio.sleep(1)
        await qa.shot("logs-page")
        await qa.assert_no_console_errors("logs")

        # Try search box
        await qa.js("""
            const input = document.querySelector('input[placeholder*="earch"]');
            if (input) {
                const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
                setter.call(input, 'test');
                input.dispatchEvent(new Event('input', { bubbles: true }));
            }
        """)
        await asyncio.sleep(0.5)
        await qa.shot("logs-searched")

        # ─── PHASE 8: Config page ───
        print("\n=== PHASE 8: Config ===")
        await qa.click_text("Config", container="aside")
        await asyncio.sleep(1)
        await qa.shot("config-page")
        config_text = await qa.js("document.body.textContent")
        qa.record("config_has_agents", "agents.conf" in (config_text or ""), "")
        await qa.assert_no_console_errors("config")

        # ─── PHASE 9: Settings + dark mode ───
        print("\n=== PHASE 9: Settings ===")
        await qa.click_text("Settings", container="aside")
        await asyncio.sleep(1)
        await qa.shot("settings-page")

        # Toggle dark mode
        toggled = await qa.js("""
            (() => {
                const btn = Array.from(document.querySelectorAll('button'))
                    .find(b => b.querySelector('span.absolute'));
                if (btn) { btn.click(); return true; }
                return false;
            })()
        """)
        await asyncio.sleep(1)
        await qa.shot("settings-light-mode")
        cls = await qa.js("document.documentElement.className")
        qa.record("dark_to_light", "light" in (cls or ""), f"class={cls or '(empty)'}")

        # Toggle back to dark
        await qa.js("""
            (() => {
                const btn = Array.from(document.querySelectorAll('button'))
                    .find(b => b.querySelector('span.absolute'));
                btn?.click();
            })()
        """)
        await asyncio.sleep(1)
        cls = await qa.js("document.documentElement.className")
        qa.record("light_to_dark", "light" not in (cls or ""), f"class={cls or '(empty)'}")

        # ─── PHASE 10: Project wizard ───
        print("\n=== PHASE 10: Project wizard ===")
        await qa.click_text("Add Project", container="aside")
        await asyncio.sleep(1.5)
        await qa.shot("wizard-step1")
        wizard_text = await qa.js("document.body.textContent")
        qa.record("wizard_opens", "Pick a project folder" in (wizard_text or "") or "Use this folder" in (wizard_text or ""), "")

        # Try clicking a folder
        clicked = await qa.js("""
            (() => {
                const btns = document.querySelectorAll('[role="dialog"] button, .fixed button');
                const folderBtns = Array.from(btns).filter(b => b.querySelector('svg') && b.textContent.trim() && !b.textContent.includes('Close') && !b.textContent.includes('Use'));
                if (folderBtns.length > 0) { folderBtns[0].click(); return true; }
                return false;
            })()
        """)
        await asyncio.sleep(1)
        await qa.shot("wizard-clicked-folder")

        # Close wizard (Escape or X button)
        await qa.cmd("Input.dispatchKeyEvent", {"type": "keyDown", "key": "Escape", "code": "Escape"})
        await asyncio.sleep(0.5)
        # Force close
        await qa.js("""
            const x = Array.from(document.querySelectorAll('[role="dialog"] button, .fixed button'))
                .find(b => b.querySelector('svg.lucide-x'));
            x?.click();
        """)
        await asyncio.sleep(0.5)

        # ─── PHASE 11: Header buttons ───
        print("\n=== PHASE 11: Header buttons ===")
        await qa.click_text("Dashboard", container="aside")
        await asyncio.sleep(1)
        await qa.shot("header-idle")

        button_state = await qa.js("""
            JSON.stringify({
                start: !!Array.from(document.querySelectorAll('header button'))
                    .find(b => b.textContent.trim() === 'Start'),
                stop: !!Array.from(document.querySelectorAll('header button'))
                    .find(b => b.textContent.trim() === 'Stop')
            })
        """)
        state = json.loads(button_state or "{}")
        qa.record(
            "header_idle_only_start",
            state.get("start") and not state.get("stop"),
            f"start={state.get('start')} stop={state.get('stop')}"
        )

        # ─── PHASE 12: Sidebar collapse ───
        print("\n=== PHASE 12: Sidebar collapse ===")
        # Click chevron to collapse
        collapsed = await qa.js("""
            (() => {
                const btn = Array.from(document.querySelectorAll('aside button'))
                    .find(b => b.querySelector('svg.lucide-chevron-left, svg.lucide-chevron-right'));
                if (btn) { btn.click(); return true; }
                return false;
            })()
        """)
        await asyncio.sleep(0.5)
        await qa.shot("sidebar-collapsed")

        # Re-expand
        await qa.js("""
            const btn = Array.from(document.querySelectorAll('aside button'))
                .find(b => b.querySelector('svg.lucide-chevron-left, svg.lucide-chevron-right'));
            btn?.click();
        """)
        await asyncio.sleep(0.5)

        # ─── PHASE 13: Random nav stress test (5 random transitions) ───
        print("\n=== PHASE 13: Stress test ===")
        import random
        navs = ["Dashboard", "Agents", "Chat", "Logs", "Config", "Settings"]
        for i in range(8):
            choice = random.choice(navs)
            await qa.click_text(choice, container="aside")
            await asyncio.sleep(0.3)
        await qa.shot("after-stress")
        await qa.assert_no_console_errors("stress_test")

        # ─── REPORT ───
        print()
        passed = sum(1 for r in qa.results if r["ok"])
        total = len(qa.results)
        print(f"=== RESULTS: {passed}/{total} passed ===")
        print()
        for r in qa.results:
            status = "PASS" if r["ok"] else "FAIL"
            note = f" — {r['note']}" if r["note"] else ""
            print(f"  [{status}] {r['test']}{note}")
        print()
        print(f"Screenshots: {OUTPUT_DIR}/ ({qa.shot_num} captured)")
        return passed == total


if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
