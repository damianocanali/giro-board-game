import pathlib
HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
src = open(ROOT / 'prototype' / 'index.html', encoding='utf-8').read()
def R(a, b):
    global src
    assert a in src, a[:80]; src = src.replace(a, b, 1)
PRE = r"""<script>
window.__VT = 0; performance.now = () => window.__VT;
window.__raf = null; window.requestAnimationFrame = cb => { window.__raf = cb; return 1; };
const __timers = []; let __tid = 1;
window.setTimeout = (fn, ms=0) => { const id = __tid++; __timers.push({ id, at: window.__VT + (ms||0), fn }); return id; };
window.clearTimeout = id => { const i = __timers.findIndex(t => t.id===id); if (i>=0) __timers.splice(i,1); };
window.__runTimers = () => { __timers.sort((a,b)=>a.at-b.at); while (__timers.length && __timers[0].at <= window.__VT){ const t = __timers.shift(); try { t.fn(); } catch(e){ console.error(e); } } };
let __s = 4242; Math.random = () => ((__s = (__s*16807) % 2147483647) / 2147483647);
window.SFXEV = []; window.SFX = (k, n) => window.SFXEV.push({ t: +((window.__VT - 1000)/1000).toFixed(3), k, n: n||72 });
</script>
"""
CSS = r"""<style>
body{padding:0!important;overflow:hidden} header,.cards{display:none!important} .wrap{max-width:none;padding:0;gap:0}
.stage{height:720px!important;min-height:0;border-radius:0;border:0}
.toast,.rolled{transition:none!important}
.vcap{position:absolute;left:24px;bottom:24px;width:410px;box-sizing:border-box;background:rgba(255,255,255,.97);border-radius:20px;padding:18px 22px;box-shadow:0 16px 40px rgba(27,34,48,.18);opacity:0;pointer-events:none}
.vcap.top{bottom:auto;top:76px}
.vcap .k{font:600 12px var(--mono);letter-spacing:.1em;text-transform:uppercase;color:var(--mine);margin-bottom:6px}
.vcap h2{font:400 30px/1.05 var(--display);margin:0 0 6px}
.vcap p{font:600 15.5px/1.4 var(--body);color:var(--ink-2);margin:0}
.vfull{position:absolute;inset:0;display:grid;place-items:center;text-align:center;opacity:0;pointer-events:none}
.vfull .w{font:400 150px/1 var(--display);letter-spacing:-.02em;color:var(--ink)} .vfull .w span{color:var(--mine)}
.vfull p{font:800 26px var(--body);margin-top:10px;background:rgba(255,255,255,.9);display:inline-block;padding:6px 16px;border-radius:12px}
.vfull .tag{display:inline-block;margin-top:18px;font:600 13px var(--mono);letter-spacing:.08em;text-transform:uppercase;color:var(--ink-2);border:2px solid var(--line);border-radius:99px;padding:6px 14px;background:#fff}
#vtitle{background:radial-gradient(ellipse at center, rgba(238,241,245,.92) 0%, rgba(238,241,245,.55) 55%, rgba(238,241,245,0) 80%)}
#vend{background:rgba(238,241,245,.94)}
</style>
"""
R('<script src="https://cdnjs', PRE + CSS + '<script src="https://cdnjs')
R('<div class="hud toast" id="toast" style="opacity:0"></div>', '<div class="hud toast" id="toast" style="opacity:0"></div>\n<div class="vcap" id="vcap"><div class="k" id="vk"></div><h2 id="vh"></h2><p id="vp"></p></div>\n<div class="vfull" id="vtitle"><div><div class="w">Gir<span>o</span></div><p>Mondo Dado × Città</p></div></div>\n<div class="vfull" id="vend"><div><div class="w">Gir<span>o</span></div><p>The city is the board.</p><br><span class="tag">Prototype · iOS game concept</span></div></div>')
R("window.__giro = { die, roll, land,", "window.__giro = { cam, GHOSTS, ghostTurn, options, pickups, setSimT: v => simT = v, getSimT: () => simT, die, roll, land,")
R("const nx = P.x+d[0], ny = P.y+d[1]; await hopPawn(nx, ny);", "const nx = P.x+d[0], ny = P.y+d[1]; SFX('hop', 72+i*2); await hopPawn(nx, ny);")
R("die.visible = true;", "die.visible = true; SFX('dice');")
R("$('dock').hidden = true; $('fork').hidden = false;", "SFX('click'); $('dock').hidden = true; $('fork').hidden = false;")
R("function gain(n, at){ S.coins += n;", "function gain(n, at){ SFX('chime', 76); S.coins += n;")
R("toast('All aboard: riding to the next stop', 2000);", "SFX('whoosh'); toast('All aboard: riding to the next stop', 2000);")
R("S.coins += v2; S.incomeToday += v2;", "SFX('chime', 84); S.coins += v2; S.incomeToday += v2;")
R("function paintCell(x,y,t){ draft[y][x] = t;", "function paintCell(x,y,t){ SFX('pop', 72); draft[y][x] = t;")
R("S.coins -= PRICE[bi]; owner[bi] = 'me';", "SFX('up', 67); S.coins -= PRICE[bi]; owner[bi] = 'me';")
DIRECTOR = r"""<script>
(() => {
const g = window.__giro, $ = id => document.getElementById(id);
const W = s => new Promise(res => setTimeout(res, s*1000));
const vt = () => window.__VT/1000 - 1;
const until = async t => { while (vt() < t) await W(1/60); };
const cxx = x => x*2 - 30 + 1;
const CAPS = [
  [3.4, 10.2, 'Roll', 'Roll and drive through the city', 'Every street square is a board square. At a fork, you choose where to go.'],
  [10.6, 15.4, 'Shortcuts', 'Bus stops are shortcuts', 'Land next to one and ride the line to the next stop.'],
  [15.7, 20.5, 'Get paid', 'Other players stop at your block', 'Their visits to your shops and cafés pay you coins.'],
  [20.8, 25.2, 'Build', 'Buy land. Build anything.', 'Shops, offices, parks, bus stops. Your streets must connect to your neighbours’.'],
  [25.5, 27.6, 'One city', 'Built by players around the world', 'Every block is someone’s. Every roll is a trip.'],
];
function simRoll(x,y,dx,dy,v,ch){ let f = 0; for (let i=0;i<v;i++){ const o = g.options(x,y,dx,dy); if (!o.length) return null; let d; if (o.length>1){ d = o[ch[f]]; f++; if (!d) return null; } else d = o[0]; x+=d[0]; y+=d[1]; dx=d[0]; dy=d[1]; } return { x,y,dx,dy,f }; }
function findShot(){
  const starts = [[12,14,1,0]]; const rc = []; for (let y=0;y<30;y++) for (let x=0;x<30;x++) if (g.grid[y][x]==='=') rc.push([x,y]);
  rc.sort((a,b) => Math.hypot(a[0]-12,a[1]-14) - Math.hypot(b[0]-12,b[1]-14)); rc.forEach(([x,y]) => [[1,0],[-1,0],[0,1],[0,-1]].forEach(([dx,dy]) => { if (g.grid[y-dy] && g.grid[y-dy][x-dx]==='=') starts.push([x,y,dx,dy]); }));
  for (const s of starts) for (const v of [4,5,3,6]) for (const c of [2,1,0]){ const r = simRoll(s[0],s[1],s[2],s[3],v,[c]); if (!r || r.f!==1) continue; const f = g.frontage(r.x,r.y), k = g.squareKind(f); if (k==='c' || k==='s') return { s, v, c }; }
}
async function playRoll(v, choices, hold=1.1){ g.roll(v); let k = 0; await W(.1); while (g.S.busy){ if (g.forking){ await W(hold); g.chooseFork(choices[k++] ?? 0); } if (!$('modal').hidden) g.closeModal(); await W(1/30); } }
async function director(){
  $('toast').style.opacity = 0;
  g.GHOSTS.forEach(q => q.next = 6000 + Math.random()*4000);
  const C = g.cam; C.follow = false; C.gx = C.tx = 0; C.gz = C.tz = 0; C.gd = C.dist = 72; C.theta = -.95; C.phi = .9;
  const shot = findShot(); console.log('shot', JSON.stringify(shot));
  await until(2.7); g.teleport(...shot.s); C.follow = true; C.gd = 24;
  await until(3.6); await playRoll(shot.v, [shot.c]);
  // bus
  await until(10.4); let pick = null; for (const j of g.routeStops){ const n = g.ROUTE_CELLS.length, a = g.ROUTE_CELLS[(j-1+n)%n], b = g.ROUTE_CELLS[j]; const d = [b[0]-a[0], b[1]-a[1]]; if (g.options(a[0],a[1],d[0],d[1]).length===1){ pick = [a[0],a[1],d[0],d[1]]; break; } }
  console.log('bus', JSON.stringify(pick)); g.teleport(...pick); C.tx = cxx(pick[0]); C.tz = cxx(pick[1]); C.gd = C.dist = 26;
  await until(11.0); await playRoll(1, []);
  // ghosts pay you
  await until(15.6); C.follow = false; C.gx = 1; C.gz = 0; C.gd = 20; C.theta = -.7;
  const k1 = g.GHOSTS[1], k2 = g.GHOSTS[2];
  [[k1,16,14],[k2,15,14]].forEach(([q,x,y]) => { q.next = 1e12; q.x = x; q.y = y; q.dx = 1; q.dy = 0; q.m.position.set(cxx(x)+q.off[0], 0, cxx(y)+q.off[1]); });
  await until(16.6); { const R = Math.random; Math.random = () => 0; g.ghostTurn(k1); Math.random = R; }
  await until(18.4); { const R = Math.random; Math.random = () => 0; g.ghostTurn(k2); Math.random = R; }
  await until(20.4); k1.next = k2.next = window.__VT + 3000;
  // buy + build
  if (g.S.coins < 420) g.S.coins += 400;
  await until(20.9); C.gx = -9; C.gz = 0; C.gd = 26; g.buy(11);
  await until(22.0); g.setMode('build'); C.gx = -10; C.gz = 1; C.gd = 19; C.theta = -.75; $('toast').style.opacity = 0;
  await until(22.6); g.paint(7,13,'b'); await until(23.1); g.paint(10,13,'s'); await until(23.6); g.paint(10,15,'a'); await until(24.1); g.paint(9,16,'c');
  await until(24.8); $('open').click(); SFX('up', 72);
  // night city
  await until(25.3); C.follow = false; C.gx = 0; C.gz = 0; C.gd = 64; C.phi = .85;
  await until(25.7); $('toast').style.opacity = 0;
}
let started = false; const night0 = { a: null };
function overlays(t){
  $('vtitle').style.opacity = t < 2.4 ? 1 : Math.max(0, 1 - (t-2.4)/0.7);
  $('vend').style.opacity = t < 27.7 ? 0 : Math.min(1, (t-27.7)/0.6);
  const c = CAPS.find(c => t >= c[0] && t < c[1]); const cap = $('vcap');
  if (c){ if ($('vh').textContent !== c[3]){ $('vk').textContent = c[2]; $('vh').textContent = c[3]; $('vp').textContent = c[4]; } cap.classList.toggle('top', c[2]==='Build'); cap.style.opacity = Math.min(1, (t-c[0])/.3, (c[1]-t)/.3); } else cap.style.opacity = 0;
  const C = g.cam;
  if (t < 3) C.theta = -.95 + t*.05;
  if (t >= 25.3){ C.theta += .0018; if (night0.a == null) night0.a = g.getSimT(); const D = 180, cur = night0.a, h = (cur % D)/D*24, target = cur + ((21.2 - h + 24) % 24)/24*D; g.setSimT(cur + (target-cur)*Math.min(1,(t-25.3)/2.2)); }
}
const yieldTask = () => new Promise(r => { const c = new MessageChannel(); c.port1.onmessage = () => r(); c.port2.postMessage(0); });
window.render = async t => {
  if (!started){ started = true; director(); }
  const target = 1000 + t*1000;
  while (window.__VT < target - .5){ window.__VT = Math.min(target, window.__VT + 1000/30); window.__runTimers(); await yieldTask(); overlays(window.__VT/1000 - 1); const f = window.__raf; if (f){ window.__raf = null; f(window.__VT); } await yieldTask(); }
};
})();
</script>
"""
src = src.replace('</script>\n', '</script>\n', 1)
src = src.rstrip() + '\n' + DIRECTOR
(HERE / 'build').mkdir(exist_ok=True)
open(HERE / 'build' / 'video.html', 'w', encoding='utf-8').write(src)
print('ok', len(src))
