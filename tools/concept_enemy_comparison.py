"""Reference/model comparison, assembled from the provided sheet and actual renders."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

base=Path(__file__).parent/'blender_previews/concept_enemies_v2'
sheet=Image.open('/home/clau/Downloads/game assets .jpeg').convert('RGB').resize((2048,1117),Image.Resampling.LANCZOS)
out=Image.new('RGB',(2400,1630),'#121b25');draw=ImageDraw.Draw(out)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
title=ImageFont.truetype(font,34);label=ImageFont.truetype(font,25);small=ImageFont.truetype(font,18)
draw.text((45,28),'SPACE RANGER / CONCEPT REBUILD',font=title,fill='#e0e5e7')
draw.text((46,78),'Supplied concept on the left • Actual Blender model render on the right',font=small,fill='#99aabb')
items=[('crawler','RIFT CRAWLER',(240,135,970,573)),('turret','SENTRY TURRET',(1370,122,1910,540)),('gunship','HEAVY GUNSHIP',(240,650,889,1055)),('boss','APEX DREADNOUGHT',(1150,588,1960,1081))]
for i,(kind,name,crop) in enumerate(items):
    x=30+(i%2)*1200;y=130+(i//2)*745
    draw.rounded_rectangle((x,y,x+1140,y+710),radius=12,fill='#1d2935',outline='#3a4b5c',width=2)
    draw.text((x+25,y+21),name,font=label,fill='#e0e5e7')
    draw.text((x+25,y+64),'REFERENCE',font=small,fill='#99aabb')
    draw.text((x+575,y+64),'3D MODEL',font=small,fill='#99aabb')
    ref=sheet.crop(crop);ref.thumbnail((535,550),Image.Resampling.LANCZOS)
    out.paste(ref,(x+22+(535-ref.width)//2,y+125+(540-ref.height)//2))
    model=Image.open(base/(kind+'.png')).convert('RGBA');bounds=model.getchannel('A').getbbox()
    if bounds:model=model.crop(bounds)
    model.thumbnail((540,565),Image.Resampling.LANCZOS)
    out.paste(model,(x+575+(540-model.width)//2,y+115+(565-model.height)//2),model)
out.save(base/'reference_comparison.png')
print(base/'reference_comparison.png')
