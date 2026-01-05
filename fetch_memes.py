import urllib.request
import json
import os
import ssl
import time
import argparse

# Use certifi for certificates when available; otherwise fall back
try:
    import certifi as _certifi
    ctx = ssl.create_default_context(cafile=_certifi.where())
except Exception:
    print('certifi not available; using system default SSL context')
    ctx = ssl.create_default_context()


def fetch_memes(target_count=500, batch_size=20, subreddits='wholesomememes,MadeMeSmile,aww,HumansBeingBros,wholesomeanimemes,rarepuppers,Eyebleach,wholesomecomics', out_dir='assets/memes', min_ups=0, exclude_gifs=True, stop_after_no_new=5):
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)

    # Load existing metadata to avoid duplicates and continue numbering
    meta_path = os.path.join(out_dir, '..', 'memes.json')
    seen_urls = set()
    existing_meta = {'count': 0, 'memes': []}
    if os.path.exists(meta_path):
        try:
            with open(meta_path, 'r', encoding='utf-8') as mf:
                existing_meta = json.load(mf)
                for m in existing_meta.get('memes', []):
                    url = m.get('url')
                    if url:
                        seen_urls.add(url)
        except Exception:
            existing_meta = {'count': 0, 'memes': []}

    file_index = existing_meta.get('count', 0) + 1

    subreddit_list = [s.strip() for s in subreddits.split(',') if s.strip()]
    if not subreddit_list:
        subreddit_list = []

    print(f"Starting fetch: target={target_count}, batch={batch_size}, subreddits={subreddit_list}, min_ups={min_ups}, exclude_gifs={exclude_gifs}")
    consecutive_no_new = 0

    consecutive_no_new = 0
    round_idx = 0

    while file_index <= target_count:
        fetch_count = min(batch_size, target_count - file_index + 1)
        # rotate through subreddits (or request mixed if none)
        if subreddit_list:
            subreddit = subreddit_list[round_idx % len(subreddit_list)]
            round_idx += 1
            url = f"https://meme-api.com/gimme/{subreddit}/{fetch_count}"
        else:
            url = f"https://meme-api.com/gimme/{fetch_count}"

        print(f"Requesting {fetch_count} items from {url}...")

        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            response = urllib.request.urlopen(req, context=ctx)
            data = json.loads(response.read().decode())

            memes = data.get('memes') if isinstance(data, dict) and 'memes' in data else []
            if not memes and isinstance(data, dict) and 'url' in data:
                memes = [data]

            print(f"Fetched {len(memes)} items.")

            # Prefer memes with higher upvotes first
            try:
                memes.sort(key=lambda x: int(x.get('ups', 0)), reverse=True)
            except Exception:
                pass

            new_downloaded_this_batch = 0

            for meme in memes:
                image_url = meme.get('url')
                if not image_url:
                    continue
                # Skip gifs if requested
                if exclude_gifs and image_url.lower().endswith('.gif'):
                    continue

                # Minimum upvotes filter
                try:
                    ups = int(meme.get('ups', 0))
                except Exception:
                    ups = 0
                if ups < min_ups:
                    continue

                if image_url in seen_urls:
                    continue

                ext = image_url.split('?')[0].split('.')[-1].lower()
                if ext not in ['jpg', 'png', 'jpeg']:
                    # try common fallback
                    ext = 'jpg'

                filename = os.path.join(out_dir, f"meme_{file_index:03d}.{ext}")
                print(f"Downloading {file_index}/{target_count}: {image_url} -> {filename}")

                try:
                    img_req = urllib.request.Request(image_url, headers={'User-Agent': 'Mozilla/5.0'})
                    with urllib.request.urlopen(img_req, context=ctx, timeout=30) as r, open(filename, 'wb') as f:
                        f.write(r.read())
                    seen_urls.add(image_url)
                    # Save metadata entry
                    existing_meta.setdefault('memes', []).append({
                        'postLink': meme.get('postLink'),
                        'subreddit': meme.get('subreddit'),
                        'title': meme.get('title'),
                        'url': image_url,
                        'nsfw': meme.get('nsfw', False),
                        'spoiler': meme.get('spoiler', False),
                        'author': meme.get('author'),
                        'ups': meme.get('ups', 0),
                    })

                    file_index += 1
                    if file_index > target_count:
                        break
                    new_downloaded_this_batch += 1
                    time.sleep(0.2)  # small delay between downloads
                except Exception as e:
                    print(f"Failed to download {image_url}: {e}")

            # Write metadata after each batch
            try:
                existing_meta['count'] = file_index - 1
                with open(meta_path, 'w', encoding='utf-8') as mf:
                    json.dump(existing_meta, mf, ensure_ascii=False, indent=2)
            except Exception as e:
                print(f"Failed to write metadata: {e}")

        except Exception as e:
            print(f"Error fetching batch: {e}")

        # Delay between batches to be polite
        time.sleep(1.0)

        # Update consecutive no-new counter and decide whether to stop
        if new_downloaded_this_batch == 0:
            consecutive_no_new += 1
            print(f"No new images this batch (consecutive no-new={consecutive_no_new}).")
        else:
            consecutive_no_new = 0

        if not memes:
            print("No more memes returned by API; stopping.")
            break

        if consecutive_no_new >= stop_after_no_new:
            print(f"No new images across {consecutive_no_new} batches; stopping to avoid loop.")
            break

    print(f"Finished. Downloaded {file_index-1} images to {out_dir}.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Download memes into assets/memes')
    parser.add_argument('--count', type=int, default=500, help='Total number of memes to download')
    parser.add_argument('--batch', type=int, default=20, help='Number of memes per API request')
    parser.add_argument('--subreddits', type=str, default='wholesomememes,MadeMeSmile,aww,HumansBeingBros,wholesomeanimemes,rarepuppers,Eyebleach,wholesomecomics', help='Comma-separated subreddits to rotate through (or empty for mixed)')
    parser.add_argument('--min-ups', type=int, default=0, help='Minimum upvotes to accept a meme')
    parser.add_argument('--exclude-gifs', type=lambda x: x.lower() in ('1','true','yes'), default=True, help='Exclude GIFs (True/False)')
    parser.add_argument('--stop-after-no-new', type=int, default=5, help='Stop after this many consecutive no-new-image batches')
    args = parser.parse_args()

    # WARNING: ensure you have rights to use these images and respect API terms.
    fetch_memes(target_count=args.count, batch_size=args.batch, subreddits=args.subreddits, min_ups=args.min_ups, exclude_gifs=args.exclude_gifs, stop_after_no_new=args.stop_after_no_new)
