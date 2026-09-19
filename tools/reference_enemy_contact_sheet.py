"""Lay out actual Blender renders for review; does not alter the game textures."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys

OUT = Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).parent / 'blender_previews/reference_enemies'
canvas = Image.new('RGB', (1800, 1320), '#111a24')
draw = ImageDraw.Draw(canvas)
font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
title = ImageFont.truetype(font_path, 38)
label = ImageFont.truetype(font_path, 25)
small = ImageFont.truetype(font_path, 18)
draw.text((48, 30), 'SPACE RANGER / MECHANICAL ENEMY LIBRARY', font=title, fill='#e4e6df')
draw.text((50, 87), 'Blender-authored 3D models • Reference-inspired armor, machinery and optics', font=small, fill='#9caebd')
items = [('crawler', 'RIFT CRAWLER', 'Articulated predator / red optics', '#ed414b'),
         ('turret', 'SENTRY TURRET', 'Anchored base / independent aiming head', '#ef9d3c'),
         ('gunship', 'HEAVY GUNSHIP', 'Armored nacelles / violet energy intakes', '#a275e6'),
         ('boss', 'APEX DREADNOUGHT', 'Siege cannons / segmented reactor', '#ed414b')]
for i, (kind, name, note, accent) in enumerate(items):
    x = 40 + (i % 2) * 880
    y = 137 + (i // 2) * 575
    draw.rounded_rectangle((x,y,x+840,y+550), radius=15, fill='#1b2633', outline='#354454', width=2)
    draw.rectangle((x+25,y+25,x+30,y+69), fill=accent)
    draw.text((x+46,y+21), name, font=label, fill='#e6e8e2')
    draw.text((x+46,y+56), note, font=small, fill='#9caebd')
    asset = Image.open(OUT / (kind + '.png')).convert('RGBA')
    bounds = asset.getchannel('A').getbbox()
    if bounds:
        asset = asset.crop(bounds)
    asset.thumbnail((765,425), Image.Resampling.LANCZOS)
    canvas.paste(asset, (x+(840-asset.width)//2,y+104+(425-asset.height)//2), asset)
draw.text((48,1290), 'Actual model renders • Editable .blend source + game-integrated GLB assets', font=small, fill='#869bac')
canvas.save(OUT / 'enemy_library.png')
print(OUT / 'enemy_library.png')
