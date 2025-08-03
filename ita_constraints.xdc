# 100 MHz input clock on port clk_i (period = 10 ns)
create_clock -name clk_i -period 10.0 [get_ports clk_i]

# INPUT DELAYS (setup/hold = 1 ns) for all input ports except clk_i
set_input_delay -clock clk_i -max 1.0 [get_ports -filter {DIRECTION == IN && (NAME != "clk_i")}]
set_input_delay -clock clk_i -min 1.0 [get_ports -filter {DIRECTION == IN && (NAME != "clk_i")}]

# OUTPUT DELAYS (setup/hold = 1 ns) for all output ports
set_output_delay -clock clk_i -max 1.0 [get_ports -filter {DIRECTION == OUT}]
set_output_delay -clock clk_i -min 1.0 [get_ports -filter {DIRECTION == OUT}]