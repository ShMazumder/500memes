from PIL import Image, ImageDraw, ImageFont
import os
import random

COLORS = [(255, 100, 100), (100, 255, 100), (100, 100, 255), (255, 255, 100), (255, 100, 255), (100, 255, 255)]

def create_meme(index):
    img = Image.new('RGB', (500, 500), color=random.choice(COLORS))
    d = ImageDraw.Draw(img)
    # Just simple text centered
    text = f"Meme {index}"
    # We don't have a guaranteed font file, so default font (very small) or just minimal
    # Drawing a rectangle or circle to make it look "memey" or just text
    d.text((200, 200), text, fill=(0, 0, 0))
    
    img.save(f"assets/memes/meme_{index}.png")

if __name__ == "__main__":
    if not os.path.exists("assets/memes"):
        os.makedirs("assets/memes")
    for i in range(1, 21): # Generate 20 memes for testing
        create_meme(i)
print("Generated 20 memes.")
