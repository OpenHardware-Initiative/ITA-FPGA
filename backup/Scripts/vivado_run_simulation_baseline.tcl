# ===================================================================
# Script to launch a simulation in an existing Vivado project
# ===================================================================

# Check for the project file argument passed via -tclargs
if {$argc < 2 || [lindex $argv 0] != "--project"} {
    puts "ERROR: Please provide the project file path."
    puts "Usage: vivado -mode batch -source run_simulation.tcl -tclargs --project <path_to_project.xpr>"
    exit 1
}
set proj_file [lindex $argv 1]

# Open the specified project
puts "INFO: Opening project $proj_file"
open_project $proj_file

# Launch the Vivado simulator
puts "INFO: Launching Vivado simulator..."
launch_simulation

# Run the simulation until it finishes
puts "INFO: Running simulation..."
run all

puts "INFO: Simulation finished."