class ace_v2_control_sequence extends uvm_sequence#(ace_v2_apb_item);
  `uvm_object_utils(ace_v2_control_sequence)
  ace_v2_config cfg;
  longint unsigned total_min;
  function new(string name="ace_v2_control_sequence");super.new(name);endfunction
  task transfer(input int side,input bit wr,input logic [11:0] addr,input logic [31:0] data,
                output logic [31:0] result,input bit error_expected=0);
    ace_v2_apb_item item;
    item=ace_v2_apb_item::type_id::create("access");
    start_item(item);item.side=side;item.write_access=wr;item.address=addr;
    item.data=data;item.expect_error=error_expected;finish_item(item);result=item.read_data;
  endtask
  task write_reg(input int side,input logic [11:0] addr,input logic [31:0] data);
    logic [31:0] ignored;transfer(side,1,addr,data,ignored);
  endtask
  task read_expect(input int side,input logic [11:0] addr,input logic [31:0] expected);
    logic [31:0] actual;transfer(side,0,addr,0,actual);
    if(actual!==expected) `uvm_fatal("APB_READBACK",$sformatf("side=%0d addr=%h expected=%h actual=%h",side,addr,expected,actual))
  endtask
  task enable(input int side,input bit value);write_reg(side,12'h000,{31'b0,value});endtask
  task cycles(input int n);repeat(n) @(negedge cfg.vif.clk);endtask
  function bit quiet();return cfg.vif.quiet_hw===1'b1 && cfg.engine.empty();endfunction
  task wait_link();
    int stable;realtime deadline;
    stable=0;deadline=$realtime+cfg.link_timeout_us*1us;
    while(stable<8) begin
      @(negedge cfg.vif.clk);
      if(cfg.vif.link_ready===1'b1) stable++;else stable=0;
      if($realtime>=deadline) `uvm_fatal("LINK_TIMEOUT","Both complete links did not become stable")
    end
    cfg.monitoring=1;
    `uvm_info("LINK_READY","Both RX, command and TX paths stable for eight ACE cycles",UVM_LOW)
  endtask
  task configure(input int scenario,input int inject=0);
    logic [31:0] a,b,snoop;
    a={4'b0,4'(scenario),8'(cfg.xcode),5'b0,3'(cfg.mode),8'(cfg.prbs_code)};
    b={8'b0,8'(cfg.xcode),5'b0,3'(cfg.mode),8'(cfg.prbs_code)};
    snoop={20'b0,4'(inject),8'(cfg.snoop_gap)};
    write_reg(0,12'h004,a);read_expect(0,12'h004,a);
    write_reg(0,12'h008,cfg.base_address[31:0]);read_expect(0,12'h008,cfg.base_address[31:0]);
    write_reg(0,12'h00c,{20'b0,cfg.base_address[43:32]});read_expect(0,12'h00c,{20'b0,cfg.base_address[43:32]});
    write_reg(0,12'h020,32'(cfg.burst_beats-1));read_expect(0,12'h020,32'(cfg.burst_beats-1));
    write_reg(1,12'h004,b);read_expect(1,12'h004,b);
    write_reg(1,12'h008,snoop);read_expect(1,12'h008,snoop);
  endtask
  task check_counts();
    read_expect(0,12'h014,32'(cfg.engine.requests-cfg.epoch_tx));
    read_expect(0,12'h018,32'(cfg.engine.ns[CR]-cfg.epoch_a_cr));
    read_expect(1,12'h014,32'(cfg.engine.writes-cfg.epoch_wr));
    read_expect(1,12'h018,32'(cfg.engine.reads-cfg.epoch_rd));
    read_expect(1,12'h01c,32'(cfg.engine.nd[CR]));
  endtask
  task check_status(input logic [31:0] a=0,b=0);
    read_expect(0,12'h010,a);read_expect(1,12'h010,b);
  endtask
  task run_until(input longint unsigned target);
    cfg.stage="parallel traffic";enable(1,1);enable(0,1);
    wait_requests(target);
    $display("UVM_ACE_STOP target_min=%0d issued=%0d t=%0t",target,cfg.engine.requests,$time);
    enable(0,0);
    $display("UVM_ACE_STOP_APPLIED issued=%0d t=%0t",cfg.engine.requests,$time);
    total_min=target;
  endtask
  task wait_requests(input longint unsigned target);
    realtime deadline;
    deadline=$realtime+cfg.run_timeout_us*1us;
    while(cfg.engine.requests<target) begin
      @(negedge cfg.vif.clk);if($realtime>=deadline) `uvm_fatal("RUN_TIMEOUT","Request target not reached")
    end
  endtask
  task drain();
    int stable;stable=0;cfg.stage="drain; Home remains enabled";
    for(int n=0;n<cfg.drain_cycles;n++) begin
      @(negedge cfg.vif.clk);
      if(quiet() && cfg.vif.cnt_tx===32'(cfg.engine.requests-cfg.epoch_tx) &&
         cfg.vif.cnt_wr===32'(cfg.engine.writes-cfg.epoch_wr) &&
         cfg.vif.cnt_rd===32'(cfg.engine.reads-cfg.epoch_rd)) stable++;else stable=0;
      if(stable==16) return;
    end
    `uvm_fatal("DRAIN_TIMEOUT","Pending data/ACK/CD/queues/directory did not close")
  endtask
  task apb_case();
    logic [31:0] ignored;
    cfg.stage="APB register checks";
    read_expect(0,12'h000,0);read_expect(1,12'h000,0);
    read_expect(0,12'h004,32'h005a00a5);read_expect(1,12'h004,32'h005a00a5);
    read_expect(0,12'h008,32'h20000000);read_expect(0,12'h00c,0);
    read_expect(0,12'h020,3);read_expect(1,12'h008,10);check_status();check_counts();
    write_reg(0,12'h004,32'h045a05a7);read_expect(0,12'h004,32'h045a05a7);
    write_reg(1,12'h004,32'h00a60337);read_expect(1,12'h004,32'h00a60337);
    write_reg(0,12'h008,32'h12345670);read_expect(0,12'h008,32'h12345670);
    write_reg(0,12'h00c,32'hffffffff);read_expect(0,12'h00c,32'hfff);
    write_reg(0,12'h020,255);read_expect(0,12'h020,255);
    write_reg(1,12'h008,32'h3ff);read_expect(1,12'h008,32'h3ff);
    write_reg(0,12'h014,32'hdeadbeef);read_expect(0,12'h014,0);
    write_reg(1,12'h014,32'hdeadbeef);read_expect(1,12'h014,0);
    transfer(0,0,12'hffc,0,ignored,1);transfer(1,1,12'hffc,32'hffffffff,ignored,1);
    read_expect(1,12'h004,32'h00a60337);
    write_reg(0,12'h000,2);read_expect(0,12'h000,0);
    write_reg(1,12'h000,3);read_expect(1,12'h000,1);enable(1,0);
    if(cfg.engine.requests!=0 || !quiet()) `uvm_fatal("APB_ONLY","Unexpected ACE traffic")
    `uvm_info("APB_CHECK_PASS","Reset, config, RO, undefined decode and clear-pulse checks passed",UVM_LOW)
  endtask
  task pause_case();
    longint unsigned saved,goal;logic [31:0] saved_data;
    configure(0);run_until(cfg.pause_at);drain();check_status();check_counts();
    cfg.stage="paused";saved=cfg.engine.requests;saved_data=cfg.a_data;cfg.pauses++;
    for(int n=0;n<cfg.pause_cycles;n++) begin
      @(negedge cfg.vif.clk);
      if(!quiet() || cfg.engine.requests!=saved) `uvm_fatal("PAUSE","Traffic during the drained pause")
    end
    read_expect(0,12'h000,0);read_expect(1,12'h000,1);
    read_expect(0,12'h004,saved_data);read_expect(0,12'h020,32'(cfg.burst_beats-1));
    read_expect(0,12'h008,cfg.base_address[31:0]);read_expect(0,12'h00c,{20'b0,cfg.base_address[43:32]});
    goal=(cfg.tx_target>saved)?cfg.tx_target:saved+1;
    cfg.resumes++;run_until(goal);drain();
    if(cfg.engine.requests<=saved) `uvm_fatal("RESUME","No request after resuming")
    // Engine state and stored-data history were never reset at pause/resume.
  endtask
  task clear_errors();
    write_reg(0,12'h000,2);write_reg(1,12'h000,2);cycles(4);
    read_expect(0,12'h000,0);read_expect(1,12'h000,0);check_status();check_counts();
    cfg.allowed_a=0;cfg.allowed_b=0;
  endtask
  task error_case();
    longint unsigned prior_b,prior_cr;
    configure(1);run_until(cfg.tx_target);drain();check_status();check_counts();
    cfg.stage="BRESP injection";cfg.allowed_a=6'h22;prior_b=cfg.engine.slverr_seen;
    write_reg(1,12'h008,32'(cfg.snoop_gap)|32'h100);
    run_until(cfg.engine.requests+cfg.error_target);drain();check_status(32'h22,0);check_counts();
    if(cfg.engine.slverr_seen<=prior_b) `uvm_fatal("EXPECTED_ERROR","No injected SLVERR response observed")
    cycles(8);check_status(32'h22,0);cfg.negative_phases++;
    enable(1,0);write_reg(1,12'h008,32'(cfg.snoop_gap));clear_errors();
    cfg.stage="BRESP recovery";run_until(cfg.engine.requests+cfg.error_target);drain();check_status();check_counts();cfg.recovery_phases++;
    enable(1,0);configure(2);
    cfg.stage="CR expectation injection";cfg.allowed_b=6'h24;prior_cr=cfg.engine.nd[CR];
    write_reg(1,12'h008,32'(cfg.snoop_gap)|32'h200);
    run_until(cfg.engine.requests+cfg.error_target);drain();check_status(0,32'h24);check_counts();
    if(cfg.engine.nd[CR]<=prior_cr) `uvm_fatal("EXPECTED_ERROR","No CR event during expected-response inversion")
    cycles(8);check_status(0,32'h24);cfg.negative_phases++;
    enable(1,0);write_reg(1,12'h008,32'(cfg.snoop_gap));clear_errors();
    cfg.stage="CR recovery";run_until(cfg.engine.requests+cfg.error_target);drain();check_status();check_counts();cfg.recovery_phases++;
  endtask
  task check_home_word(input logic [43:0] address,input logic [127:0] expected);
    int slot;
    slot=internal_cache_slot(address);
    if(cfg.vif.memory_written[slot]!==1'b1 ||
       cfg.vif.memory_tag[slot]!==address[43:4] ||
       cfg.vif.memory_data[slot]!==expected)
      `uvm_fatal("FIX_HOME_DATA",$sformatf("addr=%h expected=%h actual=%h",
        address,expected,cfg.vif.memory_data[slot]))
  endtask
  task data_alias_case();
    logic [43:0] address;
    logic [127:0] expected;
    int slot;
    address=cfg.base_address+44'd16;
    slot=internal_cache_slot(address);
    expected=expected_data(address,3'(cfg.mode),8'(cfg.prbs_code),8'(cfg.xcode));
    cfg.stage="data alias: burst write";
    configure(3);
    enable(0,1);wait_requests(1);enable(0,0);drain_idle();
    if(cfg.engine.categories[2]==0)
      `uvm_fatal("DATA_ALIAS_SETUP","No completed burst write")
    check_home_word(address,expected);

    cfg.stage="data alias: single read of the stored burst beat";
    cfg.base_address=address;
    configure(2);
    enable(0,1);wait_requests(cfg.engine.requests+1);enable(0,0);drain_idle();
    if(cfg.engine.categories[1]==0 || cfg.vif.cache[slot].valid!==1'b1 ||
       cfg.vif.cache[slot].tag!==address[43:4] || cfg.vif.cache[slot].data!==expected)
      `uvm_fatal("DATA_ALIAS_FAIL","Single read disagreed with the stored burst beat")
    enable(1,1);drain();enable(1,0);
    check_status();check_counts();
    total_min=2;
    $display("UVM_ACE_DATA_ALIAS_PASS addr=%h data=%h",address,expected);
  endtask
  task dirty_readonce_case();
    logic [43:0] address;
    logic [127:0] expected;
    longint unsigned prior_reads;
    int slot;
    address=cfg.base_address+44'd16;
    slot=internal_cache_slot(address);
    expected=expected_data(address,3'(cfg.mode),8'(cfg.prbs_code),8'(cfg.xcode));
    cfg.stage="dirty ReadOnce: establish UD";
    configure(2);
    enable(0,1);wait_requests(3);enable(0,0);drain_idle();
    if(cfg.engine.reads!=3 || cfg.engine.hits[1][3]!=1 ||
       !internal_cache_has(cfg.vif.cache[slot],address,ST_UD) ||
       cfg.vif.cache[slot].data!==expected || cfg.vif.directory_valid[slot]!==1'b1 ||
       cfg.vif.directory_tag[slot]!==address[43:4] || cfg.vif.directory_state[slot]!==ST_UD)
      `uvm_fatal("DIRTY_READONCE_SETUP","Expected a matching dirty line after ReadUnique")

    cfg.stage="dirty ReadOnce: walk four burst starts";
    configure(4);
    prior_reads=cfg.engine.reads;
    enable(0,1);wait_requests(prior_reads+4);enable(0,0);drain_idle();
    if(cfg.engine.categories[3]<4 || !internal_cache_has(cfg.vif.cache[slot],address,ST_UD) ||
       cfg.vif.cache[slot].data!==expected)
      `uvm_fatal("DIRTY_READONCE_FAIL","Nonallocating reads changed the dirty line")

    cfg.stage="dirty ReadOnce: return the original data";
    enable(1,1);drain();enable(1,0);
    if(cfg.engine.nd[CD]!=1)
      `uvm_fatal("DIRTY_READONCE_FAIL","Home must receive exactly one dirty-data transfer")
    check_home_word(address,expected);
    check_status();check_counts();
    total_min=7;
    $display("UVM_ACE_DIRTY_READONCE_PASS addr=%h data=%h",address,expected);
  endtask
  // These two cases deliberately separate state construction from snoops.
  // All requests still come from the ACE generator and traverse real CLCI.
  task drain_idle();
    int stable;stable=0;
    for(int n=0;n<cfg.drain_cycles;n++) begin
      @(negedge cfg.vif.clk);
      if(cfg.vif.idle_hw===1'b1 && cfg.engine.empty() &&
         cfg.vif.cnt_tx===32'(cfg.engine.requests-cfg.epoch_tx) &&
         cfg.vif.cnt_wr===32'(cfg.engine.writes-cfg.epoch_wr) &&
         cfg.vif.cnt_rd===32'(cfg.engine.reads-cfg.epoch_rd)) stable++;else stable=0;
      if(stable==16) return;
    end
    `uvm_fatal("DIRECTED_DRAIN","ACE/link data, response and ACK queues did not close")
  endtask
  task line_expect(input bit valid,input logic [1:0] state);
    int slot;logic [127:0] data_expected;
    slot=internal_cache_slot(cfg.base_address);
    data_expected=expected_data(cfg.base_address,3'(cfg.mode),8'(cfg.prbs_code),8'(cfg.xcode));
    for(int n=0;n<4;n++) begin
      if(n!=slot && (cfg.vif.cache[n].valid!==1'b0 || cfg.vif.directory_valid[n]!==1'b0))
        `uvm_fatal("DIRECTED_STATE","Unexpected valid cache/directory entry outside the target line")
    end
    if(cfg.vif.cache[slot].valid!==valid || cfg.vif.directory_valid[slot]!==valid)
      `uvm_fatal("DIRECTED_STATE",$sformatf("valid expected=%b cache=%b directory=%b",valid,cfg.vif.cache[slot].valid,cfg.vif.directory_valid[slot]))
    if(valid && (!internal_cache_has(cfg.vif.cache[slot],cfg.base_address,state) ||
       cfg.vif.directory_tag[slot]!==cfg.base_address[43:4] || cfg.vif.directory_state[slot]!==state ||
       cfg.vif.cache[slot].data!==data_expected))
      `uvm_fatal("DIRECTED_STATE","Cache state/tag/data or Home directory differ from the required line")
    if(cfg.vif.memory_written[slot]!==1'b1 || cfg.vif.memory_tag[slot]!==cfg.base_address[43:4] ||
       cfg.vif.memory_data[slot]!==data_expected)
      `uvm_fatal("DIRECTED_DATA","Home memory lost the completed single-write data")
  endtask
  task establish_uc();
    longint unsigned target,prior_wlu;realtime deadline;
    int slot;
    if(cfg.a_enable || cfg.b_enable) `uvm_fatal("DIRECTED_CONTROL","Generators must be disabled before UC setup")
    slot=internal_cache_slot(cfg.base_address);prior_wlu=cfg.engine.hits[1][1];
    cfg.stage="directed: establish UC with Home disabled";
    for(int attempt=0;attempt<8;attempt++) begin
      // APB stop is not an exact request-count limiter. Close every accepted
      // write, then inspect its result; a final WU needs another WLU attempt.
      target=cfg.engine.requests+((attempt==0)?2:1);
      enable(0,1);deadline=$realtime+cfg.run_timeout_us*1us;
      while(cfg.engine.requests<target) begin
        @(negedge cfg.vif.clk);
        if($realtime>=deadline) `uvm_fatal("DIRECTED_RUN","Single-write UC setup did not reach the request lower bound")
      end
      enable(0,0);drain_idle();check_status();check_counts();
      if(internal_cache_has(cfg.vif.cache[slot],cfg.base_address,ST_UC)) begin
        line_expect(1,ST_UC);
        if(cfg.engine.hits[1][1]<=prior_wlu) `uvm_fatal("DIRECTED_STATE","UC setup did not include a real WLU handshake")
        $display("UVM_ACE_DIRECTED_UC requests=%0d writes=%0d attempts=%0d",cfg.engine.requests,cfg.engine.writes,attempt+1);
        return;
      end
      line_expect(0,ST_I);
    end
    `uvm_fatal("DIRECTED_STATE","APB stop never left a completed WLU/UC state within eight attempts")
  endtask
  task home_step(input int type_bin,response_bin,input bit valid_after,input logic [1:0] state_after);
    longint unsigned prior_ac,prior_cr,prior_type,prior_resp,prior_cd;realtime deadline;
    prior_ac=cfg.engine.ns[AC];prior_cr=cfg.engine.nd[CR];prior_type=cfg.engine.hits[4][type_bin];
    prior_resp=cfg.engine.hits[5][response_bin];prior_cd=cfg.engine.nd[CD];
    cfg.stage=$sformatf("directed: Home rotation %0d",type_bin);
    if(cfg.vif.home_rotation!==2'(type_bin) || cfg.a_enable || cfg.b_enable)
      `uvm_fatal("DIRECTED_ROTATION","Unexpected Home rotation or enabled generator at phase entry")
    enable(1,1);deadline=$realtime+cfg.run_timeout_us*1us;
    while(cfg.engine.nd[CR]==prior_cr) begin
      @(negedge cfg.vif.clk);
      if($realtime>=deadline) `uvm_fatal("DIRECTED_SNOOP","Expected Home snoop/CR did not complete")
    end
    // The controlled gap leaves time for this APB stop before another AC.
    enable(1,0);drain_idle();check_status();check_counts();
    if(cfg.engine.ns[AC]!=prior_ac+1 || cfg.engine.nd[CR]!=prior_cr+1 ||
       cfg.engine.hits[4][type_bin]!=prior_type+1 || cfg.engine.hits[5][response_bin]!=prior_resp+1 ||
       cfg.engine.nd[CD]!=prior_cd)
      `uvm_fatal("DIRECTED_SNOOP","Phase did not deliver exactly the planned AC and matching clean CR without CD")
    line_expect(valid_after,state_after);
    $display("UVM_ACE_DIRECTED_HOME type_bin=%0d response_bin=%0d cache_valid=%b state=%0d AC=%0d CR=%0d",
      type_bin,response_bin,valid_after,state_after,cfg.engine.ns[AC],cfg.engine.nd[CR]);
  endtask
  task coverage_case(input bit need_unique);
    if(cfg.snoop_gap!=255) `uvm_fatal("DIRECTED_ARGS","Coverage cases require SNOOP_GAP=255 for bounded APB phase isolation")
    configure(1);establish_uc();
    home_step(0,3,1,ST_SC); // UC + ReadShared -> CR24 and retained SC.
    if(cfg.engine.hits[8][4]!=1 || cfg.engine.cache_observer.attempted[4]!=1 ||
       cfg.engine.cache_observer.matched[4]!=1 || cfg.engine.cache_observer.conflict[4]!=0 ||
       cfg.engine.cache_observer.not_matched(4)!=0)
      `uvm_fatal("DIRECTED_COVERAGE","UC_RS_SC requires one proved hit with zero conflict/unmatched attempts")
    // Retire the retained SC copy via the next MakeInvalid, preserving the
    // proven transition and closing the directory before final checks.
    home_step(1,0,0,ST_I);
    if(need_unique) begin
      establish_uc();home_step(2,0,0,ST_I); // CleanInvalid advances rotation.
      establish_uc();home_step(3,2,0,ST_I); // UC + ReadOnce -> CR16.
      if(cfg.engine.hits[5][2]!=1) `uvm_fatal("DIRECTED_COVERAGE","CR16 was not delivered exactly once")
    end
    if(cfg.engine.reads!=0 || cfg.engine.cache_observer.correlation_errors!=0)
      `uvm_fatal("DIRECTED_COVERAGE","Directed setup emitted reads or lost event correlation")
    for(int g=0;g<6;g++)
      if(cfg.engine.cache_observer.conflict[g]!=0 || cfg.engine.cache_observer.not_matched(g)!=0)
        `uvm_fatal("DIRECTED_COVERAGE","An observed cache behavior was conflicting or unmatched")
    total_min=need_unique?6:2;
    $display("UVM_ACE_DIRECTED_COVERAGE_PASS target=%s CR16=%0d UC_RS_SC=%0d conflicts=%0d correlation_errors=%0d",
      need_unique?"CR16":"UC_RS_SC",cfg.engine.hits[5][2],cfg.engine.hits[8][4],
      cfg.engine.cache_observer.conflict[4],cfg.engine.cache_observer.correlation_errors);
  endtask
  task shared_case();
    longint unsigned prior_requests,prior_reads,prior_shared;realtime deadline;
    configure(1);establish_uc();configure(2);
    prior_requests=cfg.engine.requests;prior_reads=cfg.engine.reads;prior_shared=cfg.engine.hits[6][2];
    cfg.stage="directed: ReadShared retains a clean shared line";
    enable(0,1);deadline=$realtime+cfg.run_timeout_us*1us;
    while(cfg.engine.reads==prior_reads) begin
      @(negedge cfg.vif.clk);
      if($realtime>=deadline) `uvm_fatal("DIRECTED_RUN","Single ReadShared setup did not issue")
    end
    enable(0,0);drain_idle();check_status();check_counts();line_expect(1,ST_SC);
    // At most the generator's supplementary ReadShared can enter before stop.
    if(cfg.engine.reads-prior_reads<1 || cfg.engine.reads-prior_reads>2 ||
       cfg.engine.requests-prior_requests!=cfg.engine.reads-prior_reads ||
       cfg.engine.hits[6][2]-prior_shared!=cfg.engine.reads-prior_reads)
      `uvm_fatal("DIRECTED_STATE","SC setup must contain only one/two actual ReadShared responses with IsShared")
    home_step(0,1,1,ST_SC);home_step(1,0,0,ST_I);
    if(cfg.engine.hits[5][1]!=1 || cfg.engine.hits[8][3]==0 || cfg.engine.hits[8][4]!=0 ||
       cfg.engine.cache_observer.correlation_errors!=0)
      `uvm_fatal("DIRECTED_COVERAGE","CR8/RS_IS_SC evidence missing or a UC_RS_SC hit was falsely attributed")
    for(int g=0;g<6;g++)
      if(cfg.engine.cache_observer.conflict[g]!=0 || cfg.engine.cache_observer.not_matched(g)!=0)
        `uvm_fatal("DIRECTED_COVERAGE","Shared setup has a conflicting or unmatched cache observation")
    total_min=3;
    $display("UVM_ACE_DIRECTED_COVERAGE_PASS target=CR8 CR8=%0d RS_IS_SC=%0d UC_RS_SC=%0d correlation_errors=%0d",
      cfg.engine.hits[5][1],cfg.engine.hits[8][3],cfg.engine.hits[8][4],cfg.engine.cache_observer.correlation_errors);
  endtask
  task body();
    int scenario;
    if(cfg==null) `uvm_fatal("CFG","Sequence has no configuration")
    wait_link();
    case(cfg.kind)
      "ace_v2_apb_test":apb_case();
      "ace_v2_uc_rs_sc_test":coverage_case(0);
      "ace_v2_cr_shared_test":shared_case();
      "ace_v2_cr_unique_test":coverage_case(1);
      "ace_v2_pause_resume_test":pause_case();
      "ace_v2_error_status_test":error_case();
      "ace_v2_data_alias_test","ace_v2_data_alias_diag_test":data_alias_case();
      "ace_v2_dirty_readonce_test":dirty_readonce_case();
      default:begin
        scenario=(cfg.kind=="ace_v2_single_write_test")?1:
                 (cfg.kind inside {"ace_v2_single_read_test","ace_v2_snoop_stress_test"})?2:
                 (cfg.kind=="ace_v2_burst_write_test")?3:(cfg.kind=="ace_v2_burst_read_test")?4:0;
        cfg.stage="APB configuration";configure(scenario);run_until(cfg.tx_target);drain();
      end
    endcase
    enable(0,0);enable(1,0);cfg.stage="final observation";
    for(int n=0;n<32;n++) begin @(negedge cfg.vif.clk);if(!quiet()) `uvm_fatal("FINAL_ACTIVITY","Activity after drain") end
    check_status();check_counts();cfg.completed=1;cfg.stage="complete";
  endtask
endclass
