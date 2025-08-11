# JESD204B Holoscan Sensor Bridge Timing Constraints
# For Lattice Certus Pro NX FPGA

# Clock definitions
create_clock -name sys_clk -period 10.000 -waveform {0 5}
create_clock -name jesd_clk -period 5.000 -waveform {0 2.5}
create_clock -name eth_clk -period 6.250 -waveform {0 3.125}

# Device clock (variable) - for internal processing
create_clock -name device_clk -period 10.000 -waveform {0 5}

# ============================================================================
# CLOCK GROUPS (Asynchronous domains)
# ============================================================================

# Define clock groups as asynchronous to each other
set_clock_groups -asynchronous \
    -group {sys_clk} \
    -group {jesd_clk} \
    -group {eth_clk}

# ============================================================================
# INPUT DELAYS - FMC Interface
# ============================================================================

# JESD204B data lanes (differential pairs)
# The * wildcard matches all array elements: fmc_rx_p[0], fmc_rx_p[1], etc.
set_input_delay -clock jesd_clk -max 1.000 [get_ports fmc_rx_p*]
set_input_delay -clock jesd_clk -max 1.000 [get_ports fmc_rx_n*]

# JESD204B control signals
set_input_delay -clock jesd_clk -max 1.000 [get_ports fmc_sysref_p]
set_input_delay -clock jesd_clk -max 1.000 [get_ports fmc_sysref_n]
set_input_delay -clock jesd_clk -max 1.000 [get_ports fmc_sync_p]
set_input_delay -clock jesd_clk -max 1.000 [get_ports fmc_sync_n]

# JESD204B clock input
set_input_delay -clock jesd_clk -max 0.500 [get_ports fmc_clk_p]
set_input_delay -clock jesd_clk -max 0.500 [get_ports fmc_clk_n]

# System interface
set_input_delay -clock sys_clk -max 2.000 [get_ports sys_reset]

# ============================================================================
# OUTPUT DELAYS - Ethernet Interface
# ============================================================================

# Ethernet data output
set_output_delay -clock eth_clk -max 2.000 [get_ports eth_tx_data*]
set_output_delay -clock eth_clk -max 2.000 [get_ports eth_tx_valid]
set_output_delay -clock eth_clk -max 2.000 [get_ports eth_tx_last]

# Status outputs
set_output_delay -clock sys_clk -max 3.000 [get_ports status_*]

# ============================================================================
# FALSE PATHS (Asynchronous signals)
# ============================================================================

# Reset signals are asynchronous
set_false_path -from [get_ports sys_reset]

# Status signals can be asynchronous
set_false_path -to [get_ports status_*]

# Configuration interface can be slow
set_false_path -from [get_ports cfg_*]

# ============================================================================
# MULTI-CYCLE PATHS
# ============================================================================

# Configuration interface can take multiple cycles
set_multicycle_path -setup 2 -from sys_clk -to jesd_clk
set_multicycle_path -hold 1 -from sys_clk -to jesd_clk

# ============================================================================
# CLOCK DOMAIN CROSSING CONSTRAINTS
# ============================================================================

# JESD to Ethernet crossing
set_false_path -from jesd_clk -to eth_clk
set_false_path -from eth_clk -to jesd_clk

# System to JESD crossing
set_false_path -from sys_clk -to jesd_clk
set_false_path -from jesd_clk -to sys_clk

# ============================================================================
# AREA AND POWER CONSTRAINTS
# ============================================================================

# Area constraints (if needed)
set_max_area 0

# Power constraints
set_max_dynamic_power 0.5W
set_max_leakage_power 0.1W

# ============================================================================
# TIMING EXCEPTIONS
# ============================================================================

# Allow longer setup time for configuration interface
set_max_delay -from [get_ports cfg_*] -to [get_clocks jesd_clk] 20.000

# Allow longer hold time for status outputs
set_min_delay -from [get_clocks sys_clk] -to [get_ports status_*] 1.000

# ============================================================================
# VERIFICATION CONSTRAINTS
# ============================================================================

# Ensure all clocks are properly constrained
set_property CLOCK_DEDICATED_ROUTE FALSE [get_ports fmc_clk_p]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_ports fmc_clk_n]

# ============================================================================
# NOTES FOR IMPLEMENTATION
# ============================================================================

# 1. Update pin assignments in the LPF file based on actual board layout
# 2. Verify clock frequencies match your design
# 3. Adjust timing constraints based on your specific requirements
# 4. Test with actual hardware to validate constraints
# 5. Use Lattice Radiant/Diamond tools for implementation 