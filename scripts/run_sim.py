# -----------------------------------------------------------------------------
# SCRIPT: run.py
# PURPOSE: Main script for managing the QuestaSim/ModelSim simulation flow
#          (compile, elaborate, simulate) for a selected testbench.
# -----------------------------------------------------------------------------
# STEP 1: Set up project paths (root, design, verification, sim, scripts).
# STEP 2: Parse command-line arguments for GUI mode, random seed, and testbench name.
# STEP 3: Select the testbench: either from command-line, prompt the user to use
#         the last run test, or let the user choose from available 'tb_*.sv' files.
# STEP 4: Save the selected testbench name to '.current_test' file.
# STEP 5: Clean up previous run files (delete 'work' directories and old log/wlf files).
# STEP 6: Execute an optional pre-compile dependency script ('run_dependencies.py').
# STEP 7: Run the compilation command (using 'compile.do' script).
# STEP 8: Run the elaboration command (using 'elaborate.do' script).
# STEP 9: Run the simulation command (with optional GUI/log/wlf files) using the selected seed.
# -----------------------------------------------------------------------------

import os
import sys
import argparse
import shutil

# שינוי התיקייה הנוכחית ל-scripts
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# --- פונקציה להרצת פקודות shell עם בדיקת הצלחה ---
def run_command(command, step_name):
    print(f"\n--- INFO: Starting Step: {step_name} ---")
    print(f"Executing: {command}")
    return_code = os.system(command)
    if return_code != 0:
        print(f"\n--- ERROR: Step '{step_name}' failed! ---")
        sys.exit(1)

# --- פונקציה לסריקה ובחירת טסט ---
def choose_testbench(tb_path):
    # מחזירים כבר בלי הסיומת
    tb_files = [os.path.splitext(f)[0] for f in os.listdir(tb_path)
                if f.startswith("tb_") and f.endswith(".sv")]

    if not tb_files:
        print("\n--- ERROR: No tb_*.sv files found in tb folder! ---")
        sys.exit(1)

    print("\nAvailable Testbenches:")
    for i, tb in enumerate(tb_files, 1):
        print(f"  {i}. {tb}")

    while True:
        try:
            choice = int(input("\nSelect a testbench number: "))
            if 1 <= choice <= len(tb_files):
                return tb_files[choice - 1]
            else:
                print("Invalid choice, try again.")
        except ValueError:
            print("Please enter a number.")

# --- Main script execution ---
try:
    ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    DESIGN_LAB = os.path.join(ROOT_DIR, "design")
    TB_LAB = os.path.join(DESIGN_LAB, "tb")
    SIM_LAB = os.path.join(ROOT_DIR, "sim")
    SCRIPTS = os.path.join(ROOT_DIR, "scripts")
    CURRENT_TEST_FILE = os.path.join(SIM_LAB, ".current_test")

    # --- בדיקת רישוי ---
    salt_server = os.environ.get("SALT_LICENSE_SERVER")
    if salt_server:
        print(f"SALT_LICENSE_SERVER = {salt_server}")
    else:
        print("\n--- WARNING: SALT_LICENSE_SERVER is not set! ---")

    # --- פרסינג ארגומנטים ---
    parser = argparse.ArgumentParser(description="Run QuestaSim simulation")
    parser.add_argument('--gui', action='store_true', help="Run simulation in GUI mode.")
    parser.add_argument('--seed', type=int, default=1, help="Random seed.")
    parser.add_argument('--test', type=str, help="Testbench name (tb_xxx).")
    args = parser.parse_args()

    # --- בחירת טסט ---
    if not args.test:
        if os.path.exists(CURRENT_TEST_FILE):
            with open(CURRENT_TEST_FILE, "r") as f:
                last_test = f.read().strip()
            # הורדת הסיומת אם קיימת
            last_test = os.path.splitext(last_test)[0]
            print(f"\nPrevious test found: {last_test}")
            use_last = input("Use previous test? (y/n): ").strip().lower()
            if use_last == "y":
                args.test = last_test
            else:
                args.test = choose_testbench(TB_LAB)
        else:
            args.test = choose_testbench(TB_LAB)

    # --- שמירת הבחירה לקובץ ---
    with open(CURRENT_TEST_FILE, "w") as f:
        f.write(args.test.strip())  # נשמר בלי הסיומת

    print(f"\n--- INFO: Selected Testbench: {args.test} ---")

    # --- ניקוי קבצים קודמים ---
    print("\n--- INFO: Cleaning previous run ---")
    cleanup_dirs = [os.path.join(SIM_LAB, "work"),
                    os.path.join(SIM_LAB, "design_work")]
    cleanup_files = [os.path.join(SIM_LAB, f"{args.test}.log"),
                     os.path.join(SIM_LAB, f"{args.test}.wlf"),
                     os.path.join(SIM_LAB, "packages.f"),
                     os.path.join(SIM_LAB, "interfaces.f"),
                     os.path.join(SIM_LAB, "rtl.f")]

    for d in cleanup_dirs:
        if os.path.exists(d):
            print(f"Deleting directory: {d}")
            shutil.rmtree(d)

    for f in cleanup_files:
        if os.path.exists(f):
            print(f"Deleting file: {f}")
            os.remove(f)

    # --- הרצת קובץ תלותות לפני כל קומפילציה ---
    DEPENDENCIES_SCRIPT = os.path.join(SCRIPTS, "creating_compilation_lists.py")
    if os.path.exists(DEPENDENCIES_SCRIPT):
        print(f"\n--- INFO: Running dependencies script: {DEPENDENCIES_SCRIPT} ---")
        dep_return_code = os.system(f'python "{DEPENDENCIES_SCRIPT}"')
        if dep_return_code != 0:
            print(f"\n--- ERROR: Dependencies script failed! ---")
            sys.exit(1)
    else:
        print(f"\n--- INFO: No dependencies script found at {DEPENDENCIES_SCRIPT}, skipping ---")


    # --- קומפילציה ---
    CMD_COMPILE = f'vsim -c -do "{os.path.join(SCRIPTS, "compile.do")}"'
    run_command(CMD_COMPILE, "Compile")

    # --- אילבורציה ---
    CMD_ELABORATE = f'vsim -c -do "{os.path.join(SCRIPTS, "elaborate.do")}"'
    run_command(CMD_ELABORATE, "Elaborate")

    # --- סימולציה ---
    log_file = os.path.join(SIM_LAB, f"{args.test}.log")
    wlf_file = os.path.join(SIM_LAB, f"{args.test}.wlf")
    top_module = args.test + "_opt"  # שם snapshot חוקי ללא נקודה

    cmd = f'vsim {top_module} -voptargs=+acc -sv_seed {args.seed} -L design_work '
    if args.gui:
        cmd += '-gui -do "add wave -r /*; run -all"'
    else:
        cmd += f'-c -logfile {log_file} -wlf {wlf_file} -do "run -all; quit -f"'

    run_command(cmd, "Simulate")

    print(f"\n--- INFO: All steps completed successfully. Check {log_file} for results. ---")

except Exception as e:
    print(f"--- ERROR: {e} ---")
    sys.exit(1)