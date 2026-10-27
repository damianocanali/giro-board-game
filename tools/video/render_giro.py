import sys, subprocess, pathlib, json, time
from playwright.sync_api import sync_playwright
out = sys.argv[1]; dur = float(sys.argv[2]); fps = int(sys.argv[3]); stills = [float(s) for s in sys.argv[4].split(',')] if len(sys.argv) > 4 and sys.argv[4] else []
HERE = pathlib.Path(__file__).resolve().parent
url = (HERE / 'build' / 'video.html').as_uri()
THREE = open(HERE / 'node_modules/three/build/three.min.js').read()
F = str(HERE / 'node_modules/@fontsource') + '/'
FONTS = {'ab': F+'archivo-black/files/archivo-black-latin-400-normal.woff2', 'a4': F+'archivo/files/archivo-latin-400-normal.woff2', 'a6': F+'archivo/files/archivo-latin-600-normal.woff2',
         'a8': F+'archivo/files/archivo-latin-800-normal.woff2', 'm5': F+'ibm-plex-mono/files/ibm-plex-mono-latin-500-normal.woff2', 'm6': F+'ibm-plex-mono/files/ibm-plex-mono-latin-600-normal.woff2'}
import base64
CSS = ''.join(f"@font-face{{font-family:'{fam}';font-weight:{w};src:url(data:font/woff2;base64,{base64.b64encode(open(FONTS[k],'rb').read()).decode()}) format('woff2')}}" for k, fam, w in
              [('ab','Archivo Black',400),('a4','Archivo',400),('a6','Archivo',600),('a8','Archivo',800),('m5','IBM Plex Mono',500),('m6','IBM Plex Mono',600)])
with sync_playwright() as p:
    b = p.chromium.launch(args=['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist'])
    pg = b.new_page(viewport={'width':1280,'height':720}, device_scale_factor=float(__import__('os').environ.get('DSF','1.5')))
    pg.on('console', lambda m: print('CON', m.type, m.text) if m.type == 'error' and 'net::' not in m.text else None)
    pg.on('pageerror', lambda e: print('ERR', e.stack))
    pg.route('**/three.min.js', lambda r: r.fulfill(body=THREE, content_type='application/javascript'))
    pg.route('https://fonts.googleapis.com/**', lambda r: r.fulfill(body=CSS, content_type='text/css'))
    pg.goto(url); pg.wait_for_timeout(1500)
    if stills:
        for s in stills:
            pg.evaluate(f'render({s})'); print('st', pg.evaluate('document.fonts.status')); pg.screenshot(path=f'{out}_{s}.png', timeout=60000)
        print(json.dumps(pg.evaluate('SFXEV'))[:400]); b.close(); sys.exit()
    ff = subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','image2pipe','-framerate',str(fps),'-i','-','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',out], stdin=subprocess.PIPE)
    n = int(dur*fps); t0 = time.time()
    for i in range(n):
        pg.evaluate(f'render({i/fps})'); pg.evaluate('document.fonts.status'); ff.stdin.write(pg.screenshot(type='jpeg', quality=93))
        if i % 60 == 0: print('frame', i, round(time.time()-t0), 's', flush=True)
    ff.stdin.close(); ff.wait()
    json.dump(pg.evaluate('SFXEV'), open(out.replace('.mp4','_ev.json'),'w')); b.close()
print('done', out)
