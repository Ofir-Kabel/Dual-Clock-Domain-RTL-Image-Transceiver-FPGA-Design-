import serial
import time
import os
import sys
import threading

# --- הגדרות ---
PORT = 'COM14'
BAUD_RATE = 5_000_000
# שם הקובץ שאתה רוצה לשלוח (הוא לא ישתנה!)
MEM_FILE_TO_SEND = 'debug_gradient.mem' 

def load_mem_file(filepath):
    """
    קורא קובץ MEM בפורמט 32 ביט, ומחזיר רשימה שטוחה של פיקסלים (בייטים)
    """
    pixels = []
    if not os.path.exists(filepath):
        print(f"Error: File {filepath} not found.")
        return []

    print(f"Reading file: {filepath}...")
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            
            try:
                # המרה מהקסדצימלי (למשל '01010101') למספר שלם
                val = int(line, 16)
                
                # פירוק ה-32 ביט ל-4 פיקסלים בודדים (P0, P1, P2, P3)
                # P0 הוא ה-MSB (השמאלי ביותר)
                p0 = (val >> 24) & 0xFF
                p1 = (val >> 16) & 0xFF
                p2 = (val >> 8) & 0xFF
                p3 = val & 0xFF
                
                # הוספה לרשימה שטוחה
                pixels.extend([p0, p1, p2, p3])
                
            except ValueError:
                print(f"Skipping invalid line: {line}")
                continue
                
    return pixels

def main():
    # 1. מציאת הנתיב לקובץ
    script_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(script_dir, MEM_FILE_TO_SEND)
    
    # 2. טעינת הנתונים לזיכרון (קריאה בלבד!)
    pixel_data = load_mem_file(file_path)
    
    total_pixels = len(pixel_data)
    if total_pixels == 0:
        print("No data to send."); return

    print(f"Loaded {total_pixels} pixels from file.")

    # 3. חיבור ל-UART
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=0.1, rtscts=True) # RTS/CTS חשוב
        print(f"Connected to {PORT}")
    except Exception as e:
        print(f"Serial Error: {e}"); return

    # 4. שידור ל-FPGA
    print("Starting Transmission...")
    start_time = time.time()
    
    try:
        for addr, val in enumerate(pixel_data):
            # אנחנו שולחים את אותו ערך (val) ל-R, G ו-B 
            # כי זה קובץ גרדיאנט שחור-לבן
            r, g, b = val, val, val
            
            # בניית הפקטה: { W A2 A1 A0 , P R G B }
            pkt = bytearray([
                0x7B, 0x57,
                (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF,
                0x2C, 0x50,
                r, g, b,
                0x7D
            ])
            
            ser.write(pkt)
            
            # --- Flow Control (השהיה למניעת הצפה) ---
            if addr % 100 == 0:
                time.sleep(0.001)

            # עדכון התקדמות
            if addr % 5000 == 0:
                print(f"\rProgress: {addr/total_pixels*100:.1f}%", end="")

        print(f"\nDone! Sent {total_pixels} pixels in {time.time() - start_time:.2f}s")

    except KeyboardInterrupt:
        print("\nStopped by user.")
    except Exception as e:
        print(f"\nError during transmission: {e}")
    finally:
        ser.close()

if __name__ == "__main__":
    main()