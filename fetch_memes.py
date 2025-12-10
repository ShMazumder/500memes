import urllib.request
import json
import os
import ssl
import certifi

# Use certifi for certificates
ctx = ssl.create_default_context(cafile=certifi.where())

def fetch_memes():
    url = "https://meme-api.com/gimme/wholesomememes/20"
    print(f"Fetching from {url}...")
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        response = urllib.request.urlopen(req, context=ctx)
        data = json.loads(response.read().decode())
        
        memes = data.get('memes', [])
        print(f"Found {len(memes)} memes.")
        
        if os.path.exists("assets/memes"):
            for f in os.listdir("assets/memes"):
                # Clean up old files
                os.remove(os.path.join("assets/memes", f))
        else:
            os.makedirs("assets/memes")
            
        for i, meme in enumerate(memes):
            image_url = meme['url']
            ext = image_url.split('.')[-1]
            if ext not in ['jpg', 'png', 'jpeg']:
                 continue # strict filter for safety

            filename = f"assets/memes/meme_{i+1}.{ext}"
            print(f"Downloading {i+1}/20: {image_url}")
            
            try:
                img_req = urllib.request.Request(image_url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(img_req, context=ctx) as r, open(filename, 'wb') as f:
                    f.write(r.read())
            except Exception as e:
                print(f"Failed to download {image_url}: {e}")

        print("Done!")

    except Exception as e:
        print(f"Error fetching memes: {e}")

if __name__ == "__main__":
    fetch_memes()
