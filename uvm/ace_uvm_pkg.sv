`timescale 1ns/1ps
package ace_uvm_pkg;
  import uvm_pkg::*;
  import ace_pkg::*;
  import ace_uvm_model_pkg::*;
  import ace_uvm_cache_cov_pkg::*;
  import ace_uvm_checker_pkg::*;
  import ace_uvm_runtime_cov_pkg::*;
  `include "uvm_macros.svh"
  `uvm_analysis_imp_decl(_ace)
  `uvm_analysis_imp_decl(_apb)

  class ace_v2_config extends uvm_object;
    `uvm_object_utils(ace_v2_config)
    virtual ace_uvm_if vif;
    ace_checker engine;
    string kind,stage="boot",report_dir=".",backend="off";
    int mode=0,burst_beats=4,tx_target=64,prbs_code=165,xcode=90,snoop_gap=10;
    int link_timeout_us=1000,run_timeout_us=500,global_timeout_us=3000;
    int drain_cycles=50000,progress_us=10,pause_cycles=100,pause_at=0,error_target=8;
    bit [43:0] base_address=44'h20000000;
    bit monitoring,completed,checked,apb_trace,diagnostic;
    bit [5:0] allowed_a,allowed_b;
    logic [31:0] a_data=32'h005a00a5,b_data=32'h005a00a5;
    bit [43:0] configured_base=44'h20000000;
    bit [7:0] configured_len=3;
    logic [31:0] snoop_config=10;
    bit a_enable,b_enable;
    longint unsigned epoch_tx,epoch_a_cr,epoch_wr,epoch_rd;
    int a_clears,b_clears,pauses,resumes,negative_phases,recovery_phases;
    function new(string name="ace_v2_config");super.new(name);endfunction
    function void parse();
      bit [63:0] wide_address;
      wide_address=base_address;
      void'($value$plusargs("DATA_MODE=%d",mode));void'($value$plusargs("BURST_BEATS=%d",burst_beats));
      void'($value$plusargs("TX_TARGET=%d",tx_target));void'($value$plusargs("PRBS_CODE=%d",prbs_code));
      void'($value$plusargs("XCODE=%d",xcode));void'($value$plusargs("SNOOP_GAP=%d",snoop_gap));
      void'($value$plusargs("BASE_ADDR=%h",wide_address));
      void'($value$plusargs("LINK_TIMEOUT_US=%d",link_timeout_us));void'($value$plusargs("RUN_TIMEOUT_US=%d",run_timeout_us));
      void'($value$plusargs("GLOBAL_TIMEOUT_US=%d",global_timeout_us));void'($value$plusargs("DRAIN_TIMEOUT_CYC=%d",drain_cycles));
      void'($value$plusargs("PROGRESS_US=%d",progress_us));void'($value$plusargs("PAUSE_CYCLES=%d",pause_cycles));
      void'($value$plusargs("PAUSE_AT=%d",pause_at));void'($value$plusargs("ERROR_TARGET=%d",error_target));
      void'($value$plusargs("REPORT_DIR=%s",report_dir));void'($value$plusargs("CODE_COV=%s",backend));
      apb_trace=$test$plusargs("APB_TRACE");diagnostic=(kind=="ace_v2_data_alias_diag_test");
      if(mode<0 || mode>5 || burst_beats<2 || burst_beats>256 || tx_target<1 || tx_target>100000 ||
         prbs_code<0 || prbs_code>255 || xcode<0 || xcode>255 || snoop_gap<0 || snoop_gap>255 ||
         wide_address[63:44]!=0 || wide_address[3:0]!=0 || wide_address>64'hfffffffffc0 ||
         link_timeout_us<1 || run_timeout_us<1 || global_timeout_us<1 || drain_cycles<16 ||
         progress_us<0 || progress_us>1000 || pause_cycles<16 || pause_at<0 || error_target<2 ||
         !(backend inside {"off","collect","runtime"})) `uvm_fatal("ARGS","Invalid UVM configuration")
      base_address=wide_address[43:0];
      if(kind inside {"ace_v2_uc_rs_sc_test","ace_v2_cr_unique_test","ace_v2_cr_shared_test"}) begin
        if(snoop_gap!=255 || tx_target!=((kind=="ace_v2_uc_rs_sc_test")?2:(kind=="ace_v2_cr_shared_test")?3:6))
          `uvm_fatal("DIRECTED_ARGS","Coverage cases require fixed TX_TARGET=2/3/6 and SNOOP_GAP=255")
      end
      if(pause_at==0) pause_at=(tx_target>2)?tx_target/2:1;
    endfunction
  endclass

  `include "ace_uvm_apb.svh"
  `include "ace_uvm_monitor.svh"
  `include "ace_uvm_env.svh"
  `include "ace_uvm_sequences.svh"
  `include "ace_uvm_tests.svh"
endpackage
