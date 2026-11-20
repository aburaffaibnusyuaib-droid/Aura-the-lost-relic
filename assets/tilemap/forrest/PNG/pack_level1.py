import os
import math
from PIL import Image

def pack_level1_assets(output_name="tileset_level1.png", padding=4):
    image_paths = []
    
    # Ambil semua file PNG dari folder ini dan subfoldernya (kecuali background)
    for root, dirs, files in os.walk('.'):
        if 'Background' in root:
            continue
        for file in files:
            if file.lower().endswith('.png') and file != output_name and not file.startswith('tileset_'):
                image_paths.append(os.path.join(root, file))

    if not image_paths:
        print("Tidak ada file PNG yang ditemukan!")
        return

    print(f"Mengumpulkan {len(image_paths)} aset untuk Level 1...")
    loaded_imgs = [Image.open(p).convert("RGBA") for p in image_paths]

    # Ambil ukuran standar (rata-rata aset platform/tanah) agar tidak melompong lebar
    avg_w = math.ceil(sum(img.width for img in loaded_imgs) / len(loaded_imgs))
    avg_h = math.ceil(sum(img.height for img in loaded_imgs) / len(loaded_imgs))

    tile_w = avg_w + padding
    tile_h = avg_h + padding

    cols = math.ceil(math.sqrt(len(loaded_imgs)))
    rows = math.ceil(len(loaded_imgs) / cols)

    # Buat kanvas rapat
    sheet_w = cols * tile_w
    sheet_h = rows * tile_h
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    # Susun berdekatan dan rapi
    for idx, img in enumerate(loaded_imgs):
        # Kalau ada aset dekorasi yang kelewat besar, disesuaikan agar grid tetap serasi
        if img.width > tile_w or img.height > tile_h:
            img.thumbnail((tile_w - padding, tile_h - padding), Image.Resampling.LANCZOS)

        c = idx % cols
        r = idx // cols

        x = c * tile_w + (padding // 2)
        y = r * tile_h + (padding // 2)
        sheet.paste(img, (x, y))

    sheet.save(output_name)
    print(f"\nSukses! Aset Level 1 sudah digabung rapat ke '{output_name}' ({sheet_w}x{sheet_h} px).")

if __name__ == "__main__":
    pack_level1_assets()