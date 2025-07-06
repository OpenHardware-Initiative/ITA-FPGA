# ========================================================================
# Final script to create the Vivado project by sourcing Bender's output
# ========================================================================

# --- 1. Project Configuration ---
set proj_name "ita_kria_project"
set part_name "xck26-sfvc784-2LV-c"
set top_rtl   "ita_hwpe_top"
set top_tb    "ita_hwpe_tb"
set ROOT "/Projects/Agus/ITA"

# --- 2. Create the Project ---
puts "INFO: Creating Vivado project..."
create_project -force $proj_name ./$proj_name -part $part_name

# --- 3. Pre-load Critical Files (THE DEFINITIVE FIX) ---
# We pre-load all packages and headers in the correct dependency order.
# We use the '-used_in' flag to explicitly assign them to BOTH synthesis
# and simulation, which is the most robust method.

puts "INFO: Pre-loading critical SystemVerilog packages..."
set crit_packages [list \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cf_math_pkg.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/hwpe_stream_package.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common/hci_package.sv" \
    "$ROOT/src/ita_package.sv" \
    "$ROOT/src/hwpe/ita_hwpe_package.sv" \
]
# Add the files and assign them to both synthesis and simulation runs.
add_files -norecurse -used_in {synthesis simulation} $crit_packages
set_property is_global_include true [get_files $crit_packages]

puts "INFO: Pre-loading critical SystemVerilog headers..."
set crit_headers [list \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common/hci_helpers.svh" \
]
add_files -norecurse -used_in {synthesis simulation} $crit_headers
set_property file_type "SystemVerilog Header" [get_files $crit_headers]


# --- 4. Add All Other Files using Bender's Script ---
puts "INFO: Sourcing all other files and properties from Bender..."
source ./sources_from_bender.tcl

# --- 5. Finalize Setup ---
puts "INFO: Setting top-level modules..."
update_compile_order -fileset sources_1
set_property top $top_rtl [get_filesets sources_1]

update_compile_order -fileset sim_1
set_property top $top_tb [get_filesets sim_1]

puts "INFO: Project setup complete."