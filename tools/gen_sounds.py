"""Генератор звуков игры (процедурный синтез, без внешних файлов).

Запуск с ПК:  python3 tools/gen_sounds.py
Результат: audio/*.wav (22050 Гц, 16 бит, моно).
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)


def t_axis(duration):
    return np.arange(int(SR * duration)) / SR


def noise(duration):
    return rng.uniform(-1.0, 1.0, int(SR * duration))


def lowpass(x, cutoff):
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(duration, tau, attack=0.002):
    t = t_axis(duration)
    e = np.exp(-t / tau)
    if attack > 0:
        e *= np.clip(t / attack, 0.0, 1.0)
    return e


def sweep(duration, f0, f1, curve=1.0):
    t = t_axis(duration)
    k = (t / duration) ** curve
    freq = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def pad(x, duration):
    n = int(SR * duration)
    out = np.zeros(n)
    out[: min(n, len(x))] = x[:n]
    return out


def place(dst, src, at):
    i = int(SR * at)
    end = min(len(dst), i + len(src))
    dst[i:end] += src[: end - i]
    return dst


def finish(x, gain=0.9, drive=1.6):
    x = np.tanh(x * drive)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    fade = min(len(x), int(SR * 0.01))
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    return x


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{name}.wav  {len(x) / SR:.2f}s")


def gunshot(duration, thump_f0, thump_f1, thump_tau, crack_tau, body_cut, body_tau, tail_cut, tail_tau, tail_amp):
    d = duration
    thump = sweep(d, thump_f0, thump_f1, 0.4) * env(d, thump_tau)
    crack = highpass(noise(d), 2500) * env(d, crack_tau, 0.0005)
    body = lowpass(noise(d), body_cut) * env(d, body_tau)
    tail = lowpass(noise(d), tail_cut) * env(d, tail_tau, 0.01)
    return thump * 1.0 + crack * 0.7 + body * 1.4 + tail * tail_amp


def click(duration=0.04, freq=3200, tau=0.006):
    return highpass(noise(duration), freq) * env(duration, tau, 0.0003)


def squelch(duration, cut=900, tau=0.05, f0=260, f1=90):
    wet = lowpass(noise(duration), cut) * env(duration, tau)
    tone = sweep(duration, f0, f1) * env(duration, tau * 0.8)
    wobble = 1.0 + 0.6 * np.sin(2 * np.pi * 38 * t_axis(duration))
    return (wet * 1.6 + tone * 0.5) * wobble


def tone(duration, freq, tau=0.2, attack=0.005, harmonics=(1.0, 0.3, 0.1)):
    t = t_axis(duration)
    x = sum(a * np.sin(2 * np.pi * freq * (i + 1) * t) for i, a in enumerate(harmonics))
    return x * env(duration, tau, attack)


def resonator(x, freq, bandwidth):
    """Двухполюсный резонатор — форманта голоса."""
    r = np.exp(-np.pi * bandwidth / SR)
    c1 = 2 * r * np.cos(2 * np.pi * freq / SR)
    c2 = -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    g = 1.0 - r
    for i, v in enumerate(x):
        y0 = g * v + c1 * y1 + c2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y


def voice(duration, f0, f1, formants, vibrato=0.0, breath=0.2, rough=0.0):
    """Гласная: пилообразный «голосовой» сигнал через форманты (крик, смех, рык)."""
    t = t_axis(duration)
    freq = np.linspace(f0, f1, len(t)) * (1 + vibrato * np.sin(2 * np.pi * 6.5 * t))
    freq *= 1 + rough * lowpass(rng.uniform(-1, 1, len(t)), 40) * 4
    phase = np.cumsum(freq) / SR
    source = 2 * (phase % 1.0) - 1.0 + breath * noise(duration)
    out = sum(resonator(source, f, bw) * a for f, bw, a in formants)
    return out


VOWEL_A = ((800, 90, 1.0), (1200, 110, 0.6), (2500, 160, 0.25))
VOWEL_A_DARK = ((650, 90, 1.0), (1000, 100, 0.6), (2400, 150, 0.2))


def main():
    save("pistol", finish(gunshot(0.45, 190, 70, 0.05, 0.012, 2200, 0.06, 700, 0.2, 0.35)))
    save("deagle", finish(gunshot(0.8, 150, 45, 0.09, 0.02, 1600, 0.11, 450, 0.42, 0.6), drive=2.2))

    shot = gunshot(1.0, 120, 38, 0.12, 0.03, 1300, 0.17, 380, 0.55, 0.7)
    shot = place(shot, click(0.05, 2000, 0.01) * 0.5, 0.42)
    shot = place(shot, lowpass(noise(0.12), 2500) * env(0.12, 0.04) * 0.4, 0.46)
    shot = place(shot, click(0.05, 1800, 0.012) * 0.6, 0.6)
    save("shotgun", finish(shot, drive=2.4))

    save("enemy_shot", finish(gunshot(0.5, 160, 60, 0.05, 0.01, 1500, 0.07, 500, 0.22, 0.3) * 0.9, gain=0.8))

    rel = np.zeros(int(SR * 0.9))
    rel = place(rel, click(0.05, 2500, 0.008), 0.02)
    rel = place(rel, lowpass(noise(0.18), 3000) * env(0.18, 0.06, 0.02) * 0.35, 0.25)
    rel = place(rel, click(0.06, 2200, 0.01) * 1.2, 0.62)
    rel = place(rel, click(0.04, 3500, 0.005) * 0.8, 0.75)
    save("reload", finish(rel, gain=0.7, drive=1.0))

    save("dry_fire", finish(click(0.08, 2800, 0.008), gain=0.5, drive=1.0))
    switch = np.zeros(int(SR * 0.3))
    switch = place(switch, click(0.05, 2000, 0.01), 0.0)
    switch = place(switch, click(0.05, 3000, 0.006) * 0.7, 0.12)
    save("switch", finish(switch, gain=0.6, drive=1.0))

    save("hit", finish(squelch(0.16), gain=0.7))
    hs = squelch(0.45, 1200, 0.09, 320, 70)
    crunch = highpass(noise(0.2), 900) * env(0.2, 0.03) * (rng.random(int(SR * 0.2)) > 0.6)
    hs = place(hs, crunch * 1.5, 0.0)
    save("headshot", finish(hs, gain=0.9, drive=2.0))

    gib = lowpass(noise(0.8), 600) * env(0.8, 0.18) * 1.6
    gib += sweep(0.8, 110, 30) * env(0.8, 0.12)
    for at in (0.0, 0.05, 0.12, 0.2, 0.31):
        gib = place(gib, squelch(0.2, 1100, 0.04, 300, 120) * 0.7, at)
    save("gib", finish(gib, gain=0.95, drive=2.2))

    save("death", finish(sweep(0.35, 210, 90) * env(0.35, 0.12, 0.02) * (1 + 0.3 * np.sin(2 * np.pi * 30 * t_axis(0.35)))
                         + lowpass(noise(0.35), 500) * env(0.35, 0.08) * 0.6, gain=0.6))
    save("hurt", finish(sweep(0.3, 320, 140) * env(0.3, 0.09, 0.01) + lowpass(noise(0.3), 1200) * env(0.3, 0.05) * 0.8, gain=0.7))

    swing = lowpass(highpass(noise(0.3), 400), 2500) * np.sin(np.pi * t_axis(0.3) / 0.3) ** 2
    save("swing", finish(swing, gain=0.6, drive=1.0))
    save("melee_hit", finish(sweep(0.25, 150, 50) * env(0.25, 0.06) + lowpass(noise(0.25), 1500) * env(0.25, 0.04), gain=0.85))

    impact = pad(click(0.1, 2500, 0.01), 0.25) + sweep(0.25, 2400, 1300) * env(0.25, 0.06) * 0.15
    save("impact", finish(pad(impact, 0.25), gain=0.45, drive=1.0))

    pick = np.zeros(int(SR * 0.35))
    pick = place(pick, tone(0.15, 880, 0.08), 0.0)
    pick = place(pick, tone(0.2, 1320, 0.1), 0.08)
    save("pickup", finish(pick, gain=0.55, drive=1.0))

    wpn = np.zeros(int(SR * 0.6))
    for i, f in enumerate((523, 659, 784, 1046)):
        wpn = place(wpn, tone(0.25, f, 0.12), i * 0.08)
    wpn = place(wpn, click(0.05, 2000, 0.01) * 0.6, 0.0)
    save("weapon_pickup", finish(wpn, gain=0.6, drive=1.0))

    alarm = np.zeros(int(SR * 1.0))
    for i in range(4):
        f = 880 if i % 2 == 0 else 660
        sq = np.sign(np.sin(2 * np.pi * f * t_axis(0.2))) * env(0.2, 0.5, 0.005)
        alarm = place(alarm, lowpass(sq, 3000), i * 0.23)
    save("alarm", finish(alarm, gain=0.5, drive=1.0))

    door = lowpass(noise(0.9), 220) * np.sin(np.pi * t_axis(0.9) / 0.9) * 2.0
    door += np.sin(2 * np.pi * 55 * t_axis(0.9)) * np.sin(np.pi * t_axis(0.9) / 0.9) * 0.5
    door = place(door, click(0.08, 900, 0.03) * 1.5, 0.8)
    save("door", finish(pad(door, 1.0), gain=0.7))

    win = np.zeros(int(SR * 1.2))
    for i, f in enumerate((523, 659, 784, 1046, 1318)):
        win = place(win, tone(0.5, f, 0.25), i * 0.11)
    save("level_complete", finish(win, gain=0.6, drive=1.0))

    save("ui_click", finish(click(0.05, 2500, 0.004) + tone(0.05, 1200, 0.01) * 0.3, gain=0.4, drive=1.0))

    # Взрыв: глухой удар, рёв огня и треск обломков.
    boom = sweep(1.8, 70, 24, 0.5) * env(1.8, 0.35, 0.004) * 1.4
    boom += lowpass(noise(1.8), 380) * env(1.8, 0.5, 0.003) * 2.2
    boom += highpass(noise(1.8), 1500) * env(1.8, 0.05, 0.001) * 0.8
    for at in rng.uniform(0.1, 1.2, 14):
        boom = place(boom, click(0.04, 1800, 0.008) * rng.uniform(0.2, 0.6), at)
    save("explosion", finish(boom, gain=0.95, drive=2.6))

    # Шипение газа из пробитого баллона.
    hiss = highpass(noise(2.0), 2600) * (0.8 + 0.2 * np.sin(2 * np.pi * 17 * t_axis(2.0)))
    hiss *= np.clip(t_axis(2.0) / 0.05, 0, 1) * np.clip((2.0 - t_axis(2.0)) / 0.2, 0, 1)
    save("hiss", finish(hiss, gain=0.55, drive=1.0))

    # Треск огня на горящей бочке.
    fire = lowpass(noise(2.4), 700) * 0.6
    for at in rng.uniform(0.0, 2.3, 40):
        fire = place(fire, click(0.03, 1200, 0.006) * rng.uniform(0.3, 1.0), at)
    fire *= np.clip(t_axis(2.4) / 0.2, 0, 1)
    save("fire", finish(fire, gain=0.5, drive=1.2))

    # Крик раненого: «А-а-а!» с дрожью в голосе.
    scream = voice(1.0, 430, 330, VOWEL_A, vibrato=0.05, breath=0.35, rough=0.02)
    scream *= np.clip(t_axis(1.0) / 0.04, 0, 1) * np.exp(-np.maximum(t_axis(1.0) - 0.55, 0) / 0.15)
    save("scream", finish(scream, gain=0.7, drive=2.0))

    # Смех Худого: «ха-ха-ха-ха», по слогу, тон понижается.
    laugh = np.zeros(int(SR * 1.5))
    for i in range(6):
        f = 250 - i * 14
        syllable = lowpass(noise(0.05), 3000) * env(0.05, 0.03) * 0.6
        syllable = np.concatenate([syllable, voice(0.13, f, f * 0.9, VOWEL_A, breath=0.5) * env(0.13, 0.08, 0.01)])
        laugh = place(laugh, syllable, 0.05 + i * 0.21)
    save("laugh", finish(laugh, gain=0.75, drive=1.8))

    # Рык Толстяка.
    roar = voice(1.1, 120, 85, VOWEL_A_DARK, vibrato=0.03, breath=0.6, rough=0.08)
    roar *= np.clip(t_axis(1.1) / 0.08, 0, 1) * np.exp(-np.maximum(t_axis(1.1) - 0.6, 0) / 0.2)
    save("roar", finish(roar, gain=0.85, drive=3.0))

    # Дымовая шашка Худого: хлопок и шипение.
    smoke = sweep(0.9, 200, 60) * env(0.9, 0.05) + highpass(noise(0.9), 1500) * env(0.9, 0.35, 0.02) * 0.7
    save("smoke", finish(smoke, gain=0.6, drive=1.5))


# --- Музыка (синтез нотами: бас, рояль, саксофон, ударные) ----------------------------

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def bass_note(freq, dur):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) + 0.1 * np.sin(6 * np.pi * freq * t)
    return x * np.exp(-t / 0.45) * np.clip(t / 0.006, 0, 1)


def piano_note(freq, dur):
    t = t_axis(dur)
    x = sum(a * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (1.2 + 1.5 * k))
            for k, a in ((1, 1.0), (2, 0.45), (3, 0.2), (4, 0.1)))
    x *= 1 + 0.15 * np.sin(2 * np.pi * 5.0 * t)
    release = np.clip((dur - t) / 0.05, 0, 1)
    return x * np.clip(t / 0.004, 0, 1) * release


def sax_note(freq, dur, bright=2200):
    t = t_axis(dur)
    vib = 1 + 0.007 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    phase = np.cumsum(freq * vib) / SR
    x = sum(np.sin(2 * np.pi * k * phase) / k ** 1.1 for k in range(1, 11))
    x = lowpass(x, bright) + lowpass(noise(dur), 1800) * 0.05
    return x * np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.08, 0, 1)


def saw_pad(freqs, dur, attack=1.2):
    t = t_axis(dur)
    x = np.zeros(len(t))
    for f in freqs:
        for detune in (0.997, 1.003):
            x += sum(np.sin(2 * np.pi * f * detune * k * t) / k for k in range(1, 7))
    return x * np.clip(t / attack, 0, 1) * np.clip((dur - t) / 1.0, 0, 1) / (len(freqs) * 2)


def ride(dur=0.3):
    t = t_axis(dur)
    metal = sum(np.sin(2 * np.pi * f * t) for f in (3150, 4730, 6080)) * 0.15
    return (highpass(noise(dur), 5000) * 0.6 + metal) * np.exp(-t / 0.09)


def brush(dur=0.2):
    return highpass(noise(dur), 1500) * env(dur, 0.06, 0.01) * 0.6


def kick(dur=0.35):
    return sweep(dur, 120, 42, 0.5) * env(dur, 0.12, 0.002)


def snare(dur=0.2):
    t = t_axis(dur)
    return highpass(noise(dur), 1500) * env(dur, 0.06) + np.sin(2 * np.pi * 185 * t) * env(dur, 0.04) * 0.6


def hat(dur=0.06):
    return highpass(noise(dur), 6500) * env(dur, 0.015, 0.0005)


def chord_tones(root, quality):
    shape = {"m7": [3, 7, 10, 14], "7": [4, 7, 10, 14], "maj7": [4, 7, 11, 14], "m7b5": [3, 6, 10, 15],
             "m9": [3, 7, 10, 14], "sus": [5, 7, 10, 14]}[quality]
    return [root + i for i in shape]


def room(x, amount=0.25):
    """Простое «эхо клуба»: несколько затухающих повторов."""
    out = x.copy()
    for delay, gain in ((0.083, 0.5), (0.131, 0.35), (0.197, 0.25), (0.293, 0.15)):
        n = int(SR * delay)
        out[n:] += x[:-n] * gain * amount
    return out


def track_length(bars, bpm):
    return bars * 4 * 60.0 / bpm


def jazz_track():
    """Нуарный джаз для меню и базы: ре минор, свинг, контрабас, рояль, щётки, саксофон."""
    bpm = 88
    beat = 60.0 / bpm
    bars = [(50, "m7"), (50, "m7"), (55, "m7"), (55, "m7"), (52, "m7b5"), (57, "7"), (50, "m7"), (57, "7"),
            (50, "m7"), (50, "m7"), (55, "m7"), (48, "7"), (53, "maj7"), (46, "maj7"), (52, "m7b5"), (57, "7")]
    total = track_length(len(bars), bpm)
    bass = np.zeros(int(SR * total))
    keys = np.zeros_like(bass)
    drums = np.zeros_like(bass)
    lead = np.zeros_like(bass)
    swing = 2.0 / 3.0
    for i, (root, quality) in enumerate(bars):
        start = i * 4 * beat
        nxt = bars[(i + 1) % len(bars)][0]
        tones = [root, root + (3 if "m" in quality else 4), root + 7, nxt + (1 if i % 2 else -1)]
        for b, n in enumerate(tones):
            place(bass, bass_note(midi(n - 12), beat * 0.95), start + b * beat)
        voicing = [n + 12 if n < 55 else n for n in chord_tones(root, quality)]
        for at, length, gain in ((0.0, 1.2, 0.9), (1 + swing, 0.6, 0.6), (3 + swing, 0.4, 0.4) if i % 2 else (3.0, 0.5, 0.5)):
            for n in voicing:
                place(keys, piano_note(midi(n), beat * length) * gain, start + at * beat)
        for b in range(4):
            place(drums, ride() * 0.5, start + b * beat)
            if b in (1, 3):
                place(drums, ride() * 0.3, start + (b + swing) * beat)
                place(drums, brush() * 0.5, start + b * beat)
                place(drums, hat() * 0.5, start + b * beat)
    melody = [(0, 0, 69, 1.5), (0, 1 + swing, 67, 0.5), (0, 2, 65, 1), (0, 3, 62, 1), (1, 0, 64, 2),
              (2, 0, 67, 1), (2, 1, 70, 1), (2, 2, 69, 1), (2, 3, 67, 1), (3, 0, 65, 3),
              (4, 0, 67, 1), (4, 1, 64, 1), (4, 2, 70, 1.5), (5, 0, 69, 1), (5, 1, 73, 1), (5, 2, 76, 1), (5, 3, 74, 1),
              (6, 0, 74, 2), (6, 2, 69, 1), (6, 3, 65, 1), (7, 0, 64, 2), (7, 2, 61, 1),
              (8, 0, 74, 1), (8, 1, 77, 1), (8, 2, 76, 1), (8, 3, 74, 1), (9, 0, 69, 3),
              (10, 0, 70, 1), (10, 1, 74, 1), (10, 2, 77, 1.5), (11, 0, 76, 1), (11, 1, 72, 1), (11, 2, 70, 2),
              (12, 0, 69, 2), (12, 2, 72, 1), (12, 3, 76, 1), (13, 0, 74, 3),
              (14, 0, 70, 1), (14, 1, 67, 1), (14, 2, 64, 1), (14, 3, 67, 1), (15, 0, 69, 2)]
    for bar, at, n, length in melody:
        place(lead, sax_note(midi(n - 12), beat * length * 0.95), bar * 4 * beat + at * beat)
    mix = bass * 0.55 + keys * 0.22 + drums * 0.35 + room(lead, 0.4) * 0.4
    return room(mix, 0.2)


def explore_track():
    """Тягучий нуарный эмбиент для уровней: аккорды-подушки, редкие ноты рояля, щётки."""
    bpm = 66
    beat = 60.0 / bpm
    chords = [(50, "m9"), (46, "maj7"), (55, "m7"), (57, "sus")]
    total = track_length(16, bpm)
    pad = np.zeros(int(SR * total))
    keys = np.zeros_like(pad)
    bass = np.zeros_like(pad)
    drums = np.zeros_like(pad)
    for c, (root, quality) in enumerate(chords):
        start = c * 4 * 4 * beat
        voicing = [n + 12 if n < 55 else n for n in chord_tones(root, quality)]
        place(pad, saw_pad([midi(n) for n in voicing], 16 * beat + 0.8), start)
        for bar in range(4):
            bar_start = start + bar * 4 * beat
            place(bass, bass_note(midi(root - 12), beat * 1.8) * 0.9, bar_start)
            place(bass, bass_note(midi(root - 5), beat * 1.5) * 0.6, bar_start + 2 * beat)
            for b in range(4):
                place(drums, ride() * 0.25, bar_start + b * beat)
                if b in (1, 3):
                    place(drums, brush() * 0.35, bar_start + b * beat)
            for step in range(2):
                if rng.random() < 0.8:
                    n = rng.choice(voicing) + 12
                    place(keys, piano_note(midi(n), beat * 1.5) * 0.7, bar_start + (step * 2 + rng.choice([0, 0.5, 1])) * beat)
    pad = lowpass(pad, 900)
    mix = pad * 0.5 + room(keys, 0.6) * 0.3 + bass * 0.45 + drums * 0.25
    return room(mix, 0.25)


def combat_track():
    """Напряжённая тема боя: бочка, малый, хэт, остинато баса и рваные аккорды."""
    bpm = 128
    beat = 60.0 / bpm
    total = track_length(16, bpm)
    drums = np.zeros(int(SR * total))
    bass = np.zeros_like(drums)
    stabs = np.zeros_like(drums)
    pattern = [38, 38, 41, 38, 43, 38, 41, 40]
    roots = [50, 46, 48, 45]
    for bar in range(16):
        start = bar * 4 * beat
        for b in range(4):
            place(drums, kick(), start + b * beat)
            if b in (1, 3):
                place(drums, snare() * 0.7, start + b * beat)
            for h in range(2 if bar < 8 else 4):
                place(drums, hat() * (0.5 if h % 2 else 0.8), start + b * beat + h * beat / (2 if bar < 8 else 4))
        shift = roots[(bar // 2) % 4] - 50
        for i, n in enumerate(pattern):
            place(bass, bass_note(midi(n + shift), beat * 0.45) * 0.9, start + i * beat / 2)
        voicing = [n + 12 for n in chord_tones(roots[(bar // 2) % 4], "m7" if bar % 4 < 2 else "7")][:3]
        for at in (0.5, 1.5, 2.75, 3.5):
            place(stabs, saw_pad([midi(n) for n in voicing], beat * 0.3, attack=0.01) * 1.5, start + at * beat)
        if bar >= 8:
            place(stabs, saw_pad([midi(62 + bar - 8)], 4 * beat, attack=2.0) * 0.8, start)
    stabs = lowpass(stabs, 1800)
    return drums * 0.5 + bass * 0.5 + stabs * 0.45


def extra_sounds():
    save("rifle", finish(gunshot(0.4, 175, 65, 0.035, 0.008, 2600, 0.045, 900, 0.14, 0.3), drive=2.0))
    save("beep", finish(tone(0.09, 2300, 0.05, 0.002, (1.0, 0.2)), gain=0.5, drive=1.0))
    t = t_axis(0.7)
    horn = (np.sign(np.sin(2 * np.pi * 392 * t)) + np.sign(np.sin(2 * np.pi * 494 * t))) * np.clip(t / 0.02, 0, 1)
    save("horn", finish(lowpass(horn * np.clip((0.7 - t) / 0.05, 0, 1), 1800), gain=0.6, drive=1.0))
    rain = lowpass(noise(4.0), 2500) * 0.6 + highpass(noise(4.0), 5000) * 0.25
    for at in rng.uniform(0.0, 3.9, 60):
        rain = place(rain, click(0.02, 2500, 0.004) * rng.uniform(0.1, 0.4), at)
    save("rain", finish(rain, gain=0.5, drive=1.0))
    save("music_menu", finish(jazz_track(), gain=0.8, drive=1.0))
    save("music_explore", finish(explore_track(), gain=0.75, drive=1.0))
    save("music_combat", finish(combat_track(), gain=0.8, drive=1.2))
    save("magnum", finish(gunshot(0.9, 130, 40, 0.1, 0.022, 1500, 0.12, 420, 0.5, 0.65), drive=2.4))


if __name__ == "__main__":
    main()
    extra_sounds()
