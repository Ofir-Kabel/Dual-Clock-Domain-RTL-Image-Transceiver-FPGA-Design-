import os
from PIL import Image

# --- הגדרות ---
# וודא שהתמונה נמצאת באותה תיקייה או עדכן נתיב מלא
IMAGE_FILENAME = 'fpga_img.png' 
TARGET_SIZE = (256, 256)

def convert_image_to_mem_32bit():
    # 1. הגדרת נתיבים
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # בדיקת נתיב התמונה
    if os.path.isabs(IMAGE_FILENAME):
        img_path = IMAGE_FILENAME
    else:
        img_path = os.path.join(script_dir, IMAGE_FILENAME)

    file_r = os.path.join(script_dir, 'image_red_32bit.mem')
    file_g = os.path.join(script_dir, 'image_green_32bit.mem')
    file_b = os.path.join(script_dir, 'image_blue_32bit.mem')

    # 2. טעינת התמונה
    if not os.path.exists(img_path):
        print(f"Error: Image not found at: {img_path}")
        return

    try:
        print(f"Opening image: {img_path}")
        img = Image.open(img_path).convert('RGB')

        if img.size != TARGET_SIZE:
            print(f"Resizing from {img.size} to {TARGET_SIZE}...")
            img = img.resize(TARGET_SIZE)
        
        # רשימה של טאפלים (R, G, B)
        pixels = list(img.getdata())
        total_pixels = len(pixels)
        
        # בדיקה שהגודל מתחלק ב-4 (חובה לפורמט 32 ביט)
        if total_pixels % 4 != 0:
            print(f"Error: Total pixels ({total_pixels}) must be divisible by 4 for 32-bit packing.")
            return

        print(f"Processing {total_pixels} pixels into 32-bit words...")

        # 3. כתיבה לקבצי MEM
        with open(file_r, 'w') as fr, \
             open(file_g, 'w') as fg, \
             open(file_b, 'w') as fb:
            
            # רצים בלולאה בקפיצות של 4
            for i in range(0, total_pixels, 4):
                # שליפת 4 פיקסלים
                p0 = pixels[i]
                p1 = pixels[i+1]
                p2 = pixels[i+2]
                p3 = pixels[i+3]
                
                # יצירת מחרוזת Hex באורך 8 תווים (32 ביט) לכל ערוץ צבע
                # פורמט: R0 R1 R2 R3 (כאשר R0 הוא השמאלי ביותר - MSB)
                
                # RED Channel
                hex_r = f"{p0[0]:02X}{p1[0]:02X}{p2[0]:02X}{p3[0]:02X}"
                fr.write(hex_r + "\n")
                
                # GREEN Channel
                hex_g = f"{p0[1]:02X}{p1[1]:02X}{p2[1]:02X}{p3[1]:02X}"
                fg.write(hex_g + "\n")
                
                # BLUE Channel
                hex_b = f"{p0[2]:02X}{p1[2]:02X}{p2[2]:02X}{p3[2]:02X}"
                fb.write(hex_b + "\n")

        print("-" * 30)
        print("Conversion Complete (32-bit packed)!")
        print(f"Generated 3 files in: {script_dir}")
        print("Format: [Pixel_0][Pixel_1][Pixel_2][Pixel_3] per line")
        print("-" * 30)

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    convert_image_to_mem_32bit()