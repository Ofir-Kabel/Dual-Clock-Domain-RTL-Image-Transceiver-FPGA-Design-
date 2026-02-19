# --------------------------------------------------------------------------------
# Script: full_ff_analysis.tcl
# Description: Exports Elaborated Registers & Synthesized Netlist.
# --------------------------------------------------------------------------------

if { $argc != 1 } {
    puts "❌ ERROR: Missing project path argument."
    exit 1
}
set xpr_file [lindex $argv 0]

set script_path [file dirname [file normalize [info script]]]
set config_file "$script_path/project_paths.cfg"

# Load Config
if {![file exists $config_file]} {
    puts "❌ ERROR: Config file missing."
    exit 1
}
set fp [open $config_file r]
set file_data [read $fp]
close $fp
foreach line [split $file_data "\n"] {
    if {[regexp {^(\w+)\s*=\s*(.*)$} $line -> key value]} {
        set CFG($key) [string trim $value]
    }
}

puts "\n========================================================"
puts " TCL WORKER: Processing Project"
puts "========================================================"

open_project $xpr_file

set lab_root_dir [file normalize "$script_path/.."]
set report_dir "$lab_root_dir/$CFG(REPORTS_DIR)"
file mkdir $report_dir

# PHASE A: ELABORATION
puts "INFO: Opening RTL Design (Elaboration)..."
if {[catch {open_rtl_design -name rtl_1} err]} {
    puts "❌ ERROR: Elaboration failed: $err"
    exit 1
}

set elab_list_path "$report_dir/elaborated_registers.txt"
set rtl_regs [get_cells -hierarchical -filter {PRIMITIVE_SUBGROUP == flop || PRIMITIVE_SUBGROUP == latch}]

set fp_list [open $elab_list_path w]
foreach r $rtl_regs {
    puts $fp_list $r
}
close $fp_list
puts "✅ Elaboration list exported."

# PHASE B: SYNTHESIS
puts "INFO: Resetting and launching Synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set run_status [get_property STATUS [get_runs synth_1]]
if {[string match "*omplete*" $run_status] || [string match "*to-date*" $run_status]} {
    puts "✅ Synthesis OK. Exporting Netlist..."
    open_run synth_1 -name synth_1
    
    write_verilog -force -mode funcsim "$report_dir/$CFG(NETLIST_NAME)"
    report_utilization -file "$report_dir/$CFG(UTIL_RPT_NAME)"
    puts "✅ Netlist exported."
} else {
    puts "❌ ERROR: Synthesis failed. Status: $run_status"
    exit 1
}

close_project
exit 0