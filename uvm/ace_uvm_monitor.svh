class ace_v2_monitor extends uvm_monitor;
  `uvm_component_utils(ace_v2_monitor)
  ace_v2_config cfg;
  uvm_analysis_port#(ace_sample) analysis;
  function new(string name,uvm_component parent);super.new(name,parent);analysis=new("analysis",this);endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(ace_v2_config)::get(this,"","cfg",cfg)) `uvm_fatal("CFG","Missing ACE monitor configuration")
  endfunction
  task run_phase(uvm_phase phase);
    ace_sample t;
    forever begin
      @(posedge cfg.vif.clk);
      if(cfg.monitoring && !cfg.completed) begin
        if(cfg.vif.link_ready!==1'b1) `uvm_fatal("LINK_LOST","Complete link readiness lost")
        if($isunknown({cfg.vif.status_a,cfg.vif.status_b})) `uvm_fatal("ACE_STATUS","Unknown ACE status")
        if((cfg.vif.status_a & ~cfg.allowed_a)!=0 || (cfg.vif.status_b & ~cfg.allowed_b)!=0) begin
          if(cfg.diagnostic && cfg.vif.status_a[0])
            `uvm_fatal("DIAGNOSTIC_FAIL","Same-address data self-check failed after the address-stable data fix")
          `uvm_fatal("ACE_STATUS",$sformatf("Unexpected ACE status A=%h B=%h allowed=%h/%h stage=%s",cfg.vif.status_a,cfg.vif.status_b,cfg.allowed_a,cfg.allowed_b,cfg.stage))
        end
        t=new();t.svld=cfg.vif.src_valid;t.srdy=cfg.vif.src_ready;
        t.dvld=cfg.vif.dst_valid;t.drdy=cfg.vif.dst_ready;
        for(int ch=0;ch<10;ch++) begin t.sp[ch]=cfg.vif.src_payload[ch];t.dp[ch]=cfg.vif.dst_payload[ch];end
        for(int n=0;n<4;n++) t.before_cache[n]=cfg.vif.cache[n];
        #1ps;
        for(int n=0;n<4;n++) t.after_cache[n]=cfg.vif.cache[n];
        analysis.write(t);
      end
    end
  endtask
endclass
