#!/usr/bin/env python3
"""Rebrand a RustDesk source checkout as "HelperBee" (subtitle "Remote assistance · powered by RustDesk").

  python3 apply-branding.py <rustdesk-checkout>

Internal APP_NAME is "HelperBeeRemote": RustDesk derives the install dir, exe, Windows service and
config file names from it, and "HelperBee" alone would collide with the HelperBee agent folder.
The HelperBee agent detects both flavors. Every edit is pattern-based and reported; a pattern that
no longer matches (new RustDesk version) is printed as SKIP instead of failing silently.
AGPL-3.0: the branded build must be published with its source (the fork is public).
"""
import os, pathlib, re, sys

APP = "HelperBeeRemote"
TITLE = "HelperBee"
PRODUCT = "HelperBee - RustDesk"          # Windows product name / window title
SUB = "RustDesk · remote assistance"
ACCENT = "0xFFEF443B"
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
ok = skip = 0


def edit(rel, pattern, repl, count=1, flags=0):
    global ok, skip
    f = root / rel
    if not f.exists():
        print(f"SKIP {rel}: missing"); skip += 1; return
    s = f.read_text(encoding="utf-8")
    n = re.subn(pattern, repl, s, count=count, flags=flags)
    if n[1] == 0:
        print(f"SKIP {rel}: pattern not found: {pattern[:60]}"); skip += 1; return
    f.write_text(n[0], encoding="utf-8"); ok += 1
    print(f"ok   {rel} ({n[1]})")


# 1. application name (drives paths, service, config file names)
# set in the main crate (libs/hbb_common is a submodule that the fork would not carry)
edit("src/core_main.rs", r"(pub fn core_main\(\) -> Option<CoreMainAction> \{\n)",
     rf'\g<1>    *hbb_common::config::APP_NAME.write().unwrap() = "{APP}".to_owned();\n')
# 2. Windows binary metadata
edit("Cargo.toml", r'(ProductName\s*=\s*")[^"]*(")', rf"\g<1>{PRODUCT}\g<2>")
edit("Cargo.toml", r'(FileDescription\s*=\s*")[^"]*(")', rf"\g<1>{PRODUCT}\g<2>")
edit("Cargo.toml", r'(OriginalFilename\s*=\s*")[^"]*(")', rf"\g<1>{APP.lower()}.exe\g<2>")
edit("flutter/windows/runner/Runner.rc", r'"RustDesk"', f'"{PRODUCT}"', count=0)
# 3. Flutter theme: HelperBee accent
edit("flutter/lib/common.dart", r"(static const Color accent = Color\()0x[0-9A-Fa-f]{8}(\))", rf"\g<1>{ACCENT}\g<2>")
edit("flutter/lib/common.dart", r"(static const Color button = Color\()0x[0-9A-Fa-f]{8}(\))", rf"\g<1>{ACCENT}\g<2>")
# 4. Desktop home: HelperBee header (live status, click = HelperBee panel) + HelperBee button bottom right.
#    The panel (helperbee_panel.dart) shows connection, the remote-assistance apps of this PC with their IDs,
#    password policy and the assistance request, from the local HelperBee agent API.
PANEL = os.environ.get("HB_PANEL") or str(pathlib.Path(__file__).resolve().parent / "helperbee_panel.dart")
(root / "flutter/lib/desktop/pages/helperbee_panel.dart").write_text(pathlib.Path(PANEL).read_text(encoding="utf-8"), encoding="utf-8")
ok += 1; print("ok   flutter/lib/desktop/pages/helperbee_panel.dart")
HOME = "flutter/lib/desktop/pages/desktop_home_page.dart"
edit(HOME, r"(import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';\n)", r"\g<1>import 'package:flutter_hbb/desktop/pages/helperbee_panel.dart';\n")
edit(HOME, r"(Widget buildLeftPane\(BuildContext context\) \{.*?Column\(\s*children: \[)", r"\g<1>\n                    const HelperBeeHeader(),", flags=re.S)
edit(HOME, r"(Widget build\(BuildContext context\) \{.*?return _buildBlock\(\s*child: )Row\((.*?)\n    \)\);\n  \}",
     r"\g<1>Stack(fit: StackFit.expand, children: [Row(\g<2>\n    ), const Positioned(right: 18, bottom: 44, child: HelperBeeFab())]));\n  }", flags=re.S)

# 5. icons (rounded red square + monitor, same as the HelperBee web GUI)
try:
    from PIL import Image, ImageDraw
except ImportError:
    print("SKIP icons: pip install pillow"); skip += 1
else:
    # the HelperBee mark exported by scripts/brand-export.mjs (rsvg-convert -w 512 brand/mark.svg -o brand/mark-512.png)
    MARK = Image.open(os.environ.get("HB_MARK") or str(pathlib.Path(__file__).resolve().parents[2] / "brand" / "mark-512.png")).convert("RGBA")
    def logo(n):
        return MARK.resize((n, n), Image.LANCZOS)
    big = logo(512)
    for rel, n in [("res/icon.png", 512), ("res/128x128.png", 128), ("res/128x128@2x.png", 256), ("res/32x32.png", 32),
                   ("res/64x64.png", 64), ("flutter/assets/helperbee.png", 256), ("flutter/assets/icon.png", 256)]:
        p = root / rel
        if p.parent.exists():
            logo(n).save(p); ok += 1; print(f"ok   {rel}")
    for rel in ["res/icon.ico", "res/tray-icon.ico", "flutter/windows/runner/resources/app_icon.ico"]:
        p = root / rel
        if p.parent.exists():
            big.save(p, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]); ok += 1; print(f"ok   {rel}")

print(f"\n{ok} edits applied, {skip} skipped")
sys.exit(1 if ok == 0 else 0)
