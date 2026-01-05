from PIL import Image, ImageDraw, ImageFont
import os
import random

COLORS = [
    (255, 100, 100),
    (100, 255, 100),
    (100, 100, 255),
    (255, 255, 100),
    (255, 100, 255),
    (100, 255, 255),
]


def create_meme(index, size=(800, 800)):
    img = Image.new('RGB', size, color=random.choice(COLORS))
    d = ImageDraw.Draw(img)
    text = f"Meme {index}"

    try:
        # Try loading a truetype font for nicer output
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 48)
    except Exception:
        font = ImageFont.load_default()

    w, h = d.textsize(text, font=font)
    d.text(((size[0] - w) / 2, (size[1] - h) / 2), text, fill=(0, 0, 0), font=font)

    filename = f"assets/memes/meme_{index:03d}.png"
    img.save(filename)


if __name__ == "__main__":
    count = 500
    out_dir = "assets/memes"
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)

    print(f"Generating {count} placeholder memes in {out_dir} ...")
    for i in range(1, count + 1):
        create_meme(i)
        if i % 50 == 0:
            print(f"  Created {i}/{count}")

    print(f"Done: {count} generated. Remember to add real images if you prefer.")
