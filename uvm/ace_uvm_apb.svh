// Active APB control only. No ACE request driving agent exists in this environment.
class ace_v2_apb_item extends uvm_sequence_item;
  `uvm_object_utils(ace_v2_apb_item)
  int side;
  bit write_access,expect_error;
  logic [11:0] address;
  logic [31:0] data,read_data;
  logic error;
  function new(string name="ace_v2_apb_item");super.new(name);endfunction
endclass

class ace_v2_apb_driver extends uvm_driver#(ace_v2_apb_item);
  `uvm_component_utils(ace_v2_apb_driver)
  ace_v2_config cfg;
  function new(string name,uvm_component parent);super.new(name,parent);endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(ace_v2_config)::get(this,"","cfg",cfg)) `uvm_fatal("CFG","Missing APB configuration")
  endfunction
  task run_phase(uvm_phase phase);
    int waited;
    cfg.vif.apb_psel=0;cfg.vif.apb_penable=0;cfg.vif.apb_pwrite=0;
    foreach(cfg.vif.apb_paddr[i]) begin cfg.vif.apb_paddr[i]=0;cfg.vif.apb_pwdata[i]=0;end
    forever begin
      seq_item_port.get_next_item(req);
      if(req.side<0 || req.side>1) `uvm_fatal("APB","Invalid side")
      if(cfg.vif.reset_n!==1'b1) `uvm_fatal("APB","APB request before reset release")
      @(negedge cfg.vif.clk);
      cfg.vif.apb_psel[req.side]=1;cfg.vif.apb_penable[req.side]=0;
      cfg.vif.apb_pwrite[req.side]=req.write_access;cfg.vif.apb_paddr[req.side]=req.address;
      cfg.vif.apb_pwdata[req.side]=req.data;
      @(negedge cfg.vif.clk);cfg.vif.apb_penable[req.side]=1;waited=0;
      do begin
        @(posedge cfg.vif.clk);#1ps;waited++;
        if(waited>16 || $isunknown(cfg.vif.apb_pready[req.side])) `uvm_fatal("APB","APB PREADY/timeout failure")
      end while(!cfg.vif.apb_pready[req.side]);
      req.read_data=cfg.vif.apb_prdata[req.side];req.error=cfg.vif.apb_pslverr[req.side];
      if(req.error!==req.expect_error || (!req.write_access && $isunknown(req.read_data)))
        `uvm_fatal("APB",$sformatf("APB response side=%0d addr=%h expected_error=%b actual_error=%b rdata=%h",req.side,req.address,req.expect_error,req.error,req.read_data))
      if(cfg.apb_trace) $display("UVM_APB side=%0d write=%b addr=%h data=%h read=%h error=%b",req.side,req.write_access,req.address,req.data,req.read_data,req.error);
      @(negedge cfg.vif.clk);
      cfg.vif.apb_psel[req.side]=0;cfg.vif.apb_penable[req.side]=0;cfg.vif.apb_pwrite[req.side]=0;
      seq_item_port.item_done();
    end
  endtask
endclass

class ace_v2_apb_monitor extends uvm_monitor;
  `uvm_component_utils(ace_v2_apb_monitor)
  ace_v2_config cfg;
  uvm_analysis_port#(ace_v2_apb_item) analysis;
  bit setup[2];logic [44:0] held[2];
  function new(string name,uvm_component parent);super.new(name,parent);analysis=new("analysis",this);endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(ace_v2_config)::get(this,"","cfg",cfg)) `uvm_fatal("CFG","Missing APB monitor configuration")
  endfunction
  task run_phase(uvm_phase phase);
    ace_v2_apb_item observed;
    forever begin
      @(posedge cfg.vif.clk);
      if(cfg.vif.reset_n!==1'b1) begin setup[0]=0;setup[1]=0;end
      else for(int s=0;s<2;s++) begin
        if($isunknown({cfg.vif.apb_psel[s],cfg.vif.apb_penable[s]})) `uvm_fatal("APB_PROTOCOL","Unknown APB control")
        if(cfg.vif.apb_penable[s] && !cfg.vif.apb_psel[s]) `uvm_fatal("APB_PROTOCOL","PENABLE without PSEL")
        if(cfg.vif.apb_psel[s] && !cfg.vif.apb_penable[s]) begin
          setup[s]=1;held[s]={cfg.vif.apb_pwrite[s],cfg.vif.apb_paddr[s],cfg.vif.apb_pwdata[s]};
        end else if(cfg.vif.apb_psel[s] && cfg.vif.apb_penable[s]) begin
          if(!setup[s] || held[s]!=={cfg.vif.apb_pwrite[s],cfg.vif.apb_paddr[s],cfg.vif.apb_pwdata[s]})
            `uvm_fatal("APB_PROTOCOL","Missing SETUP or changing ACCESS payload")
          if(cfg.vif.apb_pready[s]===1'b1) begin
            observed=new();observed.side=s;observed.write_access=cfg.vif.apb_pwrite[s];
            observed.address=cfg.vif.apb_paddr[s];observed.data=cfg.vif.apb_pwdata[s];
            observed.read_data=cfg.vif.apb_prdata[s];observed.error=cfg.vif.apb_pslverr[s];
            analysis.write(observed);setup[s]=0;
          end
        end else setup[s]=0;
      end
    end
  endtask
endclass

class ace_v2_apb_agent extends uvm_agent;
  `uvm_component_utils(ace_v2_apb_agent)
  uvm_sequencer#(ace_v2_apb_item) sequencer;
  ace_v2_apb_driver driver;ace_v2_apb_monitor monitor;
  function new(string name,uvm_component parent);super.new(name,parent);endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer=new("sequencer",this);driver=ace_v2_apb_driver::type_id::create("driver",this);
    monitor=ace_v2_apb_monitor::type_id::create("monitor",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
