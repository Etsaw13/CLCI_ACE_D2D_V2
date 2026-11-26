`timescale 1ns/1ps
`default_nettype none
import ace_pkg::*;
// Deterministic regression for cache/snoop ordering and miss handling.
// State is established through public APB/ACE/order interfaces. Internal
// cache/directory arrays are read only for the final architectural check.
module tb_a_ac_order;
  initial begin #20000; $fatal(1,"A_AC_ORDER watchdog"); end
  logic aclk;
  logic areset_n;
  logic awvalid;
  logic awready;
  logic [ID_W-1:0] awid;
  logic [ADDR_W-1:0] awaddr;
  logic [LEN_W-1:0] awlen;
  logic [2:0] awsize;
  logic [1:0] awburst;
  logic [3:0] awregion;
  logic awlock;
  logic [3:0] awcache;
  logic [2:0] awprot;
  logic [3:0] awqos;
  logic [2:0] awsnoop;
  logic [1:0] awdomain;
  logic [1:0] awbar;
  logic awunique;
  logic wvalid;
  logic wready;
  logic [DATA_W-1:0] wdata;
  logic [STRB_W-1:0] wstrb;
  logic wlast;
  logic bvalid;
  logic bready;
  logic [ID_W-1:0] bid;
  logic [1:0] bresp;
  logic arvalid;
  logic arready;
  logic [ID_W-1:0] arid;
  logic [ADDR_W-1:0] araddr;
  logic [LEN_W-1:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;
  logic [3:0] arregion;
  logic arlock;
  logic [3:0] arcache;
  logic [2:0] arprot;
  logic [3:0] arqos;
  logic [3:0] arsnoop;
  logic [1:0] ardomain;
  logic [1:0] arbar;
  logic rvalid;
  logic rready;
  logic [ID_W-1:0] rid;
  logic [DATA_W-1:0] rdata;
  logic [RRESP_W-1:0] rresp;
  logic rlast;
  logic acvalid;
  logic acready;
  logic [ACVID_W-1:0] acvid;
  logic [ADDR_W-1:0] acaddr;
  logic [3:0] acsnoop;
  logic [2:0] acprot;
  logic crvalid;
  logic crready;
  logic [CRRESP_W-1:0] crresp;
  logic cdvalid;
  logic cdready;
  logic [DATA_W-1:0] cddata;
  logic cdlast;
  logic rack;
  logic wack;
  logic pclk;
  logic presetn;
  logic psel;
  logic penable;
  logic pwrite;
  logic [11:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic pready;
  logic pslverr;
  logic ord_valid;
  logic ord_ready;
  logic ord_write;
  logic [3:0] ord_arsnoop;
  logic [2:0] ord_awsnoop;
  logic ord_awunique;
  logic [ADDR_W-1:0] ord_addr;
  logic cfg_ord_ext;
  module_a dut(.*);
  always #5 begin aclk=~aclk; pclk=~pclk; end
  task automatic apb_write(input logic [11:0] address,input logic [31:0] data);
    @(negedge aclk); psel=1; penable=0; pwrite=1; paddr=address; pwdata=data;
    @(negedge aclk); penable=1;
    @(posedge aclk); #1; if(pready!==1'b1 || pslverr!==1'b0) $fatal(1,"APB write failed");
    @(negedge aclk); psel=0; penable=0; pwrite=0; paddr='0; pwdata='0;
  endtask
  initial begin
    areset_n = '0;
    awready = '0;
    wready = '0;
    bvalid = '0;
    bid = '0;
    bresp = '0;
    arready = '0;
    rvalid = '0;
    rid = '0;
    rdata = '0;
    rresp = '0;
    rlast = '0;
    acvalid = '0;
    acvid = '0;
    acaddr = '0;
    acsnoop = '0;
    acprot = '0;
    crready = '0;
    cdready = '0;
    presetn = '0;
    psel = '0;
    penable = '0;
    pwrite = '0;
    paddr = '0;
    pwdata = '0;
    ord_valid = '0;
    ord_write = '0;
    ord_arsnoop = '0;
    ord_awsnoop = '0;
    ord_awunique = '0;
    ord_addr = '0;
    cfg_ord_ext = '0;
    aclk=0; pclk=0;
    repeat(3) @(posedge aclk); areset_n=1; presetn=1;
    cfg_ord_ext=1; crready=1; awready=0;
    apb_write(12'h000,32'h1);
    @(negedge aclk); ord_valid=1; ord_write=1;
    ord_awsnoop=AWSNOOP_WRITE_UNIQUE; ord_addr=44'h0000_0000_100;
    wait(ord_ready); @(posedge aclk); @(negedge aclk); ord_valid=0;
    acvalid=1; acaddr=44'h0000_0000_040; acsnoop=ARSNOOP_READ_SHARED;
    #1;
    if(acready!==1'b1)
      $fatal(1,"CACHE_SNOOP_REGRESSION_FAIL A blocked an earlier AC while AW waited for READY");
    $display("CACHE_SNOOP_SUBTEST_PASS A_AC_ORDER"); $finish;
  end
endmodule

module tb_a_snoop_miss;
  initial begin #20000; $fatal(1,"A cache and response watchdog"); end
  logic aclk;
  logic areset_n;
  logic awvalid;
  logic awready;
  logic [ID_W-1:0] awid;
  logic [ADDR_W-1:0] awaddr;
  logic [LEN_W-1:0] awlen;
  logic [2:0] awsize;
  logic [1:0] awburst;
  logic [3:0] awregion;
  logic awlock;
  logic [3:0] awcache;
  logic [2:0] awprot;
  logic [3:0] awqos;
  logic [2:0] awsnoop;
  logic [1:0] awdomain;
  logic [1:0] awbar;
  logic awunique;
  logic wvalid;
  logic wready;
  logic [DATA_W-1:0] wdata;
  logic [STRB_W-1:0] wstrb;
  logic wlast;
  logic bvalid;
  logic bready;
  logic [ID_W-1:0] bid;
  logic [1:0] bresp;
  logic arvalid;
  logic arready;
  logic [ID_W-1:0] arid;
  logic [ADDR_W-1:0] araddr;
  logic [LEN_W-1:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;
  logic [3:0] arregion;
  logic arlock;
  logic [3:0] arcache;
  logic [2:0] arprot;
  logic [3:0] arqos;
  logic [3:0] arsnoop;
  logic [1:0] ardomain;
  logic [1:0] arbar;
  logic rvalid;
  logic rready;
  logic [ID_W-1:0] rid;
  logic [DATA_W-1:0] rdata;
  logic [RRESP_W-1:0] rresp;
  logic rlast;
  logic acvalid;
  logic acready;
  logic [ACVID_W-1:0] acvid;
  logic [ADDR_W-1:0] acaddr;
  logic [3:0] acsnoop;
  logic [2:0] acprot;
  logic crvalid;
  logic crready;
  logic [CRRESP_W-1:0] crresp;
  logic cdvalid;
  logic cdready;
  logic [DATA_W-1:0] cddata;
  logic cdlast;
  logic rack;
  logic wack;
  logic pclk;
  logic presetn;
  logic psel;
  logic penable;
  logic pwrite;
  logic [11:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic pready;
  logic pslverr;
  logic ord_valid;
  logic ord_ready;
  logic ord_write;
  logic [3:0] ord_arsnoop;
  logic [2:0] ord_awsnoop;
  logic ord_awunique;
  logic [ADDR_W-1:0] ord_addr;
  logic cfg_ord_ext;
  module_a dut(.*);
  always #5 begin aclk=~aclk; pclk=~pclk; end
  task automatic apb_write(input logic [11:0] address,input logic [31:0] data);
    @(negedge aclk); psel=1; penable=0; pwrite=1; paddr=address; pwdata=data;
    @(negedge aclk); penable=1;
    @(posedge aclk); #1; if(pready!==1'b1 || pslverr!==1'b0) $fatal(1,"APB write failed");
    @(negedge aclk); psel=0; penable=0; pwrite=0; paddr='0; pwdata='0;
  endtask
  initial begin
    areset_n = '0;
    awready = '0;
    wready = '0;
    bvalid = '0;
    bid = '0;
    bresp = '0;
    arready = '0;
    rvalid = '0;
    rid = '0;
    rdata = '0;
    rresp = '0;
    rlast = '0;
    acvalid = '0;
    acvid = '0;
    acaddr = '0;
    acsnoop = '0;
    acprot = '0;
    crready = '0;
    cdready = '0;
    presetn = '0;
    psel = '0;
    penable = '0;
    pwrite = '0;
    paddr = '0;
    pwdata = '0;
    ord_valid = '0;
    ord_write = '0;
    ord_arsnoop = '0;
    ord_awsnoop = '0;
    ord_awunique = '0;
    ord_addr = '0;
    cfg_ord_ext = '0;
    aclk=0; pclk=0;
    repeat(3) @(posedge aclk); areset_n=1; presetn=1;
    cfg_ord_ext=1; crready=1;
    apb_write(12'h000,32'h1);
    // Establish slot0/tag0/UC through a real external WLU transaction.
    @(negedge aclk); ord_valid=1; ord_write=1;
    ord_awsnoop=AWSNOOP_WRITE_LINE_UNIQUE; ord_addr=44'h0;
    wait(ord_ready); @(posedge aclk); @(negedge aclk); ord_valid=0;
    wait(awvalid); awready=1; @(posedge aclk); @(negedge aclk); awready=0;
    wait(wvalid); wready=1; @(posedge aclk); @(negedge aclk); wready=0;
    wait(bready); bid=awid; bresp=2'b00; bvalid=1;
    @(posedge aclk); @(negedge aclk); bvalid=0;
    repeat(2) @(posedge aclk); #1;
    if(dut.c_valid[0]!==1'b1 || dut.c_tag[0]!=={TAG_W{1'b0}} || dut.c_state[0]!==ST_UC)
      $fatal(1,"CACHE_SNOOP_REGRESSION_SETUP_FAIL WLU did not establish slot0/tag0/UC");
    // Address 0x40 is tag4 but maps to the same direct-mapped slot0.
    @(negedge aclk); acvalid=1; acaddr=44'h0000_0000_040; acsnoop=ARSNOOP_READ_SHARED;
    wait(acready); @(posedge aclk); @(negedge aclk); acvalid=0;
    wait(crvalid);
    if(crresp!==5'd0) $fatal(1,"CACHE_SNOOP_REGRESSION_FAIL snoop miss returned nonzero CR");
    @(posedge aclk); repeat(2) @(posedge aclk); #1;
    if(dut.c_valid[0]!==1'b1 || dut.c_tag[0]!=={TAG_W{1'b0}} || dut.c_state[0]!==ST_UC)
      $fatal(1,"CACHE_SNOOP_REGRESSION_FAIL snoop miss overwrote slot0/tag0/UC");
    check_adjacent_snoops();
    check_other_tag_wu();
    check_bad_bid();
    check_stalled_aw();
    check_burst_responses();
    $display("CACHE_SNOOP_SUBTEST_PASS A_SNOOP_MISS"); $finish;
  end

  task automatic reset_a();
    @(negedge aclk);
    areset_n=0; presetn=0; psel=0; penable=0; pwrite=0;
    awready=0; wready=0; bvalid=0; arready=0; rvalid=0;
    acvalid=0; crready=0; cdready=0; ord_valid=0; cfg_ord_ext=1;
    repeat(3) @(negedge aclk);
    areset_n=1; presetn=1;
  endtask

  task automatic expect_a_status(input logic [31:0] expected);
    @(negedge aclk); psel=1; pwrite=0; penable=0; paddr=12'h010;
    @(negedge aclk); penable=1;
    @(posedge aclk); #1ps;
    if (pready!==1'b1 || pslverr!==1'b0 || prdata!==expected)
      $fatal(1,"A STATUS expected=%08h actual=%08h",expected,prdata);
    @(negedge aclk); psel=0; penable=0;
  endtask

  task automatic issue_write(input logic [ADDR_W-1:0] address);
    @(negedge aclk); ord_valid=1; ord_write=1;
    ord_addr=address; ord_awsnoop=AWSNOOP_WRITE_UNIQUE; ord_awunique=1;
    do @(posedge aclk); while (ord_ready!==1'b1);
    @(negedge aclk); ord_valid=0; awready=1;
    do @(posedge aclk); while (awvalid!==1'b1);
    if (awaddr!==address || awsnoop!==AWSNOOP_WRITE_UNIQUE)
      $fatal(1,"A issued unexpected write");
    @(negedge aclk); awready=0; wready=1;
    do @(posedge aclk); while (wvalid!==1'b1);
    if (wlast!==1'b1) $fatal(1,"A expected one write beat");
    @(negedge aclk); wready=0;
  endtask

  task automatic send_b(input logic [ID_W-1:0] response_id,input bit expect_wack);
    @(negedge aclk); bid=response_id; bresp=0; bvalid=1;
    do @(posedge aclk); while (bready!==1'b1);
    @(negedge aclk); bvalid=0;
    if (wack!==expect_wack) $fatal(1,"A WACK disagrees with BID validity");
  endtask

  task automatic accept_ar(input logic [ADDR_W-1:0] address,input logic [LEN_W-1:0] len);
    @(negedge aclk); arready=1;
    do @(posedge aclk); while (arvalid!==1'b1);
    if (araddr!==address || arlen!==len)
      $fatal(1,"A AR expected addr=%h len=%0d, got %h len=%0d",address,len,araddr,arlen);
    @(negedge aclk); arready=0;
  endtask

  task automatic send_r(input logic [DATA_W-1:0] data,input bit last,
                        input logic [RRESP_W-1:0] response);
    rvalid=1; rid=arid; rdata=data; rlast=last; rresp=response;
    do @(posedge aclk); while (rready!==1'b1);
    @(negedge aclk); rvalid=0;
  endtask

  task automatic expect_cr(input logic [CRRESP_W-1:0] expected);
    do @(posedge aclk); while (acready!==1'b1);
    @(negedge aclk); acvalid=0;
    if (crvalid!==1'b1 || crresp!==expected)
      $fatal(1,"A CR expected=%0d actual=%0d",expected,crresp);
  endtask

  task automatic check_adjacent_snoops();
    // The preceding miss test left line 0 in UC.
    @(negedge aclk); crready=0; acvalid=1; acaddr=0; acsnoop=ARSNOOP_READ_SHARED;
    expect_cr(5'd24);
    crready=1;
    @(posedge aclk); @(negedge aclk); crready=0;
    acvalid=1; acsnoop=ARSNOOP_READ_ONCE;
    #1ps;
    expect_cr(5'd8);
    $display("CACHE_SNOOP_CASE_PASS A_ADJACENT_SNOOPS");
  endtask

  task automatic check_other_tag_wu();
    reset_a();
    apb_write(12'h004,32'h00000200);
    apb_write(12'h000,1);
    @(negedge aclk); ord_valid=1; ord_write=0; ord_addr=0;
    ord_arsnoop=ARSNOOP_READ_UNIQUE;
    do @(posedge aclk); while (ord_ready!==1'b1);
    @(negedge aclk); ord_valid=0;
    accept_ar(0,0);
    send_r('0,1,4'b0100);
    if (rack!==1'b1) $fatal(1,"A did not acknowledge setup ReadUnique");
    issue_write(44'h40);
    send_b(awid,1);
    @(negedge aclk); acvalid=1; acaddr=0; acsnoop=ARSNOOP_CLEAN_INVALID;
    expect_cr(5'd21);
    crready=1;
    @(posedge aclk); @(negedge aclk); crready=0;
    if (cdvalid!==1'b1 || cdlast!==1'b1 || cddata!=='0)
      $fatal(1,"A lost the dirty line after WU to another tag");
    cdready=1;
    expect_a_status(0);
    $display("CACHE_SNOOP_CASE_PASS A_WU_OTHER_TAG");
  endtask

  task automatic check_bad_bid();
    reset_a();
    apb_write(12'h000,1);
    issue_write(0);
    send_b(awid+1'b1,0);
    expect_a_status(32'h22);
    if (ord_ready!==1'b0) $fatal(1,"A retired the write after a wrong BID");
    send_b(awid,1);
    $display("CACHE_SNOOP_CASE_PASS A_BAD_BID");
  endtask

  task automatic check_stalled_aw();
    reset_a();
    apb_write(12'h000,1);
    @(negedge aclk); ord_valid=1; ord_write=1; ord_addr=0;
    do @(posedge aclk); while (ord_ready!==1'b1);
    @(negedge aclk); ord_valid=0;
    repeat(260) @(negedge aclk);
    expect_a_status(32'h28);
    apb_write(12'h000,2);
    apb_write(12'h000,1);
    expect_a_status(32'h28);
    if (awvalid!==1'b1 || ord_ready!==1'b0)
      $fatal(1,"A discarded the stalled address after APB clear");
    $display("CACHE_SNOOP_CASE_PASS A_STALLED_AW");
  endtask

  task automatic check_burst_responses();
    reset_a();
    cfg_ord_ext=0;
    apb_write(12'h004,32'h04000100);
    apb_write(12'h020,3);
    apb_write(12'h000,1);
    accept_ar(44'h20000000,3);
    send_r('0,1,0);
    if (rack!==1'b0) $fatal(1,"A acknowledged a truncated burst");
    expect_a_status(32'h22);
    $display("CACHE_SNOOP_CASE_PASS A_EARLY_RLAST");

    reset_a();
    cfg_ord_ext=0;
    apb_write(12'h004,32'h04000100);
    apb_write(12'h020,255);
    apb_write(12'h000,1);
    accept_ar(44'h20000000,255);
    for (int beat=0; beat<256; beat++) send_r('0,beat==255,0);
    if (rack!==1'b1) $fatal(1,"A did not acknowledge the aligned burst");
    expect_a_status(32'h22);
    if (arvalid!==1'b0) $fatal(1,"A launched the second 256-beat burst across 4 KB");
    $display("CACHE_SNOOP_CASE_PASS A_CROSS_4K_BLOCKED");
  endtask
endmodule

module tb_b_home_order;
  initial begin #30000; $fatal(1,"B Home and response watchdog"); end
  logic aclk;
  logic areset_n;
  logic awvalid;
  logic awready;
  logic [ID_W-1:0] awid;
  logic [ADDR_W-1:0] awaddr;
  logic [LEN_W-1:0] awlen;
  logic [2:0] awsize;
  logic [1:0] awburst;
  logic [3:0] awregion;
  logic awlock;
  logic [3:0] awcache;
  logic [2:0] awprot;
  logic [3:0] awqos;
  logic [2:0] awsnoop;
  logic [1:0] awdomain;
  logic [1:0] awbar;
  logic awunique;
  logic wvalid;
  logic wready;
  logic [DATA_W-1:0] wdata;
  logic [STRB_W-1:0] wstrb;
  logic wlast;
  logic bvalid;
  logic bready;
  logic [ID_W-1:0] bid;
  logic [1:0] bresp;
  logic arvalid;
  logic arready;
  logic [ID_W-1:0] arid;
  logic [ADDR_W-1:0] araddr;
  logic [LEN_W-1:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;
  logic [3:0] arregion;
  logic arlock;
  logic [3:0] arcache;
  logic [2:0] arprot;
  logic [3:0] arqos;
  logic [3:0] arsnoop;
  logic [1:0] ardomain;
  logic [1:0] arbar;
  logic rvalid;
  logic rready;
  logic [ID_W-1:0] rid;
  logic [DATA_W-1:0] rdata;
  logic [RRESP_W-1:0] rresp;
  logic rlast;
  logic acvalid;
  logic acready;
  logic [ACVID_W-1:0] acvid;
  logic [ADDR_W-1:0] acaddr;
  logic [3:0] acsnoop;
  logic [2:0] acprot;
  logic crvalid;
  logic crready;
  logic [CRRESP_W-1:0] crresp;
  logic cdvalid;
  logic cdready;
  logic [DATA_W-1:0] cddata;
  logic cdlast;
  logic rack;
  logic wack;
  logic pclk;
  logic presetn;
  logic psel;
  logic penable;
  logic pwrite;
  logic [11:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic pready;
  logic pslverr;
  module_b dut(.*);
  always #5 begin aclk=~aclk; pclk=~pclk; end
  task automatic apb_write(input logic [11:0] address,input logic [31:0] data);
    @(negedge aclk); psel=1; penable=0; pwrite=1; paddr=address; pwdata=data;
    @(negedge aclk); penable=1;
    @(posedge aclk); #1; if(pready!==1'b1 || pslverr!==1'b0) $fatal(1,"APB write failed");
    @(negedge aclk); psel=0; penable=0; pwrite=0; paddr='0; pwdata='0;
  endtask
  initial begin
    areset_n = '0;
    awvalid = '0;
    awid = '0;
    awaddr = '0;
    awlen = '0;
    awsize = '0;
    awburst = '0;
    awregion = '0;
    awlock = '0;
    awcache = '0;
    awprot = '0;
    awqos = '0;
    awsnoop = '0;
    awdomain = '0;
    awbar = '0;
    awunique = '0;
    wvalid = '0;
    wdata = '0;
    wstrb = '0;
    wlast = '0;
    bready = '0;
    arvalid = '0;
    arid = '0;
    araddr = '0;
    arlen = '0;
    arsize = '0;
    arburst = '0;
    arregion = '0;
    arlock = '0;
    arcache = '0;
    arprot = '0;
    arqos = '0;
    arsnoop = '0;
    ardomain = '0;
    arbar = '0;
    rready = '0;
    acready = '0;
    crvalid = '0;
    crresp = '0;
    cdvalid = '0;
    cddata = '0;
    cdlast = '0;
    rack = '0;
    wack = '0;
    presetn = '0;
    psel = '0;
    penable = '0;
    pwrite = '0;
    paddr = '0;
    pwdata = '0;
    aclk=0; pclk=0;
    repeat(3) @(posedge aclk); areset_n=1; presetn=1;
    bready=1;
    apb_write(12'h004,32'h00000100);
    // Establish directory slot0/tag0/UC through real AW/W/B/WACK handshakes.
    @(negedge aclk); awvalid=1; awaddr=44'h0; awlen=0;
    awsnoop=AWSNOOP_WRITE_LINE_UNIQUE; awid='h1;
    wait(awready); @(posedge aclk); @(negedge aclk); awvalid=0;
    // Fixed-byte mode configured above makes the initial payload all zero.
    wvalid=1; wdata='0; wstrb={STRB_W{1'b1}}; wlast=1;
    wait(wready); @(posedge aclk); @(negedge aclk); wvalid=0; wlast=0;
    wait(bvalid); @(posedge aclk); @(negedge aclk);
    wack=1; @(posedge aclk); @(negedge aclk); wack=0;
    #1;
    if(dut.dir_valid[0]!==1'b1 || dut.dir_tag[0]!=={TAG_W{1'b0}} || dut.dir_state[0]!==ST_UC)
      $fatal(1,"CACHE_SNOOP_REGRESSION_SETUP_FAIL WLU/WACK did not establish directory UC");
    apb_write(12'h008,32'h0); // zero Home gap
    apb_write(12'h000,32'h1); // enable Home; acready remains zero
    wait(acvalid); @(posedge aclk); @(negedge aclk);
    awvalid=1; awaddr=44'h0; awlen=0; awsnoop=AWSNOOP_WRITE_UNIQUE;
    #1;
    if(awready!==1'b0 || arready!==1'b0)
      $fatal(1,"CACHE_SNOOP_REGRESSION_FAIL B accepted AW/AR while earlier AC was pending");
    repeat(260) begin
      @(negedge aclk);
      if (acvalid!==1'b1 || acaddr!==0 || acsnoop!==ARSNOOP_READ_SHARED ||
          acvid!==0 || awready!==0 || arready!==0)
        $fatal(1,"B withdrew or changed the stalled AC");
    end
    expect_b_reg(12'h010,32'h28);
    $display("CACHE_SNOOP_CASE_PASS B_AC_TIMEOUT_HOLDS_VALID");
    acready=1; @(posedge aclk); @(negedge aclk); #1;
    if(awready!==1'b0) $fatal(1,"CACHE_SNOOP_REGRESSION_FAIL B reopened AW before CR");
    repeat(260) begin
      @(negedge aclk);
      if (crready!==1'b1 || acvalid!==0 || awready!==0 || arready!==0)
        $fatal(1,"B lost the old snoop while waiting for late CR");
    end
    expect_b_reg(12'h01c,0);
    crresp=5'd24; crvalid=1; @(posedge aclk); @(negedge aclk); crvalid=0; #1;
    if(awready!==1'b0) $fatal(1,"CACHE_SNOOP_REGRESSION_FAIL B reopened AW before directory commit");
    @(posedge aclk); #1;
    if(awready!==1'b1) $fatal(1,"CACHE_SNOOP_REGRESSION_FAIL B did not reopen AW after snoop commit");
    if (dut.dir_state[0]!==ST_SC)
      $fatal(1,"B did not apply the late CR to the original line");
    $display("CACHE_SNOOP_CASE_PASS B_LATE_CR_ORIGINAL_REQUEST");
    check_ack_timeout();
    check_mask_and_arbitration();
    check_cd_timeout();
    $display("CACHE_SNOOP_SUBTEST_PASS B_HOME_ORDER"); $finish;
  end

  task automatic reset_b();
    @(negedge aclk);
    areset_n=0; presetn=0; psel=0; penable=0; pwrite=0;
    awvalid=0; wvalid=0; arvalid=0; acready=0; crvalid=0; cdvalid=0;
    rack=0; wack=0; bready=1; rready=1;
    repeat(3) @(negedge aclk);
    areset_n=1; presetn=1;
    apb_write(12'h004,32'h005a0100);
  endtask

  task automatic expect_b_reg(input logic [11:0] address,input logic [31:0] expected);
    @(negedge aclk); psel=1; pwrite=0; penable=0; paddr=address;
    @(negedge aclk); penable=1;
    @(posedge aclk); #1ps;
    if (pready!==1'b1 || pslverr!==1'b0 || prdata!==expected)
      $fatal(1,"B APB readback addr=%h expected=%08h actual=%08h",address,expected,prdata);
    @(negedge aclk); psel=0; penable=0;
  endtask

  task automatic write_b(input logic [ADDR_W-1:0] address,input logic [2:0] kind,
                         input logic [DATA_W-1:0] data,input logic [STRB_W-1:0] mask);
    awvalid=1; awaddr=address; awsnoop=kind; awid=1;
    awlen=0; awsize=4; awburst=1; awcache=15; awdomain=1; awunique=1;
    do @(posedge aclk); while (awready!==1'b1);
    if (arvalid && arready) $fatal(1,"B accepted AW and AR on the same edge");
    @(negedge aclk); awvalid=0; wvalid=1; wlast=1; wdata=data; wstrb=mask;
    do @(posedge aclk); while (wready!==1'b1);
    $display("B WRITE t=%0t addr=%h mode=%0d xcode=%02h data=%h expected=%h strb=%h last=%b beat=%0d len=%0d",
             $time,address,dut.cfg_data_mode,dut.cfg_xcode,wdata,dut.w_exp,wstrb,
             wlast,dut.beat_cnt,dut.aw_len_l);
    @(negedge aclk); wvalid=0;
    do @(posedge aclk); while (bvalid!==1'b1);
    if (bid!==16'd1 || bresp!==0) $fatal(1,"Unexpected write response");
    @(negedge aclk);
  endtask

  task automatic ack_write();
    wack=1; @(posedge aclk); @(negedge aclk); wack=0;
  endtask

  task automatic set_ar(input logic [ADDR_W-1:0] address,input logic [3:0] kind);
    arvalid=1; araddr=address; arsnoop=kind; arid=2;
    arlen=0; arsize=4; arburst=1; arcache=15; ardomain=1;
  endtask

  task automatic finish_read_b(input logic [DATA_W-1:0] expected,input bit pass_dirty);
    do @(posedge aclk); while (arready!==1'b1);
    @(negedge aclk); arvalid=0;
    do @(posedge aclk); while (rvalid!==1'b1);
    if (rid!==16'd2 || rlast!==1'b1 || rdata!==expected ||
        rresp!=={1'b0,pass_dirty,2'b00})
      $fatal(1,"B did not complete the pending read with the expected data");
    @(negedge aclk); rack=1;
    @(posedge aclk); @(negedge aclk); rack=0;
  endtask

  task automatic check_ack_timeout();
    reset_b();
    expect_b_reg(12'h004,32'h005a0100);
    write_b(0,AWSNOOP_WRITE_LINE_UNIQUE,{16{8'h5a}},'1); ack_write();
    expect_b_reg(12'h010,0);
    write_b(16,AWSNOOP_WRITE_LINE_UNIQUE,{16{8'h5a}},'1);
    expect_b_reg(12'h010,0);
    apb_write(12'h000,1);
    repeat(260) begin
      @(negedge aclk);
      if (awready!==0 || arready!==0 || acvalid!==0)
        $fatal(1,"B started new work while WACK was missing");
    end
    expect_b_reg(12'h010,32'h30);
    ack_write();
    #1ps;
    if (acvalid!==1'b1 || acaddr!==0) $fatal(1,"B did not resume after late WACK");
    $display("CACHE_SNOOP_CASE_PASS B_MISSING_WACK");
  endtask

  task automatic check_mask_and_arbitration();
    reset_b();
    write_b(0,AWSNOOP_WRITE_UNIQUE,{16{8'h5a}},'1); ack_write();
    apb_write(12'h004,32'h00a50100);
    set_ar(0,ARSNOOP_READ_ONCE);
    write_b(0,AWSNOOP_WRITE_UNIQUE,{16{8'ha5}},'0);
    if (arready!==0) $fatal(1,"B let AR overwrite a write awaiting WACK");
    ack_write();
    finish_read_b({16{8'h5a}},0);
    $display("CACHE_SNOOP_CASE_PASS B_AW_AR_ARBITRATION_AND_ZERO_STRB");

    write_b(0,AWSNOOP_WRITE_UNIQUE,128'ha5,16'h0001); ack_write();
    set_ar(0,ARSNOOP_READ_ONCE);
    finish_read_b({{15{8'h5a}},8'ha5},0);
    expect_b_reg(12'h010,0);
    $display("CACHE_SNOOP_CASE_PASS B_PARTIAL_STRB");
  endtask

  task automatic check_cd_timeout();
    reset_b();
    set_ar(0,ARSNOOP_READ_UNIQUE);
    finish_read_b({16{8'h5a}},1);
    apb_write(12'h000,1);
    acready=1;
    do @(posedge aclk); while (acvalid!==1'b1);
    if (acsnoop!==ARSNOOP_CLEAN_INVALID || acaddr!==0)
      $fatal(1,"B did not snoop the dirty line");
    @(negedge aclk); acready=0; crvalid=1; crresp=5'd21;
    do @(posedge aclk); while (crready!==1'b1);
    @(negedge aclk); crvalid=0;
    repeat(260) begin
      @(negedge aclk);
      if (cdready!==1'b1 || acvalid!==0 || awready!==0 || arready!==0)
        $fatal(1,"B stopped waiting for CD or started new work");
    end
    expect_b_reg(12'h010,32'h28);
    cdvalid=1; cdlast=1; cddata={16{8'h5a}};
    @(posedge aclk); @(negedge aclk); cdvalid=0;
    @(negedge aclk);
    if (dut.dir_valid[0]!==0 || dut.mem_written[0]!==1'b1 ||
        dut.mem_tag[0]!==0 || dut.mem[0]!=={16{8'h5a}} ||
        {arready,awready}===2'b00)
      $fatal(1,"B did not drain CD into the original line before reopening the request interface");
    $display("CACHE_SNOOP_CASE_PASS B_LATE_CD");
  endtask
endmodule

`default_nettype wire
