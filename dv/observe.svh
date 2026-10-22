// Passive observations on BOTH actual CLCI ACE boundaries.
assign src_valid[0] = die0.ace_slv2_awvalid;
assign src_ready[0] = die0.ace_slv2_awready;
assign src_payload[0] = {die0.ace_slv2_awid, die0.ace_slv2_awaddr, die0.ace_slv2_awlen, die0.ace_slv2_awsize, die0.ace_slv2_awburst, die0.ace_slv2_awregion, die0.ace_slv2_awlock, die0.ace_slv2_awcache, die0.ace_slv2_awprot, die0.ace_slv2_awqos, die0.ace_slv2_awsnoop, die0.ace_slv2_awdomain, die0.ace_slv2_awbar, die0.ace_slv2_awunique};
assign dst_valid[0] = die1.ace_mst2_awvalid;
assign dst_ready[0] = die1.ace_mst2_awready;
assign dst_payload[0] = {die1.ace_mst2_awid, die1.ace_mst2_awaddr, die1.ace_mst2_awlen, die1.ace_mst2_awsize, die1.ace_mst2_awburst, die1.ace_mst2_awregion, die1.ace_mst2_awlock, die1.ace_mst2_awcache, die1.ace_mst2_awprot, die1.ace_mst2_awqos, die1.ace_mst2_awsnoop, die1.ace_mst2_awdomain, die1.ace_mst2_awbar, die1.ace_mst2_awunique};
assign src_valid[1] = die0.ace_slv2_wvalid;
assign src_ready[1] = die0.ace_slv2_wready;
assign src_payload[1] = {die0.ace_slv2_wdata, die0.ace_slv2_wstrb, die0.ace_slv2_wlast};
assign dst_valid[1] = die1.ace_mst2_wvalid;
assign dst_ready[1] = die1.ace_mst2_wready;
assign dst_payload[1] = {die1.ace_mst2_wdata, die1.ace_mst2_wstrb, die1.ace_mst2_wlast};
assign src_valid[2] = die1.ace_mst2_bvalid;
assign src_ready[2] = die1.ace_mst2_bready;
assign src_payload[2] = {die1.ace_mst2_bid, die1.ace_mst2_bresp};
assign dst_valid[2] = die0.ace_slv2_bvalid;
assign dst_ready[2] = die0.ace_slv2_bready;
assign dst_payload[2] = {die0.ace_slv2_bid, die0.ace_slv2_bresp};
assign src_valid[3] = die0.ace_slv2_arvalid;
assign src_ready[3] = die0.ace_slv2_arready;
assign src_payload[3] = {die0.ace_slv2_arid, die0.ace_slv2_araddr, die0.ace_slv2_arlen, die0.ace_slv2_arsize, die0.ace_slv2_arburst, die0.ace_slv2_arregion, die0.ace_slv2_arlock, die0.ace_slv2_arcache, die0.ace_slv2_arprot, die0.ace_slv2_arqos, die0.ace_slv2_arsnoop, die0.ace_slv2_ardomain, die0.ace_slv2_arbar};
assign dst_valid[3] = die1.ace_mst2_arvalid;
assign dst_ready[3] = die1.ace_mst2_arready;
assign dst_payload[3] = {die1.ace_mst2_arid, die1.ace_mst2_araddr, die1.ace_mst2_arlen, die1.ace_mst2_arsize, die1.ace_mst2_arburst, die1.ace_mst2_arregion, die1.ace_mst2_arlock, die1.ace_mst2_arcache, die1.ace_mst2_arprot, die1.ace_mst2_arqos, die1.ace_mst2_arsnoop, die1.ace_mst2_ardomain, die1.ace_mst2_arbar};
assign src_valid[4] = die1.ace_mst2_rvalid;
assign src_ready[4] = die1.ace_mst2_rready;
assign src_payload[4] = {die1.ace_mst2_rid, die1.ace_mst2_rdata, die1.ace_mst2_rresp, die1.ace_mst2_rlast};
assign dst_valid[4] = die0.ace_slv2_rvalid;
assign dst_ready[4] = die0.ace_slv2_rready;
assign dst_payload[4] = {die0.ace_slv2_rid, die0.ace_slv2_rdata, die0.ace_slv2_rresp, die0.ace_slv2_rlast};
assign src_valid[5] = die1.ace_mst2_acvalid;
assign src_ready[5] = die1.ace_mst2_acready;
assign src_payload[5] = {die1.ace_mst2_acvid, die1.ace_mst2_acaddr, die1.ace_mst2_acsnoop, die1.ace_mst2_acprot};
assign dst_valid[5] = die0.ace_slv2_acvalid;
assign dst_ready[5] = die0.ace_slv2_acready;
assign dst_payload[5] = {die0.ace_slv2_acvid, die0.ace_slv2_acaddr, die0.ace_slv2_acsnoop, die0.ace_slv2_acprot};
assign src_valid[6] = die0.ace_slv2_crvalid;
assign src_ready[6] = die0.ace_slv2_crready;
assign src_payload[6] = {die0.ace_slv2_crresp};
assign dst_valid[6] = die1.ace_mst2_crvalid;
assign dst_ready[6] = die1.ace_mst2_crready;
assign dst_payload[6] = {die1.ace_mst2_crresp};
assign src_valid[7] = die0.ace_slv2_cdvalid;
assign src_ready[7] = die0.ace_slv2_cdready;
assign src_payload[7] = {die0.ace_slv2_cddata, die0.ace_slv2_cdlast};
assign dst_valid[7] = die1.ace_mst2_cdvalid;
assign dst_ready[7] = die1.ace_mst2_cdready;
assign dst_payload[7] = {die1.ace_mst2_cddata, die1.ace_mst2_cdlast};
assign src_valid[8] = die0.ace_slv2_rack;
assign src_ready[8] = 1'b1;
assign src_payload[8] = {die0.ace_slv2_rack};
assign dst_valid[8] = die1.ace_mst2_rack;
assign dst_ready[8] = 1'b1;
assign dst_payload[8] = {die1.ace_mst2_rack};
assign src_valid[9] = die0.ace_slv2_wack;
assign src_ready[9] = 1'b1;
assign src_payload[9] = {die0.ace_slv2_wack};
assign dst_valid[9] = die1.ace_mst2_wack;
assign dst_ready[9] = 1'b1;
assign dst_payload[9] = {die1.ace_mst2_wack};

// Preserve pre-NBA handshakes; inspect committed cache storage separately.
always @(posedge ace_clk) begin : monitor_boundaries
  dv_sample captured;
  if(checking && !done) begin
    if(!link_ready()) fail_test("LINK_LOST");
    if({u_master.o_any_err,u_slave.o_any_err} !== 2'b00)
      fail_test($sformatf("ACE error: A=%b B=%b Astatus=%b%b%b%b Bstatus=%b%b%b%b%b",
        u_master.o_any_err,u_slave.o_any_err,u_master.err_rd_data,u_master.err_rsp,
        u_master.err_main_timeout,u_master.err_snoop_timeout,u_slave.err_wr_data,
        u_slave.err_cd_data,u_slave.err_cr_mismatch,u_slave.err_snoop_timeout,u_slave.err_slave_timeout));
    captured=new();
    captured.svld=src_valid;captured.srdy=src_ready;
    captured.dvld=dst_valid;captured.drdy=dst_ready;
    for(int ch=0;ch<10;ch++) begin captured.sp[ch]=src_payload[ch];captured.dp[ch]=dst_payload[ch];end
    for(int n=0;n<4;n++) begin
      captured.before_cache[n].valid=u_master.c_valid[n];captured.before_cache[n].tag=u_master.c_tag[n];
      captured.before_cache[n].state=u_master.c_state[n];captured.before_cache[n].data=u_master.c_data[n];
    end
    #1ps;
    for(int n=0;n<4;n++) begin
      captured.after_cache[n].valid=u_master.c_valid[n];captured.after_cache[n].tag=u_master.c_tag[n];
      captured.after_cache[n].state=u_master.c_state[n];captured.after_cache[n].data=u_master.c_data[n];
    end
    checks.sample(captured);
  end
end
