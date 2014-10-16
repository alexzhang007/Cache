//////////////////////////////////////////////////////////////////////////////////////////
//Copyright (c) 2014 by Grision Technology Inc. (GTI), and Alex Zhang  
//All rights reserved. 
//
//The contents of this file should not be disclosed to third parties, copied or duplicated
//in any form, in whole or in part, without the prior permission of the author, founder of 
//GTI company.  
//////////////////////////////////////////////////////////////////////////////////////////
//Author      : Alex Zhang (cgzhangwei@gmail.com)
//Date        : 10-11-2014
//Description : cache_4way implementation
//TO-DO       : This version is only having write-back mechanism. Need to add the write through option.
//            : When one request (read or write) is acked, the next request can be accepted. Needs to update to the pipeline working mode. 
//            : 
module cache_top (
input          cclk,
input          cresetn,
//Read/Write to cache interface
input          req_valid,
input  [31:0]  req_address,
input  [1:0]   req_op,  //2'b10 - write request; 2'b01 - read request
input  [31:0]  req_wdata,
output [31:0]  resp_rdata,
output         resp_valid,
output         resp_status,
//Cache to Memory fetch(read) interface
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
//Cache to Memory write interface
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

wire        c4_ack_hit;
wire        c4_ack_valid;
wire [1:0]  c4_ack_type;
wire [31:0] c4_ack_data;
wire        c4_ack_last;

wire [31:0] c4_req_address = req_valid ? req_address :  0;
wire [31:0] c4_req_wdata   = mc_rdata;
wire        c4_req_valid   = mc_rvalid & mc_rid == `CACHE_ID & mc_rresp==2'b00;
wire [1:0]  c4_req_op      = req_valid ? req_op : c4_req_valid ? 2'b11 : 2'bx;
wire        c4_req_last    = mc_rlast;
cache_4ways cache_4ways(
  .cclk        (cclk),
  .cresetn     (cresetn),
  .req_address (c4_req_address),
  .req_data    (c4_req_wdata),
  .req_op      (c4_req_op),       //2'b01 - read req, 2'b10 - write req, 2'b11 - fill req 
  .req_last    (c4_req_last),     //When it is fill req, req_last to indicate the last data.
  .req_valid   (c4_req_valid),
  .ack_hit     (c4_ack_hit),
  .ack_valid   (c4_ack_valid),
  .ack_type    (c4_ack_type),     //2'b11 - write-back; 2'b01 - read ack; 2'b10 - write ack ; 2'b00 - fetch memory
  .ack_data    (c4_ack_data),
  .ack_last    (c4_ack_last)  //When block is needed to be write-back, ack is the last data.
);
cache_controller cache_controller(
  .cclk        (cclk),
  .cresetn     (cresetn),
  .req_address (req_address),
  .req_valid   (req_valid),
  .req_op      (req_op),
  .ack_hit     (c4_ack_hit),
  .ack_valid   (c4_ack_valid),
  .ack_type    (c4_ack_type),     //2'b11 - write-back; 2'b01 - read ack; 2'b10 - write ack ; 2'b00 - fetch memory
  .ack_data    (c4_ack_data),
  .ack_last    (c4_ak_last),
  .aclk        (aclk),    //connect to the MC clock
  .aresetn     (aresetn), 
  .cm_arready  (cm_arready),
  .cm_arvalid  (cm_arvalid),
  .cm_arid     (cm_arid),
  .cm_araddr   (cm_araddr),
  .cm_arlen    (cm_arlen),
  .cm_arsize   (cm_arsize),
  .cm_arburst  (cm_arburst),
  .cm_arlock   (cm_arlock),
  .cm_arcache  (cm_arcache),
  .cm_arprot   (cm_arprot),
  .cm_awready  (cm_awready),
  .cm_awvalid  (cm_awvalid),
  .cm_awid     (cm_awid),
  .cm_awaddr   (cm_awaddr),
  .cm_awlen    (cm_awlen),
  .cm_awsize   (cm_awsize),
  .cm_awburst  (cm_awburst),
  .cm_awlock   (cm_awlock),
  .cm_awcache  (cm_awcache),
  .cm_awprot   (cm_awprot),
  .cm_wid      (cm_wid),
  .cm_wdata    (cm_wdata),
  .cm_wstrb    (cm_wstrb),
  .cm_wlast    (cm_wlast),
  .cm_wvalid   (cm_wvalid),
  .cm_wready   (cm_wready),
  .mc_bid      (mc_bid),
  .mc_bresp    (mc_bresp),
  .mc_bvalid   (mc_bvalid),
  .mc_bready   (mc_bready)
);
endmodule 
