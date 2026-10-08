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


if __name__ == "__main__":
    main()
