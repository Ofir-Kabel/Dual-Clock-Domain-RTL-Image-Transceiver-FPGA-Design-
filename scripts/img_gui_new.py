import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, Toplevel, filedialog
import serial
import pandas as pd
import os
import sys
import threading
import time

# --- Library Check ---
try:
    from PIL import Image, ImageTk
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("CRITICAL: PIL not found. Run 'pip install pillow'")

# --- Configuration ---
DEFAULT_PORT = 'COM14'
DEFAULT_BAUD = '5_000_000'
BAUD_RATES = ["9600", "57600", "115200", "921600", "5000000"]

IMG_WIDTH = 256
IMG_HEIGHT = 256
IMG_SCALE = 1
IMG_UPDATE_BATCH = 100 

DEFAULT_BASE_MAP = {
    'PWM':  0x07, 'LED':  0x01, 'SYS':  0x02,
    'UART': 0x03, 'MSG':  0x04, 'IMG':  0x05, 'FIFO': 0x06
}

# --- ToolTip Class ---
class ToolTip:
    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tip_window = None
        widget.bind("<Enter>", self.show_tip)
        widget.bind("<Leave>", self.hide_tip)

    def show_tip(self, event=None):
        x, y, _, _ = self.widget.bbox("insert")
        x += self.widget.winfo_rootx() + 25
        y += self.widget.winfo_rooty() + 25
        self.tip_window = tw = Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")
        label = tk.Label(tw, text=self.text, background="#ffffe0", relief="solid", borderwidth=1, font=("tahoma", "8", "normal"))
        label.pack(ipadx=1)

    def hide_tip(self, event=None):
        if self.tip_window:
            self.tip_window.destroy()
            self.tip_window = None

# --- UI Application ---
class FpgaStudio:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA Studio v39 - Image TX/RX")
        self.root.geometry("1100x800") 
        
        self.configure_styles()
        
        self.ser = None
        self.is_listening = False
        self.log_paused = False
        self.registers = {}
        self.base_addr_map = DEFAULT_BASE_MAP.copy()
        
        self.image_mode = False
        self.raw_buffer = bytearray()
        self.img_window = None
        self.curr_img = None
        self.tk_img = None
        self.pixel_count = 0
        
        # Image Upload Variables
        self.upload_img_path = None
        self.is_sending = False
        
        # Path setup
        if getattr(sys, 'frozen', False):
            self.app_path = os.path.dirname(sys.executable)
        else:
            self.app_path = os.path.dirname(os.path.abspath(__file__))

        self.setup_ui()
        self.load_rgf_data()

    def configure_styles(self):
        style = ttk.Style()
        style.theme_use('clam')
        bg_color = "#f4f6f9"
        self.root.configure(bg=bg_color)
        style.configure(".", background=bg_color, font=("Segoe UI", 9))
        style.configure("TLabel", background=bg_color)
        style.configure("TButton", borderwidth=1, background="#e1e4e8")
        style.map("TButton", background=[('active', '#d0d3d8'), ('pressed', '#c0c3c8')])
        style.configure("Action.TButton", foreground="#004085", background="#cce5ff", font=("Segoe UI", 9, "bold"))
        style.configure("Connect.TButton", foreground="#155724", background="#d4edda", font=("Segoe UI", 9, "bold"))
        style.configure("Disconnect.TButton", foreground="#721c24", background="#f8d7da", font=("Segoe UI", 9, "bold"))
        style.configure("Treeview", rowheight=22, borderwidth=0)
        style.configure("Treeview.Heading", font=("Segoe UI", 9, "bold"), background="#e9ecef")

    def setup_ui(self):
        # 1. Top Bar
        top = ttk.Frame(self.root, padding=10); top.pack(fill="x")
        ttk.Label(top, text="PORT:").pack(side="left")
        self.ent_port = ttk.Entry(top, width=10); self.ent_port.pack(side="left", padx=5); self.ent_port.insert(0, DEFAULT_PORT)
        ttk.Label(top, text="BAUD:").pack(side="left")
        self.cb_baud = ttk.Combobox(top, values=BAUD_RATES, width=10); self.cb_baud.pack(side="left", padx=5); self.cb_baud.set(DEFAULT_BAUD)
        self.btn_conn = ttk.Button(top, text="CONNECT", style="Connect.TButton", command=self.toggle_conn); self.btn_conn.pack(side="left", padx=15)
        
        ttk.Separator(top, orient="vertical").pack(side="left", fill="y", padx=10)
        
        # 2. Main Workspace (Split Pane)
        paned = ttk.PanedWindow(self.root, orient="horizontal"); paned.pack(fill="both", expand=True, padx=10, pady=5)
        f_left = ttk.Labelframe(paned, text="Register Map", padding=5); paned.add(f_left, weight=1)
        self.tree = ttk.Treeview(f_left, columns=("addr", "type"), show="tree headings", selectmode="browse")
        self.tree.heading("#0", text="Register"); self.tree.column("#0", width=140)
        self.tree.heading("addr", text="Offset"); self.tree.column("addr", width=60)
        self.tree.heading("type", text="RW"); self.tree.column("type", width=40)
        sb_tree = ttk.Scrollbar(f_left, command=self.tree.yview); self.tree.configure(yscroll=sb_tree.set)
        self.tree.pack(side="left", fill="both", expand=True); sb_tree.pack(side="right", fill="y")
        self.tree.bind("<<TreeviewSelect>>", self.on_tree_select)

        f_right = ttk.Frame(paned); paned.add(f_right, weight=3)
        self.f_editor = ttk.Labelframe(f_right, text="Register Editor", padding=10); self.f_editor.pack(fill="both", expand=True, pady=(0, 5))
        self.cv = tk.Canvas(self.f_editor, bg="#f4f6f9", highlightthickness=0); sb_ed = ttk.Scrollbar(self.f_editor, command=self.cv.yview)
        self.f_fields = ttk.Frame(self.cv); self.cv.create_window((0,0), window=self.f_fields, anchor="nw")
        self.cv.configure(yscrollcommand=sb_ed.set); self.f_fields.bind("<Configure>", lambda e: self.cv.configure(scrollregion=self.cv.bbox("all")))
        self.cv.pack(side="left", fill="both", expand=True); sb_ed.pack(side="right", fill="y")
        ttk.Label(self.f_fields, text="Select a register to edit", foreground="gray").pack(pady=20)

        f_rw = ttk.Frame(f_right); f_rw.pack(fill="x", pady=5)
        self.btn_read = ttk.Button(f_rw, text="READ REG", state="disabled", command=self.do_read); self.btn_read.pack(side="left", fill="x", expand=True, padx=(0,5))
        self.btn_write = ttk.Button(f_rw, text="WRITE REG", state="disabled", command=self.do_write); self.btn_write.pack(side="left", fill="x", expand=True, padx=(5,0))

        # --- Image Controls (RX & TX) ---
        f_img_ctrl = ttk.Labelframe(f_right, text="Image RX/TX Controls", padding=5)
        f_img_ctrl.pack(fill="x", pady=5)
        
        # TX Section (Upload to FPGA)
        f_tx = ttk.Frame(f_img_ctrl); f_tx.pack(fill="x", pady=2)
        ttk.Label(f_tx, text="TX (PC -> FPGA):", font=("Segoe UI", 9, "bold")).pack(side="left")
        self.btn_load_img = ttk.Button(f_tx, text="Load File...", command=self.load_image_file)
        self.btn_load_img.pack(side="left", padx=5)
        self.lbl_file = ttk.Label(f_tx, text="No file selected", foreground="gray")
        self.lbl_file.pack(side="left", padx=5)
        self.btn_send_img = ttk.Button(f_tx, text="Send to Memory", state="disabled", command=self.start_image_send)
        self.btn_send_img.pack(side="right", padx=5)
        
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(f_img_ctrl, variable=self.progress_var, maximum=100)
        self.progress_bar.pack(fill="x", padx=5, pady=2)

        # RX Section (Read from FPGA)
        ttk.Separator(f_img_ctrl, orient="horizontal").pack(fill="x", pady=5)
        f_rx = ttk.Frame(f_img_ctrl); f_rx.pack(fill="x", pady=2)
        ttk.Label(f_rx, text="RX (FPGA -> PC):", font=("Segoe UI", 9, "bold")).pack(side="left")
        
        b_ready = ttk.Button(f_rx, text="1. Set IMG_READY", style="Action.TButton", command=self.cmd_img_ready)
        b_ready.pack(side="left", padx=2); ToolTip(b_ready, "Writes 1 to IMG_STATUS[20]")
        
        b_start = ttk.Button(f_rx, text="2. Start IMG_READ", style="Action.TButton", command=self.cmd_img_read)
        b_start.pack(side="left", padx=2); ToolTip(b_start, "Writes 1 to IMG_CTRL[0]")
        
        ttk.Label(f_rx, text="Scale:").pack(side="left", padx=(10, 2))
        self.ent_scale = ttk.Entry(f_rx, width=3); self.ent_scale.pack(side="left"); self.ent_scale.insert(0, str(IMG_SCALE))

        # --- NEW SAVE BUTTON ---
        self.btn_save_rx = ttk.Button(f_rx, text="Save Image", command=self.save_image_to_disk)
        self.btn_save_rx.pack(side="left", padx=(15, 2))
        ToolTip(self.btn_save_rx, "Saves the current received image as 'fpga_img.png'")


        # 3. Bottom Logs
        f_logs = ttk.Labelframe(self.root, text="Logs", padding=5); f_logs.pack(fill="both", expand=True, padx=10, pady=5)
        ctrl_log = ttk.Frame(f_logs); ctrl_log.pack(fill="x", pady=2)
        self.var_pause = tk.BooleanVar()
        tk.Checkbutton(ctrl_log, text="Pause Log", variable=self.var_pause, font=("Segoe UI", 9, "bold"), fg="red", bg="#f4f6f9").pack(side="left")
        ttk.Button(ctrl_log, text="Clear", command=self.clear_log, width=6).pack(side="right", padx=2)
        ttk.Button(ctrl_log, text="Copy", command=self.copy_log, width=6).pack(side="right", padx=2)

        nb_log = ttk.Notebook(f_logs); nb_log.pack(fill="both", expand=True)
        f_raw = ttk.Frame(nb_log); nb_log.add(f_raw, text="Raw Terminal")
        self.txt_raw = scrolledtext.ScrolledText(f_raw, height=6, font=("Consolas", 9), state="disabled"); self.txt_raw.pack(fill="both", expand=True)
        f_clean = ttk.Frame(nb_log); nb_log.add(f_clean, text="Clean Terminal")
        self.txt_clean = scrolledtext.ScrolledText(f_clean, height=6, font=("Consolas", 9), state="disabled"); self.txt_clean.pack(fill="both", expand=True)
        for t in [self.txt_raw, self.txt_clean]: t.tag_config("tx", foreground="#d35400"); t.tag_config("rx", foreground="#2980b9"); t.tag_config("err", foreground="red")

    # --- Logic: RGF Parsing (XLSX Support) ---
    def load_rgf_data(self):
        files = [f for f in os.listdir(self.app_path) if 'RGF' in f.upper()]
        for f in files:
            path = os.path.join(self.app_path, f)
            try:
                if f.lower().endswith('.xlsx'):
                    xl = pd.ExcelFile(path)
                    for sheet in xl.sheet_names:
                        if 'doc' in sheet.lower(): continue
                        self.parse_dataframe(sheet.upper(), pd.read_excel(xl, sheet_name=sheet))
                elif f.lower().endswith('.csv'):
                    mod_name = f.split('-')[-1].replace('.csv', '').upper()
                    self.parse_dataframe(mod_name, pd.read_csv(path))
            except Exception as e:
                print(f"Error loading {f}: {e}")
        self.refresh_reg_tree()

    def parse_dataframe(self, mod_name, df):
        df = df.ffill()
        df.columns = [str(c).strip().upper() for c in df.columns]
        c_map = {c: c for c in df.columns}
        for c in df.columns:
            if 'OFFSET' in c: c_map[c] = 'OFFSET'
            if 'REG' in c and 'NAME' in c: c_map[c] = 'NAME'
            if 'FIELD' in c: c_map[c] = 'FIELDS'
            if 'SIZE' in c: c_map[c] = 'SIZE'
        df = df.rename(columns=c_map)

        if 'NAME' not in df.columns or 'OFFSET' not in df.columns: return
        if mod_name not in self.registers: self.registers[mod_name] = {}
        
        for _, row in df.iterrows():
            reg_name = str(row['NAME']).strip()
            if reg_name == 'nan' or not reg_name: continue
            try: offset = int(str(row['OFFSET']).lower().replace('0x',''), 16)
            except: continue
            
            if reg_name not in self.registers[mod_name]:
                self.registers[mod_name][reg_name] = {'offset': offset, 'type': str(row.get('TYPE', 'RW')).upper(), 'fields': []}
            
            size_str = str(row.get('SIZE', '1')).strip()
            shift, size = 0, 1
            if ':' in size_str:
                p = size_str.replace('[','').replace(']','').split(':')
                size, shift = abs(int(p[0]) - int(p[1])) + 1, min(int(p[0]), int(p[1]))
            elif '[' in size_str:
                shift = int(size_str.replace('[','').replace(']',''))
            
            self.registers[mod_name][reg_name]['fields'].append({
                'name': str(row.get('FIELDS', 'Res')), 'size': size, 'shift': shift
            })

    def refresh_reg_tree(self):
        self.tree.delete(*self.tree.get_children())
        for mod in sorted(self.registers.keys()):
            base = DEFAULT_BASE_MAP.get(mod, 0x00)
            node = self.tree.insert("", "end", text=f"{mod} (Base: 0x{base:02X})", open=True)
            for reg, info in self.registers[mod].items():
                self.tree.insert(node, "end", text=reg, values=(f"0x{info['offset']:04X}", info['type']), tags=('reg',))

    # --- Logic: Editor ---
    def on_tree_select(self, event):
        sel = self.tree.selection()
        if not sel or 'reg' not in self.tree.item(sel[0])['tags']: return
        item = self.tree.item(sel[0])
        mod_name = self.tree.item(self.tree.parent(sel[0]))['text'].split(" (")[0]
        self.curr_reg = {'mod': mod_name, 'name': item['text'], 'info': self.registers[mod_name][item['text']]}
        self.build_fields_ui()

    def build_fields_ui(self):
        for w in self.f_fields.winfo_children(): w.destroy()
        info = self.curr_reg['info']
        self.btn_read.config(state='normal' if 'R' in info['type'] else 'disabled')
        self.btn_write.config(state='normal' if 'W' in info['type'] else 'disabled')
        self.field_vars = []
        for f in info['fields']:
            row = ttk.Frame(self.f_fields); row.pack(fill="x", pady=1)
            rng = f"[{f['shift']}]" if f['size'] == 1 else f"[{f['shift']+f['size']-1}:{f['shift']}]"
            ttk.Label(row, text=f"{f['name']} {rng}", width=25, anchor="w").pack(side="left")
            
            is_reserved = 'res' in f['name'].lower()
            if is_reserved:
                ttk.Entry(row, state="disabled", width=15).pack(side="left")
                self.field_vars.append(None)
            elif f['size'] == 1:
                var = tk.IntVar(value=0)
                tk.Checkbutton(row, variable=var, text="Set (1)", bg="#f4f6f9").pack(side="left")
                self.field_vars.append({'type': 'bit', 'var': var, 'shift': f['shift'], 'size': 1})
            else:
                var = tk.StringVar(value="0")
                ttk.Entry(row, textvariable=var, width=15).pack(side="left")
                self.field_vars.append({'type': 'vec', 'var': var, 'shift': f['shift'], 'size': f['size']})

    # --- Logic: Comms ---
    def send_packet(self, cmd_char, addr, data):
            if not self.ser or not self.ser.is_open: return
            
            if cmd_char == 'R':
                pkt = bytearray([
                    0x7B, ord('R'), 
                    (addr>>16)&0xFF, (addr>>8)&0xFF, addr&0xFF, 
                    0x7D
                ])
                log_data = 0 
            else:
                pkt = bytearray([
                    0x7B, ord(cmd_char), 
                    (addr>>16)&0xFF, (addr>>8)&0xFF, addr&0xFF, 
                    0x2C, 0x56, 0x00, 
                    (data>>24)&0xFF, (data>>16)&0xFF, 
                    0x2C, 0x56, 0x00, 
                    (data>>8)&0xFF, data&0xFF, 
                    0x7D
                ])
                log_data = data

            self.ser.write(pkt)
            self.log(f"TX ({cmd_char}) >> Addr: {addr:06X} Data: {log_data:08X}", "tx")

    def do_write(self):
        val = 0
        for f in self.field_vars:
            if f:
                v = int(f['var'].get()) if f['type'] == 'bit' else int(str(f['var'].get()), 16) if '0x' in str(f['var'].get()) else int(str(f['var'].get()))
                val |= (v & ((1 << f['size']) - 1)) << f['shift']
        base = DEFAULT_BASE_MAP.get(self.curr_reg['mod'], 0)
        self.send_packet('W', (base << 16) | self.curr_reg['info']['offset'], val)

    def do_read(self):
        base = DEFAULT_BASE_MAP.get(self.curr_reg['mod'], 0)
        self.send_packet('R', (base << 16) | self.curr_reg['info']['offset'], 0)

    # --- Image TX (Upload) Logic ---
    def load_image_file(self):
        path = filedialog.askopenfilename(filetypes=[("Images", "*.png;*.jpg;*.jpeg;*.bmp")])
        if path:
            self.upload_img_path = path
            self.lbl_file.config(text=os.path.basename(path), foreground="black")
            if self.ser and self.ser.is_open:
                self.btn_send_img.config(state="normal")
    
    def start_image_send(self):
        if not self.ser or not self.ser.is_open:
            messagebox.showerror("Error", "Not Connected")
            return
        if not self.upload_img_path: return
        
        self.is_sending = True
        self.btn_send_img.config(state="disabled", text="Sending...")
        threading.Thread(target=self.tx_image_thread, daemon=True).start()

    def tx_image_thread(self):
        try:
            # 1. Prepare Image
            img = Image.open(self.upload_img_path).convert('RGB')
            img = img.resize((256, 256))
            pixels = list(img.getdata())
            total = len(pixels)
            
            self.log(f"Starting Image TX: {total} pixels...", "tx")
            
            # 2. Loop and Send
            for addr, (r, g, b) in enumerate(pixels):
                if not self.is_sending or not self.ser.is_open: break
                
                # Format: { W A2 A1 A0 , P R G B }
                pkt = bytearray([
                    0x7B,               # {
                    0x57,               # W
                    (addr >> 16) & 0xFF,# A2
                    (addr >> 8) & 0xFF, # A1
                    addr & 0xFF,        # A0
                    0x2C,               # ,
                    0x50,               # P
                    r, g, b,
                    0x7D                # }
                ])
                
                self.ser.write(pkt)
                
                # Progress Update (Every 500 pixels)
                if addr % 500 == 0:
                    prog = (addr / total) * 100
                    self.root.after(0, lambda p=prog: self.progress_var.set(p))
            
            self.root.after(0, lambda: self.progress_var.set(100))
            self.log("Image TX Complete!", "tx")
            
        except Exception as e:
            self.log(f"Image TX Error: {e}", "err")
        finally:
            self.is_sending = False
            self.root.after(0, self.reset_tx_ui)

    def reset_tx_ui(self):
        self.btn_send_img.config(state="normal", text="Send to Memory")

    # --- Image RX (Download) Logic ---
    def cmd_img_ready(self): self.send_packet('W', 0x050000, 0x00100000)
    def cmd_img_read(self):
        self.raw_buffer, self.image_mode, self.pixel_count = bytearray(), True, 0
        self.curr_img = Image.new("RGB", (IMG_WIDTH, IMG_HEIGHT), "black")
        if self.img_window is None or not self.img_window.winfo_exists():
            self.img_window = Toplevel(self.root); self.img_window.title(f"Image Stream")
            self.lbl_img = tk.Label(self.img_window, text="Waiting...", bg="black"); self.lbl_img.pack(fill="both", expand=True)
        self.ser.reset_input_buffer()
        self.send_packet('W', 0x050008, 0x00000001)
        self.var_pause.set(True)

    # --- NEW: Save Image Logic ---
    def save_image_to_disk(self):
        if not self.curr_img:
            messagebox.showwarning("Warning", "No image received yet from FPGA.")
            return
        
        try:
            save_path = os.path.join(self.app_path, "fpga_img.png")
            self.curr_img.save(save_path)
            messagebox.showinfo("Success", f"Image saved successfully:\n{save_path}")
            self.log(f"Image saved to {save_path}", "rx")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save image:\n{e}")
            self.log(f"Save Error: {e}", "err")

    # --- Serial & Image Loop ---
    def toggle_conn(self):
        if self.ser:
            self.is_listening = False; self.is_sending = False
            self.ser.close(); self.ser = None
            self.btn_conn.config(text="CONNECT", style="Connect.TButton"); self.log("Disconnected", "err")
            self.btn_send_img.config(state="disabled")
        else:
            try:
                self.ser = serial.Serial(self.ent_port.get(), int(self.cb_baud.get()), timeout=0.1, rtscts=True) # Added rtscts=True
                self.btn_conn.config(text="DISCONNECT", style="Disconnect.TButton")
                self.log("Connected (RTS/CTS Enabled)", "rx"); self.start_listening()
                if self.upload_img_path: self.btn_send_img.config(state="normal")
            except Exception as e: messagebox.showerror("Error", str(e))

    def start_listening(self):
        self.is_listening = True
        threading.Thread(target=self.rx_thread, daemon=True).start()

    def rx_thread(self):
        while self.is_listening and self.ser and self.ser.is_open:
            try:
                if self.ser.in_waiting:
                    data = self.ser.read(self.ser.in_waiting)
                    if self.image_mode: self.process_image(data)
                    else: self.root.after(0, self.log_rx_data, data)
                else: time.sleep(0.005)
            except: break

    def process_image(self, data):
        self.raw_buffer.extend(data)
        updated = False
        while len(self.raw_buffer) >= 16:
            try: idx = self.raw_buffer.index(0x7B)
            except: self.raw_buffer = self.raw_buffer[-15:]; return
            if len(self.raw_buffer) < idx + 16: return
            pkt = self.raw_buffer[idx : idx+16]
            if pkt[15] == 0x7D:
                # { R r r , C c c , P p p }
                row = (pkt[2]<<16) | (pkt[3]<<8) | pkt[4]
                col = (pkt[7]<<16) | (pkt[8]<<8) | pkt[9]
                r, g, b = pkt[12], pkt[13], pkt[14]
                try:
                    self.curr_img.putpixel((col, row), (r, g, b))
                    self.pixel_count += 1
                    updated = True
                except: pass
                del self.raw_buffer[:idx+16]
            else: del self.raw_buffer[:idx+1]
        
        if updated and (self.pixel_count % IMG_UPDATE_BATCH == 0):
            self.root.after(0, self.refresh_image_window)

    def refresh_image_window(self):
        if self.img_window and self.img_window.winfo_exists() and self.curr_img:
            scale = int(self.ent_scale.get())
            disp = self.curr_img
            if scale > 1:
                disp = self.curr_img.resize((self.curr_img.width*scale, self.curr_img.height*scale), Image.NEAREST)
            self.tk_img = ImageTk.PhotoImage(disp)
            self.lbl_img.config(image=self.tk_img, text="")
            self.root.update_idletasks()

    # --- Logging ---
    def log_rx_data(self, data):
        if self.var_pause.get(): return
        hex_s = " ".join([f"{b:02X}" for b in data])
        asc_s = "".join([chr(b) if 32 <= b <= 126 else "." for b in data])
        self.log(f"RX >> HEX: {hex_s} | ASCII: {asc_s}", "rx")
        try:
            decoded = data.decode('latin-1')
            if '{' in decoded: self.log_clean(decoded)
        except: pass

    def log(self, msg, tag):
        if self.var_pause.get(): return
        self.txt_raw.config(state="normal"); self.txt_raw.insert("end", msg + "\n", tag)
        self.txt_raw.see("end"); self.txt_raw.config(state="disabled")

    def log_clean(self, text):
        if self.var_pause.get(): return
        self.txt_clean.config(state="normal"); self.txt_clean.insert("end", text + "\n", "rx")
        self.txt_clean.see("end"); self.txt_clean.config(state="disabled")
        
    def clear_log(self):
        for t in [self.txt_raw, self.txt_clean]: t.config(state="normal"); t.delete("1.0", "end"); t.config(state="disabled")
    def copy_log(self): self.root.clipboard_clear(); self.root.clipboard_append(self.txt_raw.get("1.0", "end"))

if __name__ == "__main__":
    root = tk.Tk()
    app = FpgaStudio(root)
    root.mainloop()