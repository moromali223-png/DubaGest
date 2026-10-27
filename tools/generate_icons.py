import os
import shutil
from PIL import Image

SOURCE_IMAGE = r"C:\Users\pc\.gemini\antigravity-ide\brain\8fce5fec-2668-4326-9255-ba404b3f140a\dubagest_croissance_1792085955792.jpg"
WORKSPACE = r"c:\Users\pc\Desktop\projet 1\dubagest"

def run():
    print(f"Loading source image: {SOURCE_IMAGE}")
    img = Image.open(SOURCE_IMAGE).convert("RGBA")
    w, h = img.size
    print(f"Original size: {w}x{h}")
    
    # Resize to exact 1024x1024 high-res master
    master_1024 = img.resize((1024, 1024), Image.Resampling.LANCZOS)
    
    # 1. Save master into assets/icons/app_icon.png
    assets_icons_dir = os.path.join(WORKSPACE, "assets", "icons")
    os.makedirs(assets_icons_dir, exist_ok=True)
    master_path = os.path.join(assets_icons_dir, "app_icon.png")
    master_1024.save(master_path, format="PNG", optimize=True)
    print(f"Saved master icon to: {master_path}")

    # 2. Web / PWA
    web_icons_dir = os.path.join(WORKSPACE, "web", "icons")
    os.makedirs(web_icons_dir, exist_ok=True)
    
    master_1024.resize((192, 192), Image.Resampling.LANCZOS).save(
        os.path.join(web_icons_dir, "Icon-192.png"), format="PNG"
    )
    master_1024.resize((512, 512), Image.Resampling.LANCZOS).save(
        os.path.join(web_icons_dir, "Icon-512.png"), format="PNG"
    )
    
    # Maskable icons: Safe zone is 80% diameter circle centered. Add 10% padding around
    def create_maskable(size):
        content_size = int(size * 0.82)
        offset = (size - content_size) // 2
        bg_color = (26, 37, 34, 255) # AppColors.ink / Dark slate background
        # Sample edge pixel for background
        edge_px = master_1024.getpixel((10, 10))
        mask_bg = Image.new("RGBA", (size, size), edge_px)
        resized_content = master_1024.resize((content_size, content_size), Image.Resampling.LANCZOS)
        mask_bg.paste(resized_content, (offset, offset), resized_content)
        return mask_bg

    create_maskable(192).save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), format="PNG")
    create_maskable(512).save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), format="PNG")
    print("Generated Web PWA icons (192, 512, maskable)")

    # Favicon
    favicon_path = os.path.join(WORKSPACE, "web", "favicon.png")
    master_1024.resize((48, 48), Image.Resampling.LANCZOS).save(favicon_path, format="PNG")
    print("Generated web/favicon.png")

    # 3. Windows Desktop .ico
    windows_res_dir = os.path.join(WORKSPACE, "windows", "runner", "resources")
    os.makedirs(windows_res_dir, exist_ok=True)
    ico_path = os.path.join(windows_res_dir, "app_icon.ico")
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master_1024.save(ico_path, format="ICO", sizes=ico_sizes)
    print(f"Generated Windows app_icon.ico with sizes: {ico_sizes}")

    # 4. Android mipmaps
    android_res_dir = os.path.join(WORKSPACE, "android", "app", "src", "main", "res")
    android_densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_densities.items():
        folder_path = os.path.join(android_res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        out_file = os.path.join(folder_path, "ic_launcher.png")
        master_1024.resize((size, size), Image.Resampling.LANCZOS).save(out_file, format="PNG")
        print(f"Generated Android {folder}/ic_launcher.png ({size}x{size})")

    # 5. iOS AppIcon.appiconset
    ios_icon_dir = os.path.join(WORKSPACE, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_icon_dir):
        ios_files = {
            "Icon-App-20x20@1x.png": 20,
            "Icon-App-20x20@2x.png": 40,
            "Icon-App-20x20@3x.png": 60,
            "Icon-App-29x29@1x.png": 29,
            "Icon-App-29x29@2x.png": 58,
            "Icon-App-29x29@3x.png": 87,
            "Icon-App-40x40@1x.png": 40,
            "Icon-App-40x40@2x.png": 80,
            "Icon-App-40x40@3x.png": 120,
            "Icon-App-60x60@2x.png": 120,
            "Icon-App-60x60@3x.png": 180,
            "Icon-App-76x76@1x.png": 76,
            "Icon-App-76x76@2x.png": 152,
            "Icon-App-83.5x83.5@2x.png": 167,
            "Icon-App-1024x1024@1x.png": 1024,
        }
        for fname, size in ios_files.items():
            out_file = os.path.join(ios_icon_dir, fname)
            master_1024.resize((size, size), Image.Resampling.LANCZOS).save(out_file, format="PNG")
        print(f"Generated all {len(ios_files)} iOS AppIcon variants.")

    print("\n[SUCCESS] All app icons have been generated cleanly and professionally across all platforms!")

if __name__ == "__main__":
    run()
