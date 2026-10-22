class ace_v2_base_test extends uvm_test;
  `uvm_component_utils(ace_v2_base_test)
  ace_v2_config cfg;ace_v2_env env;string kind="ace_v2_smoke_test";
  function new(string name,uvm_component parent);super.new(name,parent);endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);cfg=ace_v2_config::type_id::create("cfg");cfg.kind=kind;
    if(!uvm_config_db#(virtual ace_uvm_if)::get(this,"","vif",cfg.vif)) `uvm_fatal("VIF","Missing interface")
    if(kind=="ace_v2_snoop_stress_test") cfg.snoop_gap=0;
    if(kind inside {"ace_v2_uc_rs_sc_test","ace_v2_cr_unique_test","ace_v2_cr_shared_test"}) begin
      cfg.snoop_gap=255;cfg.tx_target=(kind=="ace_v2_uc_rs_sc_test")?2:(kind=="ace_v2_cr_shared_test")?3:6;
    end
    cfg.parse();uvm_config_db#(ace_v2_config)::set(this,"*","cfg",cfg);
    env=ace_v2_env::type_id::create("env",this);
  endfunction
  task run_phase(uvm_phase phase);
    ace_v2_control_sequence sequence_run;
    phase.raise_objection(this);
    sequence_run=ace_v2_control_sequence::type_id::create("sequence_run");sequence_run.cfg=cfg;
    fork
      sequence_run.start(env.apb.sequencer);
      begin #(cfg.global_timeout_us*1us);`uvm_fatal("GLOBAL_TIMEOUT","UVM did not finish within the global simulation deadline") end
      begin
        if(cfg.progress_us>0) forever begin
          #(cfg.progress_us*1us);
          $display("UVM_ACE_PROGRESS t=%0.3f us stage=%s ready=%b A/Home=%b/%b requests=%0d completed=%0d",
            $realtime/1us,cfg.stage,cfg.vif.link_ready,cfg.a_enable,cfg.b_enable,cfg.engine.requests,cfg.vif.cnt_tx);
        end else forever @(negedge cfg.vif.clk);
      end
    join_any
    disable fork;
    env.scoreboard.total_min=sequence_run.total_min;
    if(!cfg.completed) `uvm_fatal("INCOMPLETE","Control sequence exited without closure")
    phase.drop_objection(this);
  endtask
  function void final_phase(uvm_phase phase);
    uvm_report_server server;super.final_phase(phase);server=uvm_report_server::get_server();
    if(cfg.completed && cfg.checked && server.get_severity_count(UVM_ERROR)==0 && server.get_severity_count(UVM_FATAL)==0) begin
      $display("UVM_ACE_SUMMARY test=%s mode=%0d burst=%0d target_min=%0d completed=%0d writes=%0d reads=%0d CD=%0d pauses=%0d negative_phases=%0d recoveries=%0d",
        cfg.kind,cfg.mode,cfg.burst_beats,env.scoreboard.total_min,cfg.engine.requests,cfg.engine.writes,cfg.engine.reads,cfg.engine.nd[CD],cfg.pauses,cfg.negative_phases,cfg.recovery_phases);
      $display("ACE_V2_UVM_PASS");
    end
  endfunction
endclass

`define ACE_V2_TEST(CLASS_NAME) \
class CLASS_NAME extends ace_v2_base_test; \
  `uvm_component_utils(CLASS_NAME) \
  function new(string name,uvm_component parent);super.new(name,parent);kind=`"CLASS_NAME`";endfunction \
endclass
`ACE_V2_TEST(ace_v2_apb_test)
`ACE_V2_TEST(ace_v2_smoke_test)
`ACE_V2_TEST(ace_v2_single_write_test)
`ACE_V2_TEST(ace_v2_single_read_test)
`ACE_V2_TEST(ace_v2_burst_write_test)
`ACE_V2_TEST(ace_v2_burst_read_test)
`ACE_V2_TEST(ace_v2_snoop_stress_test)
`ACE_V2_TEST(ace_v2_pause_resume_test)
`ACE_V2_TEST(ace_v2_error_status_test)
`ACE_V2_TEST(ace_v2_uc_rs_sc_test)
`ACE_V2_TEST(ace_v2_cr_unique_test)
`ACE_V2_TEST(ace_v2_cr_shared_test)
// Separate diagnostic, excluded from normal coverage merging.
`ACE_V2_TEST(ace_v2_data_alias_diag_test)
`undef ACE_V2_TEST
