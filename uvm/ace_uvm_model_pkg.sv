`timescale 1ns/1ps
// Independent verification contract. Never include DUT data functions here.
package ace_uvm_model_pkg;
  import ace_pkg::*;
  typedef enum int {AW,W,B,AR,R,AC,CR,CD,RACK,WACK} channel_e;
  typedef struct packed {
    logic [ID_W-1:0] id; logic [ADDR_W-1:0] addr;
    logic [LEN_W-1:0] len; logic [2:0] size; logic [1:0] burst;
    logic [3:0] region; logic lock; logic [3:0] cache;
    logic [2:0] prot; logic [3:0] qos; logic [2:0] snoop;
    logic [1:0] domain,bar; logic unq;
  } aw_t;
  typedef struct packed {
    logic [ID_W-1:0] id; logic [ADDR_W-1:0] addr;
    logic [LEN_W-1:0] len; logic [2:0] size; logic [1:0] burst;
    logic [3:0] region; logic lock; logic [3:0] cache;
    logic [2:0] prot; logic [3:0] qos; logic [3:0] snoop;
    logic [1:0] domain,bar;
  } ar_t;
  typedef struct packed {logic [127:0] data;logic [15:0] strb;logic last;} w_t;
  typedef struct packed {logic [15:0] id;logic [127:0] data;logic [3:0] resp;logic last;} r_t;
  typedef struct packed {logic [14:0] id;logic [43:0] addr;logic [3:0] snoop;logic [2:0] prot;} ac_t;
  typedef struct packed {
    bit write;bit [43:0] addr;bit [7:0] len;
    bit [3:0] arsn;bit [2:0] awsn;bit supplement;
  } request_t;

  function automatic string channel_name(int ch);
    case(ch)
      AW:return "AW";W:return "W";B:return "B";AR:return "AR";R:return "R";
      AC:return "AC";CR:return "CR";CD:return "CD";RACK:return "RACK";WACK:return "WACK";
      default:return "invalid";
    endcase
  endfunction

  function automatic logic [127:0] expected_data(
      input bit [43:0] address,input bit [2:0] mode,
      input bit [7:0] code,fixed_byte);
    bit [39:0] line;
    bit [30:0] seed,state31;
    bit [22:0] state23;
    bit [9:0] state10;
    logic [127:0] result;
    line=address[43:4];result='0;
    seed=line[30:0]^{3'b0,line[39:33],line[29:9]}^{23'b0,code};
    case(mode)
      1: for(int n=0;n<16;n++) result[n*8+:8]=fixed_byte;
      2: for(int n=0;n<4;n++) result[n*32+:32]={line[15:0],line[31:24],line[23:16]};
      3: result[int'(line[6:0])]=1;
      4: begin
        state23=seed[22:0];if(state23==0) state23=1;
        for(int n=0;n<128;n++) begin
          result[n]=state23[22];state23={state23[21:0],state23[22]^state23[17]};
        end
      end
      5: begin
        state10=seed[9:0];if(state10==0) state10=1;
        for(int n=0;n<128;n++) begin
          result[n]=state10[9];state10={state10[8:0],state10[9]^state10[6]};
        end
      end
      default: begin
        state31=seed;if(state31==0) state31=1;
        for(int n=0;n<128;n++) begin
          result[n]=state31[30];state31={state31[29:0],state31[30]^state31[27]};
        end
      end
    endcase
    return result;
  endfunction

  function automatic logic [4:0] expected_cr(
      input bit valid,input bit [1:0] state,input bit [3:0] snoop);
    if(!valid) return 0;
    case(state)
      ST_UD:return 21;
      ST_SC:return (snoop==ARSNOOP_READ_SHARED || snoop==ARSNOOP_READ_ONCE)?5'd8:5'd0;
      ST_UC:begin
        if(snoop==ARSNOOP_READ_SHARED) return 24;
        if(snoop==ARSNOOP_READ_ONCE || snoop==ARSNOOP_READ_UNIQUE) return 16;
        return 0;
      end
      default:return 0;
    endcase
  endfunction

  class generator_model;
    bit [1:0] operation,line,read_pattern;
    bit write_pattern,supplement;
    bit [43:0] base;
    bit [7:0] burst_len;
    int test_type;
    function new();
      operation=0;line=0;read_pattern=0;write_pattern=0;supplement=0;
      base=44'h20000000;burst_len=3;test_type=0;
    endfunction
    function request_t take();
      request_t item;
      int selected;
      selected=(test_type>=1 && test_type<=4)?test_type-1:int'(operation);
      item='0;item.supplement=supplement;
      item.write=supplement?0:!(selected&1);
      item.len=(!supplement && selected>=2)?burst_len:0;
      item.addr=base+44'((supplement?((int'(line)+3)%4):int'(line))*16);
      item.arsn=supplement?ARSNOOP_READ_SHARED:
        (selected>=2)?ARSNOOP_READ_ONCE:
        (read_pattern==1)?ARSNOOP_READ_UNIQUE:
        (read_pattern==3)?ARSNOOP_READ_ONCE:ARSNOOP_READ_SHARED;
      item.awsn=(selected>=2)?AWSNOOP_WRITE_UNIQUE:
        write_pattern?AWSNOOP_WRITE_LINE_UNIQUE:AWSNOOP_WRITE_UNIQUE;
      if(supplement) supplement=0;
      else begin
        if(test_type==0 || test_type>4) operation++;
        if(item.write) write_pattern=~write_pattern;
        else begin
          line++;
          if(item.len==0) read_pattern++;
          if(item.len==0 && item.arsn==ARSNOOP_READ_SHARED) supplement=1;
        end
      end
      return item;
    endfunction
  endclass
  class payload_fifo;
    logic [255:0] data[$];
    function void push(input logic [255:0] value);
      data.push_back(value);
    endfunction
    function logic [255:0] pop();
      return data.pop_front();
    endfunction
    function int size();
      return data.size();
    endfunction
  endclass
endpackage
