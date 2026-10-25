#!/usr/bin/env python3
"""Génère le projet HyperFrames « Le Grand Pronostic » (index.html + compositions/*.html)."""
import os, random

ROOT = os.path.dirname(os.path.abspath(__file__))
TOTAL = 82.2

FONTS = """
@font-face { font-family:'Bebas Neue'; font-weight:400; src:url('assets/fonts/bebas-neue.woff2') format('woff2'); }
@font-face { font-family:'Barlow'; font-weight:400; src:url('assets/fonts/barlow-400.woff2') format('woff2'); }
@font-face { font-family:'Barlow'; font-weight:600; src:url('assets/fonts/barlow-600.woff2') format('woff2'); }
@font-face { font-family:'Barlow'; font-weight:700; src:url('assets/fonts/barlow-700.woff2') format('woff2'); }
"""
TOKENS = """--ink:#f4f6fb; --text:#cdd4e2; --muted:#8592ab; --red:#e62429; --red2:#ff6d61;
  --gold:#f0cf7d; --gold2:#d3a43a; --hud:#78dcff; --card:#0f1420;"""
COMMON = """
#root { position:absolute; inset:0; font-family:'Barlow',sans-serif; color:#f4f6fb; %s }
.bebas { font-family:'Bebas Neue',sans-serif; font-weight:400; letter-spacing:.02em; }
.kicker { font-weight:600; letter-spacing:.42em; color:#f0cf7d; font-size:30px; text-transform:uppercase; }
.red { background:linear-gradient(90deg,#f28a72,#e62429 45%%,#ff6d61); -webkit-background-clip:text; background-clip:text; color:transparent; }
.shield { filter:drop-shadow(0 0 30px rgba(230,36,41,.6)); }
""" % TOKENS
SHIELD = ('<svg class="shield" id="{id}" viewBox="0 0 40 40"><circle cx="20" cy="20" r="19" fill="#e62429"/>'
          '<circle cx="20" cy="20" r="15" fill="#f4f6fb"/><circle cx="20" cy="20" r="11" fill="#e62429"/>'
          '<circle cx="20" cy="20" r="7.5" fill="#2f6fd6"/>'
          '<path d="M20 13.2l1.6 4.6h4.8l-3.9 2.9 1.5 4.6-4-2.9-4 2.9 1.5-4.6-3.9-2.9h4.8z" fill="#f4f6fb"/></svg>')

# Utilitaires JS communs : fromTo sans rendu immédiat, l'état initial vient du CSS ou d'un set à 0.
JS_HELPERS = """
const tl = gsap.timeline({ paused: true });
const ft = (t, a, b, at) => tl.fromTo(t, a, Object.assign({ immediateRender: false }, b), at);
"""

def scene(cid, css, html, js, extra_attrs=''):
    return f"""<template>
  <style>
{FONTS}
{COMMON}
{css}
  </style>
  <div id="root" data-composition-id="{cid}" data-width="1920" data-height="1080"{extra_attrs}>
{html}
  </div>
  <script>
{JS_HELPERS}
{js}
    window.__timelines["{cid}"] = tl;
  </script>
</template>
"""

def write(name, s):
    with open(os.path.join(ROOT, name), 'w') as f:
        f.write(s)

# ---------------------------------------------------------------- fond
rnd = random.Random(7)
stars, star_js = [], []
for i in range(60):
    x, y, sc = rnd.uniform(0, 1920), rnd.uniform(0, 1080), rnd.uniform(.5, 1.4)
    stars.append(f'<i class="star" id="bg-s{i}" style="left:{x:.0f}px;top:{y:.0f}px;width:{3*sc:.1f}px;height:{3*sc:.1f}px"></i>')
    per = rnd.uniform(1.6, 4.5); k = rnd.uniform(0, per); reps = int((TOTAL - k) // per) * 2 - 1
    star_js.append(f'ft("#bg-s{i}", {{opacity:.12}}, {{opacity:{rnd.uniform(.4,.95):.2f}, duration:{per/2:.2f}, yoyo:true, repeat:{reps}, ease:"sine.inOut"}}, {k:.2f});')
write('compositions/bg.html', scene('bg', """
#bg-grad { position:absolute; inset:0; background:
  radial-gradient(1100px 800px at 0% 0%, rgba(150,22,30,.55), transparent 65%),
  radial-gradient(1100px 800px at 100% 100%, rgba(40,70,170,.45), transparent 65%),
  linear-gradient(160deg,#120a14,#06080f 50%,#0a1024); }
#bg-grid { position:absolute; left:0; top:-140px; width:1920px; height:1220px; opacity:.35;
  background-image:radial-gradient(rgba(255,255,255,.18) 1px, transparent 1.4px); background-size:14px 14px; }
.star { position:absolute; border-radius:50%; background:#fff; opacity:.12; }
""", '    <div id="bg-grad"></div><div id="bg-grid"></div>\n    ' + '\n    '.join(stars),
    f'ft("#bg-grid", {{y:0}}, {{y:140, duration:{TOTAL}, ease:"none"}}, 0);\n' + '\n'.join(star_js),
    ' data-layout-allow-overflow'))

# ---------------------------------------------------------------- 1. intro
write('compositions/intro.html', scene('intro', """
#in-box { position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; }
#in-shield { width:190px; height:190px; margin-bottom:34px; }
#in-kicker { font-size:36px; margin-bottom:18px; }
#in-t1 { font-size:250px; line-height:.86; }
#in-t2 { font-size:290px; line-height:.86; }
#in-sub { margin-top:36px; font-size:42px; color:#cdd4e2; }
#in-flash { position:absolute; inset:0; background:#fff; opacity:0; }
""", f"""    <div id="in-box">
      {SHIELD.format(id='in-shield')}
      <div class="kicker" id="in-kicker" data-var-text="kicker">Miss France 2027</div>
      <div class="bebas" id="in-t1">LE GRAND</div>
      <div class="bebas red" id="in-t2">PRONOSTIC</div>
      <div id="in-sub">Le jeu de pronostics des agents du jury</div>
    </div>
    <div id="in-flash"></div>""", """
tl.fromTo("#in-shield", {scale:0, rotation:-200}, {scale:1, rotation:0, duration:1, ease:"back.out(1.6)"}, .3);
ft("#in-flash", {opacity:.55}, {opacity:0, duration:.5}, 1.0);
tl.fromTo("#in-kicker", {opacity:0, scaleX:1.6}, {opacity:1, scaleX:1, duration:1, ease:"power3.out"}, 1.1);
tl.fromTo("#in-t1", {opacity:0, y:80}, {opacity:1, y:0, duration:.8, ease:"power4.out"}, 1.4);
tl.fromTo("#in-t2", {opacity:0, scale:1.4}, {opacity:1, scale:1, duration:.7, ease:"power4.out"}, 1.9);
tl.fromTo("#in-sub", {opacity:0, y:20}, {opacity:1, y:0, duration:.8}, 2.8);
ft("#in-box", {scale:1}, {scale:1.04, duration:5, ease:"none"}, 2.8);
ft("#in-box", {opacity:1}, {opacity:0, duration:.45, ease:"power2.in"}, 7.75);
"""))

# ---------------------------------------------------------------- téléphone (scènes 2 à 6)
W = {'1': 687, '2': 724, '3': 695, '4': 745, '5': 749, '6': 730}
T0 = 8.2  # début absolu du téléphone
def P(img, x, y):
    k = 478 / W[img]; return x * k, y * k
taps = [  # (abs, image, x, y)
    (11.0, '1', 180, 1162), (16.0, '2', 360, 1060), (26.6, '3', 181, 1048),
    (31.4, '3', 181, 1110), (42.6, '5', 240, 1212), (48.0, '6', 362, 966)]
tap_html, tap_js = [], []
for n, (t, img, x, y) in enumerate(taps, 1):
    px, py = P(img, x, y); lt = t - T0
    tap_html.append(f'<div class="tap" id="ph-tap{n}" style="left:{px:.0f}px;top:{py:.0f}px"><i class="dot"></i><i class="ring"></i></div>')
    tap_js.append(f'ft("#ph-tap{n} .dot", {{opacity:0, scale:1.4}}, {{opacity:1, scale:.8, duration:.18, ease:"power2.out"}}, {lt:.2f});'
                  f'ft("#ph-tap{n} .dot", {{opacity:1, scale:.8}}, {{opacity:0, scale:.6, duration:.25}}, {lt+.3:.2f});'
                  f'ft("#ph-tap{n} .ring", {{opacity:.9, scale:.6}}, {{opacity:0, scale:2.4, duration:.6, ease:"power2.out"}}, {lt+.12:.2f});')
L = lambda a: round(a - T0, 2)
write('compositions/phone.html', scene('phone', """
#ph-body { position:absolute; left:250px; top:80px; width:510px; height:920px; border-radius:62px; padding:16px;
  background:linear-gradient(145deg,#2a2f3d,#0c0f17 40%,#1b2030);
  box-shadow:0 0 0 2px rgba(240,207,125,.35), 0 40px 120px rgba(0,0,0,.7), 0 0 90px rgba(230,36,41,.18); }
#ph-screen { position:relative; width:478px; height:888px; border-radius:48px; overflow:hidden; background:#0b0f1a; }
#ph-notch { position:absolute; top:12px; left:174px; width:130px; height:34px; border-radius:20px; background:#000; z-index:5; }
#ph-wrap { position:absolute; inset:0; }
.shot { position:absolute; left:0; top:0; width:478px; opacity:0; }
.tap { position:absolute; width:0; height:0; z-index:6; }
.tap i { position:absolute; left:-35px; top:-35px; width:70px; height:70px; border-radius:50%; opacity:0; }
.tap .dot { background:rgba(255,255,255,.35); border:3px solid #fff; box-shadow:0 0 30px rgba(255,255,255,.7); }
.tap .ring { border:3px solid #f0cf7d; }
#ph-dots { position:absolute; left:133px; top:578px; width:204px; height:68px; display:flex; align-items:center; justify-content:center; gap:22px; z-index:4; opacity:0; }
#ph-dots i { width:18px; height:18px; border-radius:50%; background:#f0cf7d; opacity:0; box-shadow:0 0 12px #f0cf7d; }
#ph-scan { position:absolute; left:0; top:0; width:478px; height:4px; background:#78dcff; box-shadow:0 0 24px 6px rgba(120,220,255,.6); opacity:0; z-index:5; }
""", f"""    <div id="ph-body">
      <div id="ph-screen" data-layout-allow-overflow>
        <div id="ph-notch"></div>
        <div id="ph-wrap">
          <img class="shot" id="ph-i1" src="assets/shots/1.jpg">
          <img class="shot" id="ph-i2" src="assets/shots/2.jpg">
          <img class="shot" id="ph-i6" src="assets/shots/6.jpg">
          <img class="shot" id="ph-i3" src="assets/shots/3.jpg">
          <img class="shot" id="ph-i4" src="assets/shots/4.jpg">
          <img class="shot" id="ph-i5" src="assets/shots/5.jpg">
          <div id="ph-dots"><i></i><i></i><i></i><i></i></div>
          {''.join(tap_html)}
        </div>
        <div id="ph-scan"></div>
      </div>
    </div>""", f"""
const show = (id, at, d) => ft(id, {{opacity:0}}, {{opacity:1, duration:d || .4}}, at);
const hide = (id, at) => ft(id, {{opacity:1}}, {{opacity:0, duration:.01}}, at);
tl.fromTo("#ph-body", {{x:-900, opacity:0}}, {{x:0, opacity:1, duration:.9, ease:"power3.out"}}, .1);
show("#ph-i1", 0, .01);
// Connexion
ft("#ph-i2", {{opacity:0, scale:1.04}}, {{opacity:1, scale:1, duration:.35}}, {L(11.45)});
hide("#ph-i1", {L(11.8)});
show("#ph-dots", {L(12.0)}, .01);
[{L(14.0)}, {L(14.35)}, {L(14.7)}, {L(15.05)}].forEach((t, i) =>
  ft("#ph-dots i:nth-child(" + (i + 1) + ")", {{opacity:0, scale:0}}, {{opacity:1, scale:1, duration:.15, ease:"back.out(3)"}}, t));
// Les 4 phases
hide("#ph-dots", {L(17.5)});
show("#ph-i6", {L(17.5)});
hide("#ph-i2", {L(17.9)});
ft("#ph-wrap", {{scale:1, transformOrigin:"50% 40%"}}, {{scale:1.3, duration:1.6, ease:"power2.inOut"}}, {L(18.0)});
ft("#ph-wrap", {{scale:1.3}}, {{scale:1, duration:.6, ease:"power2.inOut"}}, {L(24.6)});
// Recrues
show("#ph-i3", {L(25.1)});
hide("#ph-i6", {L(25.5)});
// Fiche candidate
show("#ph-i4", {L(35.0)});
hide("#ph-i3", {L(35.4)});
ft("#ph-scan", {{y:40, opacity:0}}, {{y:560, opacity:1, duration:1.1, ease:"sine.inOut"}}, {L(36.0)});
ft("#ph-scan", {{opacity:1}}, {{opacity:0, duration:.3}}, {L(37.1)});
ft("#ph-i4", {{y:0}}, {{y:-300, duration:1.4, ease:"power2.inOut"}}, {L(39.2)});
ft("#ph-i5", {{opacity:0, y:40}}, {{opacity:1, y:0, duration:.5}}, {L(40.4)});
hide("#ph-i4", {L(41.0)});
// Classer au S.H.I.E.L.D.
show("#ph-i6", {L(44.6)});
hide("#ph-i5", {L(45.0)});
ft("#ph-wrap", {{scale:1, transformOrigin:"50% 80%"}}, {{scale:1.35, duration:1.4, ease:"power2.inOut"}}, {L(45.2)});
ft("#ph-wrap", {{scale:1.35}}, {{scale:1, duration:.6}}, {L(53.3)});
ft("#ph-body", {{x:0, opacity:1}}, {{x:-900, opacity:0, duration:.7, ease:"power3.in"}}, {L(54.0)});
// Doigt
{chr(10).join(tap_js)}
"""))

# ---------------------------------------------------------------- panneaux de droite
PANEL_CSS = """
#{p} { position:absolute; left:900px; top:0; width:900px; height:1080px; display:flex; flex-direction:column; justify-content:center; }
#{p} .kicker { margin-bottom:22px; }
#{p} .title { font-size:132px; line-height:.9; margin-bottom:34px; }
#{p} .text { font-size:40px; line-height:1.35; color:#cdd4e2; max-width:840px; }
#{p} .text b { color:#f0cf7d; font-weight:700; }
"""
def panel(cid, kicker, title1, title2, text, extra_html, extra_css, extra_js, dur):
    p = cid + '-p'
    html = f"""    <div id="{p}">
      <div class="kicker" id="{cid}-k">{kicker}</div>
      <div class="bebas title" id="{cid}-t">{title1}<br><span class="red">{title2}</span></div>
      {f'<div class="text" id="{cid}-x">{text}</div>' if text else ''}
      {extra_html}
    </div>"""
    js = f"""
tl.fromTo("#{p}", {{opacity:0, x:60}}, {{opacity:1, x:0, duration:.7, ease:"power3.out"}}, 0);
tl.fromTo("#{p} > *", {{opacity:0, y:30}}, {{opacity:1, y:0, duration:.6, stagger:.12, ease:"power3.out"}}, .1);
{extra_js}
ft("#{p}", {{opacity:1, x:0}}, {{opacity:0, x:-40, duration:.4, ease:"power2.in"}}, {dur - .5:.2f});
"""
    return scene(cid, PANEL_CSS.replace('{p}', p) + extra_css, html, js)

# 2. Connexion (abs 8.6 → 17.7)
write('compositions/login.html', panel('login', 'Étape 1 · Identification', 'IDENTIFIE-TOI,', 'AGENT !',
    'Touche ta photo de <b>super-héros</b>,<br>puis tape ton <b>code d\'accès à 4 chiffres</b>.', '', '', '', 9.1))

# 3. Les 4 phases (abs 17.8 → 25.2)
steps = ''.join(f'<div class="step" id="ph3-st{i}"><div class="c">{i}<i class="on"></i></div><div class="l">{l}</div></div>'
                for i, l in enumerate(['LES 15', 'LES 5', "L'ORDRE", 'LE SACRE'], 1))
write('compositions/phases.html', panel('phases', 'Ta mission', '4 PHASES,', '1 COURONNE', '',
    f'<div class="steps" id="phases-steps">{steps}</div>', """
.steps { display:flex; gap:40px; margin-top:50px; }
.step { text-align:center; width:170px; }
.step .c { position:relative; width:96px; height:96px; margin:0 auto 16px; border-radius:50%; display:flex; align-items:center; justify-content:center;
  font-family:'Bebas Neue'; font-size:58px; color:#8ea0c4; background:#1a2236; border:2px solid #2c3854; }
.step .on { position:absolute; inset:-2px; border-radius:50%; opacity:0; background:linear-gradient(160deg,#f6dc93,#d3a43a);
  box-shadow:0 0 34px rgba(240,207,125,.65); mix-blend-mode:normal; }
.step .l { font-weight:700; letter-spacing:.12em; font-size:28px; color:#8592ab; }
.step .num { position:relative; z-index:1; }
""", '\n'.join(
    f'ft("#ph3-st{i} .on", {{opacity:0, scale:1.35}}, {{opacity:1, scale:1, duration:.4, ease:"back.out(2)"}}, {t - 17.8:.2f});'
    f'ft("#ph3-st{i} .c", {{color:"#8ea0c4"}}, {{color:"#1b1408", duration:.2}}, {t - 17.8:.2f});'
    f'ft("#ph3-st{i} .l", {{color:"#8592ab"}}, {{color:"#f0cf7d", duration:.2}}, {t - 17.8:.2f});'
    for i, t in [(1, 19.6), (2, 20.6), (3, 21.6), (4, 23.0)]), 7.4)
    .replace('<div class="c">', '<div class="c"><span class="num">').replace('<i class="on"></i></div>', '</span><i class="on"></i></div>'))

# 4. Recrues (abs 25.3 → 35.0)
write('compositions/recrues.html', panel('recrues', 'Phase 1 · Les recrues', 'RECRUTE', 'TON ESCOUADE',
    '<b>31 candidates</b>, 15 places dans ton équipe.<br>Et ton <b>essai Miss France Nº1</b> : celle que tu vois couronnée.',
    '<div class="counter" id="recrues-c"><div class="chip" id="recrues-chip"><div class="k">MON ESCOUADE</div><div class="v"><span id="recrues-cnt">0</span> / 15</div></div>'
    '<div class="chip goldc" id="recrues-essai"><div class="k">♛ ESSAI Nº1</div><div class="v">POSÉ</div></div></div>', """
.counter { margin-top:46px; display:flex; gap:28px; }
.chip { padding:22px 34px; background:rgba(15,20,32,.85); border:2px solid rgba(240,207,125,.35);
  clip-path:polygon(0 0,100% 0,100% calc(100% - 22px),calc(100% - 22px) 100%,0 100%); }
.chip .k { font-size:28px; letter-spacing:.2em; color:#f0cf7d; font-weight:600; }
.chip .v { font-family:'Bebas Neue'; font-size:84px; line-height:1; margin-top:6px; }
.goldc { background:linear-gradient(160deg,#f6dc93,#c9982f); border-color:#f6dc93; color:#1b1408; opacity:0; }
.goldc .k { color:#3a2a08; }
""", """
const cnt = { v: 0 }, el = document.getElementById("recrues-cnt");
ft(cnt, { v: 0 }, { v: 15, duration: 3.2, ease: "power1.in", onUpdate: () => { el.textContent = Math.round(cnt.v); } }, 1.7);
ft("#recrues-chip", { boxShadow: "0 0 0px rgba(240,207,125,0)" }, { boxShadow: "0 0 40px rgba(240,207,125,.6)", duration: .3, yoyo: true, repeat: 1 }, 4.9);
ft("#recrues-essai", { opacity: 0, scale: 1.6, rotation: 8 }, { opacity: 1, scale: 1, rotation: 0, duration: .5, ease: "back.out(2)" }, 6.4);
""", 9.7))

# 5. Fiche (abs 35.2 → 44.6)
stats = ''.join(f'<div class="stat" id="fiche-s{i}"><span class="dot"></span>{s}</div>'
                for i, s in enumerate(['Âge', 'Taille', 'Métier', 'Abonnés Instagram', 'Photos', 'Région']))
write('compositions/fiche.html', panel('fiche', 'Dossier candidate', 'SCANNE', 'CHAQUE MISS', '',
    f'<div class="stats" id="fiche-stats">{stats}</div>', """
.stats { display:grid; grid-template-columns:repeat(2, 400px); gap:20px; margin-top:42px; }
.stat { padding:20px 26px; border:2px solid #2a3348; background:rgba(15,20,32,.85); display:flex; align-items:center; gap:20px; font-size:34px; font-weight:600; opacity:0; }
.stat .dot { width:14px; height:14px; border-radius:50%; background:#78dcff; box-shadow:0 0 12px #78dcff; }
""", 'ft("#fiche-stats .stat", {opacity:0, x:40}, {opacity:1, x:0, duration:.45, stagger:.55, ease:"power3.out"}, 2.2);', 9.4))

# 6. S.H.I.E.L.D. (abs 44.8 → 54.3)
write('compositions/shield.html', panel('shield', 'Escouade complète', 'CLASSE TON DOSSIER', 'AU S.H.I.E.L.D.',
    'Ta sélection devient <b>officielle</b>.<br>Tu peux la déclassifier tant que la phase est ouverte.',
    '<div class="stampwrap"><div class="stamp bebas" id="shield-stamp">✓ DOSSIER CLASSÉ</div></div>', """
.stampwrap { margin-top:50px; }
.stamp { display:inline-block; padding:18px 40px; border:6px solid #f0cf7d; color:#f0cf7d; font-size:76px; letter-spacing:.08em; opacity:0;
  box-shadow:0 0 40px rgba(240,207,125,.35), inset 0 0 30px rgba(240,207,125,.2); }
""", 'ft("#shield-stamp", {opacity:0, scale:2.2, rotation:-16}, {opacity:1, scale:1, rotation:-6, duration:.35, ease:"power4.in"}, 3.45);'
     'ft("#shield-p .stampwrap", {x:0}, {x:8, duration:.05, yoyo:true, repeat:5}, 3.8);', 9.5))

# ---------------------------------------------------------------- 7 & 8 : plein écran
FULL_CSS = """
.full { position:absolute; inset:0; padding:0 140px; display:flex; flex-direction:column; justify-content:center; }
.full .head { font-size:118px; line-height:.95; margin-bottom:56px; }
.cards { display:flex; gap:50px; }
.card { flex:1; padding:44px 48px 50px; background:rgba(15,20,32,.9); border:2px solid #2c3854;
  clip-path:polygon(0 0,calc(100% - 34px) 0,100% 34px,100% 100%,34px 100%,0 calc(100% - 34px)); }
.card .ph { font-weight:700; letter-spacing:.3em; color:#ff6d61; font-size:30px; }
.card .ct { font-family:'Bebas Neue'; font-size:92px; line-height:1; margin:12px 0 18px; }
.card .cx { font-size:36px; line-height:1.35; color:#cdd4e2; }
.card .cx b { color:#f0cf7d; }
.row { display:flex; gap:16px; margin-top:30px; }
.badge { width:84px; height:84px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-family:'Bebas Neue'; font-size:50px;
  background:#1a2236; border:2px solid #2c3854; color:#c9d2e6; }
.badge.pick { border:3px solid #e62429; background:rgba(230,36,41,.15); font-family:'Barlow'; font-size:40px; color:#f4f6fb; }
.badge.first { background:linear-gradient(160deg,#f6dc93,#d3a43a); color:#1b1408; border-color:#f6dc93; box-shadow:0 0 30px rgba(240,207,125,.6); }
"""
write('compositions/suite.html', scene('suite', FULL_CSS, """    <div class="full" id="suite-box">
      <div class="kicker" id="suite-k" style="margin-bottom:18px">La suite de la mission</div>
      <div class="bebas head" id="suite-h">ET ENSUITE ?</div>
      <div class="cards">
        <div class="card" id="suite-c2">
          <div class="ph">PHASE 2</div>
          <div class="ct">TES 5 + ESSAI Nº2</div>
          <div class="cx">Il reste <b>15 Miss en lice</b> : choisis tes <b>5</b> et pose ton essai Nº2.</div>
          <div class="row" id="suite-picks"><div class="badge pick">★</div><div class="badge pick">★</div><div class="badge pick">★</div><div class="badge pick">★</div><div class="badge pick">★</div></div>
        </div>
        <div class="card" id="suite-c3">
          <div class="ph">PHASE 3</div>
          <div class="ct">L'ORDRE FINAL</div>
          <div class="cx">Classe les <b>5 finalistes officielles</b>, de la 1<sup>re</sup> à la 5<sup>e</sup>.</div>
          <div class="row" id="suite-ranks"><div class="badge first">1</div><div class="badge">2</div><div class="badge">3</div><div class="badge">4</div><div class="badge">5</div></div>
        </div>
      </div>
    </div>""", """
tl.fromTo("#suite-k, #suite-h", {opacity:0, y:30}, {opacity:1, y:0, duration:.6, stagger:.12}, 0);
tl.fromTo("#suite-c2", {opacity:0, y:80}, {opacity:1, y:0, duration:.7, ease:"power3.out"}, .6);
tl.fromTo("#suite-picks .badge", {scale:0}, {scale:1, duration:.35, stagger:.3, ease:"back.out(2.5)"}, 2.2);
tl.fromTo("#suite-c3", {opacity:0, y:80}, {opacity:1, y:0, duration:.7, ease:"power3.out"}, 5.0);
tl.fromTo("#suite-ranks .badge", {scale:0}, {scale:1, duration:.35, stagger:.3, ease:"back.out(2.5)"}, 6.6);
ft("#suite-box", {opacity:1}, {opacity:0, duration:.4}, 9.75);
"""))

cds = ''.join(f'<div class="cd" id="end-cd{i}"><span>{n}</span><i class="lit{" win" if n == 1 else ""}"></i></div>' for i, n in enumerate([5, 4, 3, 2, 1]))
write('compositions/endgame.html', scene('endgame', FULL_CSS + """
.lock { width:110px; height:120px; }
.countdown { display:flex; gap:22px; margin-top:30px; }
.cd { position:relative; width:96px; height:110px; display:flex; align-items:center; justify-content:center; font-family:'Bebas Neue'; font-size:76px;
  background:#141b2b; border:2px solid #2c3854; color:#5d6a86; }
.cd span { position:relative; z-index:1; }
.cd .lit { position:absolute; inset:-2px; border:2px solid #e62429; box-shadow:0 0 26px rgba(230,36,41,.5); background:#1a2236; opacity:0; }
.cd .lit.win { background:linear-gradient(160deg,#f6dc93,#d3a43a); border-color:#f6dc93; box-shadow:0 0 40px rgba(240,207,125,.7); }
""", f"""    <div class="full" id="end-box">
      <div class="kicker" id="end-k" style="margin-bottom:18px">Phase 4 · Le sacre</div>
      <div class="bebas head" id="end-h">ENDGAME <span class="red">EN DIRECT</span></div>
      <div class="cards">
        <div class="card" id="end-c4">
          <svg class="lock" id="end-lock" viewBox="0 0 44 48"><path d="M12 22v-8a10 10 0 0 1 20 0v8" fill="none" stroke="#f0cf7d" stroke-width="5"/><rect x="4" y="21" width="36" height="25" rx="4" fill="#d3a43a"/><circle cx="22" cy="31" r="4" fill="#1b1408"/><rect x="20.5" y="32" width="3" height="8" fill="#1b1408"/></svg>
          <div class="ct">POINTS SOUS SCELLÉS</div>
          <div class="cx">Pendant l'élection, <b>personne ne voit son score</b>.</div>
        </div>
        <div class="card" id="end-c5">
          <div class="ct">RÉSULTATS PLACE PAR PLACE</div>
          <div class="cx">De la <b>dernière</b> à la <b>première</b> place.</div>
          <div class="countdown">{cds}</div>
        </div>
      </div>
    </div>""", """
tl.fromTo("#end-k, #end-h", {opacity:0, y:30}, {opacity:1, y:0, duration:.6, stagger:.12}, 0);
tl.fromTo("#end-c4", {opacity:0, y:80}, {opacity:1, y:0, duration:.7, ease:"power3.out"}, .6);
tl.fromTo("#end-lock", {opacity:0, scale:2, rotation:-20}, {opacity:1, scale:1, rotation:0, duration:.5, ease:"back.out(2)"}, 1.4);
tl.fromTo("#end-c5", {opacity:0, y:80}, {opacity:1, y:0, duration:.7, ease:"power3.out"}, 4.0);
[0,1,2,3,4].forEach(i => {
  const t = 5.2 + i * .6;
  ft("#end-cd" + i + " .lit", {opacity:0}, {opacity:1, duration:.1}, t);
  ft("#end-cd" + i, {scale:1.3}, {scale:1, duration:.3, ease:"back.out(2)"}, t);
  ft("#end-cd" + i, {color:"#5d6a86"}, {color: i === 4 ? "#1b1408" : "#f4f6fb", duration:.1}, t);
});
ft("#end-box", {opacity:1}, {opacity:0, duration:.4}, 8.8);
"""))

# ---------------------------------------------------------------- 9. outro
heroes = ''.join(f'<img id="out-h{i}" src="assets/av/{i}.png">' for i in range(10))
write('compositions/outro.html', scene('outro', """
#out-box { position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; }
#out-shield { width:150px; height:150px; margin-bottom:20px; }
#out-t { font-size:200px; line-height:.86; }
#out-heroes { display:flex; gap:22px; margin:44px 0 40px; }
#out-heroes img { width:118px; height:118px; border-radius:50%; border:4px solid #d3a43a; box-shadow:0 0 24px rgba(0,0,0,.6); }
#out-cta { font-size:64px; color:#f0cf7d; letter-spacing:.06em; }
#out-flash { position:absolute; inset:0; background:#fff; opacity:0; }
#out-black { position:absolute; inset:0; background:#06080f; opacity:0; }
""", f"""    <div id="out-box">
      {SHIELD.format(id='out-shield')}
      <div class="bebas" id="out-t">LE GRAND <span class="red">PRONOSTIC</span></div>
      <div id="out-heroes">{heroes}</div>
      <div class="bebas" id="out-cta" data-var-text="cta">À TOI DE JOUER, AGENT DU JURY !</div>
    </div>
    <div id="out-flash"></div><div id="out-black"></div>""", """
tl.fromTo("#out-shield", {scale:0, rotation:200}, {scale:1, rotation:0, duration:.8, ease:"back.out(1.6)"}, 0);
ft("#out-flash", {opacity:.4}, {opacity:0, duration:.5}, .5);
tl.fromTo("#out-t", {opacity:0, scale:1.3}, {opacity:1, scale:1, duration:.7, ease:"power4.out"}, .5);
tl.fromTo("#out-heroes img", {opacity:0, y:40, scale:.6}, {opacity:1, y:0, scale:1, duration:.45, stagger:.12, ease:"back.out(2)"}, 1.3);
tl.fromTo("#out-cta", {opacity:0, y:30}, {opacity:1, y:0, duration:.7, ease:"power3.out"}, 3.3);
ft("#out-box", {scale:1}, {scale:1.03, duration:4, ease:"none"}, 3.7);
ft("#out-black", {opacity:0}, {opacity:1, duration:1}, 6.9);
"""))

# ---------------------------------------------------------------- racine
HOSTS = [  # id, start, duration, z
    ('bg', 0, TOTAL, 0), ('intro', 0, 8.3, 2), ('phone', 8.2, 46.6, 3),
    ('login', 8.6, 9.1, 4), ('phases', 17.8, 7.4, 4), ('recrues', 25.3, 9.7, 4),
    ('fiche', 35.2, 9.4, 4), ('shield', 44.8, 9.5, 4),
    ('suite', 54.8, 10.2, 5), ('endgame', 65.0, 9.3, 5), ('outro', 74.3, TOTAL - 74.3, 6)]
VO = [('s1', 1.0), ('s2a', 9.0), ('s2b', 12.4), ('s3', 18.0), ('s4', 25.4), ('s5', 35.6),
      ('s6', 45.0), ('s7', 55.0), ('s8', 65.3), ('s9', 74.6)]
# (fichier, début absolu, volume[, durée])
SFX = [('whoosh-cinematic', .2, .35, 2.5), ('impact-bass-1', 1.0, .5), ('pop', 1.95, .35),
       ('whoosh', 8.2, .35), ('click', 11.1, .45),
       ('key-press', 14.0, .4), ('key-press', 14.35, .4), ('key-press', 14.7, .4), ('key-press', 15.05, .4),
       ('click', 16.1, .45), ('sparkle', 16.25, .3),
       ('whoosh-short', 17.4, .35), ('pop', 19.6, .3), ('pop', 20.6, .3), ('pop', 21.6, .3), ('sparkle', 23.0, .3),
       ('whoosh', 25.0, .35), ('click', 26.7, .45), ('pop', 30.2, .35),
       ('click', 31.5, .45), ('sparkle', 31.75, .35),
       ('whoosh-short', 34.9, .35), ('glitch-1', 36.0, .22, 1.2),
       ('click-soft', 37.45, .35), ('click-soft', 38.0, .35), ('click-soft', 38.55, .35),
       ('click-soft', 39.1, .35), ('click-soft', 39.65, .35), ('click-soft', 40.2, .35),
       ('click', 42.7, .45),
       ('whoosh', 44.5, .35), ('click', 48.1, .45), ('impact-bass-2', 48.25, .5),
       ('whoosh-cinematic', 53.8, .3, 2.0),
       ('pop', 57.0, .3), ('pop', 57.3, .3), ('pop', 57.6, .3), ('pop', 57.9, .3), ('pop', 58.2, .3),
       ('pop', 61.4, .3), ('pop', 61.7, .3), ('pop', 62.0, .3), ('pop', 62.3, .3), ('pop', 62.6, .3),
       ('impact-bass-1', 65.0, .4), ('pop', 66.4, .35),
       ('key-press', 70.2, .4), ('key-press', 70.8, .4), ('key-press', 71.4, .4), ('key-press', 72.0, .4), ('sparkle', 72.6, .35),
       ('riser', 64.77, .18), ('impact-bass-2', 74.75, .55), ('pop', 77.6, .35)]

hosts = '\n'.join(
    f'      <div id="{h}" data-composition-id="{h}" data-composition-src="compositions/{h}.html" data-start="{s}" '
    f'data-duration="{d:.1f}" data-track-index="{i}" data-track-kind="graphics" data-width="1920" data-height="1080" style="z-index:{z}"></div>'
    for i, (h, s, d, z) in enumerate(HOSTS))
import subprocess
def dur(p):
    return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', os.path.join(ROOT, p)],
                                capture_output=True, text=True).stdout)
audios = '\n'.join(f'      <audio id="vo-{k}" class="clip" src="assets/vo/{k}.mp3" data-start="{t}" data-duration="{dur(f"assets/vo/{k}.mp3"):.2f}" data-track-index="20" data-volume="1"></audio>' for k, t in VO)
lanes = []  # fin de la dernière clip sur chaque piste
for n, c in sorted(enumerate(SFX), key=lambda x: x[1][1]):
    f, t, v = c[:3]
    d = c[3] if len(c) > 3 else round(dur(f'assets/sfx/{f}.mp3'), 2)
    lane = next((i for i, e in enumerate(lanes) if e <= t), None)
    if lane is None: lanes.append(0); lane = len(lanes) - 1
    lanes[lane] = t + d
    fade = ' data-fade-out="0.4"' if len(c) > 3 else ''
    audios += f'\n      <audio id="fx{n}" class="clip" src="assets/sfx/{f}.mp3" data-start="{t}" data-duration="{d}"{fade} data-track-index="{21 + lane}" data-volume="{v}"></audio>'

write('index.html', f"""<!doctype html>
<html lang="fr" data-resolution="landscape" data-composition-variables='[{{"id":"kicker","type":"string","label":"Surtitre","default":"Miss France 2027"}},{{"id":"cta","type":"string","label":"Phrase de fin","default":"À TOI DE JOUER, AGENT DU JURY !"}}]'>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <title>Le Grand Pronostic</title>
    <script src="assets/js/gsap.min.js"></script>
    <style>
      * {{ margin:0; padding:0; box-sizing:border-box; }}
      html, body {{ margin:0; width:1920px; height:1080px; overflow:hidden; background:#06080f; }}
      #root {{ position:relative; width:100%; height:100%; }}
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{TOTAL}" data-width="1920" data-height="1080">
{hosts}
{audios}
    </div>
    <script>
      window.__timelines["main"] = gsap.timeline({{ paused: true }});
    </script>
  </body>
</html>
""")
print('ok')
