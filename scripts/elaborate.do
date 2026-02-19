# ===========================
# QuestaSim Elaborate Script
# ===========================

# --- הגדרת משתנים ---
variable SIM_LAB ../sim

# קריאת שם הטסט שנבחר
set fp [open "$SIM_LAB/.current_test" r]
set TEST_NAME [gets $fp]
close $fp

puts "Using testbench name: $TEST_NAME"

# --- מיפוי הספריות ---
vmap work $SIM_LAB/work 
vmap design_work $SIM_LAB/design_work

# --- יצירת snapshot אופטימלי ---
# כאן אנו מניחים שה-TB הוא ה-top level, אין צורך נפרד ב-TOP של DUT
vopt +acc=npr -L design_work -o ${TEST_NAME}_opt work.${TEST_NAME}

quit -force