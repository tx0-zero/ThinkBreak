#!/usr/bin/env python3
"""Generate the tracked ThinkBreak icon and documentation UI images using Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import subprocess, shutil

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
DOCS = ROOT / "docs/images"
ASSETS.mkdir(exist_ok=True); DOCS.mkdir(parents=True, exist_ok=True)

font_candidates = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]
font_path = next(p for p in font_candidates if Path(p).exists())
def font(size, bold=False):
    if bold and Path('/System/Library/Fonts/SFNS.ttf').exists():
        return ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', size)
    return ImageFont.truetype(font_path, size)

def rr(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def icon_image(size):
    im = Image.new('RGBA', (size,size), (0,0,0,0)); d=ImageDraw.Draw(im)
    s=size/1024
    rr(d,(64*s,64*s,960*s,960*s),218*s,'#111722')
    # subtle diagonal layers
    d.polygon([(64*s,640*s),(64*s,960*s),(960*s,960*s),(960*s,270*s)],fill='#0b1019')
    w=max(2,int(58*s))
    d.line((330*s,250*s,694*s,250*s),fill='#f7f9fc',width=w)
    d.line((330*s,774*s,694*s,774*s),fill='#f7f9fc',width=w)
    d.line([(376*s,284*s),(376*s,350*s),(430*s,445*s),(512*s,512*s),(430*s,579*s),(376*s,674*s),(376*s,740*s)],fill='#f7f9fc',width=w,joint='curve')
    d.line([(648*s,284*s),(648*s,350*s),(594*s,445*s),(512*s,512*s),(594*s,579*s),(648*s,674*s),(648*s,740*s)],fill='#f7f9fc',width=w,joint='curve')
    d.polygon([(478*s,420*s),(610*s,512*s),(478*s,604*s)], fill='#63e2bd')
    d.ellipse((736*s,210*s,820*s,294*s), fill='#63e2bd')
    return im

iconset=ASSETS/'ThinkBreak.iconset'
if iconset.exists(): shutil.rmtree(iconset)
iconset.mkdir()
for pts,scale in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]:
    px=pts*scale
    name=f'icon_{pts}x{pts}' + ('@2x' if scale==2 else '') + '.png'
    icon_image(px).save(iconset/name)
subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(ASSETS/'ThinkBreak.icns')],check=True)
shutil.rmtree(iconset)
icon_image(1024).save(ASSETS/'thinkbreak-icon.png')

BG='#f3f4f7'; PANEL='#ffffff'; LINE='#d7d9df'; TEXT='#17191f'; MUTED='#6c7079'; BLUE='#3478f6'; GREEN='#31c79a'

def label(d, xy, text, size=22, color=TEXT, bold=False, anchor=None):
    d.text(xy,text,font=font(size,bold),fill=color,anchor=anchor)

def chrome(im,title):
    d=ImageDraw.Draw(im); rr(d,(20,20,im.width-20,im.height-20),22,PANEL,'#c9ccd3',2)
    d.rectangle((21,70,im.width-21,71),fill=LINE)
    for i,c in enumerate(['#ff5f57','#febc2e','#28c840']): d.ellipse((42+i*30,40,58+i*30,56),fill=c)
    label(d,(im.width/2,47),title,18,MUTED,anchor='mm')
    return d

def toggle(d,x,y,on=True,disabled=False):
    color=GREEN if on else '#c6c8cd'; color='#dedfe3' if disabled else color
    rr(d,(x,y,x+64,y+34),17,color)
    cx=x+47 if on else x+17
    d.ellipse((cx-14,y+3,cx+14,y+31),fill='white')

# menu screenshot
im=Image.new('RGB',(900,620),BG); d=chrome(im,'ThinkBreak 菜单栏')
rr(d,(245,105,655,545),16,'#fbfbfc','#d0d2d8',2)
label(d,(278,140),'ThinkBreak',30,TEXT,True); d.ellipse((590,125,622,157),fill=GREEN)
items=[('启用自动切换',True),('等待内容：抖音',False),('立即打开当前内容',False),('设置…',False),('退出 ThinkBreak',False)]
y=205
for text,on in items:
    if text=='设置…': d.line((270,y-16,630,y-16),fill=LINE,width=2)
    label(d,(285,y),text,23,TEXT)
    if on: toggle(d,555,y-7,True)
    if '抖音' in text: label(d,(606,y),'✓',25,GREEN,True)
    y+=67
im.save(DOCS/'menu.png')

# full settings
im=Image.new('RGB',(1480,1200),BG); d=chrome(im,'ThinkBreak 设置')
d.rectangle((21,72,388,1178),fill='#f6f6f8'); d.line((388,72,388,1178),fill=LINE,width=2)
label(d,(58,115),'等待内容',27,TEXT,True)
rr(d,(40,155,366,215),10,'#e6edf9'); label(d,(68,185),'▶  抖音',23,TEXT,True); label(d,(330,185),'✓',24,GREEN,True)
label(d,(68,252),'▣  小说',23,TEXT)
label(d,(55,1132),'+     −                         ↑   ↓',28,MUTED)
label(d,(435,120),'ThinkBreak 设置',34,TEXT,True)
# groups
rr(d,(430,165,1420,295),14,PANEL,LINE,2); label(d,(470,205),'自动切换',25,TEXT,True); label(d,(470,245),'已开启：任务超过等待时间后会打开当前内容。',20,MUTED); toggle(d,1310,207,True)
rr(d,(430,320,1420,610),14,PANEL,LINE,2); label(d,(470,360),'当前内容',22,MUTED); label(d,(470,410),'名称',20,MUTED); rr(d,(590,385,1365,435),8,'#fafafa',LINE); label(d,(612,410),'抖音',21)
label(d,(470,475),'网址',20,MUTED); rr(d,(590,450,1240,500),8,'#fafafa',LINE); label(d,(612,475),'https://www.douyin.com/',20)
rr(d,(1255,450,1365,500),8,'#f4f4f6',LINE); label(d,(1310,475),'保存',18,anchor='mm')
label(d,(470,540),'类型：媒体',20); label(d,(730,540),'启用此内容',20); toggle(d,860,523,True)
rr(d,(1080,520,1230,570),8,'#f4f4f6',LINE); label(d,(1155,545),'设为当前',18,anchor='mm'); rr(d,(1245,520,1365,570),8,BLUE); label(d,(1305,545),'立即打开',18,'white',anchor='mm')
rr(d,(430,635,1420,765),14,PANEL,LINE,2); label(d,(470,675),'触发时间',22,MUTED); label(d,(470,720),'任务运行 2 秒后切出      安全时限 30 分钟',21)
rr(d,(430,790,1420,925),14,PANEL,LINE,2); label(d,(470,830),'看广告换 Token（玩梗）',22,MUTED); label(d,(470,872),'当前只是预留开关，不展示广告，也不会增加 Token。',20,MUTED); toggle(d,1300,842,False,True); label(d,(1210,900),'暂未开放',18,MUTED)
rr(d,(430,950,1420,1095),14,PANEL,LINE,2); label(d,(470,990),'首次使用',22,MUTED)
for x,t in [(470,'授予辅助功能权限'),(750,'Chrome 脚本设置'),(1020,'测试 Chrome')]: rr(d,(x,1020,x+235,1070),8,'#f4f4f6',LINE); label(d,(x+117,1045),t,18,anchor='mm')
im.save(DOCS/'settings.png')

# ad closeup
im=Image.new('RGB',(1200,560),BG); d=chrome(im,'ThinkBreak 设置 · 玩梗功能区')
rr(d,(100,140,1100,440),18,PANEL,LINE,2); label(d,(145,190),'看广告换 Token（玩梗）',27,MUTED)
label(d,(145,250),'等待时看广告',30,TEXT,True)
label(d,(145,300),'传说打开以后可以边等边看广告换 Token。',22,MUTED)
label(d,(145,337),'当前只是预留开关，不会展示广告，也不会真的增加 Token。',22,MUTED)
toggle(d,920,260,False,True); label(d,(952,330),'暂未开放',19,MUTED,anchor='mm')
im.save(DOCS/'ad-joke.png')
