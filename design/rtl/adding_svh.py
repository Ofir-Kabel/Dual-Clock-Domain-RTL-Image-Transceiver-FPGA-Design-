import os
import shutil
import re

# --- CONFIGURATION ---
INCLUDE_LINE = '`include "top_pkg.svh"\n'
BACKUP_DIR = "./backup_files"
EXTENSIONS = [".sv", ".v"]

# Regex definitions
IMPORT_PATTERN = re.compile(r'^\s*import\s+\w+_pkg::\*;\s*')
TIMESCALE_PATTERN = re.compile(r'^\s*`timescale')

# --- FIX: Set Working Directory to Script Location ---
script_location = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_location)
# -----------------------------------------------------

def process_files():
    # 1. Create Backup Directory
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)
        print(f"[Info] Created backup directory: {os.path.abspath(BACKUP_DIR)}")

    current_dir = os.getcwd()
    print(f"Scanning directory: {current_dir}...")

    count_modified = 0

    for filename in os.listdir(current_dir):
        # Check extension
        if not any(filename.endswith(ext) for ext in EXTENSIONS):
            continue
            
        # Avoid processing the generated package file itself if it's there
        if filename == "top_pkg.svh": 
            continue

        filepath = os.path.join(current_dir, filename)
        
        # 2. Read File Content
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"[Error] Could not read {filename}: {e}")
            continue

        # 3. Analyze and Filter Content
        new_lines = []
        has_include_already = False
        timescale_index = -1
        
        # First pass: Filter imports and find key positions
        for i, line in enumerate(lines):
            # Check if include already exists
            if '`include "top_pkg.svh"' in line:
                has_include_already = True
            
            # Record timescale location
            if TIMESCALE_PATTERN.match(line):
                timescale_index = len(new_lines) 

            # Skip existing package imports to clean up
            if IMPORT_PATTERN.match(line):
                continue
            
            new_lines.append(line)

        # 4. Insert the new include line
        if not has_include_already:
            insert_pos = 0
            if timescale_index != -1:
                insert_pos = timescale_index + 1
            
            new_lines.insert(insert_pos, INCLUDE_LINE)
            
            # Add a newline for spacing if strictly needed
            if insert_pos < len(new_lines) and new_lines[insert_pos+1].strip() != "":
                 new_lines.insert(insert_pos + 1, "\n")

            # 5. Write changes
            shutil.copy2(filepath, os.path.join(BACKUP_DIR, filename))
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            
            print(f"[V] Updated: {filename}")
            count_modified += 1
        else:
            print(f"[-] Skipped: {filename} (Already has include)")

    print(f"\nDone! Modified {count_modified} files.")
    print(f"Backups are stored in '{os.path.abspath(BACKUP_DIR)}'")

if __name__ == "__main__":
    process_files()