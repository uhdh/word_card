from PIL import Image, ImageDraw
import math

def make_rotate_icon(size=32):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    gold = (245, 158, 11, 255)
    light_gold = (254, 240, 138, 255)
    dark_gold = (180, 83, 9, 255)
    
    cx, cy = size // 2, size // 2
    r = 8
    
    # Draw circular arc (clockwise arrow)
    for deg in range(35, 315, 3):
        rad = math.radians(deg)
        x = int(round(cx + r * math.cos(rad)))
        y = int(round(cy + r * math.sin(rad)))
        draw.point((x, y), fill=gold)
        
        x2 = int(round(cx + (r - 1) * math.cos(rad)))
        y2 = int(round(cy + (r - 1) * math.sin(rad)))
        draw.point((x2, y2), fill=light_gold)
        
    # Arrow tip
    tip_x = int(round(cx + r * math.cos(math.radians(35))))
    tip_y = int(round(cy + r * math.sin(math.radians(35))))
    
    arrow = [
        (tip_x - 1, tip_y - 4), (tip_x, tip_y - 4),
        (tip_x - 2, tip_y - 3), (tip_x - 1, tip_y - 3), (tip_x, tip_y - 3), (tip_x + 1, tip_y - 3),
        (tip_x - 3, tip_y - 2), (tip_x - 2, tip_y - 2), (tip_x - 1, tip_y - 2), (tip_x, tip_y - 2), (tip_x + 1, tip_y - 2), (tip_x + 2, tip_y - 2),
        (tip_x, tip_y - 1)
    ]
    for pt in arrow:
        draw.point(pt, fill=gold)
    draw.point((tip_x, tip_y - 2), fill=light_gold)
    
    return img

icon = make_rotate_icon(32)
for p in [
    "godot/assets/map_ui/ui_rotate_icon_32px_pastel.png",
    "assets/map_ui/ui_rotate_icon_32px_pastel.png",
    "src/assets/map_ui/ui_rotate_icon_32px_pastel.png",
    "public/assets/map_ui/ui_rotate_icon_32px_pastel.png"
]:
    icon.save(p)
print("Successfully created pixel rotate icon")
