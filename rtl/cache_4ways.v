//////////////////////////////////////////////////////////////////////////////////////////
//Copyright (c) 2014 by Grision Technology Inc. (GTI), and Alex Zhang  
//All rights reserved. 
//
//The contents of this file should not be disclosed to third parties, copied or duplicated
//in any form, in whole or in part, without the prior permission of the author, founder of 
//GTI company.  
//////////////////////////////////////////////////////////////////////////////////////////
//Author      : Alex Zhang (cgzhangwei@gmail.com)
//Date        : 10-14-2014
//Description : cache_4way implementation
//              Features :
//              * 4way set-associated cache
//              * multiwords cache line: 512 bits and 256 entries.
//              * write-back policy: 
//              * LRU replacement rule: 
`include "cache_define.vh"
module cache_4ways (
input             cclk,
input             cresetn,
input      [31:0] req_address,
input      [31:0] req_data,
input      [1:0]  req_op,       //2'b01 - read req, 2'b10 - write req, 2'b11 - fill req 
input             req_last,     //When it is fill req, req_last to indicate the last data.
input             req_valid,
output reg        ack_hit,
output reg        ack_valid,
output reg [1:0]  ack_type,     //2'b11 - write-back; 2'b01 - read ack; 2'b10 - write ack ; 2'b00 - fetch memory
output reg [31:0] ack_data,
output reg        ack_last      //When block is needed to be write-back, ack is the last data.
);
///Stage 0 
wire [`CA_TAG_W-1:0]   req_tag = req_valid && (req_op==2'b01 || req_op==2'b10)? req_address[`CA_TAG_R] : 0;
wire [`CA_INDEX_W-1:0] req_index = req_valid && (req_op==2'b01 || req_op==2'b10) ? req_address[`CA_INDEX_R] : 0;
wire [`CA_BLOCK_W-1:0] req_block = req_valid && (req_op==2'b01 || req_op==2'b10) ? req_address[`CA_BLOCK_R] : 0;
wire                   fetch_resp = req_valid ? req_op== 2'b11 : 1'b0;
wire                   fetch_resp_last = req_valid & req_op==2'b11 & req_last;
wire wr_cs_set0 = 1; 
wire wr_cs_set1 = 1; 
wire wr_cs_set2 = 1; 
wire wr_cs_set3 = 1; 

wire [`CA_INDEX_W-1:0] rd_addr_set0 = req_index; 
wire [`CA_INDEX_W-1:0] rd_addr_set1 = req_index; 
wire [`CA_INDEX_W-1:0] rd_addr_set2 = req_index; 
wire [`CA_INDEX_W-1:0] rd_addr_set3 = req_index; 
wire                   rd_we_set0   = ~req_valid;
wire                   rd_cs_set0   = req_valid;
wire                   rd_we_set1   = ~req_valid;
wire                   rd_cs_set1   = req_valid;
wire                   rd_we_set2   = ~req_valid;
wire                   rd_cs_set2   = req_valid;
wire                   rd_we_set3   = ~req_valid;
wire                   rd_cs_set3   = req_valid;
wire [`TR_TAG_W-1:0]   tr_tag_out0, tr_tag_out1, tr_tag_out2, tr_tag_out3;
wire [`TR_LRU_W-1:0]   tr_lru_out0, tr_lru_out1, tr_lru_out2, tr_lru_out3;
wire [`TR_DIRTY_W-1:0] tr_dirty_out0, tr_dirty_out1, tr_dirty_out2, tr_dirty_out3;
wire [`TR_VALID_W-1:0] tr_valid_out0, tr_valid_out1, tr_valid_out2, tr_valid_out3;
wire                   req_valid_p0;
ffd_posedge_async_reset#(1) stag0_valid_reg (.clk(cclk), .resetn(cresetn), .D(req_valid), .Q(req_valid_p0));
wire [1:0]             req_op_p0;
ffd_posedge_async_reset#(2) stage0_op_reg (.clk(cclk), .resetn(cresetn), .D(req_op), .Q(req_op_p0));
wire [`CA_TAG_W-1:0]   req_tag_p0;
ffd_posedge_async_reset#(`CA_TAG_W) stage0_tag_reg (.clk(cclk), .resetn(cresetn), .D(req_tag), .Q(req_tag_p0));
wire [`CA_BLOCK_W-1:0] req_block_p0;
ffd_posedge_async_reset#(`CA_BLOCK_W) stage0_block_reg (.clk(cclk), .resetn(cresetn), .D(req_block), .Q(req_block_p0));
wire [31:0]            req_data_p0;
ffd_posedge_async_reset#(32) stage0_data_reg (.clk(cclk), .resetn(cresetn), .D(req_data), .Q(req_data_p0));

//Stage 1
wire [`TR_LINE_N-1:0]  rd_tag_set0, rd_tag_set1, rd_tag_set2, rd_tag_set3;
reg  [`TR_LINE_N-1:0] tr_data_in0, tr_data_in1, tr_data_in2, tr_data3; 
assign {tr_tag_out0, tr_lru_out0, tr_dirty_out0, tr_valid_out0} = rd_tag_set0;
assign {tr_tag_out1, tr_lru_out1, tr_dirty_out1, tr_valid_out1} = rd_tag_set1;
assign {tr_tag_out2, tr_lru_out2, tr_dirty_out2, tr_valid_out2} = rd_tag_set2;
assign {tr_tag_out3, tr_lru_out3, tr_dirty_out3, tr_valid_out3} = rd_tag_set3;

wire [3:0] tr_valid = {tr_valid_out3, tr_valid_out2, tr_valid_out1, tr_valid_out0};
wire [3:0] tr_dirty = {tr_dirty_out3, tr_dirty_out2, tr_dirty_out1, tr_dirty_out0};
wire tr_replace = &tr_valid;
wire tr_flush   = |tr_dirty;
//tag_ram fill set is calculated in the RA_REPLACE state. 
reg [3:0] tr_fill_set;
always @(*) begin 
  casex(tr_valid)
    4'b???0 : tr_fill_set = 4'b0001;
    4'b??01 : tr_fill_set = 4'b0010;
    4'b?011 : tr_fill_set = 4'b0100;
    4'b0111 : tr_fill_set = 4'b1000;
    default : tr_fill_set = 4'b0000;
  endcase
end 

reg  [`CACHE_LINE_N-1:0] dr_data_in0, dr_data_in1, dr_data_in2, dr_data_in3;
wire [`CACHE_LINE_N-1:0] rd_data_set0, rd_data_set1, rd_data_set2, rd_data_set3;
always @(*) begin 
  case (req_block_p0)
    4'b0000 : dr_data_in0 = rd_data_set0[0  +: 32] |req_data_p0; 
    4'b0001 : dr_data_in0 = rd_data_set0[32 +: 32] |req_data_p0; 
    4'b0010 : dr_data_in0 = rd_data_set0[64 +: 32] |req_data_p0; 
    4'b0011 : dr_data_in0 = rd_data_set0[96 +: 32] |req_data_p0; 
    4'b0100 : dr_data_in0 = rd_data_set0[128+: 32] |req_data_p0; 
    4'b0101 : dr_data_in0 = rd_data_set0[160+: 32] |req_data_p0; 
    4'b0110 : dr_data_in0 = rd_data_set0[192+: 32] |req_data_p0; 
    4'b0111 : dr_data_in0 = rd_data_set0[224+: 32] |req_data_p0; 
    4'b1000 : dr_data_in0 = rd_data_set0[256+: 32] |req_data_p0; 
    4'b1001 : dr_data_in0 = rd_data_set0[288+: 32] |req_data_p0; 
    4'b1010 : dr_data_in0 = rd_data_set0[320+: 32] |req_data_p0; 
    4'b1011 : dr_data_in0 = rd_data_set0[352+: 32] |req_data_p0; 
    4'b1100 : dr_data_in0 = rd_data_set0[384+: 32] |req_data_p0; 
    4'b1101 : dr_data_in0 = rd_data_set0[416+: 32] |req_data_p0; 
    4'b1110 : dr_data_in0 = rd_data_set0[448+: 32] |req_data_p0; 
    4'b1111 : dr_data_in0 = rd_data_set0[480+: 32] |req_data_p0; 
    default : dr_data_in0 = rd_data_set0 ;
  endcase 
  case (req_block_p0)
    4'b0000 : dr_data_in1 = rd_data_set1[0  +: 32] |req_data_p0; 
    4'b0001 : dr_data_in1 = rd_data_set1[32 +: 32] |req_data_p0; 
    4'b0010 : dr_data_in1 = rd_data_set1[64 +: 32] |req_data_p0; 
    4'b0011 : dr_data_in1 = rd_data_set1[96 +: 32] |req_data_p0; 
    4'b0100 : dr_data_in1 = rd_data_set1[128+: 32] |req_data_p0; 
    4'b0101 : dr_data_in1 = rd_data_set1[160+: 32] |req_data_p0; 
    4'b0110 : dr_data_in1 = rd_data_set1[192+: 32] |req_data_p0; 
    4'b0111 : dr_data_in1 = rd_data_set1[224+: 32] |req_data_p0; 
    4'b1000 : dr_data_in1 = rd_data_set1[256+: 32] |req_data_p0; 
    4'b1001 : dr_data_in1 = rd_data_set1[288+: 32] |req_data_p0; 
    4'b1010 : dr_data_in1 = rd_data_set1[320+: 32] |req_data_p0; 
    4'b1011 : dr_data_in1 = rd_data_set1[352+: 32] |req_data_p0; 
    4'b1100 : dr_data_in1 = rd_data_set1[384+: 32] |req_data_p0; 
    4'b1101 : dr_data_in1 = rd_data_set1[416+: 32] |req_data_p0; 
    4'b1110 : dr_data_in1 = rd_data_set1[448+: 32] |req_data_p0; 
    4'b1111 : dr_data_in1 = rd_data_set1[480+: 32] |req_data_p0; 
    default : dr_data_in1 = rd_data_set1 ;
  endcase 
  case (req_block_p0)
    4'b0000 : dr_data_in2 = rd_data_set2[0  +: 32] |req_data_p0; 
    4'b0001 : dr_data_in2 = rd_data_set2[32 +: 32] |req_data_p0; 
    4'b0010 : dr_data_in2 = rd_data_set2[64 +: 32] |req_data_p0; 
    4'b0011 : dr_data_in2 = rd_data_set2[96 +: 32] |req_data_p0; 
    4'b0100 : dr_data_in2 = rd_data_set2[128+: 32] |req_data_p0; 
    4'b0101 : dr_data_in2 = rd_data_set2[160+: 32] |req_data_p0; 
    4'b0110 : dr_data_in2 = rd_data_set2[192+: 32] |req_data_p0; 
    4'b0111 : dr_data_in2 = rd_data_set2[224+: 32] |req_data_p0; 
    4'b1000 : dr_data_in2 = rd_data_set2[256+: 32] |req_data_p0; 
    4'b1001 : dr_data_in2 = rd_data_set2[288+: 32] |req_data_p0; 
    4'b1010 : dr_data_in2 = rd_data_set2[320+: 32] |req_data_p0; 
    4'b1011 : dr_data_in2 = rd_data_set2[352+: 32] |req_data_p0; 
    4'b1100 : dr_data_in2 = rd_data_set2[384+: 32] |req_data_p0; 
    4'b1101 : dr_data_in2 = rd_data_set2[416+: 32] |req_data_p0; 
    4'b1110 : dr_data_in2 = rd_data_set2[448+: 32] |req_data_p0; 
    4'b1111 : dr_data_in2 = rd_data_set2[480+: 32] |req_data_p0; 
    default : dr_data_in2 = rd_data_set2 ;
  endcase 
  case (req_block_p0)
    4'b0000 : dr_data_in3 = rd_data_set3[0  +: 32] |req_data_p0; 
    4'b0001 : dr_data_in3 = rd_data_set3[32 +: 32] |req_data_p0; 
    4'b0010 : dr_data_in3 = rd_data_set3[64 +: 32] |req_data_p0; 
    4'b0011 : dr_data_in3 = rd_data_set3[96 +: 32] |req_data_p0; 
    4'b0100 : dr_data_in3 = rd_data_set3[128+: 32] |req_data_p0; 
    4'b0101 : dr_data_in3 = rd_data_set3[160+: 32] |req_data_p0; 
    4'b0110 : dr_data_in3 = rd_data_set3[192+: 32] |req_data_p0; 
    4'b0111 : dr_data_in3 = rd_data_set3[224+: 32] |req_data_p0; 
    4'b1000 : dr_data_in3 = rd_data_set3[256+: 32] |req_data_p0; 
    4'b1001 : dr_data_in3 = rd_data_set3[288+: 32] |req_data_p0; 
    4'b1010 : dr_data_in3 = rd_data_set3[320+: 32] |req_data_p0; 
    4'b1011 : dr_data_in3 = rd_data_set3[352+: 32] |req_data_p0; 
    4'b1100 : dr_data_in3 = rd_data_set3[384+: 32] |req_data_p0; 
    4'b1101 : dr_data_in3 = rd_data_set3[416+: 32] |req_data_p0; 
    4'b1110 : dr_data_in3 = rd_data_set3[448+: 32] |req_data_p0; 
    4'b1111 : dr_data_in3 = rd_data_set3[480+: 32] |req_data_p0; 
    default : dr_data_in3 = rd_data_set3 ;
  endcase 
end 

reg [31:0] dr_data_out0, dr_data_out1, dr_data_out2, dr_data_out3;
always @(*) begin 
  case (req_block_p0)
    4'b0000 : dr_data_out0 = rd_data_set0[0  +:32];
    4'b0001 : dr_data_out0 = rd_data_set0[32 +:32];
    4'b0010 : dr_data_out0 = rd_data_set0[64 +:32];
    4'b0011 : dr_data_out0 = rd_data_set0[96 +:32];
    4'b0100 : dr_data_out0 = rd_data_set0[128+:32];
    4'b0101 : dr_data_out0 = rd_data_set0[160+:32];
    4'b0110 : dr_data_out0 = rd_data_set0[192+:32];
    4'b0111 : dr_data_out0 = rd_data_set0[224+:32];
    4'b1000 : dr_data_out0 = rd_data_set0[256+:32];
    4'b1001 : dr_data_out0 = rd_data_set0[288+:32];
    4'b1010 : dr_data_out0 = rd_data_set0[320+:32];
    4'b1011 : dr_data_out0 = rd_data_set0[352+:32];
    4'b1100 : dr_data_out0 = rd_data_set0[384+:32];
    4'b1101 : dr_data_out0 = rd_data_set0[416+:32];
    4'b1110 : dr_data_out0 = rd_data_set0[448+:32];
    4'b1111 : dr_data_out0 = rd_data_set0[480+:32];
    default : dr_data_out0 = 32'bx;
  endcase
  case (req_block_p0)
    4'b0000 : dr_data_out1 = rd_data_set1[0  +:32];
    4'b0001 : dr_data_out1 = rd_data_set1[32 +:32];
    4'b0010 : dr_data_out1 = rd_data_set1[64 +:32];
    4'b0011 : dr_data_out1 = rd_data_set1[96 +:32];
    4'b0100 : dr_data_out1 = rd_data_set1[128+:32];
    4'b0101 : dr_data_out1 = rd_data_set1[160+:32];
    4'b0110 : dr_data_out1 = rd_data_set1[192+:32];
    4'b0111 : dr_data_out1 = rd_data_set1[224+:32];
    4'b1000 : dr_data_out1 = rd_data_set1[256+:32];
    4'b1001 : dr_data_out1 = rd_data_set1[288+:32];
    4'b1010 : dr_data_out1 = rd_data_set1[320+:32];
    4'b1011 : dr_data_out1 = rd_data_set1[352+:32];
    4'b1100 : dr_data_out1 = rd_data_set1[384+:32];
    4'b1101 : dr_data_out1 = rd_data_set1[416+:32];
    4'b1110 : dr_data_out1 = rd_data_set1[448+:32];
    4'b1111 : dr_data_out1 = rd_data_set1[480+:32];
    default : dr_data_out1 = 32'bx;
  endcase
  case (req_block_p0)
    4'b0000 : dr_data_out2 = rd_data_set2[0  +:32];
    4'b0001 : dr_data_out2 = rd_data_set2[32 +:32];
    4'b0010 : dr_data_out2 = rd_data_set2[64 +:32];
    4'b0011 : dr_data_out2 = rd_data_set2[96 +:32];
    4'b0100 : dr_data_out2 = rd_data_set2[128+:32];
    4'b0101 : dr_data_out2 = rd_data_set2[160+:32];
    4'b0110 : dr_data_out2 = rd_data_set2[192+:32];
    4'b0111 : dr_data_out2 = rd_data_set2[224+:32];
    4'b1000 : dr_data_out2 = rd_data_set2[256+:32];
    4'b1001 : dr_data_out2 = rd_data_set2[288+:32];
    4'b1010 : dr_data_out2 = rd_data_set2[320+:32];
    4'b1011 : dr_data_out2 = rd_data_set2[352+:32];
    4'b1100 : dr_data_out2 = rd_data_set2[384+:32];
    4'b1101 : dr_data_out2 = rd_data_set2[416+:32];
    4'b1110 : dr_data_out2 = rd_data_set2[448+:32];
    4'b1111 : dr_data_out2 = rd_data_set2[480+:32];
    default : dr_data_out2 = 32'bx;
  endcase
  case (req_block_p0)
    4'b0000 : dr_data_out3 = rd_data_set3[0  +:32];
    4'b0001 : dr_data_out3 = rd_data_set3[32 +:32];
    4'b0010 : dr_data_out3 = rd_data_set3[64 +:32];
    4'b0011 : dr_data_out3 = rd_data_set3[96 +:32];
    4'b0100 : dr_data_out3 = rd_data_set3[128+:32];
    4'b0101 : dr_data_out3 = rd_data_set3[160+:32];
    4'b0110 : dr_data_out3 = rd_data_set3[192+:32];
    4'b0111 : dr_data_out3 = rd_data_set3[224+:32];
    4'b1000 : dr_data_out3 = rd_data_set3[256+:32];
    4'b1001 : dr_data_out3 = rd_data_set3[288+:32];
    4'b1010 : dr_data_out3 = rd_data_set3[320+:32];
    4'b1011 : dr_data_out3 = rd_data_set3[352+:32];
    4'b1100 : dr_data_out3 = rd_data_set3[384+:32];
    4'b1101 : dr_data_out3 = rd_data_set3[416+:32];
    4'b1110 : dr_data_out3 = rd_data_set3[448+:32];
    4'b1111 : dr_data_out3 = rd_data_set3[480+:32];
    default : dr_data_out3 = 32'bx;
  endcase
end 

reg tr_dirty_in0, tr_dirty_in1, tr_dirty_in2, tr_dirty_in3;
reg [1:0] tr_lru_in0, tr_lru_in1, tr_lru_in2, tr_lru_in3;
wire hit_set0 = (tr_tag_out0 == req_tag_p0) & tr_valid_out0;
wire hit_set1 = (tr_tag_out1 == req_tag_p0) & tr_valid_out1;
wire hit_set2 = (tr_tag_out2 == req_tag_p0) & tr_valid_out2;
wire hit_set3 = (tr_tag_out3 == req_tag_p0) & tr_valid_out3;

assign hit = hit_set0 | hit_set1 | hit_set2 | hit_set3;

always @(*) begin  
  if (hit_set0 | tr_fill_set[0]) begin
    tr_dirty_in0 = 1'b1;  //FIXME: Only the write request needs to update the dirty bit.
    tr_dirty_in1 = 1'b0;
    tr_dirty_in2 = 1'b0;
    tr_dirty_in3 = 1'b0;
    if (tr_lru_out0 == 2'b00) begin  
      tr_lru_in3 =  tr_lru_out3 - 1 ;
      tr_lru_in2 =  tr_lru_out2 - 1 ;
      tr_lru_in1 =  tr_lru_out1 - 1 ;
      tr_lru_in0 = 2'b11;
    end else if (tr_lru_out0 == 2'b01 || tr_lru_out0 == 2'b10) begin 
      if (tr_lru_out3 == 2'b00) tr_lru_in3 = tr_lru_out3; else tr_lru_in3 = tr_lru_out3 -1 ;
      if (tr_lru_out2 == 2'b00) tr_lru_in2 = tr_lru_out2; else tr_lru_in2 = tr_lru_out2 -1 ;
      if (tr_lru_out1 == 2'b00) tr_lru_in1 = tr_lru_out1; else tr_lru_in1 = tr_lru_out1 -1 ;
      tr_lru_in0 = 2'b11;
    end else begin 
      tr_lru_in3 = tr_lru_out3;
      tr_lru_in2 = tr_lru_out2;
      tr_lru_in1 = tr_lru_out1;
      tr_lru_in0 = tr_lru_out0;
    end 
  end else if (hit_set1 | tr_fill_set[1]) begin
    tr_dirty_in0 = 1'b0;
    tr_dirty_in1 = 1'b1;
    tr_dirty_in2 = 1'b0;
    tr_dirty_in3 = 1'b0;
    if (tr_lru_out1 == 2'b00) begin  
      tr_lru_in3 =  tr_lru_out3 - 1 ;
      tr_lru_in2 =  tr_lru_out2 - 1 ;
      tr_lru_in0 =  tr_lru_out0 - 1 ;
      tr_lru_in1 = 2'b11;
    end else if (tr_lru_out1 == 2'b01 || tr_lru_out1 == 2'b10) begin 
      if (tr_lru_out3 == 2'b00) tr_lru_in3 = tr_lru_out3; else tr_lru_in3 = tr_lru_out3 -1 ;
      if (tr_lru_out2 == 2'b00) tr_lru_in2 = tr_lru_out2; else tr_lru_in2 = tr_lru_out2 -1 ;
      if (tr_lru_out0 == 2'b00) tr_lru_in0 = tr_lru_out0; else tr_lru_in0 = tr_lru_out0 -1 ;
      tr_lru_in1 = 2'b11;
    end else begin 
      tr_lru_in3 = tr_lru_out3;
      tr_lru_in2 = tr_lru_out2;
      tr_lru_in1 = tr_lru_out1;
      tr_lru_in0 = tr_lru_out0;
    end 
  end else if (hit_set2 | tr_fill_set[2]) begin
    tr_dirty_in0 = 1'b0;
    tr_dirty_in1 = 1'b0;
    tr_dirty_in2 = 1'b1;
    tr_dirty_in3 = 1'b0;
    if (tr_lru_out2 == 2'b00) begin  
      tr_lru_in3 =  tr_lru_out3 - 1 ;
      tr_lru_in1 =  tr_lru_out1 - 1 ;
      tr_lru_in0 =  tr_lru_out0 - 1 ;
      tr_lru_in2 = 2'b11;
    end else if (tr_lru_out2 == 2'b01 || tr_lru_out2 == 2'b10) begin 
      if (tr_lru_out3 == 2'b00) tr_lru_in3 = tr_lru_out3; else tr_lru_in3 = tr_lru_out3 -1 ;
      if (tr_lru_out1 == 2'b00) tr_lru_in1 = tr_lru_out1; else tr_lru_in1 = tr_lru_out1 -1 ;
      if (tr_lru_out0 == 2'b00) tr_lru_in0 = tr_lru_out0; else tr_lru_in0 = tr_lru_out0 -1 ;
      tr_lru_in2 = 2'b11;
    end else begin 
      tr_lru_in3 = tr_lru_out3;
      tr_lru_in2 = tr_lru_out2;
      tr_lru_in1 = tr_lru_out1;
      tr_lru_in0 = tr_lru_out0;
    end 
  end else if (hit_set3 | tr_fill_set[3]) begin
    tr_dirty_in0 = 1'b0;
    tr_dirty_in1 = 1'b1;
    tr_dirty_in2 = 1'b0;
    tr_dirty_in3 = 1'b0;
    if (tr_lru_out3 == 2'b00) begin  
      tr_lru_in1 =  tr_lru_out1 - 1 ;
      tr_lru_in2 =  tr_lru_out2 - 1 ;
      tr_lru_in0 =  tr_lru_out0 - 1 ;
      tr_lru_in3 = 2'b11;
    end else if (tr_lru_out3 == 2'b01 || tr_lru_out3 == 2'b10) begin 
      if (tr_lru_out1 == 2'b00) tr_lru_in1 = tr_lru_out1; else tr_lru_in1 = tr_lru_out1 -1 ;
      if (tr_lru_out2 == 2'b00) tr_lru_in2 = tr_lru_out2; else tr_lru_in2 = tr_lru_out2 -1 ;
      if (tr_lru_out0 == 2'b00) tr_lru_in0 = tr_lru_out0; else tr_lru_in0 = tr_lru_out0 -1 ;
      tr_lru_in3 = 2'b11;
    end else begin 
      tr_lru_in3 = tr_lru_out3;
      tr_lru_in2 = tr_lru_out2;
      tr_lru_in1 = tr_lru_out1;
      tr_lru_in0 = tr_lru_out0;
    end 
  end 
end 
assign tr_data_in0 = {tr_tag_out0, tr_lru_in0, tr_dirty_in0, tr_valid_out0};
assign tr_data_in1 = {tr_tag_out1, tr_lru_in1, tr_dirty_in1, tr_valid_out1};
assign tr_data_in2 = {tr_tag_out2, tr_lru_in2, tr_dirty_in2, tr_valid_out2};
assign tr_data_in3 = {tr_tag_out3, tr_lru_in3, tr_dirty_in3, tr_valid_out3};

wire                 req_valid_p1;
ffd_posedge_async_reset#(1) stag1_valid_reg (.clk(cclk), .resetn(cresetn), .D(req_valid_p0), .Q(req_valid_p1));
wire [1:0]           req_op_p1;
ffd_posedge_async_reset#(2) stage1_op_reg (.clk(cclk), .resetn(cresetn), .D(req_op_p0), .Q(req_op_p1));
wire [`CA_BLOCK_W-1:0] req_block_p1;
ffd_posedge_async_reset#(`CA_BLOCK_W) stage1_block_reg (.clk(cclk), .resetn(cresetn), .D(req_block_p0), .Q(req_block_p1));
wire [31:0] dr_data_out0_p1, dr_data_out1_p1, dr_data_out2_p1, dr_data_out3_p1;
ffd_posedge_async_reset#(32) stage1_dr_data_out0_reg (.clk(cclk), .resetn(cresetn), .D(dr_data_out0), .Q(dr_data_out0_p1));
ffd_posedge_async_reset#(32) stage1_dr_data_out1_reg (.clk(cclk), .resetn(cresetn), .D(dr_data_out1), .Q(dr_data_out1_p1));
ffd_posedge_async_reset#(32) stage1_dr_data_out2_reg (.clk(cclk), .resetn(cresetn), .D(dr_data_out2), .Q(dr_data_out2_p1));
ffd_posedge_async_reset#(32) stage1_dr_data_out3_reg (.clk(cclk), .resetn(cresetn), .D(dr_data_out3), .Q(dr_data_out3_p1));
wire [3:0] hit_p1; //FIXME : Write assertion to make sure the hit_p1 is one hot. 
ffd_posedge_async_reset#(4) stage1_hit_reg (.clk(cclk), .resetn(cresetn), .D({hit_set3, hit_set2, hit_set1, hit_set0}), .Q(hit_p1));
reg [31:0] hit_dr_data_out;
always @(*) begin 
  case (hit_p1)
    4'b0001 : hit_dr_data_out = dr_data_out0_p1;
    4'b0010 : hit_dr_data_out = dr_data_out1_p1;
    4'b0100 : hit_dr_data_out = dr_data_out2_p1;
    4'b1000 : hit_dr_data_out = dr_data_out3_p1;
    default : hit_dr_data_out = 32'bx;
  endcase 
end  
//Stage 3
//request access FSM
parameter RA_IDLE = 0,
          RA_DIRECT_HIT  = 1, //request access directly hit
          RA_FETCH_MEM   = 2, //request access not hit, need fetch memory
          RA_DIRECT_FILL = 3, //fetch memory directly fill into block
          RA_REPLACE     = 4, //fetch memory need to replace the block
          RA_DIRTY_FLUSH = 5, //replaced block need to be flushed to main memory
          RA_REPLACE_ERR = 6, //replaced block has no dirty 
          RA_FETCH_STALL = 7; //When it is fetch memory, it enters the stall state;
reg [2:0] ra_cs, ra_ns; 
always @(posedge cclk or negedge cresetn)
  if (~cresetn)
    ra_cs <= RA_IDLE;
  else 
    ra_cs <= ra_ns;

always @(*) begin 
  ra_ns = ra_cs;
  case (ra_cs) 
    RA_IDLE : begin 
      if (req_valid_p0 & ~hit) 
        ra_ns = RA_FETCH_MEM;
      else if (req_valid_p0 & hit) 
        ra_ns = RA_DIRECT_HIT; 
      else 
        ra_ns = RA_IDLE;
    end 
    RA_DIRECT_HIT : begin 
      ra_ns = RA_IDLE;
    end 
    RA_FETCH_MEM : begin 
      ra_ns = RA_FETCH_STALL;
    end 
    RA_FETCH_STALL : begin 
      if (fetch_resp) 
        ra_ns = RA_FETCH_STALL;
      else if (fetch_resp_last)
        ra_ns = RA_REPLACE;
      else 
        ra_ns = RA_FETCH_STALL;
    end 
    RA_REPLACE : begin 
      if (~tr_replace | (tr_replace&~tr_flush)) 
        ra_ns = RA_DIRECT_FILL; 
      else if (tr_replace&tr_flush)
        ra_ns = RA_DIRTY_FLUSH;
      else 
        ra_ns = RA_REPLACE_ERR;
    end 
    RA_DIRECT_FILL : begin 
      ra_ns = RA_IDLE;
    end 
    RA_DIRTY_FLUSH : begin 
      ra_ns = RA_DIRECT_FILL; //First flush the data and the fill.
    end 
    RA_REPLACE_ERR : begin 
      ra_ns = RA_IDLE;
    end 
    default : ra_ns = RA_IDLE;
  endcase 
end 

reg wr_dr_set0, wr_dr_set1, wr_dr_set2, wr_dr_set3;
reg wr_tr_set0, wr_tr_set1, wr_tr_set2, wr_tr_set3;
reg [`CACHE_LINE_W-1:0] dr_data_in;
reg wr_dr_tr;
reg dirty_flush;
reg cache_exception;

always @(posedge cclk or negedge cresetn)
  if (~cresetn) begin 
    ack_hit         <= 1'b0;
    ack_valid       <= 1'b0;
    ack_type        <= 1'b0;
    ack_data        <= 0;
    ack_last        <= 0;
    wr_dr_set0      <= 0;
    wr_dr_set1      <= 0;
    wr_dr_set2      <= 0;
    wr_dr_set3      <= 0;
    wr_tr_set0      <= 0;
    wr_tr_set1      <= 0;
    wr_tr_set2      <= 0;
    wr_tr_set3      <= 0;
    wr_dr_tr        <= 0;
    dirty_flush     <= 0;
    cache_exception <= 0;
  end else begin 
    case (ra_cs)
      RA_IDLE : begin 
        ack_hit         <= 1'b0;
        ack_valid       <= 1'b0;
        ack_type        <= 1'b0;
        ack_data        <= 0;
        ack_last        <= 0;
        wr_dr_set0      <= 0;
        wr_dr_set1      <= 0;
        wr_dr_set2      <= 0;
        wr_dr_set3      <= 0;
        wr_tr_set0      <= 0;
        wr_tr_set1      <= 0;
        wr_tr_set2      <= 0;
        wr_tr_set3      <= 0;
        wr_dr_tr        <= 0;
        dirty_flush     <= 0;
        cache_exception <= 0;
      end 
      //If request access hit directly, write the data to the data_ram and dirty the tag_ram. 
      //give the ack data 
      RA_DIRECT_HIT : begin 
        if (req_op_p1 == 2'b10) begin //write hit 
           ack_hit    <= 1'b1;
           ack_valid  <= 1'b1;
           ack_type   <= 2'b10;
           wr_dr_set0 <= hit_p1[0] ;
           wr_dr_set1 <= hit_p1[1] ;
           wr_dr_set2 <= hit_p1[2] ;
           wr_dr_set3 <= hit_p1[3] ;
           wr_tr_set0 <= hit_p1[0] ;
           wr_tr_set1 <= hit_p1[1] ;
           wr_tr_set2 <= hit_p1[2] ;
           wr_tr_set3 <= hit_p1[3] ;
        end else if (req_op_p1== 2'b01 ) begin  //read hit
           ack_hit   <= 1'b1;
           ack_valid <= 1'b1;
           ack_type  <= 2'b01;
           ack_data  <= hit_dr_data_out;
        end 
      end 
      RA_FETCH_MEM : begin 
        ack_type  <= 2'b00; 
        ack_valid <= 2'b1;
        ack_hit   <= 1'b0;
      end 
      RA_FETCH_STALL : begin 
        if (fetch_resp)
          dr_data_in <= dr_data_in << 32 | req_data; 
      end 
      RA_REPLACE : begin 

      end 
      RA_DIRECT_FILL : begin 
        wr_dr_tr <= 1'b1; //write into the data_ram and tag_ram
        dirty_flush <= 1'b0;
      end 
      RA_DIRTY_FLUSH : begin 
        dirty_flush <= 1'b1;
      end 
      RA_REPLACE_ERR : begin 
        cache_exception <= 1'b1;
      end
    endcase
  end 

wire [`CA_INDEX_W-1:0] wr_addr_set0, wr_addr_set1, wr_addr_set2, wr_addr_set3;
wire [`CACHE_LINE_N-1:0] wr_data_set0, wr_data_set1, wr_data_set2, wr_data_set3;
wire [`TR_LINE_N-1:0] wr_tag_set0, wr_tag_set1, wr_tag_set2, wr_tag_set3;
assign wr_data_set0 = wr_dr_set0 ? dr_data_in0 : tr_fill_set[0] ? dr_data_in : 512'bx;
assign wr_data_set1 = wr_dr_set1 ? dr_data_in1 : tr_fill_set[1] ? dr_data_in : 512'bx;
assign wr_data_set2 = wr_dr_set2 ? dr_data_in2 : tr_fill_set[2] ? dr_data_in : 512'bx;
assign wr_data_set3 = wr_dr_set3 ? dr_data_in3 : tr_fill_set[3] ? dr_data_in : 512'bx;
assign wr_we_set0   = wr_dr_set0| (tr_fill_set[0] & wr_dr_tr);
assign wr_we_set1   = wr_dr_set1| (tr_fill_set[1] & wr_dr_tr);
assign wr_we_set2   = wr_dr_set2| (tr_fill_set[2] & wr_dr_tr);
assign wr_we_set3   = wr_dr_set3| (tr_fill_set[3] & wr_dr_tr);
assign wr_tag_set0  = tr_data_in0;
assign wr_tag_set1  = tr_data_in1;
assign wr_tag_set2  = tr_data_in2;
assign wr_tag_set3  = tr_data_in3;
assign wr_we_set0   = wr_tr_set0 | (tr_fill_set[0] & wr_dr_tr);
assign wr_we_set1   = wr_tr_set1 | (tr_fill_set[1] & wr_dr_tr);
assign wr_we_set2   = wr_tr_set2 | (tr_fill_set[2] & wr_dr_tr);
assign wr_we_set3   = wr_tr_set3 | (tr_fill_set[3] & wr_dr_tr);
assign wr_addr_set0 = req_index; //FIXME : Need to correct it.
assign wr_addr_set1 = req_index;
assign wr_addr_set2 = req_index;
assign wr_addr_set3 = req_index;


//Using the dual-port ram, it is to support he write and read in parallel.
ram_dp_sr_sw #(.DATA_WIDTH(`CACHE_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) data_ram_set0 (
  .clk       (cclk),
  .address_0 (wr_addr_set0),
  .data_0    (wr_data_set0),
  .cs_0      (wr_cs_set0),
  .we_0      (wr_we_set0),
  .oe_0      (1'b0),
  .address_1 (rd_addr_set0),
  .data_1    (rd_data_set0),
  .cs_1      (rd_cs_set0),
  .we_1      (rd_we_set0),
  .oe_1      (1'b1)
);
ram_dp_sr_sw #(.DATA_WIDTH(`CACHE_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) data_ram_set1 (
  .clk       (cclk),
  .address_0 (wr_addr_set1),
  .data_0    (wr_data_set1),
  .cs_0      (wr_cs_set1),
  .we_0      (wr_we_set1),
  .oe_0      (1'b0),
  .address_1 (rd_addr_set1),
  .data_1    (rd_data_set1),
  .cs_1      (rd_cs_set1),
  .we_1      (rd_we_set1),
  .oe_1      (1'b1)
);
ram_dp_sr_sw #(.DATA_WIDTH(`CACHE_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) data_ram_set2 (
  .clk       (cclk),
  .address_0 (wr_addr_set2),
  .data_0    (wr_data_set2),
  .cs_0      (wr_cs_set2),
  .we_0      (wr_we_set2),
  .oe_0      (1'b0),
  .address_1 (rd_addr_set2),
  .data_1    (rd_data_set2),
  .cs_1      (rd_cs_set2),
  .we_1      (rd_we_set2),
  .oe_1      (1'b1)
);
ram_dp_sr_sw #(.DATA_WIDTH(`CACHE_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) data_ram_set3 (
  .clk       (cclk),
  .address_0 (wr_addr_set3),
  .data_0    (wr_data_set3),
  .cs_0      (wr_cs_set3),
  .we_0      (wr_we_set3),
  .oe_0      (1'b0),
  .address_1 (rd_addr_set3),
  .data_1    (rd_data_set3),
  .cs_1      (rd_cs_set3),
  .we_1      (rd_we_set3),
  .oe_1      (1'b1)
);


//Tag Ram 
ram_dp_sr_sw #(.DATA_WIDTH(`TR_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) tag_ram_set0 (
  .clk       (cclk        ),
  .address_0 (wr_addr_set0),
  .data_0    (wr_tag_set0 ),
  .cs_0      (wr_cs_set0  ),
  .we_0      (wr_we_set0  ),
  .oe_0      (1'b0        ),
  .address_1 (rd_addr_set0),
  .data_1    (rd_tag_set0 ),
  .cs_1      (rd_cs_set0  ),
  .we_1      (rd_we_set0  ),
  .oe_1      (1'b1        )
);
ram_dp_sr_sw #(.DATA_WIDTH(`TR_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) tag_ram_set1 (
  .clk       (cclk        ),
  .address_0 (wr_addr_set1),
  .data_0    (wr_tag_set1 ),
  .cs_0      (wr_cs_set1  ),
  .we_0      (wr_we_set1  ),
  .oe_0      (1'b0        ),
  .address_1 (rd_addr_set1),
  .data_1    (rd_tag_set1 ),
  .cs_1      (rd_cs_set1  ),
  .we_1      (rd_we_set1  ),
  .oe_1      (1'b1        )
);
ram_dp_sr_sw #(.DATA_WIDTH(`TR_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) tag_ram_set2 (
  .clk       (cclk        ),
  .address_0 (wr_addr_set2),
  .data_0    (wr_tag_set2 ),
  .cs_0      (wr_cs_set2  ),
  .we_0      (wr_we_set2  ),
  .oe_0      (1'b0        ),
  .address_1 (rd_addr_set2),
  .data_1    (rd_tag_set2 ),
  .cs_1      (rd_cs_set2  ),
  .we_1      (rd_we_set2  ),
  .oe_1      (1'b1        )
);
ram_dp_sr_sw #(.DATA_WIDTH(`TR_LINE_N), .ADDR_WIDTH(`CACHE_DEPTH_W)) tag_ram_set3 (
  .clk       (cclk        ),
  .address_0 (wr_addr_set3),
  .data_0    (wr_tag_set3 ),
  .cs_0      (wr_cs_set3  ),
  .we_0      (wr_we_set3  ),
  .oe_0      (1'b0        ),
  .address_1 (rd_addr_set3),
  .data_1    (rd_tag_set3 ),
  .cs_1      (rd_cs_set3  ),
  .we_1      (rd_we_set3  ),
  .oe_1      (1'b1        )
);


endmodule 
