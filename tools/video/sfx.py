# Generic SFX bed: python3 sfx.py events.json out.wav ; events: [{"t":..,"k":"pop|click|hop|chime|dice|whoosh|thud|tick|down|up","n":midi}]
import json, sys, numpy as np, wave
SR=44100; D=30.0; N=int(SR*D); out=np.zeros(N); rng=np.random.default_rng(1)
ev=json.load(open(sys.argv[1])); pad=json.load(open(sys.argv[3])) if len(sys.argv)>3 else [[130.8,.03],[196,.025],[261.6,.018],[329.6,.012]]
def add(t0,sig):
    i0=int(t0*SR); n=min(len(sig),N-i0)
    if n>0 and i0>=0: out[i0:i0+n]+=sig[:n]
def tone(f,dur,vol,dec,pl=True):
    tt=np.arange(int(dur*SR))/SR; e=np.exp(-tt/dec)*np.minimum(1,tt/.003); w=np.sin(2*np.pi*f*tt)
    if pl: w=w+.4*np.sin(4*np.pi*f*tt)+.18*np.sin(6*np.pi*f*tt)
    return w*e*vol
def noise(dur,vol,dec): tt=np.arange(int(dur*SR))/SR; return rng.normal(0,1,len(tt))*np.exp(-tt/dec)*vol
m=lambda n:440*2**((n-69)/12)
for e in ev:
    t,k,n=e['t'],e['k'],e.get('n',72)
    if k=='pop': add(t,tone(m(n),.5,.2,.12)); add(t,noise(.04,.08,.006))
    elif k=='click': add(t,noise(.04,.12,.006))
    elif k=='tick': add(t,tone(2200,.03,.05,.006,False))
    elif k=='hop': add(t,tone(m(n),.22,.13,.05))
    elif k=='chime':
        for j,d in enumerate([0,4,7,12]): add(t+j*.08,tone(m(n+d),1.2,.15,.35))
    elif k=='dice':
        for j in range(8): add(t+j*.045,noise(.03,.11,.005))
    elif k=='up':
        for j in range(4): add(t+j*.06,tone(m(n+j*4),.3,.14,.08))
    elif k=='down':
        for j in range(5): add(t+j*.05,tone(m(n-j*3),.25,.13,.07))
    elif k=='whoosh':
        tt=np.arange(int(1.0*SR))/SR; w=rng.normal(0,1,len(tt))*np.sin(np.pi*tt/1.0)**2*.1; add(t,np.convolve(w,np.ones(40)/40,'same'))
    elif k=='thud': add(t,tone(70,.4,.35,.08,False))
tt=np.arange(N)/SR; bed=sum(np.sin(2*np.pi*f*tt)*a for f,a in pad)*np.minimum(1,tt/2)*np.minimum(1,(D-tt)/2)
out+=bed; out/=np.abs(out).max()/0.85
pcm=(out*32767).astype(np.int16)
with wave.open(sys.argv[2],'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(np.stack([pcm,pcm],1).tobytes())
print('ok')
