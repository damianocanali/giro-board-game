# Renders Giro's looping background tune: marimba melody, soft bass, warm pad and a light shaker.
# Notes that ring past the end wrap to the start, so the loop is seamless.
import math, random, struct, wave, sys
SR = 32000
BPM = 100
beat = 60 / BPM
bars = 16
N = int(round(bars * 4 * beat * SR))
L = [0.0] * N
R = [0.0] * N
random.seed(7)

def midi(m): return 440 * 2 ** ((m - 69) / 12)

def add(t, dur, f, amp, kind, pan=0.0):
    start = int(t * SR); n = int(dur * SR)
    gl = amp * math.sqrt((1 - pan) / 2); gr = amp * math.sqrt((1 + pan) / 2)
    w = 2 * math.pi * f / SR
    for i in range(n):
        x = i / SR
        if kind == 'marimba':
            e = math.exp(-x * 7.0) * min(1, i / 60)
            v = math.sin(w * i) + 0.25 * math.sin(4 * w * i) * math.exp(-x * 30)
        elif kind == 'bass':
            e = math.exp(-x * 2.2) * min(1, i / 200)
            v = math.sin(w * i) + 0.2 * math.sin(2 * w * i)
        elif kind == 'pad':
            e = min(1, x / 0.6) * min(1, (dur - x) / 0.8)
            v = math.sin(w * i) + 0.3 * math.sin(w * 1.003 * i)
        else:  # shaker
            e = math.exp(-x * 60)
            v = random.uniform(-1, 1)
        s = v * e
        k = (start + i) % N
        L[k] += s * gl; R[k] += s * gr

# F major: F  Dm  Bb  C | F  Am  Bb  C (two bars each, played twice with a new melody)
chords = [[53, 57, 60], [50, 53, 57], [46, 50, 53], [48, 52, 55],
          [53, 57, 60], [45, 48, 52], [46, 50, 53], [48, 52, 55]]
penta = [65, 67, 69, 72, 74, 77, 79, 81]  # F pentatonic, upper register
bar = 4 * beat
for b in range(bars):
    ch = chords[(b // 2) % 8]
    t0 = b * bar
    # bass on beats 1 and 3
    add(t0, 1.6, midi(ch[0] - 12), 0.30, 'bass')
    add(t0 + 2 * beat, 1.2, midi(ch[0] - 12 + (7 if b % 2 else 0)), 0.22, 'bass')
    # pad, once per two bars
    if b % 2 == 0:
        for m in ch:
            add(t0, 2 * bar, midi(m + 12), 0.035, 'pad', pan=random.uniform(-0.4, 0.4))
    # shaker on off-beats
    for k in range(4):
        add(t0 + (k + 0.5) * beat, 0.08, 0, 0.035, 'shaker', pan=0.3)
    # melody: eighth notes, mostly chord tones, with rests so it breathes
    tones = [m + 12 for m in ch] + [m + 24 for m in ch]
    pos = random.randrange(len(penta))
    for k in range(8):
        if random.random() < (0.35 if b % 4 == 3 else 0.2):
            continue
        if k % 2 == 0:
            m = random.choice([x for x in tones if 64 <= x <= 84] or tones)
        else:
            pos = max(0, min(len(penta) - 1, pos + random.choice([-2, -1, 1, 2])))
            m = penta[pos]
        add(t0 + k * beat / 2, 0.9, midi(m), 0.16 if k % 2 == 0 else 0.11, 'marimba', pan=random.uniform(-0.5, 0.5))

peak = max(max(abs(x) for x in L), max(abs(x) for x in R))
g = 0.7 / peak
with wave.open(sys.argv[1], 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b''.join(struct.pack('<hh', int(l * g * 32767), int(r * g * 32767)) for l, r in zip(L, R)))
print('frames', N, 'seconds', N / SR)
