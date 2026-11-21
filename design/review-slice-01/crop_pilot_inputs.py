import os
from PIL import Image, ImageOps

BASE = r"c:\AI\gemini\promise-path-next\design\review-slice-01"
OUT = os.path.join(BASE, "inputs")
os.makedirs(OUT, exist_ok=True)

abram = Image.open(os.path.join(BASE, "abram-turnaround-4view.png")).convert("RGBA")
bg = abram.getpixel((10, 10))


def save_square(img: Image.Image, name: str) -> None:
    cw, ch = img.size
    side = max(cw, ch) + 40
    sq = Image.new("RGBA", (side, side), bg)
    sq.paste(img, ((side - cw) // 2, (side - ch) // 2))
    sq.resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, name))


# 4-view turnaround (1680x945), crop above bottom text labels (y < 855)
save_square(abram.crop((30, 20, 455, 855)), "abram_front.png")
save_square(abram.crop((455, 20, 885, 855)), "abram_back.png")
save_square(abram.crop((895, 20, 1175, 855)), "abram_left.png")
save_square(ImageOps.mirror(abram.crop((1190, 20, 1465, 855))), "abram_right_flipped.png")
save_square(abram.crop((1500, 95, 1650, 855)), "prop_shepherd_crook.png")

camp = Image.open(os.path.join(BASE, "camp-scene-mobile.png")).convert("RGBA")
camp.crop((360, 220, 950, 620)).save(os.path.join(OUT, "bldg_main_tent_ref.png"))
camp.crop((410, 460, 560, 600)).save(os.path.join(OUT, "prop_amphora_ref.png"))

print("CROPPED_OK:", sorted(os.listdir(OUT)))
