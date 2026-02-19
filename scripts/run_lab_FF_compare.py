# --------------------------------------------------------------------------------
# Script: run_lab_FF_compare.py
# Description: 
#   1. Runs Vivado TCL.
#   2. Parses & Normalizes names to merge "renamed" registers.
#   3. Highlights Partial Optimization (Gap 2) while resolving Gaps 1 & 3.
#   4. Adds a Summary column on the leftmost side for per-module totals.
# --------------------------------------------------------------------------------

import os
import sys
import re
import subprocess
import pandas as pd
from pathlib import Path

# --- Setup Paths ---
SCRIPT_DIR = Path(__file__).resolve().parent
CURRENT_LAB_DIR = SCRIPT_DIR.parent
CURRENT_LAB_NAME = CURRENT_LAB_DIR.name

CONFIG_FILE = SCRIPT_DIR / "project_paths.cfg"
TCL_SCRIPT  = SCRIPT_DIR / "full_ff_analysis.tcl"

# --- Config Loader ---
def load_config(path):
    config = {}
    if not path.exists():
        print(f"CRITICAL: Config file missing at {path}")
        sys.exit(1)
    
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('['): continue
            if '=' in line:
                k, v = line.split('=', 1)
                config[k.strip()] = v.strip()
    return config

# --- Orchestration Logic ---
def run_vivado_export(cfg):
    print("\n" + "="*50)
    print(f" STEP 1: VIVADO PROCESS ({CURRENT_LAB_NAME})")
    print("="*50)

    # Clean up old logs first
    for f in SCRIPT_DIR.glob("vivado*.log"): os.remove(f)
    for f in SCRIPT_DIR.glob("vivado*.jou"): os.remove(f)

    vivado_root_str = cfg.get('VIVADO_PROJECTS_ROOT')
    if not vivado_root_str:
         print("CRITICAL: 'VIVADO_PROJECTS_ROOT' missing in config.")
         sys.exit(1)

    vivado_root = Path(vivado_root_str)
    target_project_dir = vivado_root / CURRENT_LAB_NAME
    
    if not target_project_dir.exists():
        print(f"ERROR: Project folder not found: {target_project_dir}")
        sys.exit(1)

    xpr_files = list(target_project_dir.glob("*.xpr"))
    if not xpr_files:
        print(f"ERROR: No .xpr file found in {target_project_dir}")
        sys.exit(1)
    
    project_xpr = xpr_files[0]
    print(f"Target Project: {project_xpr}")

    vivado_exec = cfg.get('VIVADO_EXEC')
    if not vivado_exec:
        print("CRITICAL: 'VIVADO_EXEC' missing in config.")
        sys.exit(1)
    vivado_exec = vivado_exec.replace('"', '')

    if not os.path.exists(vivado_exec):
        print(f"CRITICAL: Vivado executable not found at: {vivado_exec}")
        sys.exit(1)

    cmd = [
        vivado_exec, 
        "-mode", "batch", 
        "-notrace", 
        "-source", str(TCL_SCRIPT),
        "-tclargs", str(project_xpr)
    ]
    
    print(f"Launching Vivado...")

    try:
        result = subprocess.run(
            cmd,
            cwd=SCRIPT_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding='utf-8', 
            errors='replace'
        )
        
        if result.returncode != 0:
            print("\n❌ Vivado process failed.")
            print("--- Vivado Output Tail ---")
            print(result.stdout[-2000:])
            sys.exit(1)
        else:
            print("✅ Vivado export completed.")

    except Exception as e:
        print(f"\n❌ Execution failed: {e}")
        sys.exit(1)

# ----------------------------------------------------------------------
#  CORE NORMALIZATION LOGIC (Fixes Gaps 1 & 3)
# ----------------------------------------------------------------------
def clean_register_name(raw_name):
    """
    Normalizes register names to handle Vivado transformations.
    """
    name = raw_name.replace('\\', '').lstrip('/')
    if '/' in name:
        _, name_part = name.rsplit('/', 1)
    else:
        name_part = name

    name_part = re.sub(r'^FSM_onehot_', '', name_part, flags=re.IGNORECASE)
    name_part = re.sub(r'^FSM_sequential_', '', name_part, flags=re.IGNORECASE)
    name_part = re.sub(r'_reg(\[\d+\])?.*$', '', name_part, flags=re.IGNORECASE)
    name_part = re.sub(r'_i$', '', name_part)
    name_part = re.sub(r'\[\d+\]$', '', name_part) 

    return name_part

def clean_module_name(raw_name):
    """
    Normalizes module names (Rx_inst -> Rx)
    """
    name = raw_name.replace('\\', '').lstrip('/')
    if '/' in name:
        name = name.split('/')[-1]
    if name.endswith('_inst'):
        name = name[:-5]
    return name

# ----------------------------------------------------------------------
#  PARSING LOGIC
# ----------------------------------------------------------------------
def analyze_netlist(content):
    FF_PRIMITIVES = r'(?:FDRE|FDSE|FDCE|FDPE|FD|DFFE|LDCE)'
    ff_pattern = re.compile(
        rf'({FF_PRIMITIVES})\s*#\(.*?\)[\s\n]*([a-zA-Z0-9_\\\/\$\[\]\.]+)\s*\(',
        re.IGNORECASE | re.DOTALL
    )
    mod_pattern = re.compile(r'^\s*module\s+([a-zA-Z0-9_]+)\s*\((.*?);?\s*\n', re.IGNORECASE | re.DOTALL | re.MULTILINE)
    
    ff_data = []
    mod_matches = list(mod_pattern.finditer(content))
    mod_ranges = []
    for m in mod_matches:
        start = m.start()
        end = content.find('endmodule', m.end())
        if end == -1: end = len(content)
        mod_ranges.append({'name': m.group(1), 'start': start, 'end': end})

    for m in ff_pattern.finditer(content):
        pos = m.start()
        raw_name = m.group(2)
        curr_mod = "TOP"
        for mr in mod_ranges:
            if mr['start'] < pos < mr['end']:
                curr_mod = mr['name']
                break
        norm_mod = clean_module_name(curr_mod)
        norm_reg = clean_register_name(raw_name)
        ff_data.append({'Module': norm_mod, 'Register': norm_reg, 'Size': 1})

    df = pd.DataFrame(ff_data)
    if not df.empty:
        df = df.groupby(['Module', 'Register'])['Size'].sum().reset_index()
        df.rename(columns={'Size': 'Actual_Synthesis'}, inplace=True)
    else:
        df = pd.DataFrame(columns=['Module', 'Register', 'Actual_Synthesis'])
    return df

def parse_data(cfg):
    print("\n" + "="*50)
    print(" STEP 2: ANALYZING REGISTERS (GAP 2 FOCUS)")
    print("="*50)

    report_dir = CURRENT_LAB_DIR / cfg['REPORTS_DIR']
    netlist_path = report_dir / cfg['NETLIST_NAME']
    csv_path = report_dir / cfg['CSV_RPT_NAME']
    elab_list_path = report_dir / "elaborated_registers.txt"

    if not netlist_path.exists():
        print(f"❌ Error: Netlist not found.")
        sys.exit(1)

    try:
        with open(netlist_path, 'r', encoding='utf-8') as f: content = f.read()
    except:
        with open(netlist_path, 'r', encoding='latin-1') as f: content = f.read()

    df_actual = analyze_netlist(content)

    if not elab_list_path.exists():
        print(f"❌ Error: Elaboration list not found.")
        sys.exit(1)
    
    elab_data = []
    with open(elab_list_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            if '/' in line:
                mod_part = line.rsplit('/', 1)[0]
                norm_mod = clean_module_name(mod_part)
            else:
                norm_mod = "TOP"
            norm_reg = clean_register_name(line)
            elab_data.append({'Module': norm_mod, 'Register': norm_reg, 'Size': 1})

    df_plan = pd.DataFrame(elab_data)
    if not df_plan.empty:
        df_plan = df_plan.groupby(['Module', 'Register'])['Size'].sum().reset_index()
        df_plan.rename(columns={'Size': 'Planned_RTL'}, inplace=True)
    else:
        df_plan = pd.DataFrame(columns=['Module', 'Register', 'Planned_RTL'])

    merged = pd.merge(df_plan, df_actual, on=['Module', 'Register'], how='outer').fillna(0)
    merged['Planned_RTL'] = merged['Planned_RTL'].astype(int)
    merged['Actual_Synthesis'] = merged['Actual_Synthesis'].astype(int)

    def get_status(row):
        p = row['Planned_RTL']
        a = row['Actual_Synthesis']
        if p == a: return "Match"
        elif p == 0 and a > 0: return "Inferred / Generated"
        elif p > 0 and a == 0: return "Optimized Out"
        elif p > a: return "Partial Opt"
        elif a > p: return "FSM/Logic Expansion"
        return "Mismatch"

    merged['Status'] = merged.apply(get_status, axis=1)

    # --- 5. Summary & Save with Per-Module Total Formula ---
    total_p = merged['Planned_RTL'].sum()
    total_a = merged['Actual_Synthesis'].sum()
    
    # Sort and prepare the main data
    cols = ['Module', 'Register', 'Planned_RTL', 'Actual_Synthesis', 'Status']
    data_df = merged[cols].sort_values(['Module', 'Register']).reset_index(drop=True)
    
    # Initialize the leftmost column
    data_df.insert(0, 'Total FF per Module', "")
    
    # Calculate module totals and place them at the last row of each module group
    module_sums = data_df.groupby('Module')['Actual_Synthesis'].sum()
    for mod_name, total_val in module_sums.items():
        if mod_name == "": continue # Skip empty
        # Find the index of the last row for this module in the sorted dataframe
        last_idx = data_df[data_df['Module'] == mod_name].index[-1]
        data_df.at[last_idx, 'Total FF per Module'] = total_val

    # Create summary row
    summary_data = {
        'Total FF per Module': total_a,
        'Module': '',
        'Register': '=== TOTAL ===',
        'Planned_RTL': total_p,
        'Actual_Synthesis': total_a,
        'Status': ''
    }
    summary = pd.DataFrame([summary_data])
    
    # Final merge
    final_df = pd.concat([data_df, summary], ignore_index=True)
    
    # Save result
    final_df.to_csv(csv_path, index=False)
    
    print(f"Report Generated: {csv_path}")
    print("-" * 75)
    print(final_df.head(15))
    print("...")
    print(final_df.tail(1))
    print("-" * 75)
    
    gap2 = final_df[final_df['Status'] == 'Partial Opt']
    if not gap2.empty:
        print("\n🔎 GAP 2 FINDINGS (Partial Optimizations):")
        print(gap2.to_string(index=False))

if __name__ == "__main__":
    cfg = load_config(CONFIG_FILE)
    run_vivado_export(cfg)
    parse_data(cfg)