//////////////////////////////////////////////////////////////////////////////////////////
//Copyright (c) 2014 by Grision Technology Inc. (GTI), and Alex Zhang  
//All rights reserved. 
//
//The contents of this file should not be disclosed to third parties, copied or duplicated
//in any form, in whole or in part, without the prior permission of the author, founder of 
//GTI company.  
//////////////////////////////////////////////////////////////////////////////////////////
//Author      : Alex Zhang (cgzhangwei@gmail.com)
//Date        : 10-15-2014
//Description : cache controller implementation
`include "cache_define.vh"
module cache_controller (
input          cclk,
input          cresetn,
input  [31:0]  req_address,
input          req_valid,
input  [1:0]   req_op,
input          ack_hit,
input          ack_valid,
input  [1:0]   ack_type,     //2'b11 - write-back; 2'b01 - read ack; 2'b10 - write ack ; 2'b00 - fetch memory
input  [31:0]  ack_data,
input          ack_last,
//Fetch memory interface 
input          aclk,    //connect to the MC clock
input          aresetn, 
input          cm_arready,
output         cm_arvalid,
output [5:0]   cm_arid,
output [31:0]  cm_araddr,
output [3:0]   cm_arlen,
output [2:0]   cm_arsize,
output [1:0]   cm_arburst,
output [1:0]   cm_arlock,
output [3:0]   cm_arcache,
output [2:0]   cm_arprot,

output         mc_rready,
input          mc_rvalid,
input  [31:0]  mc_rdata,
input  [5:0]   mc_rid,
input  [1:0]   mc_rresp,
input          mc_rlast,
//Cache to Memory write back interface
input          cm_awready,
output         cm_awvalid,
output [5:0]   cm_awid,
output [31:0]  cm_awaddr,
output [3:0]   cm_awlen,
output [2:0]   cm_awsize,
output [1:0]   cm_awburst,
output [1:0]   cm_awlock,
output [3:0]   cm_awcache,
output [2:0]   cm_awprot,
output [5:0]   cm_wid,
output [31:0]  cm_wdata,
output [3:0]   cm_wstrb,
output         cm_wlast,
output         cm_wvalid,
input          cm_wready,
input  [5:0]   mc_bid,
input  [1:0]   mc_bresp,
input          mc_bvalid,
output         mc_bready
);

wire [32:0] pop_data;
wire        ack_pop;
wire        ack_full;
wire        ack_empty;
localparam OK_RESP = 2'b00;
async_fifo #(.DSIZE(33), .ASIZE(5)) ack_data_fifo (
  .wclk(cclk),
  .wrst_n(cresetn),
  .rclk(aclk),
  .rrst_n(aresetn),
  .wdata({ack_data, ack_last}),
  .rdata(pop_data),
  .wfull(ack_full),
  .wempty(ack_empty),
  .wr(ack_type==2'b11 && ar_valid),
  .rd(ack_pop)
);


wire [31:0] req_addr_buf;
ffd_posedge_sync_reset #(31) req_addr_reg (.clk(cclk), .resetn(cresetn), .en(req_valid), .D(req_address), .Q(req_addr_buf) );
wire [1:0] req_op_buf;
ffd_posedge_sync_reset #(31) req_op_reg (.clk(cclk), .resetn(cresetn), .en(req_valid), .D(req_op), .Q(req_op_buf) );

wire fetch_memory = ack_valid & ( ack_type == 2'b00 );
wire write_back   = ack_valid & ( ack_type == 2'b11 );
wire w_resp_confirmed = mc_bvalid & (mc_bresp==OK_RESP) & mc_bready; 
reg         ar_valid;
reg [5:0]   ar_id;
reg [31:0]  ar_addr;
reg [3:0]   ar_len;
reg [2:0]   ar_size;
reg [1:0]   ar_burst;
reg [1:0]   ar_lock;
reg [3:0]   ar_cache;
reg [2:0]   ar_prot;

wire fetch_memory_sync;
dsi_sync_pulse fetch_memory_sync_reg (
  .clka(cclk),
  .rsta_(cresetn),
  .clkb(aclk),
  .rstb_(aresetn),
  .din(fetch_memory),
  .dout(fetch_memory_sync)
);

always @(posedge aclk or negedge aresetn)
  if (~aresetn) begin 
    ar_valid   <= 1'b0;
    ar_addr    <= 0;
    ar_len     <= 0;
    ar_size    <= 0;
    ar_burst   <= 0;
    ar_lock    <= 0;
    ar_cache   <= 0;
    ar_prot    <= 0;
    ar_id      <= 0;
  end else begin 
    if (fetch_memory_sync) begin 
      ar_valid   <= 1'b1;
    else if (cm_arready)
      ar_valid   <= 1'b0;

    if (fetch_memory_sync) begin
      ar_addr    <= {req_addr_buf[`CA_TAG_R], 14'b0}; //fetch the cache line
      ar_len     <= 4'b1111;
      ar_size    <= 3'b010; //4bytes in a transfer
      ar_burst   <= 2'b01;  //increase mode
      ar_lock    <= 2'b00;  
      ar_cache   <= 4'b0;
      ar_prot    <= 3'b010; //nonsecure access
      ar_id      <= `CACHE_ID;
    end else if (cm_arready) begin 
      ar_addr    <= 0;
      ar_len     <= 0;
      ar_size    <= 0;
      ar_burst   <= 0;
      ar_lock    <= 0;
      ar_cache   <= 0;
      ar_prot    <= 0;
      ar_id      <= 0;
    end 
  end 
assign cm_arvalid  = ar_valid;
assign cm_arid     = ar_id;
assign cm_araddr   = ar_addr;
assign cm_arlen    = ar_len;
assign cm_arsize   = ar_size;
assign cm_arburst  = ar_burst;
assign cm_arlock   = ar_lock;
assign cm_arcache  = ar_cache;
assign cm_arprot   = ar_prot;

wire write_back_sync;
dsi_sync_pulse write_back_sync_reg (
  .clka(cclk),
  .rsta_(cresetn),
  .clkb(aclk),
  .rstb_(aresetn),
  .din(write_back),
  .dout(write_back_sync)
);
reg         aw_valid;
reg [5:0]   aw_id;
reg [31:0]  aw_addr.
reg [3:0]   aw_len;
reg [2:0]   aw_size;
reg [1:0]   aw_burst;
reg [1:0]   aw_lock;
reg [3:0]   aw_cache;
reg [2:0]   aw_prot;
reg [5:0]   w_id;
reg [31:0]  w_data;
reg [3:0]   w_strb;
reg         w_last;
reg         w_valid;
parameter  AW_IDLE = 0, //Waits for the non-empty of Data Fifo
           AW_DATA = 1, //Keep transmit the data as soon as accepted by slave
           AW_WFRC = 2; //Waits for posted write response to complete
reg [2:0]  aw_ns, aw_cs;

wire allow_read = aw_valid & cm_awready;
wire w_ready = cm_wready;
always @(posedge aclk or negedge aresetn)
  if (~aresetn)
    aw_cs <= AW_IDLE;
  else 
    aw_cs <= aw_ns;

always @(*) begin 
  aw_ns = 0;
  case (1)
    aw_cs[AW_IDLE] : begin 
      if (allow_read & !ack_empty) 
        aw_ns[AW_DATA] = 1'b1;
      else 
        aw_ns[AW_IDLE] = 1'b1;
    end 
    aw_cs[AW_DATA] : begin 
      if (w_valid & w_ready & w_last)
        aw_cs[AW_WFRC] = 1'b1;
      else if (w_valid & w_ready & ack_empty)
        aw_cs[AW_IDLE] = 1'b1;
      else 
        aw_cs[AW_DATA] = 1'b1;
    end 
    aw_cs[AW_WFRC] : begin 
      if (w_resp_confirmed)
        aw_ns[AW_IDLE] = 1'b1;
      else 
        aw_ns[AW_WFRC] = 1'b1;
    end 
    default : aw_ns = 0;
  endcase 
end 

assign ack_pop = aw_cs[AW_DATA] & !ack_empty;

always @(posedge aclk or negedge aresetn)
  if (~aresetn) begin 
    aw_valid   <= 1'b0;
    aw_addr    <= 0;
    aw_len     <= 0;
    aw_size    <= 0;
    aw_burst   <= 0;
    aw_lock    <= 0;
    aw_cache   <= 0;
    aw_prot    <= 0;
    aw_id      <= 0;
  end else begin 
    if (write_back_sync) begin 
      aw_valid   <= 1'b1;
    else if (cm_arready)
      aw_valid   <= 1'b0;

    if (write_back_sync) begin
      aw_addr    <= {req_addr_buf[`CA_TAG_R], 14'b0}; //fetch the cache line
      aw_len     <= 4'b1111;
      aw_size    <= 3'b010; //4bytes in a transfer
      aw_burst   <= 2'b01;  //increase mode
      aw_lock    <= 2'b00;  
      aw_cache   <= 4'b0;
      aw_prot    <= 3'b010; //nonsecure access
      aw_id      <= `CACHE_ID;
    end else if (cm_arready) begin 
      aw_addr    <= 0;
      aw_len     <= 0;
      aw_size    <= 0;
      aw_burst   <= 0;
      aw_lock    <= 0;
      aw_cache   <= 0;
      aw_prot    <= 0;
      aw_id      <= 0;
    end 
  end 

always @(posedge aclk or negedge aresetn)
  if (~aresetn) begin 

  end else begin 
    if (ack_pop)
      w_valid <= 1'b1;
    else if (w_ready)
      w_valid <= 1'b0;

    if (ack_pop) begin 
      w_data <= pop_data[32:1];
      w_id   <= `CACHE_ID;
      w_strb <= 4'b1111;
      w_last <= pop_data[0];
    end 
  end 
assign mc_bready = 1'b1;
assign cm_awvalid = aw_valid;
assign cm_awid    = aw_id;
assign cm_awaddr  = aw_addr;
assign cm_awlen   = aw_len;
assign cm_awsize  = aw_size;
assign cm_awburst = aw_burst;
assign cm_awlock  = aw_lock;
assign cm_awcache = aw_cache;
assign cm_awprot  = aw_prot;
assign cm_wid     = w_id;
assign cm_wdata   = w_data;
assign cm_wstrb   = w_strb;
assign cm_wlast   = w_last;
assign cm_wvalid  = w_valid;

endmodule 
