import serial
import time
import tkinter as tk
from PIL import Image, ImageTk
import threading

# --- קונפיגורציה ---
PORT = 'COM14'
BAUD = 115200 
WIDTH, HEIGHT = 256, 256
SCALE = 1

class PureImageDebugger:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("IMAGE ONLY DEBUGGER - v44")
        
        # יצירת קנבס לתצוגה
        self.canvas = tk.Label(self.root, bg="blue") # רקע כחול כדי לזהות אם הקנבס עלה
        self.canvas.pack()
        
        self.img = Image.new("RGB", (WIDTH, HEIGHT), "black")
        self.tk_img = None
        self.ser = None
        self.pixel_count = 0
        
        print(f"--- Starting Debugger on {PORT} at {BAUD} ---")
        threading.Thread(target=self.run_logic, daemon=True).start()
        self.root.mainloop()

    def log_hex(self, data):
        """ מדפיס את המידע הגולמי ב-Hex כדי שנראה מה באמת עובר בכבל """
        print(f"RAW DATA: {data.hex().upper()}")

    def send_cmd(self, addr, data):
        """ שליחת פקודה בפורמט 16 בייטים קשיח """
        pkt = bytearray([0x7B, ord('W'), (addr>>16)&0xFF, (addr>>8)&0xFF, addr&0xFF, 
                         0x2C, 0x56, 0x00, (data>>24)&0xFF, (data>>16)&0xFF, 
                         0x2C, 0x56, 0x00, (data>>8)&0xFF, data&0xFF, 0x7D])
        self.ser.write(pkt)
        print(f"TX Command >> {pkt.hex().upper()}")

    def run_logic(self):
        try:
            self.ser = serial.Serial(PORT, BAUD, timeout=0.05)
            self.ser.reset_input_buffer()
            time.sleep(1)

            # שליחת IMG_READY (כתובת 050000, ביט 20)
            self.send_cmd(0x050000, 0x00100000)
            time.sleep(0.5)

            # שליחת IMG_READ (כתובת 050008, ביט 0)
            self.send_cmd(0x050008, 0x00000001)
            
            buffer = bytearray()
            print("\n--- WAITING FOR PIXELS ---")
            
            while len(buffer) >= 16:
                # חיפוש סנכרון אגרסיבי
                try:
                    start_idx = buffer.index(0x7B)
                except ValueError:
                    # לא מצאנו התחלה, נשמור רק את הסוף למקרה שההתחלה תגיע בחתיכה הבאה
                    buffer = buffer[-15:] 
                    break
                
                # זורקים את כל הזבל שלפני ה-{
                if start_idx > 0:
                    del buffer[:start_idx]
                
                # עכשיו buffer מתחיל ב-0x7B. האם יש מספיק מידע?
                if len(buffer) < 16:
                    break
                    
                pkt = buffer[:16]
                if pkt[15] == 0x7D: # בדיקת סיום תקינה
                    # ... (הפענוח הרגיל שלך) ...
                    row = (pkt[2] << 16) | (pkt[3] << 8) | pkt[4]
                    col = (pkt[7] << 16) | (pkt[8] << 8) | pkt[9]
                    # ...
                    del buffer[:16] # מחיקת הפאקט שטופל
                else:
                    # פאקט שבור למרות ההתחלה, נמחק בייט אחד וננסה שוב
                    del buffer[0]
                time.sleep(0.001)

        except Exception as e:
            print(f"ERROR: {e}")

    def update_ui(self):
        # עדכון התמונה על המסך
        resized = self.img.resize((WIDTH*SCALE, HEIGHT*SCALE), Image.NEAREST)
        self.tk_img = ImageTk.PhotoImage(resized)
        self.canvas.config(image=self.tk_img)
        self.root.update_idletasks()

if __name__ == "__main__":
    PureImageDebugger()