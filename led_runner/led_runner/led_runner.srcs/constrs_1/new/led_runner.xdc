## =========================================================
## Nexys A7-100T：100 MHz 系统时钟
## =========================================================
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}]


## =========================================================
## CPU_RESETN 按钮，低电平有效
## =========================================================
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports {rstn}]


## =========================================================
## 八位数码管位选 AN0～AN7
## 低电平有效
## =========================================================
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[0]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[2]}]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[3]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[4]}]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[5]}]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[6]}]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports {disp_an_o[7]}]


## =========================================================
## 七段数码管段选
##
## disp_seg_o[7:0] = {DP, G, F, E, D, C, B, A}
## 低电平有效
## =========================================================
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[0]}]
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[1]}]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[2]}]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[3]}]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[4]}]
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[5]}]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[6]}]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {disp_seg_o[7]}]


## FPGA 配置电压属性
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]