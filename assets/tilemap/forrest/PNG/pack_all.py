import os
import math
from PIL import Image

def pack_recursive_images(output_filename="tileset_sheet.png"):
    image_paths = []
    
    # os.walk akan menyisir folder ini dan seluruh subfolder di dalamnya
    for root, dirs, files in os.walk('.'):
        # Lewati folder Background agar tidak merusak ukuran grid tileset
        if 'Background' in root:
            continue
            
        for file in files:
            if file.lower().endswith('.png') and file != output_filename:
                image_paths.append(os.path.join(root, file))
    
    if not image_paths:
        print("Tidak ada file PNG yang ditemukan di subfolder!")
        return

    print(f"Ditemukan {len(image_paths)} gambar di semua subfolder. Memproses...")

    # Membaca seluruh file gambar
    loaded_imgs = [Image.open(p).convert("RGBA") for p in image_paths]
    
    # Cari ukuran terlebar dan tertinggi untuk ukuran kotak grid
    max_w = max(img.width for img in loaded_imgs)
    max_h = max(img.height for img in loaded_imgs)

    # Susun ke bentuk grid kotak
    num_imgs = len(loaded_imgs)
    cols = math.ceil(math.sqrt(num_imgs))
    rows = math.ceil(num_imgs / cols)

    sheet_w = cols * max_w
    sheet_h = rows * max_h
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    # Tempel setiap gambar ke dalam kanvas
    for idx, img in enumerate(loaded_imgs):
        c = idx % cols
        r = idx // cols
        x = c * max_w
        y = r * max_h
        sheet.paste(img, (x, y))

    sheet.save(output_filename)
    print(f"Berhasil! {num_imgs} aset dari semua subfolder disatukan ke '{output_filename}' ({sheet_w}x{sheet_h} px).")

if __name__ == "__main__":
    pack_recursive_images()