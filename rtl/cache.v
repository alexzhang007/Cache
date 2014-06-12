//Author      : Alex Zhang (cgzhangwei@gmail.com)
//Date        : Jun. 10. 2014
//Description : Implement the cache design with ref of Chandra M.R. Thimmannagari
//Features    : 8bits pseduo LRU replacement algorithm 
//              4-way set associated TLB.   -addr[31:30]
//              256bits cache lines.        -addr[11:0], addr[11:5] is index [4:0] is 0.
//              each way has 64 cache lines -addr[29:12] is tag.  
//              prefetch from main memory
//
`define DATA_W  32
`define ADDR_W  32
`define WAY_W   2
`define TAG_W   18
`define INDEX_W 7
`define BYTE_W  3
`define RESV_W  2 
module cache_4way_64KB(
clk,
resetn,
iRd,
iWr,
iData,
iAddr,
oData,
oHit
);
input clk;
input iRd;
input iWr;
input iData;
input iAddr;
output oData;
output oHit;
wire [`DATA_W-1:0]  iData;
wire [`ADDR_W-1:0]  iAddr;
reg  [`DATA_W-1:0]  oData;
reg  [`WAY_W-1:0]   rWay;
reg  [`TAG_W-1:0]   rTag;
reg  [`INDEX_W-1:0] rIndex;
reg  [`BYTE_W-1:0]  rByte;
reg  [`RESV_W-1:0]  rResv;
reg                 oHit;

wire []

always @(iAddr) begin 
    {rWay, rTag, rIndex, rByte, rResv} = iAddr;
end 

always @(posedge clk or negedge resetn) begin 
    if (~resetn) begin  
      
    end else begin 
        casex (rWay)
            2'b00 : begin 
                        rEnWay0Tag    <= 1'b1; 
                        rAddrWay0Tag  <= rIndex;
                    end 
            2'b01 : begin 
                        rEnWay1Tag <= 1'b1; 
                        rAddrWay1Tag  <= rIndex;
                    end
            2'b10 : begin 
                        rEnWay2Tag <= 1'b1; 
                        rAddrWay2Tag  <= rIndex;
                    end
            2'b11 : begin 
                        rEnWay3Tag <= 1'b1; 
                        rAddrWay3Tag  <= rIndex;
                    end
        endcase 
        rHit0 <=( (oDataWay0Tag[`TAG_W+1-1:1] == rTag ) & oDataWay0Tag[0]) ? 1'b1 : 1'b0;
        rHit1 <=( (oDataWay1Tag[`TAG_W+1-1:1] == rTag ) & oDataWay1Tag[0]) ? 1'b1 : 1'b0;
        rHit2 <=( (oDataWay2Tag[`TAG_W+1-1:1] == rTag ) & oDataWay2Tag[0]) ? 1'b1 : 1'b0;
        rHit3 <=( (oDataWay3Tag[`TAG_W+1-1:1] == rTag ) & oDataWay3Tag[0]) ? 1'b1 : 1'b0;
        oHit  <= rHit0 | rHit1 | rHit2 | rHit3;
    end 
end 

//Operate on the memory
always @(*)begin 
    if(iRd & rHit0) begin 
        oData = rByte==3'b000 ? oDataWay0Data[ 31:  0] : 
                rByte==3'b001 ? oDataWay0Data[ 63: 32] : 
                rByte==3'b010 ? oDataWay0Data[ 95: 64] : 
                rByte==3'b011 ? oDataWay0Data[127: 96] : 
                rByte==3'b100 ? oDataWay0Data[159:128] : 
                rByte==3'b101 ? oDataWay0Data[191:160] : 
                rByte==3'b110 ? oDataWay0Data[223:192] : 
                rByte==3'b111 ? oDataWay0Data[255:224] : 32'b0;
    end else if (iRd & rHit1) begin 
        oData = rByte==3'b000 ? oDataWay1Data[ 31:  0] : 
                rByte==3'b001 ? oDataWay1Data[ 63: 32] : 
                rByte==3'b010 ? oDataWay1Data[ 95: 64] : 
                rByte==3'b011 ? oDataWay1Data[127: 96] : 
                rByte==3'b100 ? oDataWay1Data[159:128] : 
                rByte==3'b101 ? oDataWay1Data[191:160] : 
                rByte==3'b110 ? oDataWay1Data[223:192] : 
                rByte==3'b111 ? oDataWay1Data[255:224] : 32'b0;
    end else if (iRd & rHit2) begin 
        oData = rByte==3'b000 ? oDataWay2Data[ 31:  0] : 
                rByte==3'b001 ? oDataWay2Data[ 63: 32] : 
                rByte==3'b010 ? oDataWay2Data[ 95: 64] : 
                rByte==3'b011 ? oDataWay2Data[127: 96] : 
                rByte==3'b100 ? oDataWay2Data[159:128] : 
                rByte==3'b101 ? oDataWay2Data[191:160] : 
                rByte==3'b110 ? oDataWay2Data[223:192] : 
                rByte==3'b111 ? oDataWay2Data[255:224] : 32'b0;
    end else if (iRd & rHit3) begin 
        oData = rByte==3'b000 ? oDataWay3Data[ 31:  0] : 
                rByte==3'b001 ? oDataWay3Data[ 63: 32] : 
                rByte==3'b010 ? oDataWay3Data[ 95: 64] : 
                rByte==3'b011 ? oDataWay3Data[127: 96] : 
                rByte==3'b100 ? oDataWay3Data[159:128] : 
                rByte==3'b101 ? oDataWay3Data[191:160] : 
                rByte==3'b110 ? oDataWay3Data[223:192] : 
                rByte==3'b111 ? oDataWay3Data[255:224] : 32'b0;
    end
    if(iWr & rHit0) begin 
         rWrByte0 = (rByte==3'b000) ? iData : oDataWay0Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? iData : oDataWay0Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? iData : oDataWay0Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? iData : oDataWay0Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? iData : oDataWay0Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? iData : oDataWay0Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? iData : oDataWay0Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? iData : oDataWay0Data[255:224]; 
         rWrDataWay0 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,wWrByte0};
         rWrWay0     = 1'b1;
    end else if(iWr & rHit1) begin 
         rWrByte0 = (rByte==3'b000) ? iData : oDataWay1Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? iData : oDataWay1Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? iData : oDataWay1Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? iData : oDataWay1Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? iData : oDataWay1Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? iData : oDataWay1Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? iData : oDataWay1Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? iData : oDataWay1Data[255:224]; 
         rWrDataWay1 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,wWrByte0};
         rWrWay1     = 1'b1;
    end else if(iWr & rHit2) begin 
         rWrByte0 = (rByte==3'b000) ? iData : oDataWay2Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? iData : oDataWay2Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? iData : oDataWay2Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? iData : oDataWay2Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? iData : oDataWay2Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? iData : oDataWay2Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? iData : oDataWay2Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? iData : oDataWay2Data[255:224]; 
         rWrDataWay2 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,wWrByte0};
         rWrWay2     = 1'b1;
    end else if(iWr & rHit1) begin 
         rWrByte0 = (rByte==3'b000) ? iData : oDataWay3Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? iData : oDataWay3Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? iData : oDataWay3Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? iData : oDataWay3Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? iData : oDataWay3Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? iData : oDataWay3Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? iData : oDataWay3Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? iData : oDataWay3Data[255:224]; 
         rWrDataWay3 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,wWrByte0};
         rWrWay3     = 1'b1;
    end else begin 
         rWrWay0     = 1'b0;
         rWrWay1     = 1'b0;
         rWrWay2     = 1'b0;
         rWrWay3     = 1'b0;
    end 
end 

//Data Cache line is 256 bit
ssram #(.AW(7), .DW(256)) way0_data_ram (
  .clk(clk),
  .iEnable(rHit0),
  .iWr(wWrWay0),
  .iAddr(rAddrWay0Tag),
  .iData(rWrDataWay0),
  .oData(rDataWay0Data)
);
ssram #(.AW(7), .DW(256)) way1_data_ram (
  .clk(clk),
  .iEnable(rHit1),
  .iWr(wWrWay1),
  .iAddr(rAddrWay1Tag),
  .iData(rWrDataWay1),
  .oData(rDataWay1Data)
);
ssram #(.AW(7), .DW(256)) way2_data_ram (
  .clk(clk),
  .iEnable(rHit2),
  .iWr(wWrWay2),
  .iAddr(rAddrWay2Tag),
  .iData(rWrDataWay2),
  .oData(rDataWay2Data)
);
ssram #(.AW(7), .DW(256)) way3_data_ram (
  .clk(clk),
  .iEnable(rHit3),
  .iWr(wWrWay3),
  .iAddr(rAddrWay3Tag),
  .iData(rWrDataWay3),
  .oData(rDataWay3Data)
);

//Tag+Valid is Data of Tag TLB
ssram #(.AW(7), .DW(19) ) way0_tag_ram (
  .clk(clk),
  .iEnable(rEnWay0Tag),
  .iWr(rWrWay0Tag),
  .iAddr(rAddrWay0Tag),
  .iData(),
  .oData(rDataWay0Tag)
);
ssram #(.AW(7), .DW(19) ) way1_tag_ram (
  .clk(clk),
  .iEnable(rEnWay1Tag),
  .iWr(rWrWay1Tag),
  .iAddr(rAddrWay1Tag),
  .iData(),
  .oData(rDataWay1Tag)
);
ssram #(.AW(7), .DW(19) ) way2_tag_ram (
  .clk(clk),
  .iEnable(rEnWay2Tag),
  .iWr(rWrWay2Tag),
  .iAddr(rAddrWay2Tag),
  .iData(),
  .oData(rDataWay2Tag)
);
ssram #(.AW(7), .DW(19) ) way3_tag_ram (
  .clk(clk),
  .iEnable(rEnWay3Tag),
  .iWr(rWrWay3Tag),
  .iAddr(rAddrWay3Tag),
  .iData(),
  .oData(rDataWay3Tag)
);

ssram #(.AW(7), .DW(8)) pseudo_LRU_ram(
  .clk(clk),
  .iEnable(),
  .iWr(),
  .iAddr(),
  .iData(),
  .oData()
);
endmodule 
