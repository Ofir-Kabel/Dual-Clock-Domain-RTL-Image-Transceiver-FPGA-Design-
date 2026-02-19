import os
from PIL import Image

def get_script_directory():
    return os.path.dirname(os.path.abspath(__file__))

def load_mem_channel_32bit(filename):
    pixel_values = []
    file_path = os.path.join(get_script_directory(), filename)
    
    if not os.path.exists(file_path):
        print(f"Error: File '{filename}' not found at {file_path}")
        return []

    print(f"Reading {filename}...")
    try:
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line: continue
                # דילוג על הערות (כמו @address)
                if line.startswith('@') or line.startswith('['): continue 
                
                try:
                    # המרה ממחרוזת Hex באורך 8 תווים למספר שלם (32 ביט)
                    val = int(line, 16)
                    
                    # פירוק ה-32 ביט ל-4 בייטים נפרדים (Big Endian: P0 P1 P2 P3)
                    # P0 הוא ה-MSB (השמאלי ביותר בקובץ)
                    p0 = (val >> 24) & 0xFF
                    p1 = (val >> 16) & 0xFF
                    p2 = (val >> 8) & 0xFF
                    p3 = val & 0xFF
                    
                    pixel_values.extend([p0, p1, p2, p3])
                    
                except ValueError:
                    continue
    except Exception as e:
        print(f"Error reading file: {e}")
        return []
        
    return pixel_values

def main():
    # הגדרות גודל
    width = 256
    height = 256
    total_pixels = width * height
    
    print(f"Script Directory: {get_script_directory()}")
    
    # # טעינת הערוצים (ודא שהשמות תואמים לקבצים שיצרת)
    # r = load_mem_channel_32bit("image_red_32bit.mem")
    # g = load_mem_channel_32bit("image_green_32bit.mem")
    # b = load_mem_channel_32bit("image_blue_32bit.mem")

    r = load_mem_channel_32bit("image_red.mem")
    g = load_mem_channel_32bit("image_green.mem")
    b = load_mem_channel_32bit("image_blue.mem")

    # r = load_mem_channel_32bit("debug_gradient.mem")
    # g = load_mem_channel_32bit("debug_gradient.mem")
    # b = load_mem_channel_32bit("debug_gradient.mem")
    
    # בדיקת תקינות
    if len(r) != total_pixels or len(g) != total_pixels or len(b) != total_pixels:
        print(f"Warning: Data length mismatch. Expected {total_pixels}")
        print(f"Got -> R:{len(r)}, G:{len(g)}, B:{len(b)}")
        # ניסיון תיקון (חיתוך אם יש יותר מדי, או עצירה אם חסר)
        if len(r) < total_pixels: return
        r = r[:total_pixels]
        g = g[:total_pixels]
        b = b[:total_pixels]

    print("Reconstructing Image from 32-bit packed MEM files...")
    img = Image.new("RGB", (width, height))
    pixels = img.load()
    
    idx = 0
    try:
        for y in range(height):
            for x in range(width):
                pixels[x, y] = (r[idx], g[idx], b[idx])
                idx += 1
    except Exception as e:
        print(f"Error constructing image: {e}")
        return

    # שמירה
    output_path = os.path.join(get_script_directory(), "restored_from_32bit.png")
    img.save(output_path)
    print(f"Success! Image saved to: {output_path}")
    
    # הצגה (אופציונלי)
    try:
        img.show()
    except:
        pass

if __name__ == "__main__":
    main()