`timescale 1ns/1ps
`default_nettype none
module tb_ace_clci_2die_smoke;
  import ace_pkg::*;
  import ace_dv_model_pkg::*;
  import ace_dv_checker_pkg::*;
  import ace_dv_runtime_cov_pkg::*;
  M2_clci_ucie_s die0();
  M2_clci_ucie_s die1();
reg pclk;
reg presetn;
reg top_pll_800mhz;
reg soc_i_pclk;
reg soc_i_presetn;
reg reset_n;
reg ref_clk;

reg axi_5_clk;
reg axi_5_rst_n;
reg ace_clk;
reg ace_rst_n;

reg mcu_trst_n;



  logic [1:0] apb_psel,apb_penable,apb_pwrite;
  logic [11:0] apb_paddr[2];
  logic [31:0] apb_pwdata[2];
  wire [31:0] apb_prdata[2];
  wire [1:0] apb_pready,apb_pslverr;
  wire [9:0] src_valid,src_ready,dst_valid,dst_ready;
  wire [255:0] src_payload[10],dst_payload[10];
  dv_checker checks;
  bit checking=0,done=0,reports_saved=0,main_enabled=0,home_enabled=0;
  string test_name="smoke",direction="write",stage="boot",report_dir=".";
  string code_backend="off";
  int data_mode=0,burst_beats=4,tx_target=64,direction_number=0;
  int link_timeout_us=1000,run_timeout_us=500,global_timeout_us=3000;
  int drain_timeout_cycles=50000,progress_us=10,snoop_gap=10;
  int prbs_code=165,xcode=90;
  logic [63:0] base_argument=64'h20000000;
  logic [31:0] status_a,status_b,value;
  realtime traffic_start;

module_a u_master (
    .aclk(ace_clk), .areset_n(ace_rst_n),
    .awvalid(die0.ace_slv2_awvalid), .awready(die0.ace_slv2_awready),
    .awid(die0.ace_slv2_awid), .awaddr(die0.ace_slv2_awaddr),
    .awlen(die0.ace_slv2_awlen), .awsize(die0.ace_slv2_awsize),
    .awburst(die0.ace_slv2_awburst), .awregion(die0.ace_slv2_awregion),
    .awlock(die0.ace_slv2_awlock), .awcache(die0.ace_slv2_awcache),
    .awprot(die0.ace_slv2_awprot), .awqos(die0.ace_slv2_awqos),
    .awsnoop(die0.ace_slv2_awsnoop), .awdomain(die0.ace_slv2_awdomain),
    .awbar(die0.ace_slv2_awbar), .awunique(die0.ace_slv2_awunique),
    .wvalid(die0.ace_slv2_wvalid), .wready(die0.ace_slv2_wready),
    .wdata(die0.ace_slv2_wdata), .wstrb(die0.ace_slv2_wstrb),
    .wlast(die0.ace_slv2_wlast),
    .bvalid(die0.ace_slv2_bvalid), .bready(die0.ace_slv2_bready),
    .bid(die0.ace_slv2_bid), .bresp(die0.ace_slv2_bresp),
    .arvalid(die0.ace_slv2_arvalid), .arready(die0.ace_slv2_arready),
    .arid(die0.ace_slv2_arid), .araddr(die0.ace_slv2_araddr),
    .arlen(die0.ace_slv2_arlen), .arsize(die0.ace_slv2_arsize),
    .arburst(die0.ace_slv2_arburst), .arregion(die0.ace_slv2_arregion),
    .arlock(die0.ace_slv2_arlock), .arcache(die0.ace_slv2_arcache),
    .arprot(die0.ace_slv2_arprot), .arqos(die0.ace_slv2_arqos),
    .arsnoop(die0.ace_slv2_arsnoop), .ardomain(die0.ace_slv2_ardomain),
    .arbar(die0.ace_slv2_arbar),
    .rvalid(die0.ace_slv2_rvalid), .rready(die0.ace_slv2_rready),
    .rid(die0.ace_slv2_rid), .rdata(die0.ace_slv2_rdata),
    .rresp(die0.ace_slv2_rresp), .rlast(die0.ace_slv2_rlast),
    .acvalid(die0.ace_slv2_acvalid), .acready(die0.ace_slv2_acready), .acvid(die0.ace_slv2_acvid),
    .acaddr(die0.ace_slv2_acaddr), .acsnoop(die0.ace_slv2_acsnoop), .acprot(die0.ace_slv2_acprot),
    .crvalid(die0.ace_slv2_crvalid), .crready(die0.ace_slv2_crready), .crresp(die0.ace_slv2_crresp),
    .cdvalid(die0.ace_slv2_cdvalid), .cdready(die0.ace_slv2_cdready),
    .cddata(die0.ace_slv2_cddata), .cdlast(die0.ace_slv2_cdlast),
    .rack(die0.ace_slv2_rack), .wack(die0.ace_slv2_wack),
    .pclk(ace_clk), .presetn(ace_rst_n),
    .psel(apb_psel[0]), .penable(apb_penable[0]), .pwrite(apb_pwrite[0]),
    .paddr(apb_paddr[0]), .pwdata(apb_pwdata[0]), .prdata(apb_prdata[0]),
    .pready(apb_pready[0]), .pslverr(apb_pslverr[0]),
    .ord_valid(1'b0), .ord_ready(),
    .ord_write(1'b0), .ord_arsnoop(4'b0), .ord_awsnoop(3'b0),
    .ord_awunique(1'b0), .ord_addr({ADDR_W{1'b0}}), .cfg_ord_ext(1'b0)
);

module_b u_slave (
    .aclk(ace_clk), .areset_n(ace_rst_n),
    .awvalid(die1.ace_mst2_awvalid), .awready(die1.ace_mst2_awready),
    .awid(die1.ace_mst2_awid), .awaddr(die1.ace_mst2_awaddr),
    .awlen(die1.ace_mst2_awlen), .awsize(die1.ace_mst2_awsize),
    .awburst(die1.ace_mst2_awburst), .awregion(die1.ace_mst2_awregion),
    .awlock(die1.ace_mst2_awlock), .awcache(die1.ace_mst2_awcache),
    .awprot(die1.ace_mst2_awprot), .awqos(die1.ace_mst2_awqos),
    .awsnoop(die1.ace_mst2_awsnoop), .awdomain(die1.ace_mst2_awdomain),
    .awbar(die1.ace_mst2_awbar), .awunique(die1.ace_mst2_awunique),
    .wvalid(die1.ace_mst2_wvalid), .wready(die1.ace_mst2_wready),
    .wdata(die1.ace_mst2_wdata), .wstrb(die1.ace_mst2_wstrb),
    .wlast(die1.ace_mst2_wlast),
    .bvalid(die1.ace_mst2_bvalid), .bready(die1.ace_mst2_bready),
    .bid(die1.ace_mst2_bid), .bresp(die1.ace_mst2_bresp),
    .arvalid(die1.ace_mst2_arvalid), .arready(die1.ace_mst2_arready),
    .arid(die1.ace_mst2_arid), .araddr(die1.ace_mst2_araddr),
    .arlen(die1.ace_mst2_arlen), .arsize(die1.ace_mst2_arsize),
    .arburst(die1.ace_mst2_arburst), .arregion(die1.ace_mst2_arregion),
    .arlock(die1.ace_mst2_arlock), .arcache(die1.ace_mst2_arcache),
    .arprot(die1.ace_mst2_arprot), .arqos(die1.ace_mst2_arqos),
    .arsnoop(die1.ace_mst2_arsnoop), .ardomain(die1.ace_mst2_ardomain),
    .arbar(die1.ace_mst2_arbar),
    .rvalid(die1.ace_mst2_rvalid), .rready(die1.ace_mst2_rready),
    .rid(die1.ace_mst2_rid), .rdata(die1.ace_mst2_rdata),
    .rresp(die1.ace_mst2_rresp), .rlast(die1.ace_mst2_rlast),
    .acvalid(die1.ace_mst2_acvalid), .acready(die1.ace_mst2_acready), .acvid(die1.ace_mst2_acvid),
    .acaddr(die1.ace_mst2_acaddr), .acsnoop(die1.ace_mst2_acsnoop), .acprot(die1.ace_mst2_acprot),
    .crvalid(die1.ace_mst2_crvalid), .crready(die1.ace_mst2_crready), .crresp(die1.ace_mst2_crresp),
    .cdvalid(die1.ace_mst2_cdvalid), .cdready(die1.ace_mst2_cdready),
    .cddata(die1.ace_mst2_cddata), .cdlast(die1.ace_mst2_cdlast),
    .rack(die1.ace_mst2_rack), .wack(die1.ace_mst2_wack),
    .pclk(ace_clk), .presetn(ace_rst_n),
    .psel(apb_psel[1]), .penable(apb_penable[1]), .pwrite(apb_pwrite[1]),
    .paddr(apb_paddr[1]), .pwdata(apb_pwdata[1]), .prdata(apb_prdata[1]),
    .pready(apb_pready[1]), .pslverr(apb_pslverr[1])
);

initial begin
    pclk = 1'b0;
    top_pll_800mhz = 1'b0;
    soc_i_pclk = 1'b0;
    ref_clk = 1'b0;
    axi_5_clk = 1'b0;
    ace_clk  = 1'b0;

    presetn = 1'b0;
    soc_i_presetn = 1'b0;
    reset_n = 1'b0;
    axi_5_rst_n = 1'b0;
    ace_rst_n = 1'b0;

    mcu_trst_n = 1'b0;

    #50ns;
    mcu_trst_n = 1'b1;
    
    #100ns;

    presetn = 1'b1;
    soc_i_presetn = 1'b1;
    reset_n = 1'b1;
    axi_5_rst_n = 1'b1;
    ace_rst_n = 1'b1;

end

always begin #2.5ns pclk = ~pclk; end                   // 200MHz
always begin #2.5ns soc_i_pclk = ~soc_i_pclk; end       // 200MHz
always begin #20ns ref_clk = ~ref_clk; end              // 25MHz
always begin #0.5ns axi_5_clk = ~axi_5_clk; end          // 1GHz
always begin #0.5ns ace_clk = ~ace_clk; end            // 1GHz ACE/APB clock


assign die0.pclk = pclk;         
assign die0.presetn = presetn;
assign die0.top_pll_800mhz = 'b0; 
assign die0.clci_mode_sel = 'b0;  
assign die0.boot_sel = 'b0;       
assign die0.strapping_mode = 4'b0001; // software sideband, ref_clk, mainband auto-link 
assign die0.gpio_in_sideband = 'b0;     
assign die0.chiplet_id = 'b0;
assign die0.i2c_id_vld = 'b0;     
assign die0.i2c_id = 'b0;         
assign die0.mcu_wdt_sim_speed = 'b0;
assign die0.mcu_id = 'b0;               
assign die0.mcu_jtag_id = 'b0;          
assign die0.mcu_tck = 'b0;
assign die0.mcu_tms = 'b0;
assign die0.mcu_tdi = 'b0;
assign die0.mcu_trst_n = mcu_trst_n;
assign die0.mcu_uart_rx0 = 1'b1;
assign die0.mcu_uart_rx1 = 1'b1;
assign die0.mcu_scl_in = 'b1;
assign die0.mcu_sda_in = 'b1;
assign die0.soc_i_pclk = soc_i_pclk;
assign die0.soc_i_presetn = soc_i_presetn;
assign die0.soc_i_psel = 'b0;
assign die0.soc_i_penable = 'b0;
assign die0.soc_i_pwrite = 'b0;
assign die0.soc_i_paddr = 'b0;
assign die0.soc_i_pwdata = 'b0;
assign die0.ace_2_rst_n = ace_rst_n;
assign die0.ace_2_clk = ace_clk;
assign die0.ace_mst2_bvalid = 'b0;
assign die0.ace_mst2_bid = 'b0;
assign die0.ace_mst2_bresp = 'b0;
assign die0.ace_mst2_acvalid = 'b0;
assign die0.ace_mst2_acvid = 'b0;
assign die0.ace_mst2_acaddr = 'b0;
assign die0.ace_mst2_acsnoop = 'b0;
assign die0.ace_mst2_acprot = 'b0;
assign die0.ace_mst2_rvalid = 'b0;
assign die0.ace_mst2_rid = 'b0;
assign die0.ace_mst2_rdata = 'b0;
assign die0.ace_mst2_rresp = 'b0;
assign die0.ace_mst2_rlast = 'b0;
assign die0.ace_mst2_awready = 1'b1;
assign die0.ace_mst2_arready = 1'b1;
assign die0.ace_mst2_crready = 1'b1;
assign die0.ace_mst2_wready = 1'b1;
assign die0.ace_mst2_cdready = 1'b1;
assign die0.sideband_dat = 'b0;
assign die0.reset_n = reset_n;  
assign die0.test_mode = 'b0;
assign die0.scan_en = 'b0;
assign die0.scan_clk_20 = 'b0;
assign die0.scan_clk_20_tx = 'b0;
assign die0.scan_clk_20_rx = 'b0;
assign die0.scan_clk_80 = 'b0;
assign die0.ref_clk = ref_clk;
assign die0.syn_pll_in = 'b0;
assign die0.vmon_clci_phy_avdd_st_0     = 'b1;
assign die0.vmon_clci_phy_avdd_st_ck_0  = 'b1;
assign die0.vmon_clci_phy_avss_st_0     = 'b0;
assign die0.vmon_clci_phy_avss_st_ck_0  = 'b0;
assign die0.vmon_clci_phy_avdd_st_1     = 'b1;
assign die0.vmon_clci_phy_avdd_st_ck_1  = 'b1;
assign die0.vmon_clci_phy_avss_st_1     = 'b0;
assign die0.vmon_clci_phy_avss_st_ck_1  = 'b0;
assign die0.EXT_CLK_P = 'b0;
assign die0.EXT_CLK_N = 'b0;


assign die1.pclk = pclk;         
assign die1.presetn = presetn;
assign die1.top_pll_800mhz = 'b0; 
assign die1.clci_mode_sel = 'b0;  
assign die1.boot_sel = 'b0;       
assign die1.strapping_mode = 4'b0001; // software sideband, ref_clk, mainband auto-link 
assign die1.gpio_in_sideband = 'b0;     
assign die1.chiplet_id = 'b0;
assign die1.i2c_id_vld = 'b0;     
assign die1.i2c_id = 'b0;         
assign die1.mcu_wdt_sim_speed = 'b0;
assign die1.mcu_id = 'b0;               
assign die1.mcu_jtag_id = 'b0;          
assign die1.mcu_tck = 'b0;
assign die1.mcu_tms = 'b0;
assign die1.mcu_tdi = 'b0;
assign die1.mcu_trst_n = mcu_trst_n;
assign die1.mcu_uart_rx0 = 1'b1;
assign die1.mcu_uart_rx1 = 1'b1;
assign die1.mcu_scl_in = 'b1;
assign die1.mcu_sda_in = 'b1;
assign die1.soc_i_pclk = soc_i_pclk;
assign die1.soc_i_presetn = soc_i_presetn;
assign die1.soc_i_psel = 'b0;
assign die1.soc_i_penable = 'b0;
assign die1.soc_i_pwrite = 'b0;
assign die1.soc_i_paddr = 'b0;
assign die1.soc_i_pwdata = 'b0;
assign die1.ace_2_rst_n = ace_rst_n;
assign die1.ace_2_clk = ace_clk;
assign die1.ace_slv2_awvalid = 'b0;
assign die1.ace_slv2_awid = 'b0;
assign die1.ace_slv2_awaddr = 'b0;
assign die1.ace_slv2_awlen = 'b0;
assign die1.ace_slv2_awsize = 'b0;
assign die1.ace_slv2_awburst = 'b0;
assign die1.ace_slv2_awregion = 'b0;
assign die1.ace_slv2_awlock = 'b0;
assign die1.ace_slv2_awcache = 'b0;
assign die1.ace_slv2_awprot = 'b0;
assign die1.ace_slv2_awqos = 'b0;
assign die1.ace_slv2_awsnoop = 'b0;
assign die1.ace_slv2_awdomain = 'b0;
assign die1.ace_slv2_awbar = 'b0;
assign die1.ace_slv2_awunique = 'b0;
assign die1.ace_slv2_arvalid = 'b0;
assign die1.ace_slv2_arid = 'b0;
assign die1.ace_slv2_araddr = 'b0;
assign die1.ace_slv2_arlen = 'b0;
assign die1.ace_slv2_arsize = 'b0;
assign die1.ace_slv2_arburst = 'b0;
assign die1.ace_slv2_arregion = 'b0;
assign die1.ace_slv2_arlock = 'b0;
assign die1.ace_slv2_arcache = 'b0;
assign die1.ace_slv2_arprot = 'b0;
assign die1.ace_slv2_arqos = 'b0;
assign die1.ace_slv2_arsnoop = 'b0;
assign die1.ace_slv2_ardomain = 'b0;
assign die1.ace_slv2_arbar = 'b0;
assign die1.ace_slv2_crvalid = 'b0;
assign die1.ace_slv2_crresp = 'b0;
assign die1.ace_slv2_wvalid = 'b0;
assign die1.ace_slv2_wdata = 'b0;
assign die1.ace_slv2_wstrb = 'b0;
assign die1.ace_slv2_wlast = 'b0;
assign die1.ace_slv2_cdvalid = 'b0;
assign die1.ace_slv2_cddata = 'b0;
assign die1.ace_slv2_cdlast = 'b0;
assign die1.ace_slv2_wack = 'b0;
assign die1.ace_slv2_rack = 'b0;
assign die1.ace_slv2_bready = 'b0;
assign die1.ace_slv2_acready = 'b0;
assign die1.ace_slv2_rready = 'b0;
assign die1.sideband_dat = 'b0;
assign die1.reset_n = reset_n;  
assign die1.test_mode = 'b0;
assign die1.scan_en = 'b0;
assign die1.scan_clk_20 = 'b0;
assign die1.scan_clk_20_tx = 'b0;
assign die1.scan_clk_20_rx = 'b0;
assign die1.scan_clk_80 = 'b0;
assign die1.ref_clk = ref_clk;
assign die1.syn_pll_in = 'b0;
assign die1.vmon_clci_phy_avdd_st_0     = 'b1;
assign die1.vmon_clci_phy_avdd_st_ck_0  = 'b1;
assign die1.vmon_clci_phy_avss_st_0     = 'b0;
assign die1.vmon_clci_phy_avss_st_ck_0  = 'b0;
assign die1.vmon_clci_phy_avdd_st_1     = 'b1;
assign die1.vmon_clci_phy_avdd_st_ck_1  = 'b1;
assign die1.vmon_clci_phy_avss_st_1     = 'b0;
assign die1.vmon_clci_phy_avss_st_ck_1  = 'b0;
assign die1.EXT_CLK_P = 'b0;
assign die1.EXT_CLK_N = 'b0;


assign die0.RXCKSB      = die1.TXCKSB  ;
assign die0.RXDATASB    = die1.TXDATASB;
assign die0.RX_D        = die1.TX_D    ;
assign die0.RX_VLD      = die1.TX_VLD  ;
assign die0.RX_TRK      = die1.TX_TRK  ;
assign die0.RX_CLK_P    = die1.TX_CLK_P;
assign die0.RX_CLK_N    = die1.TX_CLK_N;

assign die1.RXCKSB      = die0.TXCKSB  ;
assign die1.RXDATASB    = die0.TXDATASB;
assign die1.RX_D        = die0.TX_D    ;
assign die1.RX_VLD      = die0.TX_VLD  ;
assign die1.RX_TRK      = die0.TX_TRK  ;
assign die1.RX_CLK_P    = die0.TX_CLK_P;
assign die1.RX_CLK_N    = die0.TX_CLK_N;


  `include "observe.svh"

  function automatic bit link_ready();
    return ace_rst_n===1'b1 &&
      die0.u_st_s_reg_inst0.rx_link_status===2'b11 &&
      die1.u_st_s_reg_inst0.rx_link_status===2'b11 &&
      die0.u_st_s_reg_inst0.pcs_rx_cmd_rx_link_ok===1'b1 &&
      die1.u_st_s_reg_inst0.pcs_rx_cmd_rx_link_ok===1'b1 &&
      die0.u_st_s_reg_inst0.pcs_mac_tx_ready_enable===1'b1 &&
      die1.u_st_s_reg_inst0.pcs_mac_tx_ready_enable===1'b1;
  endfunction
  function automatic bit quiet();
    return link_ready() && src_valid===10'b0 && dst_valid===10'b0 && checks.empty() &&
      u_master.st==u_master.M_IDLE && u_master.sn==u_master.S_IDLE &&
      u_slave.st==u_slave.B_IDLE && (u_slave.hs==u_slave.H_IDLE || u_slave.hs==u_slave.H_GAP) &&
      u_slave.aw_pend===1'b0 && u_slave.ar_pend===1'b0 && u_slave.scan_hit===1'b0;
  endfunction
  task automatic fail_test(input string reason);
    $display("DV_FAIL t=%0t stage=%s: %s",$time,stage,reason);
    $display("DV_FAIL_STATE A=%0d sn=%0d B=%0d home=%0d source(v/r)=%b/%b destination(v/r)=%b/%b requests=%0d",
      u_master.st,u_master.sn,u_slave.st,u_slave.hs,src_valid,src_ready,dst_valid,dst_ready,checks.requests);
    $fatal(1,"DV_FAIL: %s",reason);
  endtask
  task automatic transfer(input int side,input bit write_access,input logic [11:0] address,
      input logic [31:0] write_data,output logic [31:0] read_data,input bit expect_error=0);
    int waited;
    @(negedge ace_clk);
    apb_psel[side]=1;apb_penable[side]=0;apb_pwrite[side]=write_access;
    apb_paddr[side]=address;apb_pwdata[side]=write_data;
    @(negedge ace_clk);apb_penable[side]=1;
    waited=0;
    do begin
      @(posedge ace_clk);#1ps;waited++;
      if(waited>16) fail_test("APB response timeout");
      if($isunknown(apb_pready[side])) fail_test("Unknown APB PREADY");
    end while(!apb_pready[side]);
    read_data=apb_prdata[side];
    if(apb_pslverr[side]!==expect_error)
      fail_test($sformatf("APB PSLVERR side=%0d addr=%h expected=%b actual=%b",side,address,expect_error,apb_pslverr[side]));
    if($test$plusargs("APB_TRACE"))
      $display("APB side=%0d write=%b addr=%03h wdata=%08h rdata=%08h error=%b",side,write_access,address,write_data,read_data,apb_pslverr[side]);
    @(negedge ace_clk);
    apb_psel[side]=0;apb_penable[side]=0;apb_pwrite[side]=0;
  endtask
  task automatic write_reg(input int side,input logic [11:0] address,input logic [31:0] data);
    logic [31:0] ignored;
    transfer(side,1,address,data,ignored);
  endtask
  task automatic read_expect(input int side,input logic [11:0] address,input logic [31:0] expected);
    logic [31:0] actual;
    transfer(side,0,address,0,actual);
    if(actual!==expected) fail_test($sformatf("APB readback side=%0d addr=%h expected=%h actual=%h",side,address,expected,actual));
  endtask
  task automatic set_enable(input int side,input bit enable_value);
    write_reg(side,12'h000,{31'b0,enable_value});
    if(side==0) main_enabled=enable_value;else home_enabled=enable_value;
  endtask
  task automatic configure_agents(input int scenario);
    logic [31:0] a_data,b_data;
    a_data={4'b0,4'(scenario),8'(xcode),5'b0,3'(data_mode),8'(prbs_code)};
    b_data={8'b0,8'(xcode),5'b0,3'(data_mode),8'(prbs_code)};
    write_reg(0,12'h004,a_data);read_expect(0,12'h004,a_data);
    write_reg(0,12'h008,base_argument[31:0]);read_expect(0,12'h008,base_argument[31:0]);
    write_reg(0,12'h00c,{20'b0,base_argument[43:32]});read_expect(0,12'h00c,{20'b0,base_argument[43:32]});
    write_reg(0,12'h020,32'(burst_beats-1));read_expect(0,12'h020,32'(burst_beats-1));
    write_reg(1,12'h004,b_data);read_expect(1,12'h004,b_data);
    write_reg(1,12'h008,32'(snoop_gap));read_expect(1,12'h008,32'(snoop_gap));
    checks.mode=3'(data_mode);checks.code=8'(prbs_code);checks.fixed_byte=8'(xcode);
    checks.generator.base=base_argument[43:0];checks.generator.burst_len=8'(burst_beats-1);
    checks.generator.test_type=scenario;
  endtask
  task automatic apb_case();
    logic [31:0] ignored;
    stage="APB reset/readback";
    read_expect(0,12'h000,0);read_expect(1,12'h000,0);
    read_expect(0,12'h004,32'h005a00a5);read_expect(1,12'h004,32'h005a00a5);
    read_expect(0,12'h008,32'h20000000);read_expect(0,12'h00c,0);
    read_expect(0,12'h020,3);read_expect(1,12'h008,10);
    read_expect(0,12'h010,0);read_expect(1,12'h010,0);
    write_reg(0,12'h004,32'h045a05a7);read_expect(0,12'h004,32'h045a05a7);
    write_reg(1,12'h004,32'h00a60337);read_expect(1,12'h004,32'h00a60337);
    write_reg(0,12'h008,32'h12345670);read_expect(0,12'h008,32'h12345670);
    write_reg(0,12'h00c,32'hffffffff);read_expect(0,12'h00c,32'h00000fff);
    write_reg(0,12'h020,255);read_expect(0,12'h020,255);
    write_reg(1,12'h008,32'h000003ff);read_expect(1,12'h008,32'h000003ff);
    write_reg(0,12'h014,32'hdeadbeef);read_expect(0,12'h014,0);
    write_reg(1,12'h014,32'hdeadbeef);read_expect(1,12'h014,0);
    transfer(0,0,12'hffc,0,ignored,1);transfer(1,1,12'hffc,32'hffffffff,ignored,1);
    read_expect(1,12'h004,32'h00a60337);
    write_reg(0,12'h000,2);read_expect(0,12'h000,0);
    write_reg(1,12'h000,3);read_expect(1,12'h000,1);set_enable(1,0);
    if(checks.requests!=0 || !quiet()) fail_test("APB-only case unexpectedly generated ACE traffic");
    $display("APB_CHECK_PASS reset/config/RO/undefined-address/clear-pulse");
  endtask
  task automatic drain();
    int stable;
    stable=0;stage="drain";
    for(int n=0;n<drain_timeout_cycles;n++) begin
      @(negedge ace_clk);
      if(quiet() && u_master.o_cnt_tx===32'(checks.requests) &&
         u_slave.o_cnt_wr===32'(checks.writes) && u_slave.o_cnt_rd===32'(checks.reads)) stable++;
      else stable=0;
      if(stable==16) return;
    end
    fail_test("DRAIN_TIMEOUT: queues/ACKs/Home directory did not close");
  endtask
  task automatic check_apb_results();
    transfer(0,0,12'h010,0,status_a);transfer(1,0,12'h010,0,status_b);
    if(status_a!==0 || status_b!==0) fail_test("Nonzero APB error status");
    read_expect(0,12'h014,32'(checks.requests));read_expect(0,12'h018,32'(checks.ns[AC]));
    read_expect(1,12'h014,32'(checks.writes));read_expect(1,12'h018,32'(checks.reads));
    read_expect(1,12'h01c,32'(checks.ns[AC]));
  endtask
  function automatic void save_reports(input bit complete);
    int fd;
    runtime_cov_count_t master_count,slave_count;
    if(reports_saved || checks==null) return;reports_saved=1;
    checks.save_coverage({report_dir,"/functional_coverage.txt"},complete);
    if(code_backend=="runtime") begin
      fd=$fopen({report_dir,"/runtime_code_coverage.txt"},"w");
      if(fd==0) $fatal(1,"Cannot create runtime code coverage report");
      $fdisplay(fd,"ACE_V2_RUNTIME version=1 completion=%s",complete?"FINAL":"PARTIAL");
      $fdisplay(fd,"SCOPE master=tb_ace_clci_2die_smoke.u_master slave=tb_ace_clci_2die_smoke.u_slave");
      for(int m=0;m<RUNTIME_METRICS;m++) begin
        master_count=runtime_sample(m,"tb_ace_clci_2die_smoke.u_master");
        slave_count=runtime_sample(m,"tb_ace_clci_2die_smoke.u_slave");
        $fdisplay(fd,"%s",runtime_row("master",m,master_count));
        $fdisplay(fd,"%s",runtime_row("slave",m,slave_count));
        $fdisplay(fd,"%s",runtime_pair_row(m,master_count,slave_count));
      end
      $fclose(fd);
    end
  endfunction
  initial begin : run_case
    int stable,scenario;
    realtime deadline;
    checks=new();
    apb_psel=0;apb_penable=0;apb_pwrite=0;
    foreach(apb_paddr[i]) begin apb_paddr[i]=0;apb_pwdata[i]=0;end
    void'($value$plusargs("TEST=%s",test_name));void'($value$plusargs("DATA_MODE=%d",data_mode));
    void'($value$plusargs("BURST_BEATS=%d",burst_beats));void'($value$plusargs("TX_TARGET=%d",tx_target));
    void'($value$plusargs("DIRECTION=%s",direction));void'($value$plusargs("REPORT_DIR=%s",report_dir));
    void'($value$plusargs("CODE_COV=%s",code_backend));void'($value$plusargs("BASE_ADDR=%h",base_argument));
    void'($value$plusargs("PRBS_CODE=%d",prbs_code));void'($value$plusargs("XCODE=%d",xcode));
    void'($value$plusargs("SNOOP_GAP=%d",snoop_gap));void'($value$plusargs("LINK_TIMEOUT_US=%d",link_timeout_us));
    void'($value$plusargs("RUN_TIMEOUT_US=%d",run_timeout_us));void'($value$plusargs("GLOBAL_TIMEOUT_US=%d",global_timeout_us));
    void'($value$plusargs("DRAIN_TIMEOUT_CYC=%d",drain_timeout_cycles));void'($value$plusargs("PROGRESS_US=%d",progress_us));
    if(!(test_name inside {"apb","smoke","burst_boundary"}) || data_mode<0 || data_mode>5 ||
       burst_beats<2 || burst_beats>256 || tx_target<1 || tx_target>100000 ||
       !(direction inside {"write","read"}) || base_argument[63:44]!=0 || base_argument[3:0]!=0 ||
       prbs_code<0 || prbs_code>255 || xcode<0 || xcode>255 || snoop_gap<0 || snoop_gap>255 ||
       link_timeout_us<1 || run_timeout_us<1 || global_timeout_us<1 ||
       drain_timeout_cycles<16 || progress_us<0 || progress_us>1000)
      fail_test("Invalid simulation parameters");
    if(test_name=="burst_boundary" && tx_target!=1) fail_test("Boundary case uses TX_TARGET=1; run separate direction/length cases");
    direction_number=(direction=="read");
    if(test_name=="burst_boundary" && int'(base_argument[11:0])+burst_beats*16>4096)
      fail_test("Boundary case start address/length crosses 4KB");
    deadline=$realtime+link_timeout_us*1us;stable=0;
    while(stable<8) begin
      @(negedge ace_clk);
      if(link_ready()) stable++;else stable=0;
      if($realtime>=deadline) fail_test("LINK_TIMEOUT");
    end
    $display("DV_LINK_READY t=%0t complete links stable for eight ACE cycles",$time);
    checking=1;
    if(test_name=="apb") begin apb_case();tx_target=0;end
    else begin
      scenario=(test_name=="smoke")?0:((direction_number==0)?3:4);
      stage="APB configuration";configure_agents(scenario);
      set_enable(1,1);set_enable(0,1); // Both run concurrently for the entire traffic phase.
      stage="parallel traffic";traffic_start=$realtime;deadline=$realtime+run_timeout_us*1us;
      while(checks.requests<tx_target) begin
        @(negedge ace_clk);if($realtime>=deadline) fail_test("RUN_TIMEOUT");
      end
      $display("DV_STOP requested_minimum=%0d issued=%0d t=%0t",tx_target,checks.requests,$time);
      set_enable(0,0); // Accepted work may still issue; the model continues until closure.
      $display("DV_STOP_APPLIED issued=%0d t=%0t",checks.requests,$time);
      drain();set_enable(1,0);
    end
    stage="final observation";
    repeat(32) begin @(negedge ace_clk);if(!quiet()) fail_test("Activity after final drain");end
    checks.close(tx_target,test_name,direction_number);check_apb_results();
    done=1;stage="complete";save_reports(1);
    $display("DV_SUMMARY test=%s mode=%0d burst=%0d target_min=%0d completed=%0d writes=%0d reads=%0d CD=%0d",
      test_name,data_mode,burst_beats,tx_target,checks.requests,checks.writes,checks.reads,checks.ns[CD]);
    $display("ACE_V2_DV_PASS");$finish;
  end
  initial begin : global_guard
    #1ps;
    #(global_timeout_us*1us);
    if(!done) fail_test("GLOBAL_TIMEOUT");
  end
  initial begin : heartbeat
    #2ps;
    if(progress_us>0) forever begin
      #(progress_us*1us);
      if(!done) $display("DV_PROGRESS t=%0.3f us stage=%s ready=%b A/Home=%b/%b requests=%0d completed=%0d",
        $realtime/1us,stage,link_ready(),main_enabled,home_enabled,checks.requests,u_master.o_cnt_tx);
    end
  end
  final begin
    if(!reports_saved && checks!=null) save_reports(0);
  end
endmodule
`default_nettype wire
