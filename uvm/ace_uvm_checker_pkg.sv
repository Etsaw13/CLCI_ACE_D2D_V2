`timescale 1ns/1ps
package ace_uvm_checker_pkg;
  import uvm_pkg::*;
  import ace_pkg::*;
  import ace_uvm_model_pkg::*;
  import ace_uvm_cache_cov_pkg::*;

  class ace_sample;
    logic [9:0] svld,srdy,dvld,drdy;
    logic [255:0] sp[10],dp[10];
    internal_cache_line_t before_cache[N_LINES],after_cache[N_LINES];
  endclass
  class snoop_context;
    ac_t request;
    logic [4:0] response;
    logic [127:0] snapshot;
  endclass
  class ace_checker;
    generator_model generator;
    internal_cache_observer cache_observer;
    payload_fifo source_q[10],destination_q[10];
    longint unsigned ns[10],nd[10],nm[10],requests,writes,reads;
    longint unsigned expected_wbeats,expected_rbeats,w_completed,r_completed;
    longint unsigned master_r_completed,cd_expected;
    longint unsigned categories[4],hits[9][7];
    logic [255:0] previous[2][8];
    bit stalled[2][8];
    bit sw_active,dw_active,mr_active,br_active;
    request_t sw,mr;
    aw_t dw;
    ar_t br;
    int sw_beat,dw_beat,mr_beat,br_beat;
    bit [2:0] mode;
    bit [7:0] code,fixed_byte;
    logic [127:0] memory[4];
    bit memory_valid[4];
    bit [39:0] memory_tag[4];
    snoop_context ac_to_cr[$],cr_to_home[$],source_cd[$],destination_cd[$];
    bit reported;
    bit expected_slverr;
    longint unsigned slverr_seen;

`ifndef VERILATOR
    covergroup basic with function sample(int metric,int value);
      transaction_class:coverpoint value iff(metric==0) {bins sw={0};bins sr={1};bins bw={2};bins br={3};}
      ace_attribute:coverpoint value iff(metric==1) {bins wu={0};bins wlu={1};bins rs={2};bins ru={3};bins ro={4};}
      request_start_line:coverpoint value iff(metric==2) {bins l0={0};bins l1={1};bins l2={2};bins l3={3};}
      burst_length:coverpoint value iff(metric==3) {bins n2={0};bins n3={1};bins n4={2};bins n5_15={3};bins n16_254={4};bins n255={5};bins n256={6};}
    endgroup
    covergroup coherence with function sample(int metric,int value);
      snoop_type:coverpoint value iff(metric==4) {bins rs={0};bins mi={1};bins ci={2};bins ro={3};}
      cr_response:coverpoint value iff(metric==5) {bins none={0};bins shared={1};bins unique_clean={2};bins unique_shared={3};bins dirty_data={4};}
      r_tag:coverpoint value iff(metric==6) {bins plain={0};bins pd={1};bins shared={2};}
    endgroup
    covergroup data_modes with function sample(int value);
      data_mode:coverpoint value {bins modes[]={0,1,2,3,4,5};}
    endgroup
    covergroup cache_behaviors with function sample(int value);
      behavior:coverpoint value {bins goals[]={0,1,2,3,4,5};}
    endgroup
`endif
    function new();
      generator=new();cache_observer=new();
      foreach(source_q[i]) begin source_q[i]=new();destination_q[i]=new();ns[i]=0;nd[i]=0;nm[i]=0;end
      foreach(stalled[i,j]) stalled[i][j]=0;
      foreach(hits[i,j]) hits[i][j]=0;
      foreach(categories[i]) categories[i]=0;
      foreach(memory_valid[i]) begin memory_valid[i]=0;memory_tag[i]=0;memory[i]=0;end
      requests=0;writes=0;reads=0;expected_wbeats=0;expected_rbeats=0;
      w_completed=0;r_completed=0;master_r_completed=0;cd_expected=0;
      sw_active=0;dw_active=0;mr_active=0;br_active=0;reported=0;
      mode=0;code=8'ha5;fixed_byte=8'h5a;expected_slverr=0;slverr_seen=0;
`ifndef VERILATOR
      basic=new();coherence=new();data_modes=new();cache_behaviors=new();
`endif
    endfunction
    function void fail(input string reason);
      uvm_report_fatal("ACE_CHECK",$sformatf("t=%0t requests=%0d writes=%0d reads=%0d: %s",$time,requests,writes,reads,reason));
      $fatal(1,"ACE_CHECK: %s",reason);
    endfunction
    function void record(input int metric,value);
      hits[metric][value]++;
`ifndef VERILATOR
      if(metric<4) basic.sample(metric,value);
      else if(metric<7) coherence.sample(metric,value);
      else if(metric==7) data_modes.sample(value);
      else cache_behaviors.sample(value);
`endif
    endfunction
    function void record_request(input bit wr,input bit [43:0] address,input int length,attribute);
      int category,n;
      category=wr?((length==0)?0:2):((length==0)?1:3);
      categories[category]++;record(0,category);record(1,attribute);
      if(address<generator.base || address>generator.base+48 || address[3:0]!=0)
        fail("Request address outside the internal four-start-line window");
      record(2,int'((address-generator.base)>>4));record(7,int'(mode));
      n=length+1;
      if(length!=0) begin
        if(n==2) record(3,0);else if(n==3) record(3,1);else if(n==4) record(3,2);
        else if(n<=15) record(3,3);else if(n<=254) record(3,4);
        else if(n==255) record(3,5);else record(3,6);
      end
      if(int'(address[11:0])+n*16>4096)
        fail($sformatf("Burst crosses 4KB: addr=%h beats=%0d",address,n));
    endfunction
    function logic [127:0] data_at(input bit [43:0] address);
      return expected_data(address,mode,code,fixed_byte);
    endfunction
    function void endpoint(input int side,ch,input logic valid,ready,input logic [255:0] payload);
      if($isunknown({valid,ready}) || (valid && $isunknown(payload)))
        fail($sformatf("Unknown control/active payload: side=%0d channel=%s",side,channel_name(ch)));
      if(ch<8) begin
        if(stalled[side][ch] && (valid!==1'b1 || payload!==previous[side][ch]))
          fail($sformatf("VALID/payload changed under backpressure: side=%0d channel=%s",side,channel_name(ch)));
        stalled[side][ch]=(valid && !ready);previous[side][ch]=payload;
      end
    endfunction
    function void sample(input ace_sample t);
      logic [9:0] sf,df;
      logic [255:0] left,right;
      aw_t aw_value;
      ar_t ar_value;
      w_t write_value;
      r_t read_value;
      ac_t snoop_value;
      request_t expected;
      snoop_context context_value;
      bit hit;
      int slot,attribute;
      bit [43:0] address;
      logic [127:0] data_expected;
      longint unsigned prior_master_r,prior_master_b,prior_w_complete;
      internal_cache_event_t event_data;
      prior_master_r=master_r_completed;prior_master_b=nd[B];prior_w_complete=w_completed;
      sf=t.svld&t.srdy;df=t.dvld&t.drdy;
      for(int ch=0;ch<10;ch++) begin
        endpoint(0,ch,t.svld[ch],t.srdy[ch],t.sp[ch]);
        endpoint(1,ch,t.dvld[ch],t.drdy[ch],t.dp[ch]);
        if(sf[ch]) begin ns[ch]++;source_q[ch].push(t.sp[ch]);end
        if(df[ch]) begin nd[ch]++;destination_q[ch].push(t.dp[ch]);end
        while(source_q[ch].size()!=0 && destination_q[ch].size()!=0) begin
          left=source_q[ch].pop();right=destination_q[ch].pop();
          if(left!==right) fail($sformatf("D2D payload mismatch: %s index=%0d",channel_name(ch),nm[ch]));
          nm[ch]++;
        end
      end
      if(sf[AW] && sf[AR]) fail("Single-issue generator emitted AW and AR together");
      if(sf[AW]) begin
        if(sw_active || mr_active) fail("AW overlaps active main data transaction");
        aw_value=aw_t'(t.sp[AW]);expected=generator.take();
        if(!expected.write || aw_value.addr!==expected.addr || aw_value.len!==expected.len ||
           aw_value.snoop!==expected.awsn || aw_value.id!==16'd1 || aw_value.unq!==1'b1 ||
           aw_value.size!==3'd4 || aw_value.burst!==2'b01 || aw_value.region!==0 ||
           aw_value.lock!==0 || aw_value.cache!==4'hf || aw_value.prot!==0 ||
           aw_value.qos!==0 || aw_value.domain!==2'b01 || aw_value.bar!==0)
          fail($sformatf("AW differs from independent generator model: expected=%h actual=%h",expected,aw_value));
        sw=expected;sw_active=1;sw_beat=0;requests++;writes++;expected_wbeats+=int'(expected.len)+1;
        attribute=(aw_value.snoop==AWSNOOP_WRITE_UNIQUE)?0:1;
        record_request(1,aw_value.addr,int'(aw_value.len),attribute);
      end
      if(sf[AR]) begin
        if(sw_active || mr_active) fail("AR overlaps active main data transaction");
        ar_value=ar_t'(t.sp[AR]);expected=generator.take();
        if(expected.write || ar_value.addr!==expected.addr || ar_value.len!==expected.len ||
           ar_value.snoop!==expected.arsn || ar_value.id!==16'd2 || ar_value.size!==3'd4 ||
           ar_value.burst!==2'b01 || ar_value.region!==0 || ar_value.lock!==0 ||
           ar_value.cache!==4'hf || ar_value.prot!==0 || ar_value.qos!==0 ||
           ar_value.domain!==2'b01 || ar_value.bar!==0)
          fail("AR differs from independent generator model");
        mr=expected;mr_active=1;mr_beat=0;requests++;reads++;expected_rbeats+=int'(expected.len)+1;
        attribute=(ar_value.snoop==ARSNOOP_READ_SHARED)?2:(ar_value.snoop==ARSNOOP_READ_UNIQUE)?3:4;
        record_request(0,ar_value.addr,int'(ar_value.len),attribute);
      end
      if(df[AW]) begin
        if(dw_active) fail("Second AW before destination write completed");
        dw=aw_t'(t.dp[AW]);dw_beat=0;dw_active=1;
      end
      if(df[AR]) begin
        if(br_active) fail("Second AR before source read completed");
        br=ar_t'(t.dp[AR]);br_beat=0;br_active=1;
      end
      if(sf[W]) begin
        write_value=w_t'(t.sp[W]);
        if(!sw_active) fail("Source W without AW");
        address=sw.addr+44'(sw_beat*16);
        if(write_value.data!==data_at(address) || write_value.strb!==16'hffff ||
           write_value.last!==(sw_beat==int'(sw.len))) fail("Source W data/STRB/LAST mismatch");
        if(write_value.last) sw_active=0;else sw_beat++;
      end
      if(sf[B]) begin
        if(t.sp[B]!==256'({16'd1,(expected_slverr?2'b10:2'b00)}) || ns[B]>prior_w_complete)
          fail("B response/ID mismatch or B before delivered final W");
        if(expected_slverr) slverr_seen++;
      end
      // Read expectations precede memory writes at this edge (pre-NBA memory).
      if(sf[R]) begin
        read_value=r_t'(t.sp[R]);
        if(!br_active) fail("Source R without delivered AR");
        address=br.addr+44'(br_beat*16);slot=int'(address[5:4]);
        data_expected=(memory_valid[slot] && memory_tag[slot]==address[43:4])?
          memory[slot]:data_at(address);
        if(read_value.data!==data_expected || read_value.id!==br.id ||
           read_value.last!==(br_beat==int'(br.len)) || read_value.resp[1:0]!==0 ||
           read_value.resp[RR_PASSDIRTY] !== (br.snoop==ARSNOOP_READ_UNIQUE) ||
           (read_value.resp[RR_ISSHARED] && br.snoop!=ARSNOOP_READ_SHARED))
          fail($sformatf("R differs from independent stored-data model: addr=%h beat=%0d expected=%h got=%h",address,br_beat,data_expected,read_value.data));
        record(6,read_value.resp[RR_PASSDIRTY]?1:read_value.resp[RR_ISSHARED]?2:0);
        if(read_value.last) begin br_active=0;r_completed++;end else br_beat++;
      end
      if(df[R]) begin
        read_value=r_t'(t.dp[R]);
        if(!mr_active || read_value.last!==(mr_beat==int'(mr.len))) fail("Master R/LAST without matching AR");
        if(read_value.last) begin mr_active=0;master_r_completed++;end else mr_beat++;
      end
      if(sf[RACK] && ns[RACK]>prior_master_r) fail("RACK before prior completed R at Master");
      if(sf[WACK] && ns[WACK]>prior_master_b) fail("WACK before prior B at Master");
      if(df[W]) begin
        write_value=w_t'(t.dp[W]);
        if(!dw_active || write_value.last!==(dw_beat==int'(dw.len))) fail("Destination W/LAST without matching AW");
        address=dw.addr+44'(dw_beat*16);slot=int'(address[5:4]);
        memory[slot]=write_value.data;memory_valid[slot]=1;memory_tag[slot]=address[43:4];
        if(write_value.last) begin dw_active=0;w_completed++;end else dw_beat++;
      end
      if(sf[AC]) begin
        snoop_value=ac_t'(t.sp[AC]);
        if(snoop_value.id!==15'(ns[AC]-1) || snoop_value.prot!==0 ||
           snoop_value.addr[3:0]!==0 || snoop_value.addr<generator.base ||
           snoop_value.addr>generator.base+48)
          fail("AC ID/address/protection differs from the configured Home contract");
      end
      if(df[AC]) begin
        snoop_value=ac_t'(t.dp[AC]);slot=int'(snoop_value.addr[5:4]);
        if(snoop_value.addr[3:0]!=0 || snoop_value.prot!=0) fail("Unaligned/unsupported AC");
        context_value=new();context_value.request=snoop_value;
        hit=t.before_cache[slot].valid && t.before_cache[slot].tag===snoop_value.addr[43:4];
        context_value.response=expected_cr(hit,t.before_cache[slot].state,snoop_value.snoop);
        context_value.snapshot=t.before_cache[slot].data;ac_to_cr.push_back(context_value);
        case(snoop_value.snoop)
          ARSNOOP_READ_SHARED:record(4,0);ARSNOOP_MAKE_INVALID:record(4,1);
          ARSNOOP_CLEAN_INVALID:record(4,2);ARSNOOP_READ_ONCE:record(4,3);
          default:fail("Unexpected Home snoop type");
        endcase
      end
      if(sf[CR]) begin
        if(ac_to_cr.size()==0) fail("CR without delivered AC");
        context_value=ac_to_cr.pop_front();
        if(t.sp[CR]!==256'(context_value.response)) fail("CR does not match independent response decision");
        cr_to_home.push_back(context_value);
        if(context_value.response[CR_DT]) begin cd_expected++;source_cd.push_back(context_value);end
        case(context_value.response)
          0:record(5,0);8:record(5,1);16:record(5,2);24:record(5,3);21:record(5,4);
          default:fail("Unexpected CR response combination");
        endcase
      end
      if(df[CR]) begin
        if(cr_to_home.size()==0) fail("CR delivered before source response");
        context_value=cr_to_home.pop_front();
        if(context_value.response[CR_DT]) destination_cd.push_back(context_value);
      end
      if(sf[CD]) begin
        if(source_cd.size()==0) fail("CD without CR.DataTransfer obligation");
        context_value=source_cd.pop_front();
        if(t.sp[CD]!==256'({context_value.snapshot,1'b1})) fail("CD differs from AC-time cache snapshot");
      end
      if(df[CD]) begin
        if(destination_cd.size()==0) fail("Delivered CD without matched CR obligation");
        context_value=destination_cd.pop_front();slot=int'(context_value.request.addr[5:4]);
        memory[slot]=t.dp[CD][128:1];memory_valid[slot]=1;
        memory_tag[slot]=context_value.request.addr[43:4];
      end
      event_data='0;
      event_data.aw=sf[AW];event_data.ar=sf[AR];event_data.w_source=sf[W];
      event_data.b_at_master=df[B];event_data.r_at_master=df[R];
      event_data.wack=sf[WACK];event_data.rack=sf[RACK];
      aw_value=aw_t'(t.sp[AW]);ar_value=ar_t'(t.sp[AR]);
      event_data.awaddr=aw_value.addr;event_data.awsnoop=aw_value.snoop;
      event_data.araddr=ar_value.addr;event_data.arsnoop=ar_value.snoop;
      read_value=r_t'(t.dp[R]);event_data.rresp=read_value.resp;
      snoop_value=ac_t'(t.dp[AC]);event_data.ac_at_master=df[AC];
      event_data.acaddr=snoop_value.addr;event_data.acsnoop=snoop_value.snoop;
      event_data.cr_source=sf[CR];event_data.cr_destination=df[CR];
      event_data.crresp_source=t.sp[CR][4:0];event_data.crresp_destination=t.dp[CR][4:0];
      event_data.cd_source=sf[CD];event_data.cd_destination=df[CD];
      event_data.cddata_source=t.sp[CD][128:1];event_data.cdlast_source=t.sp[CD][0];
      event_data.cddata_destination=t.dp[CD][128:1];event_data.cdlast_destination=t.dp[CD][0];
      cache_observer.observe(event_data,t.before_cache,t.after_cache,mode,code,fixed_byte);
      if(cache_observer.correlation_errors!=0) fail("Cache observer event correlation error");
      for(int goal=0;goal<6;goal++) if(cache_observer.cycle_hits[goal]) record(8,goal);
    endfunction
    function bit empty();
      if(sw_active || dw_active || mr_active || br_active || ac_to_cr.size()!=0 ||
         cr_to_home.size()!=0 || source_cd.size()!=0 || destination_cd.size()!=0) return 0;
      for(int ch=0;ch<10;ch++)
        if(source_q[ch].size()!=0 || destination_q[ch].size()!=0 || ns[ch]!=nd[ch]) return 0;
      return 1;
    endfunction
    function void close(input int target,input string test_name);
      if(!empty() || requests<target || ns[AW]!=writes || ns[AR]!=reads ||
         ns[B]!=writes || ns[WACK]!=writes || ns[RACK]!=reads ||
         ns[W]!=expected_wbeats || ns[R]!=expected_rbeats ||
         ns[AC]!=ns[CR] || ns[CD]!=cd_expected || master_r_completed!=reads)
        fail("Final transaction/beat/ACK/CD/queue closure failed");
      for(int ch=0;ch<10;ch++) begin
        if(ns[ch]!=nm[ch]) fail("Unmatched D2D transfer at final closure");
        $display("UVM_ACE_D2D %s source=%0d destination=%0d matched=%0d",channel_name(ch),ns[ch],nd[ch],nm[ch]);
      end
      if(test_name=="ace_v2_smoke_test") begin
        for(int k=0;k<4;k++) if(categories[k]==0) fail("Smoke did not exercise all four transaction classes");
        if(ns[AC]==0 || ns[CD]==0) fail("Smoke did not exercise snoop and dirty-data return");
      end
    endfunction
    function void save_coverage(input string path,input bit complete);
      int fd;
      int totals[9]='{4,5,4,7,4,5,3,6,6};
      if(reported) return;reported=1;
      fd=$fopen(path,"w");if(fd==0) $fatal(1,"Cannot create functional report: %s",path);
      $fdisplay(fd,"ACE_V2_UVM_FUNCTIONAL version=1 plan=ace_v2_44 completion=%s",complete?"FINAL":"PARTIAL");
      for(int m=0;m<9;m++)
        for(int b=0;b<totals[m];b++) $fdisplay(fd,"BIN metric=%0d bin=%0d hits=%0d",m,b,hits[m][b]);
      for(int g=0;g<6;g++)
        $fdisplay(fd,"CACHE goal=%0d attempted=%0d matched=%0d conflict=%0d unmatched=%0d",
          g,cache_observer.attempted[g],cache_observer.matched[g],cache_observer.conflict[g],cache_observer.not_matched(g));
      $fdisplay(fd,"CD expected=%0d delivered=%0d",cd_expected,nd[CD]);
      $fclose(fd);
    endfunction
  endclass
endpackage
