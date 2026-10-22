`timescale 1ns/1ps
interface ace_uvm_if(input logic clk);
  import ace_pkg::*;
  import ace_uvm_cache_cov_pkg::*;
  logic [1:0] apb_psel=0,apb_penable=0,apb_pwrite=0;
  logic [11:0] apb_paddr[2];
  logic [31:0] apb_pwdata[2];
  wire [31:0] apb_prdata[2];
  wire [1:0] apb_pready,apb_pslverr;
  wire reset_n,link_ready,quiet_hw,idle_hw;
  wire [1:0] home_rotation;
  wire [3:0] directory_valid,memory_written;
  wire [TAG_W-1:0] directory_tag[4],memory_tag[4];
  wire [1:0] directory_state[4];
  wire [DATA_W-1:0] memory_data[4];
  wire [5:0] status_a,status_b;
  wire [31:0] cnt_tx,cnt_a_snoop,cnt_wr,cnt_rd,cnt_b_snoop;
  wire [9:0] src_valid,src_ready,dst_valid,dst_ready;
  wire [255:0] src_payload[10],dst_payload[10];
  wire internal_cache_line_t cache[4];
endinterface
