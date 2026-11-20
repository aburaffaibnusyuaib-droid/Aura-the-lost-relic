import os
from PIL import Image

# Otomatis mengambil folder tempat script ini berada (folder sky)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))

# Jika script ditaruh di root aura-20, sesuaikan jalurnya ke folder sky
if not os.path.exists(os.path.join(CURRENT_DIR, "Platfromer")):
    SKY_DIR = os.path.join(CURRENT_DIR, "assets", "tilemap", "sky")
else:
    SKY_DIR = CURRENT_DIR

OUTPUT_PATH = os.path.join(SKY_DIR, "sky_tileset_combined.png")

# Subfolder CraftPix (perhatikan ejaan 'Platfromer')
SUB_FOLDERS = ["Platfromer", "Environment", "Collectable Object"]

# Ambil semua file PNG
image_files = []
for sub in SUB_FOLDERS:
    folder_path = os.path.join(SKY_DIR, sub)
    if os.path.exists(folder_path):
        for root, _, files in os.walk(folder_path):
            for file in files:
                if file.lower().endswith(".png") and not file.startswith("."):
                    image_files.append(os.path.join(root, file))

if not image_files:
    print(f"File PNG tetap tidak ditemukan di: {SKY_DIR}")
    print("Pastikan folder Platfromer/Environment/Collectable Object ada di folder tersebut.")
    exit()

print(f"Menemukan {len(image_files)} gambar. Sedang memproses atlas...")

# Buka semua gambar dan urutkan berdasarkan tinggi gambar
loaded_images = [Image.open(f).convert("RGBA") for f in image_files]
loaded_images.sort(key=lambda img: img.height, reverse=True)

MAX_WIDTH = 2048
PADDING = 4

positions = []
cur_x = 0
cur_y = 0
row_height = 0

for img in loaded_images:
    if cur_x + img.width > MAX_WIDTH:
        cur_x = 0
        cur_y += row_height + PADDING
        row_height = 0

    positions.append((cur_x, cur_y))
    cur_x += img.width + PADDING
    row_height = max(row_height, img.height)

total_height = cur_y + row_height

# Buat kanvas transparan dan satukan
atlas = Image.new("RGBA", (MAX_WIDTH, total_height), (0, 0, 0, 0))
for img, pos in zip(loaded_images, positions):
    atlas.paste(img, pos, img)

atlas.save(OUTPUT_PATH)
print(f"Berhasil! Hasil tersimpan di: {OUTPUT_PATH}")