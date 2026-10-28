# Renders Giro's short sound effects as 16-bit mono WAV files into the folder given as the first argument.
import math, random, struct, wave, sys, os
SR = 32000
random.seed(3)

def render(name, dur, voices):
    n = int(dur * SR)
    buf = [0.0] * n
    for v in voices:
        v(buf)
    peak = max(1e-9, max(abs(x) for x in buf))
    g = 0.85 / peak
    with wave.open(os.path.join(sys.argv[1], name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(x * g * 32767)) for x in buf))

def bell(t, f, amp, decay=6.0, length=0.6, partials=((1, 1), (2.76, 0.35), (5.4, 0.12))):
    def v(buf):
        s = int(t * SR)
        for i in range(int(length * SR)):
            if s + i >= len(buf): break
            x = i / SR
            e = math.exp(-x * decay) * min(1, i / 40)
            buf[s + i] += amp * e * sum(a * math.sin(2 * math.pi * f * p * x) for p, a in partials)
    return v

def thump(t, f0, f1, amp, length=0.25):
    def v(buf):
        s = int(t * SR); ph = 0
        for i in range(int(length * SR)):
            if s + i >= len(buf): break
            x = i / SR
            f = f1 + (f0 - f1) * math.exp(-x * 25)
            ph += 2 * math.pi * f / SR
            buf[s + i] += amp * math.exp(-x * 14) * math.sin(ph)
    return v

def noise(t, amp, length, decay, lp=0.3):
    def v(buf):
        s = int(t * SR); y = 0
        for i in range(int(length * SR)):
            if s + i >= len(buf): break
            y += lp * (random.uniform(-1, 1) - y)
            buf[s + i] += amp * math.exp(-(i / SR) * decay) * y
    return v

def midi(m): return 440 * 2 ** ((m - 69) / 12)

# Coin: two quick bright bells, like a classic pickup.
render('sfx-coin', 0.5, [bell(0, midi(88), 0.6, 9, 0.3), bell(0.07, midi(93), 0.8, 7, 0.4)])
# Build: a wooden knock and a soft pop up.
render('sfx-build', 0.6, [thump(0, 260, 90, 1.0), noise(0, 0.5, 0.06, 60, 0.5), bell(0.09, midi(72), 0.35, 10, 0.3), bell(0.15, midi(79), 0.35, 10, 0.35)])
# Upgrade: a rising sparkle.
render('sfx-upgrade', 0.9, [bell(i * 0.06, midi(76 + s), 0.4, 8, 0.45) for i, s in enumerate([0, 4, 7, 12, 16, 19])])
# Achievement: a short major fanfare.
render('sfx-achievement', 1.4, [bell(0, midi(72), 0.5, 4, 0.6), bell(0.13, midi(76), 0.5, 4, 0.6), bell(0.26, midi(79), 0.5, 4, 0.6),
                                 bell(0.42, midi(84), 0.7, 2.5, 1.0), bell(0.42, midi(76), 0.35, 2.5, 1.0), bell(0.42, midi(79), 0.35, 2.5, 1.0)])
# Stamp: a heavy rubber-stamp thud.
render('sfx-stamp', 0.5, [thump(0, 180, 55, 1.0, 0.4), noise(0, 0.7, 0.08, 45, 0.25)])
# Dice: a few clattering knocks.
render('sfx-dice', 0.7, [thump(t, 900, 400, 0.5, 0.05) for t in (0, 0.09, 0.16, 0.27, 0.33, 0.45)] + [noise(t, 0.3, 0.04, 80, 0.6) for t in (0, 0.09, 0.16, 0.27, 0.33, 0.45)])
# Whoosh: the passport flying in.
def whoosh(buf):
    y = 0
    for i in range(len(buf)):
        x = i / len(buf)
        y += (0.05 + 0.4 * x) * (random.uniform(-1, 1) - y)
        buf[i] += math.sin(math.pi * x) ** 2 * y
render('sfx-whoosh', 0.45, [whoosh])
print('ok')
