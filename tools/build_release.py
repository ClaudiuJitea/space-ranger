#!/usr/bin/env python3
"""Export and package the Windows/Linux release without publishing it."""
import argparse
import hashlib
import re
import shutil
import subprocess
import tarfile
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
VERSION = '1.5'
DIST = ROOT / 'dist' / f'v{VERSION}'
NOTES = '''Space Ranger: Eclipse Protocol — version 1.5

Windows: extract the entire folder and run SpaceRanger.exe.
Linux: extract the archive and run ./SpaceRanger.x86_64 (or ./launch.sh).
No Godot installation is required. Game data and recorded audio are embedded.
Requires an x86_64 system and a Forward+ capable GPU: Vulkan on Linux,
Direct3D 12 on Windows.

Move A/D or arrows; jump Space/W/up; aim mouse; fire left mouse/J;
dash Shift/right mouse; weapons 1–4/wheel; EMP E/Q; interact F; pause Esc/P.
Find weapon pickups to unlock the scattergun, railgun and launcher.
Sync all relays to unlock each boss arena. Five missions are included.

1.5: expanded campaign, refitted enemies/bosses/guns, biomechanical hounds,
Wasp drones, compact pickup notifications, recorded audio, ranger helmet icon.

Project: https://github.com/ClaudiuJitea/space-ranger
'''
def main():
 parser = argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--skip-export', action='store_true', help='Package existing exports')
 args = parser.parse_args()
 archives = []
 for platform, preset, binary in [('linux','Linux','SpaceRanger.x86_64'),('windows','Windows','SpaceRanger.exe')]:
  source = DIST / platform
  source.mkdir(parents=True, exist_ok=True)
  executable = source / binary
  if not args.skip_export:
   subprocess.run(['godot','--headless','--path',str(ROOT),'--export-release',preset,str(executable)],cwd=ROOT,check=True)
  if not executable.is_file(): raise FileNotFoundError(executable)
  folder = f'SpaceRanger-{VERSION}-{platform}-x86_64'
  staging = DIST / 'packages' / folder
  staging.mkdir(parents=True, exist_ok=True)
  shutil.copy2(executable, staging / binary)
  shutil.copy2(ROOT / 'icon.png', staging / 'icon.png')
  shutil.copy2(ROOT / 'README.md', staging / 'README.md')
  for image in set(re.findall(r'docs/screenshots/[^\s)\"<>]+', (ROOT / 'README.md').read_text())):
   if not (ROOT / image).is_file(): continue
   destination = staging / image
   destination.parent.mkdir(parents=True, exist_ok=True)
   shutil.copy2(ROOT / image, destination)
  (staging / 'PLAY.txt').write_text(NOTES, encoding='utf-8')
  if platform == 'linux':
   (staging / binary).chmod(0o755)
   launcher = staging / 'launch.sh'
   launcher.write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")" || exit 1\nexec ./SpaceRanger.x86_64 "$@"\n')
   launcher.chmod(0o755)
   archive = DIST / (folder + '.tar.gz')
   with tarfile.open(archive,'w:gz',compresslevel=6) as bundle: bundle.add(staging,arcname=folder)
  else:
   shutil.copy2(ROOT / 'icon.ico', staging / 'icon.ico')
   archive = DIST / (folder + '.zip')
   with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
    for item in sorted(staging.rglob('*')):
     if item.is_file(): bundle.write(item,arcname=f'{folder}/{item.relative_to(staging)}')
  archives.append(archive)
  print(f'Packaged {archive}',flush=True)
 checksums = []
 for archive in archives:
  with archive.open('rb') as file: digest=hashlib.file_digest(file,'sha256').hexdigest()
  checksums.append(f'{digest}  {archive.name}\n')
 (DIST / 'SHA256SUMS.txt').write_text(''.join(checksums))
 print('Release 1.5 packaged with SHA-256 checksums. No upload performed.')
if __name__ == '__main__': main()
