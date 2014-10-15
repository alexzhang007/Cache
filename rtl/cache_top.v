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
//Write to cache interface


//Read to cache interface


//Cache to Memory fetch(read) interface
input          aclk,    //connect to the MC clock
input          aresetn, 
input          cm_arready,
output         cm_arvalid,
output [5:0]   cm_arid,
output [31:0]  cm_araddr.
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
output [31:0]  cm_awaddr.
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
output         mc_bready,

);

cache_4ways cache_4ways(
  .cclk        (cclk),
  .cresetn     (cresetn),
  .req_address (),
  .req_data,
  .req_op,       //2'b01 - read req, 2'b10 - write req, 2'b11 - fill req 
  .req_last,     //When it is fill req, req_last to indicate the last data.
  .req_valid,
  .ack_hit,
  .ack_valid,
  .ack_type,     //2'b11 - write-back; 2'b01 - read ack; 2'b10 - write ack ; 2'b00 - fetch memory
  .ack_data,
  .ack_last      //When block is needed to be write-back, ack is the last data.
);
cache_controller cache_controller(
  .cclk,
  .cresetn,
  .req_address,
  .req_valid,
  .req_op,
  .ack_hit,
  .ack_valid,
  .ack_type,     //2'b11 - write-back; 2'b01 - read ack; 2'b10 - write ack ; 2'b00 - fetch memory
  .ack_data,
  .ack_last,
  .aclk,    //connect to the MC clock
  .aresetn, 
  .cm_arready,
  .cm_arvalid,
  .cm_arid,
  .cm_araddr,
  .cm_arlen,
  .cm_arsize,
  .cm_arburst,
  .cm_arlock,
  .cm_arcache,
  .cm_arprot,
  .mc_rready,
  .mc_rvalid,
  .mc_rdata,
  .mc_rid,
  .mc_rresp,
  .mc_rlast,
  .cm_awready,
  .cm_awvalid,
  .cm_awid,
  .cm_awaddr,
  .cm_awlen,
  .cm_awsize,
  .cm_awburst,
  .cm_awlock,
  .cm_awcache,
  .cm_awprot,
  .cm_wid,
  .cm_wdata,
  .cm_wstrb,
  .cm_wlast,
  .cm_wvalid,
  .cm_wready,
  .mc_bid,
  .mc_bresp,
  .mc_bvalid,
  .mc_bready

);
endmodule 
