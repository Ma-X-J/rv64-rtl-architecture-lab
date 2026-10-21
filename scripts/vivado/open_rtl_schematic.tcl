# Open the project created by create_rtl_project.tcl, elaborate the design,
# display the top-level RTL schematic, and export it as SVG and PDF.
# This script must be run in Vivado GUI mode because show_schematic is a GUI
# command in Vivado 2019.1.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../..]]
set project_file [file join $repo_root build vivado pipelined_cpu_rtl.xpr]
set output_dir [file join $repo_root docs generated]

if {![file exists $project_file]} {
    error "Vivado project not found. Run create_rtl_project.tcl first: $project_file"
}

file mkdir $output_dir
open_project $project_file
set top_name [get_property top [current_fileset]]
synth_design -rtl -name rtl_1 -top $top_name -part [get_property part [current_project]]

# Top-level nets show the module instances, top ports, and the combinational
# logic connecting the five pipeline stages, caches, and control units.
set schematic_name "PIPELINED_CPU RTL"
current_instance
show_schematic -name $schematic_name [get_nets -quiet]

set svg_file [file join $output_dir pipelined_cpu_rtl_schematic.svg]
set pdf_file [file join $output_dir pipelined_cpu_rtl_schematic.pdf]
write_schematic -force -format svg -orientation landscape -scope all \
    -name $schematic_name $svg_file
write_schematic -force -format pdf -orientation landscape -scope all \
    -name $schematic_name $pdf_file

puts "RTL_SCHEMATIC_READY"
puts "SVG: $svg_file"
puts "PDF: $pdf_file"
puts "Vivado remains open so the schematic can be explored interactively."
