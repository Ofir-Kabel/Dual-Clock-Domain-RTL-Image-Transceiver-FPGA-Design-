import os
import shutil
import zipfile

# -----------------------------------------------------------------------------
# SCRIPT: relocate&zip_lab.py
# PURPOSE: Manages Vivado project files and creates a ZIP archive.
# -----------------------------------------------------------------------------
# NOTES: 
# 1. 'design' folder: Scanned RECURSIVELY, flattened in ZIP.
# 2. 'docs' folder: Scanned SHALLOWLY (files only), flattened in ZIP.
# 3. EXCLUDES: .git directories and .gitignore files are explicitly ignored.
# -----------------------------------------------------------------------------

# -------------------------------
# STEP 0: Setup paths
# -------------------------------

scripts_dir = os.path.dirname(os.path.abspath(__file__))
project_dir = os.path.dirname(scripts_dir)
project_name = os.path.basename(project_dir)

docs_dir = os.path.join(project_dir, 'docs')
design_dir = os.path.join(project_dir, 'design')

vivado_source_dir = os.path.join(r"C:\VivadoProjects\Projects\VerilogRTLCourse", project_name)

extensions_to_copy = (".xpr", ".bit")
# Files extensions to ignore
extensions_to_ignore_in_zip = ('.py',) 
# Specific filenames to ignore
files_to_ignore = ('.gitignore',)

print(f"Project directory: {project_dir}, Project name: {project_name}")
print(f"Target Docs directory: {docs_dir}")
print(f"Vivado source directory: {vivado_source_dir}")


# -------------------------------
# STEP 1: Clear old .xpr and .bit files in docs
# -------------------------------
print("\n--- STEP 1: Deleting old .xpr and .bit files in docs ---")
if not os.path.exists(docs_dir):
    print(f"Docs directory not found: {docs_dir}. Skipping cleanup.")
else:
    for entry in os.listdir(docs_dir):
        file_path = os.path.join(docs_dir, entry)
        if os.path.isfile(file_path) and entry.endswith(extensions_to_copy):
            try:
                os.remove(file_path)
                print(f"Deleted old file: {entry}")
            except Exception as e:
                print(f"Failed to delete {entry}: {e}")

# -------------------------------
# STEP 2: Copy updated .xpr and .bit files from Vivado project to docs
# -------------------------------
copied_files = []
print("\n--- STEP 2: Copying .xpr and .bit files from Vivado project to docs ---")

if not os.path.exists(vivado_source_dir):
    print(f"ERROR: Vivado source folder not found: {vivado_source_dir}. Skipping copy.")
else:
    for root, dirs, files in os.walk(vivado_source_dir):
        for file in files:
            if file.endswith(extensions_to_copy):
                source_file = os.path.join(root, file)
                dest_file = os.path.join(docs_dir, file)
                print(f"Copying {source_file} -> {dest_file} ...")
                try:
                    shutil.copy2(source_file, dest_file) 
                    copied_files.append(dest_file)
                except Exception as e:
                    print(f"Failed to copy {source_file}: {e}")

    if copied_files:
        print(f"\nSUCCESS: Total {len(copied_files)} files copied to docs.")
    else:
        print("WARNING: No .xpr or .bit files found to copy.")

# --------------------------------------------------
# STEP 3: Create ZIP & Copy to Docs (FLATTENED + GIT IGNORE)
# --------------------------------------------------

zip_name = f"OfirKabel_{project_name}.zip"
zip_path_root = os.path.join(project_dir, zip_name) 
zip_path_docs = os.path.join(docs_dir, zip_name)

print(f"\n--- STEP 3A: Creating ZIP file in root: {zip_path_root} ---")

# Delete previous ZIP files
if os.path.exists(zip_path_root):
    os.remove(zip_path_root)
if os.path.exists(zip_path_docs):
    os.remove(zip_path_docs)

# Create the ZIP file
with zipfile.ZipFile(zip_path_root, 'w', compression=zipfile.ZIP_DEFLATED, allowZip64=True) as zipf:
    
    # -------------------------------------------------
    # PART A: Process 'design' folder 
    # (Recursive scan, Flat output, Ignore Git)
    # -------------------------------------------------
    print(f"Processing 'design' folder...")
    if os.path.exists(design_dir):
        for root, dirs, files in os.walk(design_dir):
            
            # Prevent walking into .git directories
            if '.git' in dirs:
                dirs.remove('.git')
            
            for file in files:
                file_path = os.path.join(root, file)
                
                # Check extension ignores
                if file.lower().endswith(extensions_to_ignore_in_zip):
                    continue
                
                # Check specific filename ignores (.gitignore)
                if file in files_to_ignore:
                    print(f"  [design] Skipping ignored file: {file}")
                    continue
                
                # Flattening: save directly under 'design/' regardless of depth
                flat_arcname = os.path.join('design', file)
                
                try:
                    zipf.write(file_path, arcname=flat_arcname)
                    print(f"  [design] Added: {file}")
                except Exception as e:
                    print(f"  Failed to add {file}: {e}")
    else:
        print(f"WARNING: 'design' folder not found at {design_dir}")

    # -------------------------------------------------
    # PART B: Process 'docs' folder (Files only)
    # -------------------------------------------------
    print(f"Processing 'docs' folder...")
    if os.path.exists(docs_dir):
        for entry in os.listdir(docs_dir):
            file_path = os.path.join(docs_dir, entry)
            
            if not os.path.isfile(file_path):
                continue
            if file_path == zip_path_root or file_path == zip_path_docs:
                continue
            if entry.lower().endswith(extensions_to_ignore_in_zip):
                continue
            if entry in files_to_ignore: # Ignore .gitignore if present in docs too
                continue
            
            flat_arcname = os.path.join('docs', entry)
            
            try:
                zipf.write(file_path, arcname=flat_arcname)
                print(f"  [docs] Added: {entry}")
            except Exception as e:
                print(f"  Failed to add {entry}: {e}")
    else:
        print(f"WARNING: 'docs' folder not found at {docs_dir}")


print(f"\n--- STEP 3C: Copying ZIP from root to docs ---")
try:
    shutil.copy2(zip_path_root, zip_path_docs)
    print(f"SUCCESS: ZIP file copied to docs: {zip_path_docs}")
except Exception as e:
    print(f"ERROR: Failed to copy ZIP to docs: {e}")


print(f"\n--- DONE ---")
print(f"ZIP file created successfully at root: {zip_path_root}")