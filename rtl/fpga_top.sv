// -----------------------------------------------------------------------------
// *** Ross Video Limited Proprietary / Company Confidential ***
//                              
// Copyright 2016-2026
// Ross Video
// All Rights Reserved
//
//
// File Name     : fpga_top.sv
// Author(s)     : Mike Pala
// Date Created  : Jan 2026
// Device        : XCZU5EV-FBVB900E-2-E
//
// -----------------------------------------------------------------------------

module fpga_top #(     
    parameter PROJ_BUILD_DATE = 32'h26_01_09_01 // format: YY_MM_DD_RR, where RR is revision     
    )(     
    // HPIO ref clock

    input 	  pin_hpio_refclk_i_p,//125MHz
    input 	  pin_hpio_refclk_i_n,
   
    // HDMI RX channel GTH ref clock
   
    input 	  pin_hdmi_rx_clk_i_n,
    input 	  pin_hdmi_rx_clk_i_p,
    input [2:0]   pin_hdmi_rx_i_p,
    input [2:0]   pin_hdmi_rx_i_n,

    // HDMI TX channel GTH ref clock

    input 	  pin_hdmi_tx_clk_i_n,
    input 	  pin_hdmi_tx_clk_i_p, 
   
    output 	  pin_hdmi_tx_pixclk_sel_n_o, 
    output [3:0]  pin_hdmi_tx_o_p,
    output [3:0]  pin_hdmi_tx_o_n,
   
    // HDMI RX Misc Control

    output 	  pin_hdmi_rx_oe_o,
    // HDMI TX Misc Control

    input 	  pin_hdmi_tx_fault_n_i,
    input 	  pin_hdmi_tx_hpd_i, 

    output 	  pin_hdmi_tx_cec_o,
    output 	  pin_hdmi_tx_oe_o, 
    // General Purpose GPIO
    input [8:5]   pin_dbg_switch_i,
    output[4:1]   pin_dbg_led_o
);

// ====================================================================
// Misc signals
// ====================================================================

wire            pl_rstn             ;
wire            sfp1_rx_rdy         ;
wire            sfp1_tx_rdy         ;
//
wire [7:0]      probe_out0;
// HDMItransciver
wire  hdmi_tx_clk148m5;
wire  gtrefclk_hdmi_tx;
wire  refclk_hdmi_tx_bufg;
wire  userclk_tx_active;
wire  hdmi_tx_rdy, hdmi_rx_rdy;
wire [79:0] hdmi_tx_data;
wire [79:0] hdmi_rx_data;
//
// ====================================================================
// Clocks and resets
// ====================================================================
// Global Power-up Reset Generator.

wire gblrst, gblrst_n; // Global reset, active high and active low signals
wire hpio_refclk;
wire clk_25m;
wire clk_125m;
wire clk_125m_locked;
wire rst_125m;
wire rst_vid;

global_reset_gen # (               // Generates a reset pulse on power-up
  .N_BIT_DEBOUNCE( 5            ), // N bit shift register debouncer (Min=2)
  .N_BIT_COUNT   ( 5            )  // 2^N pulse width counter (Min=2)
) global_reset_gen (               // 2^5 default to 32 clk_i periods
  .reset_i       (1'b0          ), // Active high asynchronous reset input
  .clk_i         (clk_25m       ), // External clock oscillator
  .reset_o       (gblrst        ), // Active high global reset output
  .reset_n_o     (gblrst_n      )  // Active low  global reset output
);

IBUFDS hpio_refclk_inst (
   .I                 (pin_hpio_refclk_i_p  ),
   .IB                (pin_hpio_refclk_i_n  ),
   .O                 (hpio_refclk          )
);
BUFG hpio_refclk_bufg_inst (
   .I                 (hpio_refclk          ),
   .O                 (clk_25m              )
);

clk_125m_pll clk_125m_pll (
    .clk_in1    (clk_25m        ),// input clk_in1
    .reset      (gblrst         ),// input reset
    .clk_out1   (clk_125m       ),// output clk_out1
    .locked     (clk_125m_locked) // output locked
);

assign rst_125m = ~clk_125m_locked;
assign rst_vid  = ~clk_125m_locked | ~hdmi_tx_rdy;
// ====================================================================
// Video Unit Under Test
// ====================================================================
wire        cen_vid;
wire [ 2:0] dvh_sync_in;
wire [ 2:0] dvh_sync_out;
wire [ 1:0] vh_blank;
wire [23:0] vid_rgb_in;
wire [23:0] vide_rgb_out;

video_uut video_uut (       
    .clk_i          (hdmi_tx_clk148m5   ),//               
    .cen_i          (cen_vid            ),// video clock enable
    .rst_i          (rst_vid            ),//
    .vid_sel_i      (probe_out0[0]      ),//
    .vh_blank_i     (vh_blank           ),//[ 1:0] = {Vblank, Hblank}
    .dvh_sync_i     (dvh_sync_in        ),//[ 2:0] = {D_sync, Vsync , Hsync }
    .vid_rgb_i      (vid_rgb_in         ),//[23:0] = R[23:16], G[15:8], B[7:0]
    // Output signals
    .dvh_sync_o     (dvh_sync_out       ),//[ 2:0] = {D_sync, Vsync , Hsync }  delayed
    .vid_rgb_o      (vide_rgb_out       ) //[23:0] = R[23:16], G[15:8], B[7:0] delayed
);

// ====================================================================
// HDMI Video Output
// ====================================================================

kvm_vid_top_rgb kvm_vid_top_rgb(
    .pclk_i         (hdmi_tx_clk148m5   ),// 
    .prst_i         (rst_vid            ),// 
    // Signals to UUT
    .cen_o          (cen_vid            ),// video clock enable
    .dvh_sync_o     (dvh_sync_in        ),//[ 2:0] HDMI timing signals
    .vh_blank_o     (vh_blank           ),//[ 1:0] Video timing signals
    .vid_rgb_o      (vid_rgb_in         ),//[23:0] = R[23:16], G[15:8], B[7:0]
    // Signals from UUT
    .dvh_sync_i     (dvh_sync_out       ),//[ 2:0] HDMI timing signals
    .vid_rgb_i      (vide_rgb_out       ),//[23:0] = R[23:16], G[15:8], B[7:0]
    // HDMI TX Output                   
    .hdmi_tdms_o    (hdmi_tx_data       ) //[79:0]
);

// ===================================================================================================================
// HDMI TX Transciever
// ===================================================================================================================

wire [0:0] buffbypass_tx_reset;
wire [0:0] hb0_gtwiz_buffbypass_tx_reset_int;
assign buffbypass_tx_reset[0:0] = hb0_gtwiz_buffbypass_tx_reset_int;
//
// The TX buffer bypass controller helper block should be held in reset until the TX user clocking network helper
// block which drives it is active
(* DONT_TOUCH = "TRUE" *)
xcv_hdmi_reset_synchronizer reset_synchronizer_gtwiz_buffbypass_tx_reset_inst (
.clk_in  (hdmi_tx_clk148m5),
.rst_in  (~userclk_tx_active),
.rst_out (hb0_gtwiz_buffbypass_tx_reset_int)
);
//
//GTE4 Differential Clock Input Buffer
wire ibufds_odiv2;
IBUFDS_GTE4 ibufds_inst (
    .I          (pin_hdmi_tx_clk_i_p),
    .IB         (pin_hdmi_tx_clk_i_n),
    .CEB        (1'b0               ),
    .O          (gtrefclk_hdmi_tx   ),
    .ODIV2      (ibufds_odiv2       )
    );
    
//GT Global Clock Buffer for Fabric Use
BUFG_GT bufg_gt_inst (
    .I          (ibufds_odiv2    ),
    .CE         (1'b1            ),
    .CEMASK     (1'b0            ),
    .CLR        (1'b0            ),
    .CLRMASK    (1'b0            ),
    .DIV        (3'd0            ),//[2:0]
    .O          (refclk_hdmi_tx_bufg)
);
   
xcv_hdmi xcvr_hdmi (
    .gtwiz_userclk_tx_reset_in          (1'b0               ),// input [0 : 0] gtwiz_userclk_tx_reset_in
    .gtwiz_userclk_tx_srcclk_out        (                   ),// output[0 : 0] gtwiz_userclk_tx_srcclk_out
    .gtwiz_userclk_tx_usrclk_out        (                   ),// output[0 : 0] gtwiz_userclk_tx_usrclk_out
    .gtwiz_userclk_tx_usrclk2_out       (hdmi_tx_clk148m5   ),// output[0 : 0] gtwiz_userclk_tx_usrclk2_out
    .gtwiz_userclk_tx_active_out        (userclk_tx_active  ),// output[0 : 0] gtwiz_userclk_tx_active_out
    .gtwiz_userclk_rx_reset_in          (1'b0               ),// input [0 : 0] gtwiz_userclk_rx_reset_in
    .gtwiz_userclk_rx_srcclk_out        (                   ),// output[0 : 0] gtwiz_userclk_rx_srcclk_out
    .gtwiz_userclk_rx_usrclk_out        (                   ),// output[0 : 0] gtwiz_userclk_rx_usrclk_out
    .gtwiz_userclk_rx_usrclk2_out       (                   ),// output[0 : 0] gtwiz_userclk_rx_usrclk2_out
    .gtwiz_userclk_rx_active_out        (                   ),// output[0 : 0] gtwiz_userclk_rx_active_out
    .gtwiz_buffbypass_tx_reset_in       (buffbypass_tx_reset),// input [0 : 0] gtwiz_buffbypass_tx_reset_in
    .gtwiz_buffbypass_tx_start_user_in  (1'b0               ),// input [0 : 0] gtwiz_buffbypass_tx_start_user_in
    .gtwiz_buffbypass_tx_done_out       (                   ),// output[0 : 0] gtwiz_buffbypass_tx_done_out
    .gtwiz_buffbypass_tx_error_out      (                   ),// output[0 : 0] gtwiz_buffbypass_tx_error_out
    .gtwiz_reset_clk_freerun_in         (clk_125m           ),// input [0 : 0] gtwiz_reset_clk_freerun_in
    .gtwiz_reset_all_in                 (1'b1               ),// input [0 : 0] gtwiz_reset_all_in
    .gtwiz_reset_tx_pll_and_datapath_in (rst_125m           ),// input [0 : 0] gtwiz_reset_tx_pll_and_datapath_in
    .gtwiz_reset_tx_datapath_in         (1'b0               ),// input [0 : 0] gtwiz_reset_tx_datapath_in
    .gtwiz_reset_rx_pll_and_datapath_in (1'b0               ),// input [0 : 0] gtwiz_reset_rx_pll_and_datapath_in
    .gtwiz_reset_rx_datapath_in         (1'b0               ),// input [0 : 0] gtwiz_reset_rx_datapath_in
    .gtwiz_reset_rx_cdr_stable_out      (                   ),// output[0 : 0] gtwiz_reset_rx_cdr_stable_out
    .gtwiz_reset_tx_done_out            (hdmi_tx_rdy        ),// output[0 : 0] gtwiz_reset_tx_done_out
    .gtwiz_reset_rx_done_out            (hdmi_rx_rdy        ),// output[0 : 0] gtwiz_reset_rx_done_out
    .gtwiz_userdata_tx_in               (hdmi_tx_data       ),// input [79: 0] gtwiz_userdata_tx_in
    .gtwiz_userdata_rx_out              (hdmi_rx_data       ),// output[79: 0] gtwiz_userdata_rx_out
    .gtrefclk00_in                      (gtrefclk_hdmi_tx   ),// input [0 : 0] gtrefclk00_in
    .qpll0outclk_out                    (                   ),// output[0 : 0] qpll0outclk_out
    .qpll0outrefclk_out                 (                   ),// output[0 : 0] qpll0outrefclk_out
    .drpclk_in                          (clk_125m           ),// input [3 : 0] drpclk_in
    .gthrxn_in                          (pin_hdmi_rx_i_n    ),// input [3 : 0] gthrxn_in
    .gthrxp_in                          (pin_hdmi_rx_i_p    ),// input [3 : 0] gthrxp_in
    .gtrefclk0_in                       ({4{gtrefclk_hdmi_tx}}),// input [3 : 0] gtrefclk0_in
    .gthtxn_out                         (pin_hdmi_tx_o_n    ),// output[3 : 0] gthtxn_out
    .gthtxp_out                         (pin_hdmi_tx_o_p    ),// output[3 : 0] gthtxp_out
    .gtpowergood_out                    (                   ),// output[3 : 0] gtpowergood_out
    .rxpmaresetdone_out                 (                   ),// output[3 : 0] rxpmaresetdone_out
    .txpmaresetdone_out                 (                   ),// output[3 : 0] txpmaresetdone_out
    .txprgdivresetdone_out              (                   ) // output[3 : 0] txprgdivresetdone_out
);

assign pin_hdmi_tx_pixclk_sel_n_o = 1'b0;// 1=clk1, 0=clk0
assign pin_hdmi_tx_oe_o           = clk_125m_locked;// enable HDMI TX driver 
assign pin_hdmi_tx_cec_o          =  1'b1;// consumer electronics control
// HDMI Rx OE
assign pin_hdmi_rx_oe_o           = 1'b0; 

// ====================================================================
// Debug clock Monitor
// ====================================================================
wire            clk_in      [2];
wire [31:0]     mon_cnt     [2];

assign clk_in[0] = clk_125m;
assign clk_in[1] = hdmi_tx_clk148m5;

clock_mon #(
    .REF_CYCLES     (250_000    ),//
    .NUM_CLK        ( 2         ) //
) clock_mon (
    .ref_clk_i      (clk_25m    ),//
    .ref_toggle_o   ( ),//
    .ref_toggle_p_o ( ),//
    .mon_clk_i      (clk_in     ),// [NUM_CLK]
    .mon_cnt_o      (mon_cnt    ) // [NUM_CLK]
);
// ====================================================================
// Debug Probes
// ====================================================================

vio_0 vio_0 (
    .clk        (clk_125m  ),// input  wire clk
    .probe_in0  (mon_cnt[0]),// [31 : 0]
    .probe_in1  (mon_cnt[1]),// [31 : 0]
    .probe_out0 (probe_out0) // [7 : 0]
);
// ====================================================================
// Debug assignments
// ====================================================================
// use a counter to display a binary count on the debug board LEDs
reg [27:0]  led_cnt [4];
     
always @ (posedge clk_25m) begin
    if (gblrst) led_cnt[0] <= 0;
    else        led_cnt[0] <= led_cnt[0]+1;
end
always @ (posedge clk_125m) begin
    if (gblrst) led_cnt[1] <= 0;
    else        led_cnt[1] <= led_cnt[1]+1;
end
always @ (posedge refclk_hdmi_tx_bufg) begin
    if (gblrst) led_cnt[2] <= 0;
    else        led_cnt[2] <= led_cnt[2]+1;
end
always @ (posedge hdmi_tx_clk148m5) begin
    if (gblrst) led_cnt[3] <= 0;
    else        led_cnt[3] <= led_cnt[3]+1;
end

assign pin_dbg_led_o[1] = (~pin_dbg_switch_i[5])? led_cnt[0][24] : (~pin_dbg_switch_i[6])? led_cnt[1][24] : (~pin_dbg_switch_i[7])? led_cnt[2][24] : (~pin_dbg_switch_i[8])? led_cnt[3][23] : 1'b0;       
assign pin_dbg_led_o[2] = (~pin_dbg_switch_i[5])? led_cnt[0][25] : (~pin_dbg_switch_i[6])? led_cnt[1][25] : (~pin_dbg_switch_i[7])? led_cnt[2][25] : (~pin_dbg_switch_i[8])? led_cnt[3][24] : 1'b0;       
assign pin_dbg_led_o[3] = (~pin_dbg_switch_i[5])? led_cnt[0][26] : (~pin_dbg_switch_i[6])? led_cnt[1][26] : (~pin_dbg_switch_i[7])? led_cnt[2][26] : (~pin_dbg_switch_i[8])? led_cnt[3][25] : 1'b0;       
assign pin_dbg_led_o[4] = (~pin_dbg_switch_i[5])? led_cnt[0][27] : (~pin_dbg_switch_i[6])? led_cnt[1][27] : (~pin_dbg_switch_i[7])? led_cnt[2][27] : (~pin_dbg_switch_i[8])? led_cnt[3][26] : 1'b0;       


endmodule

// ====================================================================
//  xcv_hdmi_reset_synchronizer
// ====================================================================
module xcv_hdmi_reset_synchronizer # (
  parameter FREQUENCY = 512
)(
  input  wire clk_in,
  input  wire rst_in,
  output wire rst_out
);
  // Use 5 flip-flops as a single synchronizer, and tag each declaration with the appropriate synthesis attribute to
  // enable clustering. Each flip-flop in the synchronizer is asynchronously reset so that the downstream logic is also
  // asynchronously reset but encounters no reset assertion latency. The removal of reset is synchronous, so that the
  // downstream logic is also removed from reset synchronously. This module is designed for active-high reset use.

  (* ASYNC_REG = "TRUE" *) reg rst_in_meta  = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync1 = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync2 = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync3 = 1'b0;
                           reg rst_in_out   = 1'b0;

  always @(posedge clk_in, posedge rst_in) begin
    if (rst_in) begin
      rst_in_meta  <= 1'b1;
      rst_in_sync1 <= 1'b1;
      rst_in_sync2 <= 1'b1;
      rst_in_sync3 <= 1'b1;
      rst_in_out   <= 1'b1;
    end
    else begin
      rst_in_meta  <= 1'b0;
      rst_in_sync1 <= rst_in_meta;
      rst_in_sync2 <= rst_in_sync1;
      rst_in_sync3 <= rst_in_sync2;
      rst_in_out   <= rst_in_sync3;
    end
  end

  assign rst_out = rst_in_out;


endmodule
