//Copyright 1986-2016 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2016.2 (win64) Build 1577090 Thu Jun  2 16:32:40 MDT 2016
//Date        : Thu Mar 16 01:14:07 2017
//Host        : Charles-Area51 running 64-bit major release  (build 9200)
//Command     : generate_target block_system_wrapper.bd
//Design      : block_system_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module block_system_wrapper
   (DDR2_addr,
    DDR2_ba,
    DDR2_cas_n,
    DDR2_ck_n,
    DDR2_ck_p,
    DDR2_cke,
    DDR2_cs_n,
    DDR2_dm,
    DDR2_dq,
    DDR2_dqs_n,
    DDR2_dqs_p,
    DDR2_odt,
    DDR2_ras_n,
    DDR2_we_n,
    MISO,
    MOSI,
    SCLK,
    SSout,
    reset,
    sys_clock,
    tft_hsync,
    tft_vga_b,
    tft_vga_g,
    tft_vga_r,
    tft_vsync,
    usb_uart_rxd,
    usb_uart_txd);
  output [12:0]DDR2_addr;
  output [2:0]DDR2_ba;
  output DDR2_cas_n;
  output [0:0]DDR2_ck_n;
  output [0:0]DDR2_ck_p;
  output [0:0]DDR2_cke;
  output [0:0]DDR2_cs_n;
  output [1:0]DDR2_dm;
  inout [15:0]DDR2_dq;
  inout [1:0]DDR2_dqs_n;
  inout [1:0]DDR2_dqs_p;
  output [0:0]DDR2_odt;
  output DDR2_ras_n;
  output DDR2_we_n;
  input MISO;
  output MOSI;
  output SCLK;
  output SSout;
  input reset;
  input sys_clock;
  output tft_hsync;
  output [3:0]tft_vga_b;
  output [3:0]tft_vga_g;
  output [3:0]tft_vga_r;
  output tft_vsync;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [12:0]DDR2_addr;
  wire [2:0]DDR2_ba;
  wire DDR2_cas_n;
  wire [0:0]DDR2_ck_n;
  wire [0:0]DDR2_ck_p;
  wire [0:0]DDR2_cke;
  wire [0:0]DDR2_cs_n;
  wire [1:0]DDR2_dm;
  wire [15:0]DDR2_dq;
  wire [1:0]DDR2_dqs_n;
  wire [1:0]DDR2_dqs_p;
  wire [0:0]DDR2_odt;
  wire DDR2_ras_n;
  wire DDR2_we_n;
  wire MISO;
  wire MOSI;
  wire SCLK;
  wire SSout;
  wire reset;
  wire sys_clock;
  wire tft_hsync;
  wire [5:0]_tft_vga_b;
  wire [5:0]_tft_vga_g;
  wire [5:0]_tft_vga_r;
  wire tft_vsync;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  assign tft_vga_b = _tft_vga_b[3:0];
  assign tft_vga_g = _tft_vga_g[3:0];
  assign tft_vga_r = _tft_vga_r[3:0];
  
  block_system block_system_i
       (.DDR2_addr(DDR2_addr),
        .DDR2_ba(DDR2_ba),
        .DDR2_cas_n(DDR2_cas_n),
        .DDR2_ck_n(DDR2_ck_n),
        .DDR2_ck_p(DDR2_ck_p),
        .DDR2_cke(DDR2_cke),
        .DDR2_cs_n(DDR2_cs_n),
        .DDR2_dm(DDR2_dm),
        .DDR2_dq(DDR2_dq),
        .DDR2_dqs_n(DDR2_dqs_n),
        .DDR2_dqs_p(DDR2_dqs_p),
        .DDR2_odt(DDR2_odt),
        .DDR2_ras_n(DDR2_ras_n),
        .DDR2_we_n(DDR2_we_n),
        .MISO(MISO),
        .MOSI(MOSI),
        .SCLK(SCLK),
        .SSout(SSout),
        .reset(reset),
        .sys_clock(sys_clock),
        .tft_hsync(tft_hsync),
        .tft_vga_b(_tft_vga_b),
        .tft_vga_g(_tft_vga_g),
        .tft_vga_r(_tft_vga_r),
        .tft_vsync(tft_vsync),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule
