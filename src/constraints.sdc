# Assign base metrics to standard digital clock path (50MHz default)
create_clock -name clk -period 20.0 [get_ports clk]

# Map out specific 3.33ns timing constraints tracking your 300MHz pulse input
create_clock -name async_cnt_clk -period 3.33 [get_ports {ui_in[0]}]

# Inform LibreLane / OpenSTA that these domains are false paths relative to each other
set_false_path -from [get_clocks {clk}] -to [get_clocks {async_cnt_clk}]
set_false_path -from [get_clocks {async_cnt_clk}] -to [get_clocks {clk}]
