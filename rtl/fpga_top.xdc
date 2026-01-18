#######################################################################################################################
# File     : fpga_top.xdc
# Author   : Mike Pala
# Date     : 11/12/2025
# Revision : 0.1
# Project  : EP2 (Rev4 PCB)
#######################################################################################################################

#######################################################################################################################
# Pin Definitions
#######################################################################################################################
#######################################################################################################################
# Clocks
#######################################################################################################################
create_clock -period 40.000 -name clk_25m         [get_ports pin_hpio_refclk_i_p]
create_clock -period 6.734 -name hdmi_tx_clk_xcvr [get_ports pin_hdmi_tx_clk_i_p]

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins clk_125m_pll/inst/mmcme4_adv_inst/CLKOUT0]] \
    -group [get_clocks -include_generated_clocks clk_25m] \
    -group [get_clocks -include_generated_clocks hdmi_tx_clk_xcvr]


set_property IOSTANDARD LVDS [get_ports pin_hpio_refclk_i_n]
set_property DIFF_TERM_ADV TERM_NONE [get_ports pin_hpio_refclk_i_n]
set_property PACKAGE_PIN AD7 [get_ports pin_hpio_refclk_i_p]
set_property PACKAGE_PIN AE7 [get_ports pin_hpio_refclk_i_n]
set_property IOSTANDARD LVDS [get_ports pin_hpio_refclk_i_p]
set_property DIFF_TERM_ADV TERM_NONE [get_ports pin_hpio_refclk_i_p]

########################################################################################################################
## HDMI Rx
########################################################################################################################
#
set_property -dict {PACKAGE_PIN AC12 IOSTANDARD LVCMOS12 DRIVE 8 SLEW FAST} [get_ports pin_hdmi_rx_oe_o]
#set_property -dict {PACKAGE_PIN AD12 IOSTANDARD LVCMOS12 DRIVE 8 SLEW FAST} [get_ports pin_hdmi_rx_snk_hpd_o]
#
#set_property -dict {PACKAGE_PIN R7} [get_ports pin_hdmi_rx_clk_i_n]
#set_property -dict {PACKAGE_PIN R8} [get_ports pin_hdmi_rx_clk_i_n]
set_property -dict {PACKAGE_PIN V1} [get_ports {pin_hdmi_rx_i_n[0]}]
set_property -dict {PACKAGE_PIN V2} [get_ports {pin_hdmi_rx_i_p[0]}]
set_property -dict {PACKAGE_PIN U3} [get_ports {pin_hdmi_rx_i_n[1]}]
set_property -dict {PACKAGE_PIN U4} [get_ports {pin_hdmi_rx_i_p[1]}]
set_property -dict {PACKAGE_PIN T1} [get_ports {pin_hdmi_rx_i_n[2]}]
set_property -dict {PACKAGE_PIN T2} [get_ports {pin_hdmi_rx_i_p[2]}]
#
########################################################################################################################
## HDMI Tx
########################################################################################################################
#
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS12} [get_ports pin_hdmi_tx_pixclk_sel_n_o]
set_property -dict {PACKAGE_PIN AC2  IOSTANDARD LVCMOS12} [get_ports pin_hdmi_tx_fault_n_i]
set_property -dict {PACKAGE_PIN A12  IOSTANDARD LVCMOS33} [get_ports pin_hdmi_tx_hpd_i]
set_property -dict {PACKAGE_PIN AD9  IOSTANDARD LVCMOS12 DRIVE 8 SLEW FAST} [get_ports pin_hdmi_tx_oe_o]
set_property -dict {PACKAGE_PIN C13  IOSTANDARD LVCMOS33 DRIVE 12 SLEW FAST} [get_ports pin_hdmi_tx_cec_o]
#
set_property -dict {PACKAGE_PIN N7} [get_ports pin_hdmi_tx_clk_i_n]
set_property -dict {PACKAGE_PIN N8} [get_ports pin_hdmi_tx_clk_i_p]
#
set_property -dict {PACKAGE_PIN W3} [get_ports {pin_hdmi_tx_o_n[0]}]
set_property -dict {PACKAGE_PIN W4} [get_ports {pin_hdmi_tx_o_p[0]}]
set_property -dict {PACKAGE_PIN V5} [get_ports {pin_hdmi_tx_o_n[1]}]
set_property -dict {PACKAGE_PIN V6} [get_ports {pin_hdmi_tx_o_p[1]}]
set_property -dict {PACKAGE_PIN T5} [get_ports {pin_hdmi_tx_o_n[2]}]
set_property -dict {PACKAGE_PIN T6} [get_ports {pin_hdmi_tx_o_p[2]}]
set_property -dict {PACKAGE_PIN R3} [get_ports {pin_hdmi_tx_o_n[3]}]
set_property -dict {PACKAGE_PIN R4} [get_ports {pin_hdmi_tx_o_p[3]}]
#
#######################################################################################################################
# PL GPIO
#######################################################################################################################

set_property PACKAGE_PIN AJ6 [get_ports {pin_dbg_led_o[1]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_led_o[1]}]
set_property DRIVE 8 [get_ports {pin_dbg_led_o[1]}]
set_property SLEW SLOW [get_ports {pin_dbg_led_o[1]}]
set_property PULLUP true [get_ports {pin_dbg_led_o[1]}]
set_property PACKAGE_PIN AK2 [get_ports {pin_dbg_led_o[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_led_o[2]}]
set_property DRIVE 8 [get_ports {pin_dbg_led_o[2]}]
set_property SLEW SLOW [get_ports {pin_dbg_led_o[2]}]
set_property PULLUP true [get_ports {pin_dbg_led_o[2]}]
set_property PACKAGE_PIN AK8 [get_ports {pin_dbg_led_o[3]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_led_o[3]}]
set_property DRIVE 8 [get_ports {pin_dbg_led_o[3]}]
set_property SLEW SLOW [get_ports {pin_dbg_led_o[3]}]
set_property PULLUP true [get_ports {pin_dbg_led_o[3]}]
set_property PACKAGE_PIN AB13 [get_ports {pin_dbg_led_o[4]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_led_o[4]}]
set_property DRIVE 8 [get_ports {pin_dbg_led_o[4]}]
set_property SLEW SLOW [get_ports {pin_dbg_led_o[4]}]
set_property PULLUP true [get_ports {pin_dbg_led_o[4]}]

set_property PACKAGE_PIN AJ12 [get_ports {pin_dbg_switch_i[5]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_switch_i[5]}]
set_property PULLUP true [get_ports {pin_dbg_switch_i[5]}]
set_property PACKAGE_PIN AH13 [get_ports {pin_dbg_switch_i[6]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_switch_i[6]}]
set_property PULLUP true [get_ports {pin_dbg_switch_i[6]}]
set_property PACKAGE_PIN AH16 [get_ports {pin_dbg_switch_i[7]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_switch_i[7]}]
set_property PULLUP true [get_ports {pin_dbg_switch_i[7]}]
set_property PACKAGE_PIN AF17 [get_ports {pin_dbg_switch_i[8]}]
set_property IOSTANDARD LVCMOS12 [get_ports {pin_dbg_switch_i[8]}]
set_property PULLUP true [get_ports {pin_dbg_switch_i[8]}]

