`timescale 1ns/1ps
`ifdef ACE_V2_UVM_RUNTIME_COV
  `include "CoverMeter.vh"

  // The legacy PLI rejects a SystemVerilog string variable as the instance
  // argument on some VCS versions. Expand every native call with literal
  // paths and constant metrics, including CM_CHECK and both count queries.
  `define ACE_V2_COV_QUERY_LITERAL(TYPE, PATH) \
    begin \
      value.check_status=$cm_coverage(`CM_CHECK,TYPE,`CM_HIER,PATH); \
      value.covered=$cm_get_coverage(TYPE,`CM_HIER,PATH); \
      value.total=$cm_get_limit(TYPE,`CM_HIER,PATH); \
    end
  `define ACE_V2_COV_SCOPE_LITERAL(PATH) \
    case(metric) \
      0: `ACE_V2_COV_QUERY_LITERAL(`CM_SOURCE,PATH) \
      1: `ACE_V2_COV_QUERY_LITERAL(`CM_CONDITION,PATH) \
      2: `ACE_V2_COV_QUERY_LITERAL(`CM_TOGGLE,PATH) \
      3: `ACE_V2_COV_QUERY_LITERAL(`CM_FSM_STATE,PATH) \
      4: `ACE_V2_COV_QUERY_LITERAL(`CM_FSM_TRANS,PATH) \
      default: value.check_status=API_NOT_EXPOSED; \
    endcase
`endif

// The legacy realtime API is distinct from URG. No DPI or external process.
// All percentages use native numerator/denominator pairs for the same scope.
package ace_uvm_runtime_cov_pkg;
  localparam int RUNTIME_METRICS=6;
  localparam int API_NOT_EXPOSED=-100;
  localparam int API_NOT_COMPILED=-101;
  localparam int API_UNKNOWN_SCOPE=-102;
  typedef struct packed {
    int check_status;
    int covered;
    int total;
  } runtime_cov_count_t;

  function automatic string runtime_metric_name(input int metric);
    case(metric)
      0: return "line";
      1: return "condition";
      2: return "toggle";
      3: return "fsm_state";
      4: return "fsm_transition";
      5: return "branch";
      default: return "invalid";
    endcase
  endfunction

  function automatic runtime_cov_count_t runtime_sample(input int metric,input string instance_path);
    runtime_cov_count_t value;
    value.check_status=API_NOT_COMPILED;value.covered=-1;value.total=-1;
    // No CM_BRANCH appears in the tested 2023 CoverMeter.vh. CM_UEXPR is
    // user-expression coverage and must never be substituted for branch.
    if(metric==5) begin value.check_status=API_NOT_EXPOSED;return value;end
`ifdef ACE_V2_UVM_RUNTIME_COV
    // This string is only a selector. Never pass it to the legacy PLI.
    if(instance_path=="tb_ace_clci_2die_smoke.u_master") begin
      `ACE_V2_COV_SCOPE_LITERAL("tb_ace_clci_2die_smoke.u_master")
    end else if(instance_path=="tb_ace_clci_2die_smoke.u_slave") begin
      `ACE_V2_COV_SCOPE_LITERAL("tb_ace_clci_2die_smoke.u_slave")
    end
    else value.check_status=API_UNKNOWN_SCOPE;
`endif
    return value;
  endfunction

  function automatic bit runtime_valid(input runtime_cov_count_t value);
    return value.check_status==0 && value.total>0 && value.covered>=0 && value.covered<=value.total;
  endfunction

  function automatic string runtime_reason(input runtime_cov_count_t value);
    if(value.check_status==API_NOT_EXPOSED) return "api_not_exposed";
    if(value.check_status==API_NOT_COMPILED) return "api_not_compiled";
    if(value.check_status==API_UNKNOWN_SCOPE) return "unknown_scope";
    if(value.check_status==-3) return "partial_scope";
    if(value.check_status==-2) return "not_instrumented_or_unavailable";
    if(value.check_status!=0 || value.covered<0 || value.total<0) return "query_error";
    if(value.total==0) return "no_coverable_items";
    if(value.covered>value.total) return "invalid_counts";
    return "none";
  endfunction

  function automatic string runtime_row(input string scope,input int metric,input runtime_cov_count_t value);
    if(runtime_valid(value))
      return $sformatf("CODE scope=%s metric=%s status=OK covered=%0d total=%0d coverage=%0.2f%% check_status=%0d raw_covered=%0d raw_total=%0d reason=none",
        scope,runtime_metric_name(metric),value.covered,value.total,100.0*value.covered/value.total,
        value.check_status,value.covered,value.total);
    return $sformatf("CODE scope=%s metric=%s status=NA covered=NA total=NA coverage=NA check_status=%0d raw_covered=%0d raw_total=%0d reason=%s",
      scope,runtime_metric_name(metric),value.check_status,value.covered,value.total,runtime_reason(value));
  endfunction

  function automatic string runtime_pair_row(input int metric,input runtime_cov_count_t master,input runtime_cov_count_t slave);
    longint covered,total;
    if(runtime_valid(master) && runtime_valid(slave)) begin
      covered=longint'(master.covered)+longint'(slave.covered);
      total=longint'(master.total)+longint'(slave.total);
      return $sformatf("CODE scope=ace_pair metric=%s status=OK covered=%0d total=%0d coverage=%0.2f%% reason=weighted_two_disjoint_scopes",
        runtime_metric_name(metric),covered,total,100.0*covered/total);
    end
    return $sformatf("CODE scope=ace_pair metric=%s status=NA covered=NA total=NA coverage=NA reason=one_or_both_scopes_unavailable",
      runtime_metric_name(metric));
  endfunction
endpackage

`ifdef ACE_V2_UVM_RUNTIME_COV
  `undef ACE_V2_COV_SCOPE_LITERAL
  `undef ACE_V2_COV_QUERY_LITERAL
`endif
