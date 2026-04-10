#!/usr/bin/env python3
"""
Visual QA test suite for OrchyStraw app.
Launches Chrome via DevTools Protocol, clicks every button, screenshots each state.

Usage:
    # Start app + Chrome with debugging port first:
    #   orchystraw app &
    #   /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome \\
    #     --remote-debugging-port=9222 --user-data-dir=$HOME/chrome-automation \\
    #     http://127.0.0.1:4321 &
    python3 tests/visual/run-app-qa.py
"""

import asyncio
import base64
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

try:
    import websockets
except ImportError:
    print("ERROR: pip install websockets")
    sys.exit(1)

OUTPUT_DIR = Path("/tmp/orchystraw-qa")
OUTPUT_DIR.mkdir(exist_ok=True)

CHROME_DEBUG_URL = "http://localhost:9222/json"
APP_URL = "http://127.0.0.1:4321"


def get_ws_url():
    try:
        with urllib.request.urlopen(CHROME_DEBUG_URL) as r:
            tabs = json.loads(r.read())
            return tabs[0]["webSocketDebuggerUrl"]
    except Exception as e:
        print(f"ERROR: Cannot connect to Chrome debugger: {e}")
        print("  Launch Chrome first:")
        print('    /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome \\')
        print("      --remote-debugging-port=9222 --user-data-dir=$HOME/chrome-automation &")
        sys.exit(1)


class QARunner:
    def __init__(self, ws):
        self.ws = ws
        self.msg_id = 0
        self.results = []

    async def send(self, method, params=None):
        self.msg_id += 1
        await self.ws.send(json.dumps({
            "id": self.msg_id,
            "method": method,
            "params": params or {},
        }))
        # Wait for matching response
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("id") == self.msg_id:
                return msg

    async def navigate(self, url):
        await self.send("Page.navigate", {"url": url})
        await asyncio.sleep(2)

    async def screenshot(self, name):
        msg = await self.send("Page.captureScreenshot", {"format": "png"})
        data = msg["result"]["data"]
        path = OUTPUT_DIR / f"{name}.png"
        path.write_bytes(base64.b64decode(data))
        return path

    async def click(self, selector):
        await self.send("Runtime.evaluate", {
            "expression": f"document.querySelector('{selector}')?.click()",
        })
        await asyncio.sleep(0.5)

    async def click_text(self, text):
        """Click any element containing the text."""
        await self.send("Runtime.evaluate", {
            "expression": f"""
                Array.from(document.querySelectorAll('button, a'))
                  .find(el => el.textContent.includes('{text}'))?.click()
            """,
        })
        await asyncio.sleep(1)

    async def get_text(self, selector):
        msg = await self.send("Runtime.evaluate", {
            "expression": f"document.querySelector('{selector}')?.textContent || ''",
            "returnByValue": True,
        })
        return msg.get("result", {}).get("result", {}).get("value", "")

    async def set_viewport(self, width, height):
        await self.send("Emulation.setDeviceMetricsOverride", {
            "width": width, "height": height, "deviceScaleFactor": 2, "mobile": False,
        })

    async def assert_text(self, name, selector, expected_substring):
        actual = await self.get_text(selector)
        ok = expected_substring in actual
        self.results.append({
            "test": name, "ok": ok,
            "expected": expected_substring,
            "actual": actual[:100],
        })
        return ok

    def report(self):
        passed = sum(1 for r in self.results if r["ok"])
        total = len(self.results)
        print()
        print(f"=== Visual QA Results: {passed}/{total} passed ===")
        for r in self.results:
            status = "PASS" if r["ok"] else "FAIL"
            print(f"  [{status}] {r['test']}")
            if not r["ok"]:
                print(f"         expected: {r['expected']}")
                print(f"         actual:   {r['actual']}")
        print()
        print(f"Screenshots: {OUTPUT_DIR}/")
        return passed == total


async def main():
    ws_url = get_ws_url()
    print(f"Connected: {ws_url}")
    print(f"Output: {OUTPUT_DIR}/")

    async with websockets.connect(ws_url, max_size=50_000_000) as ws:
        qa = QARunner(ws)
        await qa.set_viewport(1440, 900)

        # ── Test 1: Dashboard loads ──
        print("→ Dashboard")
        await qa.navigate(APP_URL)
        await qa.screenshot("01-dashboard")
        # Pixel agents component should be visible
        pixel_text = await qa.get_text("body")
        qa.results.append({
            "test": "dashboard_loads",
            "ok": "Cycle" in pixel_text or "Agents" in pixel_text,
            "expected": "dashboard content",
            "actual": pixel_text[:80],
        })

        # ── Test 2: Click Agents nav ──
        print("→ Agents page")
        await qa.click_text("Agents")
        await asyncio.sleep(1)
        await qa.screenshot("02-agents")

        # ── Test 3: Click Logs nav ──
        print("→ Logs page")
        await qa.click_text("Logs")
        await asyncio.sleep(1)
        await qa.screenshot("03-logs")

        # ── Test 4: Click Chat nav ──
        print("→ Chat page")
        await qa.click_text("Chat")
        await asyncio.sleep(1)
        await qa.screenshot("04-chat")
        # Verify cofounder is selected by default
        chat_text = await qa.get_text("body")
        qa.results.append({
            "test": "chat_default_cofounder",
            "ok": "cofounder" in chat_text.lower() or "Co-Founder" in chat_text,
            "expected": "cofounder selected",
            "actual": chat_text[:120],
        })

        # ── Test 5: Click Config nav ──
        print("→ Config page")
        await qa.click_text("Config")
        await asyncio.sleep(1)
        await qa.screenshot("05-config")

        # ── Test 6: Click Settings nav ──
        print("→ Settings page")
        await qa.click_text("Settings")
        await asyncio.sleep(1)
        await qa.screenshot("06-settings-dark")

        # ── Test 7: Toggle dark mode ──
        print("→ Toggle dark mode")
        await qa.send("Runtime.evaluate", {
            "expression": """
                Array.from(document.querySelectorAll('button'))
                  .find(b => b.querySelector('span.absolute'))?.click()
            """,
        })
        await asyncio.sleep(1)
        await qa.screenshot("07-settings-light")
        # Check html class
        html_class = await qa.send("Runtime.evaluate", {
            "expression": "document.documentElement.className",
            "returnByValue": True,
        })
        cls = html_class.get("result", {}).get("result", {}).get("value", "")
        qa.results.append({
            "test": "dark_mode_toggle",
            "ok": "light" in cls,
            "expected": "light class on html",
            "actual": cls or "(empty)",
        })

        # Toggle back to dark
        await qa.send("Runtime.evaluate", {
            "expression": """
                Array.from(document.querySelectorAll('button'))
                  .find(b => b.querySelector('span.absolute'))?.click()
            """,
        })
        await asyncio.sleep(1)

        # ── Test 8: Open project wizard ──
        print("→ Project wizard")
        await qa.click_text("Add Project")
        await asyncio.sleep(1)
        await qa.screenshot("08-wizard-step1")
        wizard_text = await qa.get_text("body")
        qa.results.append({
            "test": "wizard_opens",
            "ok": "Pick a project folder" in wizard_text or "Use this folder" in wizard_text,
            "expected": "wizard step 1",
            "actual": wizard_text[:120] if wizard_text else "(empty)",
        })

        # Close wizard
        await qa.send("Runtime.evaluate", {
            "expression": """
                Array.from(document.querySelectorAll('button[aria-label*="lose"], button'))
                  .find(b => b.textContent === '' && b.querySelector('svg'))?.click();
                document.querySelector('[role="dialog"]')?.remove();
            """,
        })
        await asyncio.sleep(0.5)

        # ── Test 9: Header buttons (Start) ──
        print("→ Header Start button")
        await qa.navigate(APP_URL)
        await asyncio.sleep(2)
        await qa.screenshot("09-header-idle")
        # Verify only Start BUTTON visible in header (not Stop button)
        # Check for actual button elements, not the "Stopped" status text
        button_check = await qa.send("Runtime.evaluate", {
            "expression": """JSON.stringify({
                start: !!Array.from(document.querySelectorAll('header button')).find(b => b.textContent.trim() === 'Start'),
                stop: !!Array.from(document.querySelectorAll('header button')).find(b => b.textContent.trim() === 'Stop')
            })""",
            "returnByValue": True,
        })
        result = json.loads(button_check.get("result", {}).get("result", {}).get("value", "{}"))
        has_start = result.get("start", False)
        has_stop = result.get("stop", False)
        qa.results.append({
            "test": "header_idle_only_start",
            "ok": has_start and not has_stop,
            "expected": "Start button visible, Stop button hidden",
            "actual": f"start={has_start} stop={has_stop}",
        })

        # ── Final report ──
        return qa.report()


if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
