"""Verify and restore the frozen circular benchmark archive without overwrites."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import sys
import zipfile

EXPECTED = '99637764c0fdc7c986fd15f10317c84da486a3f6fc91ccb862e21b2bdf3ad7c9'

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def restore(archive, root):
    assert digest(archive) == EXPECTED, 'Archive SHA-256 mismatch'
    root = root.resolve()
    with zipfile.ZipFile(archive) as z:
        records = json.loads(z.read('CIRCULAR_FILES.json'))
        paths = [r['path'] for r in records]
        assert len(set(paths)) == len(paths), 'Duplicate archive entry'
        for r in records:
            p = PurePosixPath(r['path'])
            assert not p.is_absolute() and '..' not in p.parts and ':' not in str(p) and '\\' not in str(p), 'Unsafe path'
            target = (root / str(p)).resolve()
            assert target.is_relative_to(root), 'Path escapes destination'
            data = z.read(str(p))
            assert len(data) == r['size'] and hashlib.sha256(data).hexdigest() == r['sha256'], str(p)
            assert not target.exists() or (target.is_file() and digest(target) == r['sha256']), 'Refusing overwrite: ' + str(p)
        for r in records:
            target = root / r['path']
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open('xb') as out:
                    out.write(z.read(r['path']))
            assert digest(target) == r['sha256'], 'Restored hash mismatch'
    print('Verified and restored', len(records), 'files to', root)

if __name__ == '__main__':
    if len(sys.argv) not in (2, 3):
        raise SystemExit('Usage: python tools/restore_circular_results.py ARCHIVE.zip [DESTINATION]')
    restore(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) == 3 else Path(__file__).resolve().parents[1])
