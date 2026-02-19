# ===========================
# QuestaSim Compile Script
# ===========================

# --- הגדרת משתנים ראשיים ---
variable PACKAGES_LAB ../design/packages
variable INF_LAB ../design/interfaces
variable RTL_LAB ../design/rtl
variable TB_LAB ../design/tb
variable SIM_LAB ../sim

# --- קריאת שם הטסט שנבחר על ידי המשתמש ---
set fp [open "$SIM_LAB/.current_test" r]
set TEST_NAME [gets $fp]
close $fp

puts "\n--- INFO: Compiling design for testbench: $TEST_NAME ---\n"

# --- יצירת ספריות ---
vlib $SIM_LAB/work
vlib $SIM_LAB/design_work

# --- מיפוי הספריות ---
vmap work $SIM_LAB/work 
vmap design_work $SIM_LAB/design_work 

# --- קומפילציה של החבילות, אינטרפייסים, RTL ולבסוף TB ---
# השתמש בקבצי הרשימה שנוצרו על ידי run_dependencies.py

# 1. קומפילציה של Packages (חבילות)
set packages_file_path "$SIM_LAB/packages.f"
if {[file size $packages_file_path] > 0} {
    puts "--- INFO: Compiling Packages from $packages_file_path ---"
    vlog -sv -work design_work -f $packages_file_path
} else {
    puts "--- INFO: Skipping Packages compilation (packages.f is empty) ---"
}


# 2. קומפילציה של Interfaces (ממשקים)
set interface_file_path "$SIM_LAB/interfaces.f"
if {[file size $interface_file_path] > 0} {
    puts "--- INFO: Compiling SystemVerilog Interfaces from $interface_file_path ---"
    vlog -sv -work design_work -L design_work -f $interface_file_path
} else {
    puts "--- INFO: Skipping Interface compilation (interfaces.f is empty) ---"
}


# 3. קומפילציה של RTL
set rtl_file_path "$SIM_LAB/rtl.f"
if {[file size $rtl_file_path] > 0} {
    puts "--- INFO: Compiling RTL from $rtl_file_path ---"
    vlog -sv -work design_work -L design_work -f $rtl_file_path
} else {
    puts "--- ERROR: Cannot run simulation. RTL file list (rtl.f) is empty. ---"
}


# 4. קומפילציה של Testbench
puts "--- INFO: Compiling Testbench $TEST_NAME.sv ---"
vlog -sv -work work -L design_work "$TB_LAB/${TEST_NAME}.sv"

quit -force