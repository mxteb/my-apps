"""
يدور الصور المكررة في مجلد وينقلها لمجلد "_duplicates" للمراجعة (ما يحذف نهائي).

الاستخدام:
    pip install pillow imagehash
    python find_duplicates.py "C:/Users/me/Pictures"            # المتطابقة تماماً فقط
    python find_duplicates.py "C:/Users/me/Pictures" --similar  # + الصور المتشابهة
    python find_duplicates.py "..." --dry-run                   # يعرض بس بدون ما ينقل
"""
import argparse, hashlib, shutil, sys
from pathlib import Path

EXTS = {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".heic", ".tif", ".tiff"}

def file_hash(p, chunk=1 << 20):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while b := f.read(chunk):
            h.update(b)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--similar", action="store_true", help="يكشف الصور المتشابهة بعد")
    ap.add_argument("--threshold", type=int, default=5, help="كل ما قل الرقم صار أدق (0-64)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    root = Path(a.folder)
    dest = root / "_duplicates"
    files = [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in EXTS and dest not in p.parents]
    # نخلي الأقدم/الأكبر هو الأصل
    files.sort(key=lambda p: (-p.stat().st_size, p.stat().st_mtime))
    print(f"لقيت {len(files)} صورة")

    dups = []  # (المكرر, الأصل)
    seen = {}
    unique = []
    for p in files:
        h = file_hash(p)
        if h in seen:
            dups.append((p, seen[h]))
        else:
            seen[h] = p
            unique.append(p)

    if a.similar:
        try:
            from PIL import Image
            import imagehash
        except ImportError:
            sys.exit("ثبت المكتبات: pip install pillow imagehash")
        kept = []  # (hash, path)
        for p in unique:
            try:
                with Image.open(p) as im:
                    ph = imagehash.phash(im)
            except Exception:
                continue
            match = next((k for kh, k in kept if ph - kh <= a.threshold), None)
            if match:
                dups.append((p, match))
            else:
                kept.append((ph, p))

    for d, orig in dups:
        print(f"مكرر: {d}  ←  الأصل: {orig}")
        if not a.dry_run:
            target = dest / d.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(d), str(target))

    print(f"\nالمجموع: {len(dups)} صورة مكررة" + ("" if a.dry_run else f" انتقلت إلى {dest}"))

if __name__ == "__main__":
    main()
