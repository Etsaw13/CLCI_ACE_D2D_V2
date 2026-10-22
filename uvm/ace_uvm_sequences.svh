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
    realtime deadline;
    cfg.stage="parallel traffic";enable(1,1);enable(0,1);
    deadline=$realtime+cfg.run_timeout_us*1us;
    while(cfg.engine.requests<target) begin
      @(negedge cfg.vif.clk);if($realtime>=deadline) `uvm_fatal("RUN_TIMEOUT","Request target not reached")
    end
    $display("UVM_ACE_STOP target_min=%0d issued=%0d t=%0t",target,cfg.engine.requests,$time);
    enable(0,0);
    $display("UVM_ACE_STOP_APPLIED issued=%0d t=%0t",cfg.engine.requests,$time);
    total_min=target;
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
  task alias_diagnostic();
    cfg.stage="diagnostic: burst write then same address at another beat position";
    configure(3);run_until(1);drain();check_status();check_counts();enable(1,0);
    cfg.base_address+=44'd16;
    configure(2);run_until(cfg.engine.requests+1);drain();
    // The checker uses stored beat-1 data. A's own beat-0 expectation must
    // still be checked; disagreement remains an actual failing diagnostic.
  endtask
  task body();
    int scenario;
    if(cfg==null) `uvm_fatal("CFG","Sequence has no configuration")
    wait_link();
    case(cfg.kind)
      "ace_v2_apb_test":apb_case();
      "ace_v2_pause_resume_test":pause_case();
      "ace_v2_error_status_test":error_case();
      "ace_v2_data_alias_diag_test":alias_diagnostic();
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
