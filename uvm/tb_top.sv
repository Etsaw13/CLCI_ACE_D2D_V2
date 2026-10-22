`timescale 1ns/1ps
`default_nettype none
module tb_ace_clci_2die_smoke;
  import uvm_pkg::*;
  import ace_pkg::*;
  import ace_uvm_pkg::*;
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



  ace_uvm_if vif(ace_clk);

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
    .psel(vif.apb_psel[0]), .penable(vif.apb_penable[0]), .pwrite(vif.apb_pwrite[0]),
    .paddr(vif.apb_paddr[0]), .pwdata(vif.apb_pwdata[0]), .prdata(vif.apb_prdata[0]),
    .pready(vif.apb_pready[0]), .pslverr(vif.apb_pslverr[0]),
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
    .psel(vif.apb_psel[1]), .penable(vif.apb_penable[1]), .pwrite(vif.apb_pwrite[1]),
    .paddr(vif.apb_paddr[1]), .pwdata(vif.apb_pwdata[1]), .prdata(vif.apb_prdata[1]),
    .pready(vif.apb_pready[1]), .pslverr(vif.apb_pslverr[1])
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
  initial begin
    uvm_config_db#(virtual ace_uvm_if)::set(null,"uvm_test_top*","vif",vif);
    run_test(); // UVM starts at time zero. Link waiting belongs to run_phase.
  end
endmodule
`default_nettype wire
