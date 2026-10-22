// Passive observations on BOTH actual CLCI ACE boundaries.
assign vif.src_valid[0] = die0.ace_slv2_awvalid;
assign vif.src_ready[0] = die0.ace_slv2_awready;
assign vif.src_payload[0] = {die0.ace_slv2_awid, die0.ace_slv2_awaddr, die0.ace_slv2_awlen, die0.ace_slv2_awsize, die0.ace_slv2_awburst, die0.ace_slv2_awregion, die0.ace_slv2_awlock, die0.ace_slv2_awcache, die0.ace_slv2_awprot, die0.ace_slv2_awqos, die0.ace_slv2_awsnoop, die0.ace_slv2_awdomain, die0.ace_slv2_awbar, die0.ace_slv2_awunique};
assign vif.dst_valid[0] = die1.ace_mst2_awvalid;
assign vif.dst_ready[0] = die1.ace_mst2_awready;
assign vif.dst_payload[0] = {die1.ace_mst2_awid, die1.ace_mst2_awaddr, die1.ace_mst2_awlen, die1.ace_mst2_awsize, die1.ace_mst2_awburst, die1.ace_mst2_awregion, die1.ace_mst2_awlock, die1.ace_mst2_awcache, die1.ace_mst2_awprot, die1.ace_mst2_awqos, die1.ace_mst2_awsnoop, die1.ace_mst2_awdomain, die1.ace_mst2_awbar, die1.ace_mst2_awunique};
assign vif.src_valid[1] = die0.ace_slv2_wvalid;
assign vif.src_ready[1] = die0.ace_slv2_wready;
assign vif.src_payload[1] = {die0.ace_slv2_wdata, die0.ace_slv2_wstrb, die0.ace_slv2_wlast};
assign vif.dst_valid[1] = die1.ace_mst2_wvalid;
assign vif.dst_ready[1] = die1.ace_mst2_wready;
assign vif.dst_payload[1] = {die1.ace_mst2_wdata, die1.ace_mst2_wstrb, die1.ace_mst2_wlast};
assign vif.src_valid[2] = die1.ace_mst2_bvalid;
assign vif.src_ready[2] = die1.ace_mst2_bready;
assign vif.src_payload[2] = {die1.ace_mst2_bid, die1.ace_mst2_bresp};
assign vif.dst_valid[2] = die0.ace_slv2_bvalid;
assign vif.dst_ready[2] = die0.ace_slv2_bready;
assign vif.dst_payload[2] = {die0.ace_slv2_bid, die0.ace_slv2_bresp};
assign vif.src_valid[3] = die0.ace_slv2_arvalid;
assign vif.src_ready[3] = die0.ace_slv2_arready;
assign vif.src_payload[3] = {die0.ace_slv2_arid, die0.ace_slv2_araddr, die0.ace_slv2_arlen, die0.ace_slv2_arsize, die0.ace_slv2_arburst, die0.ace_slv2_arregion, die0.ace_slv2_arlock, die0.ace_slv2_arcache, die0.ace_slv2_arprot, die0.ace_slv2_arqos, die0.ace_slv2_arsnoop, die0.ace_slv2_ardomain, die0.ace_slv2_arbar};
assign vif.dst_valid[3] = die1.ace_mst2_arvalid;
assign vif.dst_ready[3] = die1.ace_mst2_arready;
assign vif.dst_payload[3] = {die1.ace_mst2_arid, die1.ace_mst2_araddr, die1.ace_mst2_arlen, die1.ace_mst2_arsize, die1.ace_mst2_arburst, die1.ace_mst2_arregion, die1.ace_mst2_arlock, die1.ace_mst2_arcache, die1.ace_mst2_arprot, die1.ace_mst2_arqos, die1.ace_mst2_arsnoop, die1.ace_mst2_ardomain, die1.ace_mst2_arbar};
assign vif.src_valid[4] = die1.ace_mst2_rvalid;
assign vif.src_ready[4] = die1.ace_mst2_rready;
assign vif.src_payload[4] = {die1.ace_mst2_rid, die1.ace_mst2_rdata, die1.ace_mst2_rresp, die1.ace_mst2_rlast};
assign vif.dst_valid[4] = die0.ace_slv2_rvalid;
assign vif.dst_ready[4] = die0.ace_slv2_rready;
assign vif.dst_payload[4] = {die0.ace_slv2_rid, die0.ace_slv2_rdata, die0.ace_slv2_rresp, die0.ace_slv2_rlast};
assign vif.src_valid[5] = die1.ace_mst2_acvalid;
assign vif.src_ready[5] = die1.ace_mst2_acready;
assign vif.src_payload[5] = {die1.ace_mst2_acvid, die1.ace_mst2_acaddr, die1.ace_mst2_acsnoop, die1.ace_mst2_acprot};
assign vif.dst_valid[5] = die0.ace_slv2_acvalid;
assign vif.dst_ready[5] = die0.ace_slv2_acready;
assign vif.dst_payload[5] = {die0.ace_slv2_acvid, die0.ace_slv2_acaddr, die0.ace_slv2_acsnoop, die0.ace_slv2_acprot};
assign vif.src_valid[6] = die0.ace_slv2_crvalid;
assign vif.src_ready[6] = die0.ace_slv2_crready;
assign vif.src_payload[6] = {die0.ace_slv2_crresp};
assign vif.dst_valid[6] = die1.ace_mst2_crvalid;
assign vif.dst_ready[6] = die1.ace_mst2_crready;
assign vif.dst_payload[6] = {die1.ace_mst2_crresp};
assign vif.src_valid[7] = die0.ace_slv2_cdvalid;
assign vif.src_ready[7] = die0.ace_slv2_cdready;
assign vif.src_payload[7] = {die0.ace_slv2_cddata, die0.ace_slv2_cdlast};
assign vif.dst_valid[7] = die1.ace_mst2_cdvalid;
assign vif.dst_ready[7] = die1.ace_mst2_cdready;
assign vif.dst_payload[7] = {die1.ace_mst2_cddata, die1.ace_mst2_cdlast};
assign vif.src_valid[8] = die0.ace_slv2_rack;
assign vif.src_ready[8] = 1'b1;
assign vif.src_payload[8] = {die0.ace_slv2_rack};
assign vif.dst_valid[8] = die1.ace_mst2_rack;
assign vif.dst_ready[8] = 1'b1;
assign vif.dst_payload[8] = {die1.ace_mst2_rack};
assign vif.src_valid[9] = die0.ace_slv2_wack;
assign vif.src_ready[9] = 1'b1;
assign vif.src_payload[9] = {die0.ace_slv2_wack};
assign vif.dst_valid[9] = die1.ace_mst2_wack;
assign vif.dst_ready[9] = 1'b1;
assign vif.dst_payload[9] = {die1.ace_mst2_wack};


assign vif.reset_n=ace_rst_n;
assign vif.link_ready=ace_rst_n===1'b1 &&
  die0.u_st_s_reg_inst0.rx_link_status===2'b11 && die1.u_st_s_reg_inst0.rx_link_status===2'b11 &&
  die0.u_st_s_reg_inst0.pcs_rx_cmd_rx_link_ok===1'b1 && die1.u_st_s_reg_inst0.pcs_rx_cmd_rx_link_ok===1'b1 &&
  die0.u_st_s_reg_inst0.pcs_mac_tx_ready_enable===1'b1 && die1.u_st_s_reg_inst0.pcs_mac_tx_ready_enable===1'b1;
assign vif.quiet_hw=vif.link_ready && vif.src_valid===10'b0 && vif.dst_valid===10'b0 &&
  u_master.st==u_master.M_IDLE && u_master.sn==u_master.S_IDLE &&
  u_slave.st==u_slave.B_IDLE && (u_slave.hs==u_slave.H_IDLE || u_slave.hs==u_slave.H_GAP) &&
  u_slave.aw_pend===1'b0 && u_slave.ar_pend===1'b0 && u_slave.scan_hit===1'b0;
assign vif.status_a={u_master.o_any_err,u_master.err_snoop_timeout,u_master.err_main_timeout,
                     u_master.err_wr_prbs,u_master.err_rsp,u_master.err_rd_data};
assign vif.status_b={u_slave.o_any_err,u_slave.err_slave_timeout,u_slave.err_snoop_timeout,
                     u_slave.err_cr_mismatch,u_slave.err_cd_data,u_slave.err_wr_data};
assign vif.cnt_tx=u_master.o_cnt_tx;
assign vif.cnt_a_snoop=u_master.o_cnt_snoop;
assign vif.cnt_wr=u_slave.o_cnt_wr;
assign vif.cnt_rd=u_slave.o_cnt_rd;
assign vif.cnt_b_snoop=u_slave.o_cnt_snoop;
for(genvar n=0;n<4;n++) begin:cache_observation
  assign vif.cache[n]={u_master.c_valid[n],u_master.c_tag[n],u_master.c_state[n],u_master.c_data[n]};
end
