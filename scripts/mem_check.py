import os

def generate_shifted_gradient():
    # --- הגדרת נתיב דינמית (כמו קודם) ---
    script_path = os.path.abspath(__file__)
    script_dir = os.path.dirname(script_path)
    output_filename = os.path.join(script_dir, 'debug_gradient_32pixels.mem')

    print(f"Generating aligned gradient file at: {output_filename}")

    try:
        with open(output_filename, 'w') as f:
            # 16,384 שורות (עבור תמונה של 256x256 בפורמט 32 ביט)
            for i in range(32*32):
                
                # --- התיקון כאן ---
                # מוסיפים 1 לאינדקס (i + 1)
                # שורה 1 (i=0)  -> 1 // 64 = 0
                # שורה 63 (i=62) -> 63 // 64 = 0
                # שורה 64 (i=63) -> 64 // 64 = 1  <-- השינוי קורה בול בשורה 64


                # val = ((i + 1) // 64) % 256
                
                val = ((i) // 8) % 32


                # שכפול הערך 4 פעמים למילוי 32 ביט
                hex_line = f"{val:02X}" * 4
                
                f.write(f"{hex_line}\n")

        print("Success! File created.")
        print("Check Line 64 - it should now be '01010101'.")
        
    except Exception as e:
        print(f"Error creating file: {e}")

if __name__ == "__main__":
    generate_shifted_gradient()