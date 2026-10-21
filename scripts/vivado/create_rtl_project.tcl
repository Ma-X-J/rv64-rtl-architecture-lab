# Create a Vivado RTL-analysis project for the current five-stage CPU.
# Testbenches and the archived single-cycle implementation are intentionally
# excluded from the fileset.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../..]]
set project_dir [file join $repo_root build vivado]
set report_dir [file join $repo_root build vivado reports]

file mkdir $project_dir
file mkdir $report_dir

set preferred_part xc7a35tcpg236-1
if {[llength [get_parts -quiet $preferred_part]] == 0} {
    set installed_parts [get_parts -quiet]
    if {[llength $installed_parts] == 0} {
        error "No Xilinx device parts are installed in this Vivado installation."
    }
    set preferred_part [lindex $installed_parts 0]
}

create_project pipelined_cpu_rtl $project_dir -force -part $preferred_part

set rtl_files [list]
foreach relative_pattern [list \
    rtl/PIPELINED_CPU.v \
    rtl/Cache/*.v \
    rtl/control/*.v \
    rtl/datapath/*.v \
    rtl/memory/*.v] {
    foreach rtl_file [glob -nocomplain [file join $repo_root $relative_pattern]] {
        lappend rtl_files [file normalize $rtl_file]
    }
}

if {[llength $rtl_files] == 0} {
    error "No RTL source files were found below $repo_root/rtl."
}

add_files -norecurse $rtl_files
set_property top PIPELINED_CPU [current_fileset]
set_property top_auto_set 0 [current_fileset]
update_compile_order -fileset sources_1

set compile_order_file [file join $report_dir compile_order.txt]
report_compile_order -used_in synthesis -file $compile_order_file

# Elaborate the RTL without technology mapping. This is the same design view
# used by Vivado's "Open Elaborated Design" action.
synth_design -rtl -name rtl_1 -top PIPELINED_CPU -part $preferred_part

set hierarchy_file [file join $report_dir top_level_instances.txt]
set hierarchy_handle [open $hierarchy_file w]
puts $hierarchy_handle "Vivado part: $preferred_part"
puts $hierarchy_handle "Top module: PIPELINED_CPU"
puts $hierarchy_handle ""
puts $hierarchy_handle "Top-level elaborated instances:"
foreach cell [lsort [get_cells -quiet]] {
    puts $hierarchy_handle [format "%-40s %s" $cell [get_property REF_NAME $cell]]
}
close $hierarchy_handle

puts "RTL_ELABORATION_PASS"
puts "Project: [file join $project_dir pipelined_cpu_rtl.xpr]"
puts "Compile order: $compile_order_file"
puts "Hierarchy report: $hierarchy_file"

close_design
close_project
exit
