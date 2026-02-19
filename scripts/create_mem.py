import os

def generate_pattern_files(num_rows=1024):
    """
    יוצר קבצי .mem עם דפוסים מתמטיים פשוטים.
    הקבצים יישמרו בתיקייה שבה הסקריפט נמצא.
    """
    
    # מציאת הנתיב המלא של התיקייה בה הסקריפט נמצא
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # הגדרת נתיבים מלאים לקבצים
    file_red = os.path.join(script_dir, "debug_red_hex.mem")
    file_green = os.path.join(script_dir, "debug_green_hex.mem")
    file_blue = os.path.join(script_dir, "debug_blue_hex.mem")

    print(f"Generating files in: {script_dir}")

    try:
        # 1. Red Channel: ערכים עולים (0, 1, 2... 255, 0, 1...)
        with open(file_red, "w") as f:
            val = 0
            for _ in range(num_rows):
                pixel_data = []
                for _ in range(4):
                    pixel_data.append(f"{val:02X}")
                    val = (val + 1) % 256
                f.write("".join(pixel_data) + "\n")

        # 2. Green Channel: ערכים עולים ויורדים
        with open(file_green, "w") as f:
            val = 0
            direction = 1
            for _ in range(num_rows):
                pixel_data = []
                for _ in range(4):
                    pixel_data.append(f"{val:02X}")
                    if val == 255: direction = -1
                    elif val == 0: direction = 1
                    val += direction
                f.write("".join(pixel_data) + "\n")

        # 3. Blue Channel: מדרגות
        with open(file_blue, "w") as f:
            val = 0
            counter = 0
            for _ in range(num_rows):
                pixel_data = []
                for _ in range(4):
                    pixel_data.append(f"{val:02X}")
                    counter += 1
                    if counter >= 32:
                        val = (val + 32) % 256
                        counter = 0
                f.write("".join(pixel_data) + "\n")

        print("SUCCESS: Files created successfully.")

    except PermissionError:
        print("ERROR: Permission denied. Please close any program using these .mem files (like Vivado) and try again.")

if __name__ == "__main__":
    generate_pattern_files()