/*
 * hwpe_ctrl_slave.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2014-2018 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */


module hwpe_ctrl_slave
  import hwpe_ctrl_package::*;
#(
  parameter int unsigned REGFILE_SCM    = 0,
  parameter int unsigned N_CORES        = 4,
  parameter int unsigned N_CONTEXT      = 2,
  parameter int unsigned N_EVT          = REGFILE_N_EVT,
  parameter int unsigned N_IO_REGS      = 2,
  parameter int unsigned N_GENERIC_REGS = 0,
  parameter int unsigned N_SW_EVT       = 8,
  parameter int unsigned ID_WIDTH       = 16,
  parameter int unsigned EXT_IN_REGGED  = REGFILE_EXT_IN_REGGED
)
(
  input  logic                clk_i,
  input  logic                rst_ni,
  output logic                clear_o,

  // peripheral interconnect side
  hwpe_ctrl_intf_periph.slave cfg,

  input  ctrl_slave_t         ctrl_i,
  output flags_slave_t        flags_o,
  output ctrl_regfile_t       reg_file
);

  localparam int unsigned N_REGISTERS         = REGFILE_N_REGISTERS;
  localparam int unsigned N_MANDATORY_REGS    = REGFILE_N_MANDATORY_REGS;
  localparam int unsigned N_RESERVED_REGS     = REGFILE_N_RESERVED_REGS;
  localparam int unsigned LOG_REGS            = $clog2(N_REGISTERS);
  localparam int unsigned LOG_CONTEXT         = N_CONTEXT > 1 ? $clog2(N_CONTEXT) : 1;
  localparam int unsigned LOG_REGS_MC         = LOG_REGS+LOG_CONTEXT;
  localparam int unsigned N_MAX_IO_REGS       = 2**$clog2(N_IO_REGS-1);
  localparam int unsigned N_MAX_GENERIC_REGS  = 2**$clog2(N_GENERIC_REGS-1);

  regfile_in_t  regfile_in;
  regfile_out_t regfile_out;

  enum logic [1:0]   {RUN_IDLE, RUN_RUN, RUN_STARTING} running_state;
  enum logic         {CXT_IDLE, CXT_PROGRAM}           context_state;

  flags_regfile_t regfile_flags;

  logic [N_CONTEXT-1:0][$clog2(N_CORES)-1:0] offloading_core;
  logic [LOG_CONTEXT-1:0] pointer_context;
  logic [LOG_CONTEXT-1:0] running_context;
  logic [LOG_CONTEXT  :0] counter_pending;

  logic [3:0] s_enable_after;
  logic [1:0] s_clear;
  logic [1:0] s_clear_regfile;
  logic clear_regfile;

  logic triggered_q;

  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(rst_ni == 1'b0)
      s_enable_after <= '0;
    else begin
      s_enable_after[0] <= 1'b1;
      for (int k=1; k<4; k++)
        s_enable_after[k] <= s_enable_after[k-1];
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(rst_ni == 1'b0)
      triggered_q <= '0;
    else if(clear_o) begin
      triggered_q <= '0;
    end
    else if(regfile_flags.is_trigger) begin
      triggered_q <= '1;
    end
    else if(running_context == pointer_context && regfile_flags.full_context == '0 && regfile_flags.true_done == 1) begin
      triggered_q <= '0;
    end
  end

  assign flags_o.done = regfile_flags.true_done;

  generate

    if(N_CONTEXT>1) begin : multi_context_gen

      // offloading core queue for evt generation
      always_ff @(posedge clk_i or negedge rst_ni)
      begin : offloading_core_proc
        if(rst_ni == 1'b0)
        begin
          offloading_core <= '0;
        end
        else
        begin
            if (regfile_flags.is_commit == 1)
            begin
              for(int i=0; i<N_CORES; i++)
                if (cfg.id[i] == 1'b1)
                  offloading_core[pointer_context] <= i;
            end
        end
      end
      
      // Current context
      always_ff @(posedge clk_i or negedge rst_ni)
      begin : pointer_context_proc
        if (rst_ni == 0)
          pointer_context <= 0;
        else if(clear_o == 1'b1)
          pointer_context <= 0;
        else begin
          if (regfile_flags.is_commit == 1)
            pointer_context <= pointer_context + 1;
        end
      end
      // Running context
      always_ff @(posedge clk_i or negedge rst_ni)
      begin : done_counter_proc
        if (rst_ni == 0)
          running_context <= 0;
        else if(clear_o == 1'b1)
          running_context <= 0;
        else begin
          if (regfile_flags.true_done == 1)
            running_context <= running_context + 1;
        end
      end
      // Pending contexts
      always_ff @(posedge clk_i or negedge rst_ni)
      begin : pending_counter_proc
        if (rst_ni == 0)
          counter_pending <= 0;
        else if(clear_o == 1'b1)
          counter_pending <= 0;
        else begin
          if ((regfile_flags.is_commit == 1) && (regfile_flags.true_done == 0))
            counter_pending <= counter_pending + 1;
          else if ((regfile_flags.is_commit == 0) && (regfile_flags.true_done == 1))
            counter_pending <= counter_pending - 1;
        end
      end

      assign regfile_flags.full_context = (counter_pending == N_CONTEXT) ? 1 : 0;  // All contexts are busy

    end
    else begin : single_context_gen

      // offloading core queue for evt generation
      always_ff @(posedge clk_i or negedge rst_ni)
      begin : offloading_core_proc
        if(rst_ni == 1'b0)
        begin
          offloading_core <= '0;
        end
        else
        begin
            if (regfile_flags.is_commit == 1)
            begin
              for(int i=0; i<N_CORES; i++)
                if (cfg.id[i] == 1'b1)
                  offloading_core[0] <= i;
            end
        end
      end

      assign pointer_context    = regfile_flags.is_commit;
      assign running_context    = 'b0;
      assign counter_pending    = (flags_o.is_working==1'b1) ? 1 : 'b0;
      assign regfile_flags.full_context = flags_o.is_working;
    end

  endgenerate

  // Flags
  always_comb
  begin : flags_proc
    regfile_flags.is_mandatory  = (cfg.add[LOG_REGS+2-1:2] <= N_MANDATORY_REGS+N_RESERVED_REGS-1)                     ? 1 : 0;  // Accessed reg is mandatory (or reserved)
    regfile_flags.is_contexted  = (cfg.add[LOG_REGS+2-1:2] > N_MANDATORY_REGS+N_RESERVED_REGS+N_MAX_GENERIC_REGS-1)   ? 1 : 0;  // Accessed reg is contexted
    regfile_flags.is_read       = (cfg.req == 1'b1 && cfg.wen == 1'b1);
    regfile_flags.is_testset    = (cfg.req == 1'b1 && cfg.wen == 1'b1 && cfg.add[LOG_REGS+2-1:2] == REGFILE_MANDATORY_ACQUIRE) ? 1 : 0;  // Operation is a test&set to register context_ts
    regfile_flags.is_trigger    = (cfg.req == 1'b1 && cfg.wen == 1'b0 && cfg.add[LOG_REGS+2-1:2] == REGFILE_MANDATORY_TRIGGER && cfg.data == '0) ? 1 : 0;  // Operation is a trigger
    regfile_flags.is_commit     = (cfg.req == 1'b1 && cfg.wen == 1'b0 && cfg.add[LOG_REGS+2-1:2] == REGFILE_MANDATORY_TRIGGER) ? 1 : 0;  // Operation is a commit (or commit & trigger)
    regfile_flags.true_done     = ctrl_i.done & flags_o.is_working;                                                             // This is necessary because sometimes done is asserted as soon as rst_ni becomes 1
    flags_o.enable              = s_enable_after[3];                                                                            // Enable after three cycles from rst_ni
  end

  generate
    logic [LOG_REGS_MC-LOG_REGS-1:0] context_addr;

    if(N_CONTEXT>1) begin : multi_context_addr_gen
    assign context_addr = cfg.add[LOG_REGS_MC+2:LOG_REGS+2] - 1;
      always_comb
      begin
        if(~cfg.wen) begin
          regfile_in.addr = {pointer_context, cfg.add[LOG_REGS+2-1:2]};
        end
        else begin
          if(cfg.add[LOG_REGS_MC+2:LOG_REGS+2] == '0)
            regfile_in.addr = {pointer_context, cfg.add[LOG_REGS+2-1:2]};
          else
            regfile_in.addr = {context_addr,    cfg.add[LOG_REGS+2-1:2]};
        end
      end
    end
    else begin : single_context_addr_gen
      assign context_addr = '0;
      assign regfile_in.addr = cfg.add[LOG_REGS+2-1:2];
    end

  endgenerate

  // Register file address generation
  always_comb
  begin : regfile_addr_en_proc
    regfile_in.rden  = (regfile_flags.is_mandatory==0) ? cfg.req &  cfg.wen : 0;
    regfile_in.wren  = (regfile_flags.is_mandatory==0) ? cfg.req & ~cfg.wen : 0;
    regfile_in.wdata = cfg.data;
    regfile_in.src   = cfg.id;
    regfile_in.be    = cfg.be;
  end

  assign regfile_flags.pointer_context = pointer_context;
  assign regfile_flags.running_context = running_context;

  hwpe_ctrl_regfile #(
    .REGFILE_SCM    ( REGFILE_SCM    ),
    .N_CONTEXT      ( N_CONTEXT      ),
    .N_IO_REGS      ( N_IO_REGS      ),
    .N_GENERIC_REGS ( N_GENERIC_REGS ),
    .ID_WIDTH       ( ID_WIDTH       )
  ) i_regfile (
    .clk_i         ( clk_i         ),
    .rst_ni        ( rst_ni        ),
    .clear_i       ( clear_regfile ),
    .regfile_in_i  ( regfile_in    ),
    .regfile_out_o ( regfile_out   ),
    .flags_i       ( regfile_flags ),
    .reg_file      ( reg_file      )
  );

  assign cfg.r_data = regfile_out.rdata;

  // Extension read and write enable, accessing ID LSB
  logic ext_access;
  logic [4:0] ext_id_n;
  assign ext_access = (regfile_flags.is_mandatory == 1'b1) && (regfile_in.addr[LOG_REGS-1:0] == REGFILE_MANDATORY_RESERVED) & cfg.req;
  assign regfile_flags.ext_re     = ext_access & cfg.wen;
  assign regfile_flags.ext_we     = ext_access & ~cfg.wen;
  assign regfile_flags.ext_flags  = ctrl_i.ext_flags;

  // ID of ext request: bit-extend or slice
  generate if (ID_WIDTH >=5) begin
    assign ext_id_n = cfg.id[4:0];
  end else begin
    assign ext_id_n = {{(5-ID_WIDTH){1'b0}}, cfg.id};
  end endgenerate

  // If inputs registered: also register flags
  generate
    if (~EXT_IN_REGGED) begin : gen_assign_ext
      assign flags_o.ext_we       = regfile_flags.ext_we;
      assign flags_o.ext_re       = regfile_flags.ext_re;
      assign flags_o.ext_id       = ext_id_n;
    end else begin : gen_assign_ext
      always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ext_flags
        if(~rst_ni) begin
          flags_o.ext_we <= 1'b0;
          flags_o.ext_re <= 1'b0;
          flags_o.ext_id <= 5'b0;
        end else begin
          flags_o.ext_we <= regfile_flags.ext_we;
          flags_o.ext_re <= regfile_flags.ext_re;
          flags_o.ext_id <= ext_id_n;
        end
      end
    end
  endgenerate

  // FSM to set the running state
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : fsm_running
    if (rst_ni==0) begin
      running_state <= RUN_IDLE;
      flags_o.start      <= 0;
      flags_o.is_working    <= 0;
    end
    else if(clear_o == 1'b1) begin
      running_state <= RUN_IDLE;
      flags_o.start      <= 0;
      flags_o.is_working    <= 0;
    end
    else begin
      case (running_state)
        RUN_IDLE : begin
          if (running_context == pointer_context && regfile_flags.full_context == 0) begin
            running_state <= RUN_IDLE;
            flags_o.start      <= 0;
            flags_o.is_working    <= 0;
          end
          else if(regfile_flags.is_trigger | triggered_q) begin
            running_state <= RUN_STARTING;
            flags_o.start      <= 0;
            flags_o.is_working    <= 1;
          end
        end
        RUN_STARTING : begin
          // just to separate RUN_IDLE and running by an additional cycle
          running_state <= RUN_RUN;
          flags_o.start      <= 1;
          flags_o.is_working    <= 1;
        end
        RUN_RUN : begin
          if (regfile_flags.true_done == 1) begin
            running_state <= RUN_IDLE;
            flags_o.start      <= 0;
            flags_o.is_working    <= 0;
          end
          else begin
            running_state <= RUN_RUN;
            flags_o.start      <= 0;
            flags_o.is_working    <= 1;
          end
        end
        default : begin
          running_state <= RUN_IDLE;
          flags_o.start      <= 0;
          flags_o.is_working    <= 0;
        end
      endcase
    end
  end

  // FSM to control critical section of offload procedure
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : fsm_context
    if (rst_ni==0) begin
      regfile_flags.is_critical <= 0;
      context_state     <= CXT_IDLE;
    end
    else if(clear_o == 1'b1) begin
      regfile_flags.is_critical <= 0;
      context_state     <= CXT_IDLE;
    end
    else begin
      case (context_state)
        CXT_IDLE : begin
          if (regfile_flags.is_testset == 1 && regfile_flags.full_context==0) begin
            regfile_flags.is_critical <= 1;
            context_state     <= CXT_PROGRAM;
          end
          else begin
            regfile_flags.is_critical <= 0;
            context_state     <= CXT_IDLE;
          end
        end
        CXT_PROGRAM : begin
          if (regfile_flags.is_commit == 1) begin
            regfile_flags.is_critical <= 0;
            context_state     <= CXT_IDLE;
          end
          else begin
            regfile_flags.is_critical <= 1;
            context_state     <= CXT_PROGRAM;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : event_interrupt_proc
    if (rst_ni == 0)
      flags_o.evt <= '0;
    else if (clear_o == 1'b1)
      flags_o.evt <= '0;
    else begin
      for(int i=0; i<N_CORES; i++)
        flags_o.evt[i][N_EVT-1:1] <= (offloading_core[running_context] == i) ? ctrl_i.evt              : '0;
      for(int i=0; i<N_CORES; i++)
        flags_o.evt[i][0] <= (offloading_core[running_context] == i)         ? regfile_flags.true_done : 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : sw_evt_proc
    if(rst_ni == 1'b0) begin
      flags_o.sw_evt <= '0;
    end
    else if(clear_o == 1'b1) begin
      flags_o.sw_evt <= '0;
    end
    else if((cfg.req == 1'b1) && (cfg.wen == 1'b0) && (cfg.add[LOG_REGS+2-1:2]) == REGFILE_MANDATORY_SWEVT) begin
      flags_o.sw_evt[cfg.data[3:0]] <= 1'b1;
    end
    else begin
      flags_o.sw_evt <= '0;
    end
  end

  // any write to SOFT_CLEAR will trigger clear_o, but not clear_regfile (only when data is '0)
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : soft_clear_proc
    if(rst_ni == 1'b0) begin
      s_clear <= '0;
      clear_o <= 1'b0;
    end
    else begin
      if((s_clear == '0) && ((cfg.req == 1'b1) && (cfg.wen == 1'b0) && (cfg.add[LOG_REGS+2-1:2]) == REGFILE_MANDATORY_SOFTCLEAR))
        s_clear <= 2'b01;
      else if (s_clear != '0)
        s_clear <= s_clear + 2'b01;
      clear_o <= |(s_clear);
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : soft_clear_regfile_proc
    if(rst_ni == 1'b0) begin
      s_clear_regfile <= '0;
      clear_regfile <= 1'b0;
    end
    else begin
      if((s_clear_regfile == '0) && ((cfg.req == 1'b1) && (cfg.wen == 1'b0) && (cfg.add[LOG_REGS+2-1:2]) == REGFILE_MANDATORY_SOFTCLEAR && cfg.data=='0))
        s_clear_regfile <= 2'b01;
      else if (s_clear_regfile != '0)
        s_clear_regfile <= s_clear_regfile + 2'b01;
      clear_regfile <= |(s_clear_regfile);
    end
  end

  logic [ID_WIDTH-1:0] cfg_id_d, cfg_id_q;
  logic cfg_req_d, cfg_req_q;

  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(rst_ni == 1'b0)
      cfg_id_q <= '0;
    else if(cfg.req == 1'b1)
      cfg_id_q <= cfg_id_d;
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : cfg_r_valid_proc
    if(rst_ni == 1'b0)
      cfg_req_q <= 1'b0;
    else
      cfg_req_q <= cfg_req_d;
  end

  assign cfg_id_d = cfg.id;
  assign cfg_req_d = cfg.req;
  assign cfg.r_id = cfg_id_q;
  assign cfg.r_valid = cfg_req_q;
  assign cfg.gnt = '1;

endmodule