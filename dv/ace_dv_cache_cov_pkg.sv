`timescale 1ns/1ps
// Passive event correlation for the six agreed cache scenarios. No UVM,
// DUT helper functions, driving, or access to the DUT's update decisions.
package ace_dv_cache_cov_pkg;
  import ace_pkg::*;
  import ace_dv_model_pkg::*;
  localparam int CACHE_BEHAVIORS=6;
  localparam int CACHE_INDEX_W=$clog2(N_LINES);
  typedef struct packed {
    logic valid;
    logic [TAG_W-1:0] tag;
    logic [1:0] state;
    logic [DATA_W-1:0] data;
  } internal_cache_line_t;
  typedef struct packed {
    bit aw,ar,w_source,b_at_master,r_at_master,wack,rack,ac_at_master,cr_source,cr_destination;
    bit cd_source,cd_destination;
    logic [ADDR_W-1:0] awaddr,araddr,acaddr;
    logic [2:0] awsnoop;
    logic [3:0] arsnoop,acsnoop;
    logic [RRESP_W-1:0] rresp;
    logic [CRRESP_W-1:0] crresp_source,crresp_destination;
    logic [DATA_W-1:0] cddata_source,cddata_destination;
    logic cdlast_source,cdlast_destination;
  } internal_cache_event_t;

  function automatic int internal_cache_slot(input logic [ADDR_W-1:0] address);
    return int'(address[LINE_SHIFT+:CACHE_INDEX_W]);
  endfunction
  function automatic bit internal_cache_has(input internal_cache_line_t line,
      input logic [ADDR_W-1:0] address,input logic [1:0] state);
    return line.valid===1'b1 && line.tag===address[ADDR_W-1:LINE_SHIFT] && line.state===state;
  endfunction
  function automatic string internal_cache_behavior_name(input int goal);
    case(goal)
      0:return "WU_invalid"; 1:return "WLU_UC"; 2:return "RU_PD_UD";
      3:return "RS_IS_SC"; 4:return "UC_RS_SC"; 5:return "UD_CI_CD_invalid";
      default:return "invalid";
    endcase
  endfunction

  class internal_cache_snoop_context;
    logic [ADDR_W-1:0] address;
    internal_cache_line_t initial_line;
    int goal=-1;
    logic [CRRESP_W-1:0] response;
    bit update_seen,transition_ok,cr_delivered,cr_ok,cd_source_ok,cd_delivered,cd_ok,closed;
    logic [DATA_W-1:0] cd_data;
    logic cd_last;
  endclass

  class internal_cache_observer;
    longint unsigned attempted[CACHE_BEHAVIORS],matched[CACHE_BEHAVIORS],conflict[CACHE_BEHAVIORS];
    longint unsigned correlation_errors;
    bit [CACHE_BEHAVIORS-1:0] cycle_hits;
    bit have_aw,have_ar,have_w,have_b,have_r;
    logic [ADDR_W-1:0] aw_address,ar_address;
    logic [2:0] aw_snoop;
    logic [3:0] ar_snoop;
    logic [RRESP_W-1:0] read_response;
    internal_cache_snoop_context ac_waiting[$],cr_waiting[$],cd_source_waiting[$],cd_destination_waiting[$];
    internal_cache_snoop_context update_due;

    function new();
      foreach(attempted[i]) begin attempted[i]=0;matched[i]=0;conflict[i]=0;end
      correlation_errors=0;cycle_hits='0;have_aw=0;have_ar=0;have_w=0;have_b=0;have_r=0;update_due=null;
    endfunction
    function longint unsigned not_matched(input int goal);
      // Includes still-pending contexts in a PARTIAL report; never a fake hit.
      return attempted[goal]-matched[goal]-conflict[goal];
    endfunction
    function void match_goal(input int goal);
      matched[goal]++;cycle_hits[goal]=1'b1;
    endfunction
    function void finish_snoop(input internal_cache_snoop_context observation);
      if(observation==null) return;
      if(observation.closed || observation.goal<0 || !observation.update_seen || !observation.cr_delivered) return;
      if(observation.goal==4) begin
        if(observation.transition_ok && observation.cr_ok && observation.response===5'd24)
          match_goal(4);
        observation.closed=1;
      end else if(!observation.response[CR_DT]) begin
        observation.closed=1;
      end else if(observation.cd_delivered) begin
        if(observation.transition_ok && observation.cr_ok && observation.response===5'd21 &&
           observation.cd_source_ok && observation.cd_ok) match_goal(5);
        observation.closed=1;
      end
    endfunction
    function void observe(input internal_cache_event_t event_data,
        input internal_cache_line_t before_cache[N_LINES],after_cache[N_LINES],
        input bit [2:0] mode,input bit [7:0] code,fixed_byte);
      internal_cache_snoop_context observation;
      logic [DATA_W-1:0] expected;
      bit snoop_update_this_cycle;
      int slot,goal;
      cycle_hits='0;
      snoop_update_this_cycle=(update_due!=null);

      // CR registers a pulse. Its cache update is at the NEXT clock edge.
      // Both snapshots here belong to that next edge, before and after NBA.
      if(update_due!=null) begin
        observation=update_due;update_due=null;
        if(observation.goal>=0) begin
          slot=internal_cache_slot(observation.address);
          observation.update_seen=1;
          if(before_cache[slot] !== observation.initial_line) begin
            // A changed observation cannot establish the agreed before/after case.
            conflict[observation.goal]++;observation.closed=1;
          end else begin
            expected=expected_data(observation.address,mode,code,fixed_byte);
            if(observation.goal==4)
              observation.transition_ok=internal_cache_has(after_cache[slot],observation.address,ST_SC) &&
                                    after_cache[slot].data===observation.initial_line.data &&
                                    observation.initial_line.data===expected;
            else observation.transition_ok=after_cache[slot].valid===1'b0 && observation.initial_line.data===expected;
          end
          finish_snoop(observation);
        end
      end

      // R attributes are sampled at the Master boundary, not from a later bus.
      if(event_data.w_source) begin
        if(!have_aw) correlation_errors++;
        have_w=1;
      end
      if(event_data.b_at_master) begin
        if(!have_aw || !have_w) correlation_errors++;
        have_b=1;
      end
      if(event_data.r_at_master) begin
        if(!have_ar) correlation_errors++;
        read_response=event_data.rresp;have_r=1;
      end
      if(event_data.wack) begin
        if(!have_aw || !have_w || !have_b) correlation_errors++;
        else begin
          goal=(aw_snoop==AWSNOOP_WRITE_UNIQUE)?0:(aw_snoop==AWSNOOP_WRITE_LINE_UNIQUE)?1:-1;
          if(goal>=0) begin
            attempted[goal]++;slot=internal_cache_slot(aw_address);
            expected=expected_data(aw_address,mode,code,fixed_byte);
            // The DUT gives snoop updates GLOBAL priority, even across slots.
            if(snoop_update_this_cycle) conflict[goal]++;
            else if((goal==0 && after_cache[slot].valid===1'b0) ||
                    (goal==1 && internal_cache_has(after_cache[slot],aw_address,ST_UC) &&
                     after_cache[slot].data===expected)) match_goal(goal);
          end
        end
        have_aw=0;have_w=0;have_b=0;
      end
      if(event_data.rack) begin
        if(!have_ar || !have_r) correlation_errors++;
        else begin
          goal=(ar_snoop==ARSNOOP_READ_UNIQUE && read_response[RR_PASSDIRTY]===1'b1)?2:
               (ar_snoop==ARSNOOP_READ_SHARED && read_response[RR_ISSHARED]===1'b1)?3:-1;
          if(goal>=0) begin
            attempted[goal]++;slot=internal_cache_slot(ar_address);
            expected=expected_data(ar_address,mode,code,fixed_byte);
            if(snoop_update_this_cycle) conflict[goal]++;
            else if(read_response===((goal==2)?4'b0100:4'b1000) &&
                    internal_cache_has(after_cache[slot],ar_address,(goal==2)?ST_UD:ST_SC) &&
                    after_cache[slot].data===expected) match_goal(goal);
          end
        end
        have_ar=0;have_r=0;
      end
      if(event_data.aw) begin
        if(have_aw || have_ar) correlation_errors++;
        have_aw=1;have_w=0;have_b=0;aw_address=event_data.awaddr;aw_snoop=event_data.awsnoop;
      end
      if(event_data.ar) begin
        if(have_aw || have_ar) correlation_errors++;
        have_ar=1;have_r=0;ar_address=event_data.araddr;ar_snoop=event_data.arsnoop;
      end

      if(event_data.ac_at_master) begin
        observation=new();observation.address=event_data.acaddr;
        slot=internal_cache_slot(observation.address);observation.initial_line=before_cache[slot];
        if(event_data.acsnoop==ARSNOOP_READ_SHARED && internal_cache_has(observation.initial_line,observation.address,ST_UC))
          observation.goal=4;
        if(event_data.acsnoop==ARSNOOP_CLEAN_INVALID && internal_cache_has(observation.initial_line,observation.address,ST_UD))
          observation.goal=5;
        if(observation.goal>=0) attempted[observation.goal]++;
        ac_waiting.push_back(observation);
      end
      if(event_data.cr_source) begin
        if(ac_waiting.size()==0) correlation_errors++;
        else begin
          observation=ac_waiting.pop_front();observation.response=event_data.crresp_source;
          update_due=observation;cr_waiting.push_back(observation);
          if(observation.response[CR_DT]) begin
            cd_source_waiting.push_back(observation);cd_destination_waiting.push_back(observation);
          end
        end
      end
      if(event_data.cr_destination) begin
        if(cr_waiting.size()==0) correlation_errors++;
        else begin
          observation=cr_waiting.pop_front();observation.cr_delivered=1;
          observation.cr_ok=(event_data.crresp_destination===observation.response);finish_snoop(observation);
        end
      end
      if(event_data.cd_source) begin
        if(cd_source_waiting.size()==0) correlation_errors++;
        else begin
          observation=cd_source_waiting.pop_front();observation.cd_data=event_data.cddata_source;
          observation.cd_last=event_data.cdlast_source;
          expected=expected_data(observation.address,mode,code,fixed_byte);
          observation.cd_source_ok=event_data.cdlast_source===1'b1 && event_data.cddata_source===expected &&
                               event_data.cddata_source===observation.initial_line.data;
        end
      end
      if(event_data.cd_destination) begin
        if(cd_destination_waiting.size()==0) correlation_errors++;
        else begin
          observation=cd_destination_waiting.pop_front();observation.cd_delivered=1;
          observation.cd_ok=(event_data.cddata_destination===observation.cd_data &&
                         event_data.cdlast_destination===observation.cd_last);
          finish_snoop(observation);
        end
      end
    endfunction
  endclass
endpackage
