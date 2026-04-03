#!/usr/bin/env python3
import argparse, hashlib, json
from pathlib import Path

def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('plugin_dir', type=Path)
    ap.add_argument('--abi-version', default='02.05.02.51')
    ap.add_argument('--out', type=Path, default=None)
    args = ap.parse_args()
    net = args.plugin_dir / 'libbambu_networking.so'
    src = args.plugin_dir / 'libBambuSource.so'
    if not net.exists() or not src.exists():
        raise SystemExit('missing linux payload files')
    files = [
        {'name': net.name, 'sha256': sha256(net), 'abi_version': args.abi_version},
        {'name': src.name, 'sha256': sha256(src)},
    ]
    live555 = args.plugin_dir / 'liblive555.so'
    if live555.exists():
        files.append({'name': live555.name, 'sha256': sha256(live555)})
    manifest = {'files': files}
    out = args.out or (args.plugin_dir / 'linux_payload_manifest.json')
    out.write_text(json.dumps(manifest, indent=2) + '\n')
    print(out)

if __name__ == '__main__':
    main()
