import cairosvg, io, math
from PIL import Image, ImageFilter, ImageChops, ImageDraw
S=1024
def svg(body, defs='', w=S, h=S):
    s=f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{DEFS}{defs}</defs>{body}</svg>'
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s.encode(),output_width=w,output_height=h))).convert('RGBA')
DEFS='''
<radialGradient id="disc" cx="45%" cy="35%" r="75%"><stop offset="0" stop-color="#B0245F"/><stop offset=".5" stop-color="#7E1641"/><stop offset="1" stop-color="#3D0A22"/></radialGradient>
<linearGradient id="rg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFE9E1"/><stop offset=".22" stop-color="#E7AE9F"/><stop offset=".45" stop-color="#B9707A"/><stop offset=".62" stop-color="#F6CDC1"/><stop offset=".8" stop-color="#C47F83"/><stop offset="1" stop-color="#8A4652"/></linearGradient>
<linearGradient id="rgv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF1EB"/><stop offset=".45" stop-color="#EDB7A8"/><stop offset=".55" stop-color="#C98A8C"/><stop offset="1" stop-color="#F3C9BD"/></linearGradient>
<linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5A0F31"/><stop offset="1" stop-color="#2A0616"/></linearGradient>
<radialGradient id="face" cx="40%" cy="30%" r="80%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".6" stop-color="#FBEDE6"/><stop offset="1" stop-color="#E9C9BD"/></radialGradient>
<radialGradient id="gloss" cx="50%" cy="20%" r="60%"><stop offset="0" stop-color="#fff" stop-opacity=".75"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
'''
JEWELS=[('#38BDF8','#0369A1','#082F49'),('#FBBF24','#D97706','#78350F'),('#F472B6','#DB2777','#6B0F3A'),('#F87171','#DC2626','#6B0F0F'),('#A3E635','#4D9A1E','#1E4410')]
def woman(i,ang,cx,cy,R,sc=1.0):
    a,b,c=JEWELS[i]
    g=f'''<radialGradient id="h{i}" cx="35%" cy="25%" r="85%"><stop offset="0" stop-color="{a}"/><stop offset=".55" stop-color="{b}"/><stop offset="1" stop-color="{c}"/></radialGradient>'''
    t=f'translate({cx} {cy}) rotate({ang}) translate(0 {-R}) scale({sc})'
    body=f'''<g transform="{t}">
 <path d="M0 -118 C 70 -118 92 -40 84 10 C 76 62 40 96 0 100 C -40 96 -76 62 -84 10 C -92 -40 -70 -118 0 -118 Z" fill="url(#h{i})" stroke="{c}" stroke-width="5"/>
 <ellipse cx="-22" cy="-74" rx="34" ry="22" fill="url(#gloss)" transform="rotate(-25 -22 -74)"/>
 <path d="M0 -62 C 46 -62 60 -10 54 24 C 48 60 24 82 0 84 C -24 82 -48 60 -54 24 C -60 -10 -46 -62 0 -62 Z" fill="url(#face)" stroke="{c}" stroke-opacity=".55" stroke-width="3"/>
 <path d="M-30 18 q10 9 20 0 M10 18 q10 9 20 0" fill="none" stroke="#5A1A2C" stroke-width="5" stroke-linecap="round"/>
 <ellipse cx="-30" cy="38" rx="9" ry="5" fill="#F4A6A6" opacity=".55"/><ellipse cx="30" cy="38" rx="9" ry="5" fill="#F4A6A6" opacity=".55"/>
</g>'''
    return g,body
def flower(cx,cy,R=118,sc=1.0):
    d='';b=''
    for k,i in enumerate([0,1,2,3,4]):
        ang=k*72
        g,w=woman(i,ang,cx,cy,R,sc); d+=g; b+=w
    b+=f'<circle cx="{cx}" cy="{cy}" r="{30*sc}" fill="url(#rgv)" stroke="#8A4652" stroke-width="3"/><circle cx="{cx-8*sc}" cy="{cy-9*sc}" r="{9*sc}" fill="#fff" opacity=".8"/>'
    return d,b
def shadow(img,off=(0,14),blur=18,op=0.55,color=(30,0,12)):
    a=img.split()[3].point(lambda v:int(v*op))
    sh=Image.new('RGBA',img.size,color+(0,)); sh.putalpha(a)
    sh=sh.filter(ImageFilter.GaussianBlur(blur))
    base=Image.new('RGBA',img.size,(0,0,0,0)); base.paste(sh,off,sh)
    return base
def comp(*layers):
    out=Image.new('RGBA',layers[0].size,(0,0,0,0))
    for l in layers: out=Image.alpha_composite(out,l)
    return out

C=512
def badge():
    # metal bezel + dark text band + inner disc
    ring=svg(f'''<circle cx="{C}" cy="{C}" r="492" fill="url(#rg)"/>
<circle cx="{C}" cy="{C}" r="476" fill="url(#band)"/>
<circle cx="{C}" cy="{C}" r="476" fill="none" stroke="#3D0A22" stroke-width="3"/>
<circle cx="{C}" cy="{C}" r="372" fill="url(#rg)"/>
<circle cx="{C}" cy="{C}" r="356" fill="url(#disc)"/>
<circle cx="{C}" cy="{C}" r="489" fill="none" stroke="#FFF4EF" stroke-opacity=".7" stroke-width="2"/>''')
    # inner disc subtle lotus rays
    rays=''.join(f'<path d="M{C} {C} L{C+340*math.cos(math.radians(a-3))} {C+340*math.sin(math.radians(a-3))} L{C+340*math.cos(math.radians(a+3))} {C+340*math.sin(math.radians(a+3))}Z" fill="#fff" opacity=".035"/>' for a in range(0,360,12))
    rays=svg(rays)
    # bevel shading on inner rim
    bev=svg(f'<circle cx="{C}" cy="{C}" r="356" fill="none" stroke="#000" stroke-opacity=".35" stroke-width="18" transform="translate(0 -6)"/>')
    bev=bev.filter(ImageFilter.GaussianBlur(10))
    mask=svg(f'<circle cx="{C}" cy="{C}" r="356" fill="#fff"/>').split()[3]
    bev.putalpha(ImageChops.multiply(bev.split()[3],mask))
    # text on band
    txt=svg(f'''<path id="top" d="M {C-424} {C} A 424 424 0 0 1 {C+424} {C}" fill="none"/>
<path id="bot" d="M {C-424} {C} A 424 424 0 0 0 {C+424} {C}" fill="none"/>
<text font-family="Poppins" font-weight="800" font-size="70" letter-spacing="10" fill="url(#rgv)"><textPath xlink:href="#top" startOffset="50%" text-anchor="middle">CHERANMOOLA</textPath></text>
<text font-family="Poppins" font-weight="800" font-size="60" letter-spacing="14" fill="url(#rgv)" dominant-baseline="hanging"><textPath xlink:href="#bot" startOffset="50%" text-anchor="middle">LADIES WING</textPath></text>
<text x="{C-424}" y="{C+14}" text-anchor="middle" font-family="Poppins" font-weight="700" font-size="28" fill="url(#rgv)">EST</text>
<text x="{C+424}" y="{C+14}" text-anchor="middle" font-family="Poppins" font-weight="700" font-size="28" fill="url(#rgv)">2026</text>
''')
    # bottom text: check placement; star separators
    stars=svg(''.join(f'<path transform="translate({C+424*math.cos(math.radians(a))} {C+424*math.sin(math.radians(a))}) scale(1.4)" d="M0 -10 L3 -3 10 0 3 3 0 10 -3 3 -10 0 -3 -3Z" fill="url(#rgv)"/>' for a in (160,200,-20,20)))
    d,f=flower(C,C-58,R=112,sc=0.82)
    fl=svg(f,d)
    script=svg(f'''<text x="{C}" y="{C+222}" text-anchor="middle" font-family="Great Vibes" font-size="128" fill="url(#rgv)">CheraSakhi</text>
<path d="M{C-150} {C+258} Q{C} {C+282} {C+150} {C+258}" fill="none" stroke="url(#rgv)" stroke-width="4" stroke-linecap="round"/>
<path transform="translate({C} {C+270})" d="M0 -9 L3 -3 9 0 3 3 0 9 -3 3 -9 0 -3 -3Z" fill="#FFF1EB"/>''')
    glow=svg(f'<circle cx="{C}" cy="{C-60}" r="230" fill="#FF8FB8" opacity=".35"/>').filter(ImageFilter.GaussianBlur(60))
    out=comp(shadow(ring,(0,22),26,.6),ring,rays,bev,glow,shadow(txt,(0,4),3,.9,(20,0,8)),txt,stars,
             shadow(fl,(0,18),16,.7),fl,shadow(script,(0,5),4,.8,(20,0,8)),script)
    # top-left specular sheen across whole badge
    sheen=svg(f'<ellipse cx="{C-120}" cy="{C-300}" rx="360" ry="170" fill="#fff" opacity=".10" transform="rotate(-25 {C-120} {C-300})"/>').filter(ImageFilter.GaussianBlur(30))
    m=svg(f'<circle cx="{C}" cy="{C}" r="492" fill="#fff"/>').split()[3]
    sheen.putalpha(ImageChops.multiply(sheen.split()[3],m))
    return Image.alpha_composite(out,sheen)

def icon(fg_only=False):
    d,f=flower(C,C-10,R=128 if not fg_only else 100,sc=1.05 if not fg_only else 0.82)
    fl=svg(f,d)
    layers=[]
    if not fg_only:
        bg=svg(f'<rect width="{S}" height="{S}" fill="url(#disc)"/><circle cx="{C}" cy="{C-10}" r="380" fill="none" stroke="url(#rg)" stroke-width="10"/>')
        glow=svg(f'<circle cx="{C}" cy="{C-10}" r="270" fill="#FF8FB8" opacity=".35"/>').filter(ImageFilter.GaussianBlur(70))
        layers=[bg,glow]
    return comp(*(layers or [Image.new('RGBA',(S,S),(0,0,0,0))]),shadow(fl,(0,20),18,.7),fl)

b=badge(); b.save('logo.png')
icon().convert('RGB').save('app_icon.png'); icon(True).save('app_icon_foreground.png')
