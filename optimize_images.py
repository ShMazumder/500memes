from PIL import Image, ImageFile
import os
import json

ImageFile.LOAD_TRUNCATED_IMAGES = True

ROOT = os.path.dirname(__file__)
ASSETS_DIR = os.path.join(ROOT, 'assets', 'memes')
WEBP_DIR = os.path.join(ASSETS_DIR, 'webp')
THUMB_DIR = os.path.join(ASSETS_DIR, 'thumbs')
META_PATH = os.path.join(ROOT, 'memes.json')

os.makedirs(WEBP_DIR, exist_ok=True)
os.makedirs(THUMB_DIR, exist_ok=True)

SUPPORTED = ('.png', '.jpg', '.jpeg', '.webp')

QUALITY = 80
THUMB_SIZE = (400, 400)


def find_images():
    files = []
    for f in os.listdir(ASSETS_DIR):
        path = os.path.join(ASSETS_DIR, f)
        if os.path.isfile(path) and f.lower().endswith(SUPPORTED):
            files.append(path)
    files.sort()
    return files


def load_meta():
    if os.path.exists(META_PATH):
        try:
            with open(META_PATH, 'r', encoding='utf-8') as mf:
                return json.load(mf)
        except Exception:
            return {'count': 0, 'memes': []}
    return {'count': 0, 'memes': []}


def save_meta(meta):
    with open(META_PATH, 'w', encoding='utf-8') as mf:
        json.dump(meta, mf, ensure_ascii=False, indent=2)


def process():
    try:
        imgs = find_images()
    except Exception as e:
        print('Error listing images:', e)
        return

    if not imgs:
        print('No images found in', ASSETS_DIR)
        return

    meta = load_meta()
    existing_urls = {m.get('url') for m in meta.get('memes', []) if m.get('url')}

    optimized = 0
    thumbs = 0

    for path in imgs:
        name = os.path.basename(path)
        base, ext = os.path.splitext(name)
        webp_name = f"{base}.webp"
        thumb_name = f"{base}.webp"
        webp_path = os.path.join(WEBP_DIR, webp_name)
        thumb_path = os.path.join(THUMB_DIR, thumb_name)

        # Skip if webp already exists
        if os.path.exists(webp_path) and os.path.exists(thumb_path):
            continue

        try:
            with Image.open(path) as im:
                # Convert and save webp (resizing large images to max 1200px)
                max_dim = 1200
                w, h = im.size
                if max(w, h) > max_dim:
                    scale = max_dim / max(w, h)
                    new_size = (int(w*scale), int(h*scale))
                    im_resized = im.resize(new_size, Image.LANCZOS)
                else:
                    im_resized = im.convert('RGB')

                im_resized.save(webp_path, 'WEBP', quality=QUALITY)
                optimized += 1

                # Create thumbnail (center-crop then resize)
                thumb = im.copy()
                tw, th = thumb.size
                # center crop
                min_side = min(tw, th)
                left = (tw - min_side)//2
                top = (th - min_side)//2
                right = left + min_side
                bottom = top + min_side
                thumb = thumb.crop((left, top, right, bottom)).resize(THUMB_SIZE, Image.LANCZOS).convert('RGB')
                thumb.save(thumb_path, 'WEBP', quality=60)
                thumbs += 1

                # Update metadata entry if present
                # Find matching meta by url or by filename
                matched = None
                for m in meta.get('memes', []):
                    if m.get('url') and os.path.basename(m.get('url')).split('?')[0] == name:
                        matched = m
                        break
                if not matched:
                    # fallback: try to match by local file name
                    for m in meta.get('memes', []):
                        if m.get('local') and os.path.basename(m.get('local')) == name:
                            matched = m
                            break

                if matched:
                    matched['local'] = os.path.relpath(webp_path, ROOT).replace('\\', '/')
                    matched['thumb'] = os.path.relpath(thumb_path, ROOT).replace('\\', '/')
                else:
                    # add a minimal record
                    meta.setdefault('memes', []).append({
                        'postLink': None,
                        'subreddit': None,
                        'title': base,
                        'url': None,
                        'local': os.path.relpath(webp_path, ROOT).replace('\\', '/'),
                        'thumb': os.path.relpath(thumb_path, ROOT).replace('\\', '/'),
                        'nsfw': False,
                        'spoiler': False,
                        'author': None,
                        'ups': 0,
                    })

        except Exception as e:
            print('Failed to process', path, e)

    meta['count'] = len(meta.get('memes', []))
    save_meta(meta)

    print(f'Optimized {optimized} images, created {thumbs} thumbnails. Metadata updated at {META_PATH}')


if __name__ == '__main__':
    try:
        process()
    except ImportError:
        print('Pillow not installed. Run `pip install pillow` and try again.')
