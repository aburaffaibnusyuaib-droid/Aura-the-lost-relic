import os
import math
from PIL import Image

# Path folder aset
folder_path = r"C:\Users\asus\OneDrive\Documents\aura-20\assets\tilemap\cristal freze\PNG"
output_file = os.path.join(folder_path, "tilesetlevl2.png")

# Cari semua file .png (Kecualikan folder Background dan file output)
file_gambar = []
for root, dirs, files in os.walk(folder_path):
    # Abaikan subfolder Background agar tidak merusak ukuran grid tile
    if "background" in root.lower():
        continue
    for f in files:
        if f.lower().endswith(".png") and f != "tilesetlevl2.png":
            file_gambar.append(os.path.join(root, f))

if not file_gambar:
    print("Nggak ada file PNG yang ditemukan di folder tersebut!")
    exit()

# Buka gambar dan filter jika masih ada gambar berukuran raksasa
images = []
for f in file_gambar:
    img = Image.open(f).convert("RGBA")
    # Hanya ambil aset tile (abaikan gambar jika lebarnya > 500px)
    if img.width <= 500 and img.height <= 500:
        images.append(img)

if not images:
    print("Tidak ada aset tile yang lolos filter ukuran!")
    exit()

# Tentukan ukuran grid seragam berdasarkan ukuran tile murni
max_w = max(img.width for img in images)
max_h = max(img.height for img in images)
kolom = 10
baris = math.ceil(len(images) / kolom)

# Buat kanvas transparan dan tempel rapat
kanvas = Image.new("RGBA", (kolom * max_w, baris * max_h), (0, 0, 0, 0))
for idx, img in enumerate(images):
    x = (idx % kolom) * max_w
    y = (idx // kolom) * max_h
    # Tempel di tengah sel agar simetris
    offset_x = (max_w - img.width) // 2
    offset_y = (max_h - img.height) // 2
    kanvas.paste(img, (x + offset_x, y + offset_y), img)

kanvas.save(output_file)
print(f"Beres! Tileset rapat berhasil dibuat: {output_file}")