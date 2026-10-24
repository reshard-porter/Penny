"""Renders Penny's app icons and brand images from SVG with headless Chromium."""
import os
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "/home/claude/icons")
OUT.mkdir(parents=True, exist_ok=True)

THEMES = {
    # name: background stops, glow, coin stops, rim, bars, highlight
    "default": dict(bg=["#1A2B6D", "#0E1740", "#070B22"], glow="#C8F25A", glow_op=0.55,
                    coin=["#F2FFB0", "#D8F36A", "#9ED53A"], rim=["#FBFFE0", "#7FB52A"],
                    bars="#101A44", ring="#0E1740"),
    "midnight": dict(bg=["#1B1D24", "#0C0D11", "#000000"], glow="#B6FF3B", glow_op=0.75,
                     coin=["#E9FF9C", "#C4F542", "#7BC21E"], rim=["#F7FFD6", "#5E9A12"],
                     bars="#06070A", ring="#0C0D11"),
    "sunrise": dict(bg=["#FFB36B", "#FF6A6A", "#B8306E"], glow="#FFE2A8", glow_op=0.65,
                    coin=["#FFFFFF", "#FFF2DD", "#FFD4A3"], rim=["#FFFFFF", "#E59A62"],
                    bars="#7A1F4A", ring="#B8306E"),
    "ocean": dict(bg=["#2FD3C6", "#1386B8", "#0B3A78"], glow="#B5FFF4", glow_op=0.55,
                  coin=["#FFFFFF", "#E6FBFF", "#B8EBF5"], rim=["#FFFFFF", "#5BB7CF"],
                  bars="#0B3A78", ring="#0B3A78"),
}


def coin_group(t, cx=512, cy=512, r=338, shadow=True):
    bars = []
    # three rising bars inside the coin (heights echo the original Penny mark)
    width = 86
    gap = 38
    base = cy + 146
    heights = [168, 286, 222]
    x0 = cx - (3 * width + 2 * gap) / 2
    for i, h in enumerate(heights):
        x = x0 + i * (width + gap)
        bars.append(f'<rect x="{x:.1f}" y="{base - h:.1f}" width="{width}" height="{h}" rx="22" fill="url(#barFill)"/>')
    shadow_svg = (
        f'<ellipse cx="{cx}" cy="{cy + r * 0.92}" rx="{r * 0.82}" ry="{r * 0.16}" fill="#000" opacity="0.35" filter="url(#soft)"/>'
        if shadow else ""
    )
    return f"""
    {shadow_svg}
    <circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#rim)"/>
    <circle cx="{cx}" cy="{cy}" r="{r - 22}" fill="url(#coin)"/>
    <circle cx="{cx}" cy="{cy}" r="{r - 58}" fill="none" stroke="{t['ring']}" stroke-opacity="0.16" stroke-width="6"/>
    <circle cx="{cx}" cy="{cy}" r="{r - 22}" fill="url(#sheen)"/>
    {''.join(bars)}
    <path d="M {cx - r * 0.62} {cy - r * 0.42} A {r * 0.78} {r * 0.78} 0 0 1 {cx + r * 0.18} {cy - r * 0.78}"
          stroke="#FFFFFF" stroke-opacity="0.75" stroke-width="16" stroke-linecap="round" fill="none" filter="url(#tiny)"/>
    """


def defs(t, mono=False):
    coin = t["coin"]
    rim = t["rim"]
    bars = t["bars"]
    if mono:
        coin = ["#FFFFFF", "#E6E6E6", "#BDBDBD"]
        rim = ["#FFFFFF", "#9A9A9A"]
        bars = "#2A2A2A"
    return f"""
    <defs>
      <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="{t['bg'][0]}"/>
        <stop offset="0.55" stop-color="{t['bg'][1]}"/>
        <stop offset="1" stop-color="{t['bg'][2]}"/>
      </linearGradient>
      <radialGradient id="glow" cx="0.5" cy="0.52" r="0.5">
        <stop offset="0" stop-color="{t['glow']}" stop-opacity="{t['glow_op']}"/>
        <stop offset="0.6" stop-color="{t['glow']}" stop-opacity="0.08"/>
        <stop offset="1" stop-color="{t['glow']}" stop-opacity="0"/>
      </radialGradient>
      <radialGradient id="corner" cx="0.1" cy="0.0" r="0.9">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.18"/>
        <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
      </radialGradient>
      <linearGradient id="coin" x1="0.15" y1="0.05" x2="0.85" y2="0.95">
        <stop offset="0" stop-color="{coin[0]}"/>
        <stop offset="0.5" stop-color="{coin[1]}"/>
        <stop offset="1" stop-color="{coin[2]}"/>
      </linearGradient>
      <linearGradient id="rim" x1="0.2" y1="0" x2="0.8" y2="1">
        <stop offset="0" stop-color="{rim[0]}"/>
        <stop offset="1" stop-color="{rim[1]}"/>
      </linearGradient>
      <radialGradient id="sheen" cx="0.32" cy="0.25" r="0.75">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>
        <stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0.0"/>
        <stop offset="1" stop-color="#000000" stop-opacity="0.10"/>
      </radialGradient>
      <linearGradient id="barFill" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="{bars}" stop-opacity="0.92"/>
        <stop offset="1" stop-color="{bars}"/>
      </linearGradient>
      <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="28"/></filter>
      <filter id="tiny" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
      <filter id="big" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="60"/></filter>
    </defs>"""


def icon_svg(t, background=True, mono=False):
    bg = ""
    if background:
        bg = f"""
        <rect width="1024" height="1024" fill="url(#bg)"/>
        <rect width="1024" height="1024" fill="url(#corner)"/>
        <circle cx="512" cy="540" r="470" fill="url(#glow)"/>
        <g opacity="0.07" fill="none" stroke="#FFFFFF" stroke-width="2">
          <circle cx="512" cy="520" r="380"/><circle cx="512" cy="520" r="430"/><circle cx="512" cy="520" r="480"/>
        </g>"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
      {defs(t, mono)}
      {bg}
      {coin_group(t, shadow=background)}
    </svg>"""


def classic_svg():
    return """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
      <rect width="1024" height="1024" fill="#D8F36A"/>
      <rect x="288" y="496" width="112" height="240" fill="#14213D"/>
      <rect x="464" y="288" width="112" height="448" fill="#14213D"/>
      <rect x="640" y="400" width="112" height="336" fill="#14213D"/>
    </svg>"""


def render(page, svg, path, size=1024, transparent=False):
    html = f"""<html><head><style>html,body{{margin:0;padding:0;background:transparent}}</style></head>
    <body>{svg}</body></html>"""
    page.set_viewport_size({"width": 1024, "height": 1024})
    page.set_content(html)
    page.screenshot(path=str(path), omit_background=transparent, clip={"x": 0, "y": 0, "width": 1024, "height": 1024})


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(device_scale_factor=1)
    for name, theme in THEMES.items():
        render(page, icon_svg(theme), OUT / f"icon-{name}.png")
    render(page, icon_svg(THEMES["default"], background=False), OUT / "icon-default-dark.png", transparent=True)
    render(page, icon_svg(THEMES["default"], background=False, mono=True), OUT / "icon-default-tinted.png", transparent=True)
    render(page, classic_svg(), OUT / "icon-classic.png")
    render(page, icon_svg(THEMES["default"], background=False), OUT / "coin.png", transparent=True)
    browser.close()
print("done", sorted(os.listdir(OUT)))
