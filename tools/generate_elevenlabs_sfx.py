#!/usr/bin/env python3
"""Generate Space Ranger SFX via ElevenLabs. Reads ELEVENLABS_API_KEY from the environment."""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "sfx"
API = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"

# name -> (duration_seconds, prompt)
SFX: dict[str, tuple[float, str]] = {
    "laser_pulse": (0.6, "Short punchy sci-fi cyan plasma blaster shot, single energy bolt, tight attack, no music, game weapon SFX"),
    "laser_spread": (0.8, "Sci-fi plasma shotgun blast, several energy pellets firing at once, heavy and short, no music"),
    "laser_beam": (1.2, "Photon railgun fire: brief charge then a piercing high-energy beam crack, sci-fi, no music"),
    "enemy_laser": (0.6, "Darker enemy plasma laser shot, slightly dirty and threatening, short game SFX, no music"),
    "explosion": (1.2, "Medium sci-fi explosion with debris and a bass thump, space station combat, no music"),
    "boss_explosion": (2.0, "Huge cinematic sci-fi explosion, collapsing reactor core, deep boom and crackling energy, no music"),
    "hit": (0.5, "Bullet hitting armored suit, short metallic impact, game hit SFX, no music"),
    "shield_hit": (0.6, "Energy shield absorbing a hit, crystalline electric ping, sci-fi, no music"),
    "pickup_energy": (0.8, "Positive energy pickup chime, bright sci-fi UI collect, short, no music"),
    "pickup_shield": (0.9, "Shield restore pickup, rising crystalline chime, sci-fi, no music"),
    "pickup_weapon": (1.2, "Weapon unlock fanfare, short heroic sci-fi stinger, no voice, no music bed"),
    "thruster": (0.7, "Jetpack thruster whoosh burst, compressed air and flame, short, no music"),
    "dash": (0.6, "Fast evasive dash whoosh with a digital snap, sci-fi movement SFX, no music"),
    "alarm": (1.0, "Sci-fi warning alarm two-tone beep, HUD alert, short, no music"),
    "weapon_swap": (0.5, "Mechanical futuristic weapon swap click, short and tactile, no music"),
    "rocket_launch": (1.0, "Rocket launcher firing a missile, ignition whoosh and rumble, game SFX, no music"),
    "hitmarker": (0.5, "Tactical FPS hitmarker tick, very short high click, no music"),
    "rocket_explode": (1.3, "Rocket splash explosion, fireball and shockwave, sci-fi, no music"),
    "footstep": (0.5, "Very loud close-mic single armored combat boot step on a steel grate, sharp heel-toe impact, dry, game footstep, no music, no voice"),
    "footstep_alt": (0.5, "Very loud close-mic opposite-foot armored boot step on a metal walkway, slightly lower thud, dry, game footstep, no music, no voice"),
    "landing": (0.6, "Boot landing on metal platform, short thud, no music"),
    "landing_hard": (0.8, "Heavy armored landing impact on metal, no music"),
    "ui_click": (0.5, "Holographic UI button click, crisp digital, very short, no music"),
    "ui_hover": (0.5, "Holographic UI hover blip, soft high tick, very short, no music"),
    "notify": (0.7, "HUD notification ping, two-note sci-fi chime, short, no music"),
    "respawn": (1.1, "Suit teleport respawn, energy materialize whoosh, sci-fi, no music"),
    "lunge": (0.8, "Creature lunge attack, aggressive whoosh and snarl, short, no music"),
    "victory": (2.0, "Short sci-fi victory sting, triumphant but small, no vocals"),
    "powerup": (1.0, "Secret cache power-up collect, sparkling energy chime, no music"),
    "plasma_burst": (0.8, "Hazard plasma beacon burst, electric zap and boom, short, no music"),
}

MUSIC: dict[str, tuple[float, str]] = {
    "music_pad": (8.0, "Seamless looping dark ambient sci-fi pad, orbital station atmosphere, no melody, no drums, no vocals, cinematic space drone"),
    "music_pulse": (8.0, "Seamless looping low electronic combat pulse, muted kick and bass ticks, sci-fi, no vocals, no lead melody"),
    "music_tension": (8.0, "Seamless looping boss tension drone, industrial heartbeat and tritone bed, dark sci-fi, no vocals"),
}


def generate(name: str, duration: float, prompt: str, loop: bool, dest: Path, api_key: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "text": prompt,
        "duration_seconds": duration,
        "prompt_influence": 0.65,
        "model_id": "eleven_text_to_sound_v2",
        "loop": loop,
    }
    req = urllib.request.Request(
        API,
        data=json.dumps(payload).encode(),
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = resp.read()
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", "replace")
        raise RuntimeError(f"{name}: HTTP {err.code} {body[:400]}") from err
    if len(data) < 400 or data[:3] != b"ID3" and data[:2] != b"\xff\xfb" and data[:2] != b"\xff\xf3":
        # MP3 may start with ID3 or frame sync; also allow raw MPEG if tiny header
        if not data.startswith(b"\xff"):
            preview = data[:120]
            raise RuntimeError(f"{name}: unexpected response ({len(data)} bytes) {preview!r}")
    dest.write_bytes(data)
    print(f"ok  {name:16s}  {len(data):7d}b  {dest.relative_to(ROOT)}")


def main() -> int:
    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        print("Set ELEVENLABS_API_KEY", file=sys.stderr)
        return 2
    only = sys.argv[1:]
    jobs: list[tuple[str, float, str, bool, Path]] = []
    for name, (dur, prompt) in SFX.items():
        jobs.append((name, dur, prompt, False, OUT / f"{name}.mp3"))
    music_dir = ROOT / "assets" / "audio" / "music"
    for name, (dur, prompt) in MUSIC.items():
        jobs.append((name, dur, prompt, True, music_dir / f"{name}.mp3"))
    if only:
        jobs = [j for j in jobs if j[0] in only]
    failed = 0
    for name, dur, prompt, loop, dest in jobs:
        if dest.exists() and dest.stat().st_size > 800:
            print(f"skip {name}")
            continue
        try:
            generate(name, dur, prompt, loop, dest, api_key)
        except Exception as exc:
            failed += 1
            print(f"FAIL {name}: {exc}", file=sys.stderr)
        time.sleep(0.35)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
