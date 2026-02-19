import serial
import tkinter as tk
from PIL import Image, ImageTk
import threading
import time
import datetime
import os

# --- Configuration ---
PORT = 'COM14'       # וודא שזה הפורט הנכון
BAUD = 5_000_000     # קצב התקשורת
W, H = 256, 256      # רזולוציית התמונה
SCALE = 2            # זום לתצוגה

# ==========================================
#           SMART ERROR LOGGER
# ==========================================
class SmartErrorLogger:
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.last_row = -1
        self.last_col = -1
        self.errors_detected = 0
        self.total_pixels = 0
        
        current_dir = os.path.dirname(os.path.abspath(__file__))
        self.filename = os.path.join(current_dir, "fpga_smart_error_log.txt")
        
        print(f"--- Smart Logger Active. Errors saved to: {self.filename} ---")
        
        with open(self.filename, "w", encoding="utf-8") as f:
            f.write("Timestamp      | Event              | Expected (Row,Col) | Actual (Row,Col)\n")
            f.write("-" * 85 + "\n")

    def check_and_log(self, row, col):
        self.total_pixels += 1
        
        if self.last_row == -1:
            self.last_row = row
            self.last_col = col
            return

        expected_col = self.last_col + 1
        expected_row = self.last_row
        
        if expected_col >= self.width:
            expected_col = 0
            expected_row += 1
            
        if expected_row >= self.height:
            expected_row = 0
            expected_col = 0

        if row != expected_row or col != expected_col:
            if row == 0 and col == 0:
                self.log_event("NEW FRAME START", expected_row, expected_col, row, col)
            else:
                self.log_event("DATA LOSS/JUMP ", expected_row, expected_col, row, col)
                self.errors_detected += 1

        self.last_row = row
        self.last_col = col

    def log_event(self, event_type, exp_r, exp_c, act_r, act_c):
        ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        msg = f"{ts} | {event_type}    | ({exp_r:3},{exp_c:3})        | ({act_r:3},{act_c:3})"
        print(msg) 
        try:
            with open(self.filename, "a", encoding="utf-8") as f:
                f.write(msg + "\n")
        except:
            pass

# ==========================================
#           MAIN APPLICATION
# ==========================================
class UARTReceiverApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA Burst Viewer + Commander")
        
        self.canvas = tk.Canvas(root, width=W*SCALE, height=H*SCALE, bg="black")
        self.canvas.pack()
        
        self.img = Image.new("RGB", (W, H))
        self.tk_img_obj = None
        self.image_on_canvas = None
        
        self.running = True
        self.ser = None
        self.pixel_count = 0
        self.logger = SmartErrorLogger(W, H)

        btn_frame = tk.Frame(root)
        btn_frame.pack(side=tk.BOTTOM, pady=5)
        start_btn = tk.Button(btn_frame, text="Start Serial & Send Commands", command=self.start_serial, bg="green", fg="white", font=("Arial", 12, "bold"))
        start_btn.pack()

    def start_serial(self):
        t = threading.Thread(target=self.serial_thread_task)
        t.daemon = True
        t.start()

    def send_write_cmd(self, addr, data):
        """
        פונקציה לשליחת פקודות בפורמט הייחודי של הפרויקט:
        { W A2 A1 A0 , V 0 D3 D2 , V 0 D1 D0 }
        """
        if not self.ser or not self.ser.is_open:
            return

        pkt = bytearray()
        pkt.append(0x7B) # '{'
        pkt.append(0x57) # 'W' (Write Opcode)
        
        # Address (24-bit)
        pkt.append((addr >> 16) & 0xFF)
        pkt.append((addr >> 8) & 0xFF)
        pkt.append(addr & 0xFF)
        
        # חלק ראשון של הדאטה + Separators (0x2C, 0x56)
        pkt.extend([0x2C, 0x56, 0x00, (data >> 24) & 0xFF, (data >> 16) & 0xFF]) 
        
        # חלק שני של הדאטה
        pkt.extend([0x2C, 0x56, 0x00, (data >> 8) & 0xFF, data & 0xFF]) 
        
        pkt.append(0x7D) # '}' (End)
        
        print(f">>> Sending CMD: Addr=0x{addr:06X}, Data=0x{data:08X}")
        # print(f"Raw Packet: {pkt.hex().upper()}") # לדיבוג אם צריך
        
        self.ser.write(pkt)

    def serial_thread_task(self):
        try:
            print(f"Opening {PORT} at {BAUD}...")
            self.ser = serial.Serial(PORT, BAUD, timeout=0.1)
            self.ser.reset_input_buffer()
            print("Serial Open.")
            
            # === שליחת רצף הפקודות ===
            time.sleep(0.5) # המתנה להתייצבות הקו
            print("Sending Start Commands...")
            
            # פקודה 1: הגדרה (כנראה גודל תמונה או איפוס)
            self.send_write_cmd(0x050000, 0x00100000)
            
            time.sleep(0.1) # השהיה בין פקודות
            
            # פקודה 2: התחלה (Start/Go)
            self.send_write_cmd(0x050008, 0x00000001)
            # =========================

            print("Listening for Image Data...")
            buffer = bytearray()
            
            while self.running:
                if self.ser.in_waiting > 0:
                    chunk = self.ser.read(self.ser.in_waiting)
                    buffer.extend(chunk)
                    
                    while len(buffer) >= 16: 
                        if buffer[0] != 0x7B:
                            buffer.pop(0)
                            continue
                        
                        if buffer[15] == 0x7D:
                            pkt = buffer[:16]
                            
                            # פענוח לפי הלוגים הקודמים
                            row = (pkt[2] << 16) | (pkt[3] << 8) | pkt[4]
                            col = (pkt[7] << 16) | (pkt[8] << 8) | pkt[9]
                            r, g, b = pkt[12], pkt[13], pkt[14]
                            
                            self.logger.check_and_log(row, col)

                            if 0 <= row < H and 0 <= col < W:
                                self.img.putpixel((col, row), (r, g, b))
                                self.pixel_count += 1
                                
                                if self.pixel_count % 1000 == 0:
                                    self.root.after(1, self.update_display)
                            
                            del buffer[:16]
                        else:
                            buffer.pop(0)
                else:
                    time.sleep(0.001)

        except Exception as e:
            print(f"\nCRITICAL ERROR: {e}")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()

    def update_display(self):
        try:
            resized = self.img.resize((W*SCALE, H*SCALE), Image.NEAREST)
            self.tk_img_obj = ImageTk.PhotoImage(resized)
            self.canvas.create_image(0, 0, anchor="nw", image=self.tk_img_obj)
        except Exception as e:
            print(f"Display Error: {e}")

if __name__ == "__main__":
    root = tk.Tk()
    app = UARTReceiverApp(root)
    root.mainloop()