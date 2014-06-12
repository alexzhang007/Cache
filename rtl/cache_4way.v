//Author      : Alex Zhang (cgzhangwei@gmail.com)
//Date        : Jun. 10. 2014
//Description : Implement the cache design with ref of Chandra M.R. Thimmannagari
//Features    : 8bits pseduo LRU replacement algorithm 
//              4-way set associated TLB.   -addr[31:30]
//              256bits cache lines.        -addr[11:0], addr[11:5] is index [4:0] is 0.
//              each way has 64 cache lines -addr[29:12] is tag.  
//              prefetch from main memory
//              Notice1: Synchronize the iData to data_mem interface
//              Notice2: Write and read should be interleave with at least one cyle
//
`define DATA_W  32
`define ADDR_W  32
`define WAY_W   2
`define TAG_W   20
`define INDEX_W 7
`define BYTE_W  3
`define RESV_W  2 
`define CL_W    256
module cache_4way_64KB(
clk,
resetn,
iRd,
iWr,
iData,
iAddr,
oData,
oReady,
oHit
);
input clk;
input resetn;
input iRd;
input iWr;
input iData;
input iAddr;
output oData;
output oReady;
output oHit;
wire [`DATA_W-1:0]  iData;
reg  [`DATA_W-1:0]  ppData;
reg  [`DATA_W-1:0]  pp2Data;
reg  [`DATA_W-1:0]  pp3Data;
wire [`ADDR_W-1:0]  iAddr;
reg  [`DATA_W-1:0]  oData;
reg  [`WAY_W-1:0]   rWay;
reg  [`TAG_W-1:0]   rTag;
reg  [`TAG_W-1:0]   ppTag;
reg  [`TAG_W-1:0]   pp2Tag;
reg  [`INDEX_W-1:0] rIndex;
reg  [`BYTE_W-1:0]  rByte;
reg  [`RESV_W-1:0]  rResv;
wire                oHit;
wire                oReady;
wire                wMiss;
reg                 rEnWay0;
reg  [`INDEX_W-1:0] rAddrWay0;     
reg                 rEnWay1;       
reg  [`INDEX_W-1:0] rAddrWay1;     
reg                 rEnWay2;       
reg  [`INDEX_W-1:0] rAddrWay2;     
reg                 rEnWay3;       
reg  [`INDEX_W-1:0] rAddrWay3;     
reg                 rEnLRU;        
reg  [`INDEX_W-1:0] rAddrLRU;      
reg                 rHit0;         
reg                 rHit1;         
reg                 rHit2;         
reg                 rHit3;         
reg  [1:0]          ppReady;       
reg  [1:0]          pp1Ready;      
reg  [1:0]          pp2Ready;      
reg                 ppLRU_Ready;   
reg                 pp1LRU_Ready;  
reg                 pp2LRU_Ready;  
reg                 rWrLRU;        
wire [`TAG_W:0]     wDataWay0Tag; //Tag+Valid
wire [`TAG_W:0]     wDataWay1Tag;
wire [`TAG_W:0]     wDataWay2Tag;
wire [`TAG_W:0]     wDataWay3Tag;
wire [`CL_W-1: 0]   wDataWay0Data;
wire [`CL_W-1: 0]   wDataWay1Data;
wire [`CL_W-1: 0]   wDataWay2Data;
wire [`CL_W-1: 0]   wDataWay3Data;
reg  [`DATA_W-1:0]  rWrByte0;
reg  [`DATA_W-1:0]  rWrByte1;
reg  [`DATA_W-1:0]  rWrByte2;
reg  [`DATA_W-1:0]  rWrByte3;
reg  [`DATA_W-1:0]  rWrByte4;
reg  [`DATA_W-1:0]  rWrByte5;
reg  [`DATA_W-1:0]  rWrByte6;
reg  [`DATA_W-1:0]  rWrByte7;
reg  [`CL_W-1:0]    rWrDataWay0;
reg                 rWrWay0;
reg  [`CL_W-1:0]    rWrDataWay1;
reg                 rWrWay1;
reg  [`CL_W-1:0]    rWrDataWay2;
reg                 rWrWay2;
reg  [`CL_W-1:0]    rWrDataWay3;
reg                 rWrWay3;
reg                 rWrWay0Tag;
reg                 rWrWay1Tag;
reg                 rWrWay2Tag;
reg                 rWrWay3Tag;
reg [`TAG_W:0]      rWrDataWay0Tag;
reg [`TAG_W:0]      rWrDataWay1Tag;
reg [`TAG_W:0]      rWrDataWay2Tag;
reg [`TAG_W:0]      rWrDataWay3Tag;
reg [7:0]           rDataLRUIn;
reg [7:0]           rDataLRUOut;

always @(iAddr) begin 
    {rTag, rIndex, rByte, rResv} = iAddr;
end 

assign oHit = rHit0 | rHit1 | rHit2 | rHit3;
assign wMiss = ~oHit;
assign oReady = | pp2Ready;

always @(posedge clk or negedge resetn) begin 
    if (~resetn) begin  
        rEnWay0       <= 1'b0;
        rAddrWay0     <= 7'b0;
        rEnWay1       <= 1'b0;
        rAddrWay1     <= 7'b0;
        rEnWay2       <= 1'b0;
        rAddrWay2     <= 7'b0;
        rEnWay3       <= 1'b0;
        rAddrWay3     <= 7'b0;
        rEnLRU        <= 1'b0;
        rAddrLRU      <= 7'b0;
        rHit0         <= 1'b0;
        rHit1         <= 1'b0;
        rHit2         <= 1'b0;
        rHit3         <= 1'b0;
        ppReady       <= 1'b0;
        pp1Ready      <= 1'b0;
        ppLRU_Ready   <= 1'b0;
        pp1LRU_Ready  <= 1'b0;
        pp2LRU_Ready  <= 1'b0;
        rWrLRU        <= 1'b0;
        ppData        <= 32'b0;
        pp2Data       <= 32'b0;
        pp3Data       <= 32'b0;
        ppTag         <= 20'h0;
        pp2Tag        <= 20'h0;
    end else begin 
        ppTag         <= rTag;
        pp2Tag        <= ppTag;
        rEnWay0       <= iRd | iWr ;  //If | rHit0 is added here, there will be another cycle delay.
        rAddrWay0     <= rIndex;
        rEnWay1       <= iRd | iWr ; 
        rAddrWay1     <= rIndex;
        rEnWay2       <= iRd | iWr ; 
        rAddrWay2     <= rIndex;
        rEnWay3       <= iRd | iWr ; 
        rAddrWay3     <= rIndex;
        rEnLRU        <= iRd | iWr | pp1LRU_Ready;
        rAddrLRU      <= rIndex;
        rHit0         <= (pp1LRU_Ready & (wDataWay0Tag[`TAG_W+1-1:1] == ppTag ) & wDataWay0Tag[0]) ? 1'b1 : 1'b0;
        rHit1         <= (pp1LRU_Ready & (wDataWay1Tag[`TAG_W+1-1:1] == ppTag ) & wDataWay1Tag[0]) ? 1'b1 : 1'b0;
        rHit2         <= (pp1LRU_Ready & (wDataWay2Tag[`TAG_W+1-1:1] == ppTag ) & wDataWay2Tag[0]) ? 1'b1 : 1'b0;
        rHit3         <= (pp1LRU_Ready & (wDataWay3Tag[`TAG_W+1-1:1] == ppTag ) & wDataWay3Tag[0]) ? 1'b1 : 1'b0;
        ppReady       <= {iRd , iWr};
        pp1Ready      <= ppReady;
        pp2Ready      <= pp1Ready;
        ppLRU_Ready   <= iRd | iWr;
        pp1LRU_Ready  <= ppLRU_Ready;
        pp2LRU_Ready  <= pp1LRU_Ready;
        rWrLRU        <= rHit0 | rHit1 | rHit2 | rHit3;
        ppData        <= iData;
        pp2Data       <= ppData;
        pp3Data       <= pp2Data;
    end 
end 

//Read Hit on the memory
always @(*)begin 
    if(pp2Ready[1] & rHit0) begin 
        oData = rByte==3'b000 ? wDataWay0Data[ 31:  0] : 
                rByte==3'b001 ? wDataWay0Data[ 63: 32] : 
                rByte==3'b010 ? wDataWay0Data[ 95: 64] : 
                rByte==3'b011 ? wDataWay0Data[127: 96] : 
                rByte==3'b100 ? wDataWay0Data[159:128] : 
                rByte==3'b101 ? wDataWay0Data[191:160] : 
                rByte==3'b110 ? wDataWay0Data[223:192] : 
                rByte==3'b111 ? wDataWay0Data[255:224] : 32'b0;
    end else if (pp2Ready[1] & rHit1) begin 
        oData = rByte==3'b000 ? wDataWay1Data[ 31:  0] : 
                rByte==3'b001 ? wDataWay1Data[ 63: 32] : 
                rByte==3'b010 ? wDataWay1Data[ 95: 64] : 
                rByte==3'b011 ? wDataWay1Data[127: 96] : 
                rByte==3'b100 ? wDataWay1Data[159:128] : 
                rByte==3'b101 ? wDataWay1Data[191:160] : 
                rByte==3'b110 ? wDataWay1Data[223:192] : 
                rByte==3'b111 ? wDataWay1Data[255:224] : 32'b0;
    end else if (pp2Ready[1] & rHit2) begin 
        oData = rByte==3'b000 ? wDataWay2Data[ 31:  0] : 
                rByte==3'b001 ? wDataWay2Data[ 63: 32] : 
                rByte==3'b010 ? wDataWay2Data[ 95: 64] : 
                rByte==3'b011 ? wDataWay2Data[127: 96] : 
                rByte==3'b100 ? wDataWay2Data[159:128] : 
                rByte==3'b101 ? wDataWay2Data[191:160] : 
                rByte==3'b110 ? wDataWay2Data[223:192] : 
                rByte==3'b111 ? wDataWay2Data[255:224] : 32'b0;
    end else if (pp2Ready[1] & rHit3) begin 
        oData = rByte==3'b000 ? wDataWay3Data[ 31:  0] : 
                rByte==3'b001 ? wDataWay3Data[ 63: 32] : 
                rByte==3'b010 ? wDataWay3Data[ 95: 64] : 
                rByte==3'b011 ? wDataWay3Data[127: 96] : 
                rByte==3'b100 ? wDataWay3Data[159:128] : 
                rByte==3'b101 ? wDataWay3Data[191:160] : 
                rByte==3'b110 ? wDataWay3Data[223:192] : 
                rByte==3'b111 ? wDataWay3Data[255:224] : 32'b0;
    end
end 

//Write Hit
always @(*) begin
    if(pp2Ready[0] & rHit0) begin 
         rWrByte0 = (rByte==3'b000) ? pp3Data : wDataWay0Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? pp3Data : wDataWay0Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? pp3Data : wDataWay0Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? pp3Data : wDataWay0Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? pp3Data : wDataWay0Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? pp3Data : wDataWay0Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? pp3Data : wDataWay0Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? pp3Data : wDataWay0Data[255:224]; 
         rWrDataWay0 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
         rWrWay0     = 1'b1;
    end else if(pp2Ready[0] & rHit1) begin 
         rWrByte0 = (rByte==3'b000) ? pp3Data : wDataWay1Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? pp3Data : wDataWay1Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? pp3Data : wDataWay1Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? pp3Data : wDataWay1Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? pp3Data : wDataWay1Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? pp3Data : wDataWay1Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? pp3Data : wDataWay1Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? pp3Data : wDataWay1Data[255:224]; 
         rWrDataWay1 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
         rWrWay1     = 1'b1;
    end else if(pp2Ready[0] & rHit2) begin 
         rWrByte0 = (rByte==3'b000) ? pp3Data : wDataWay2Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? pp3Data : wDataWay2Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? pp3Data : wDataWay2Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? pp3Data : wDataWay2Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? pp3Data : wDataWay2Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? pp3Data : wDataWay2Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? pp3Data : wDataWay2Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? pp3Data : wDataWay2Data[255:224]; 
         rWrDataWay2 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
         rWrWay2     = 1'b1;
    end else if(pp2Ready[0] & rHit1) begin 
         rWrByte0 = (rByte==3'b000) ? pp3Data : wDataWay3Data[ 31:  0];
         rWrByte1 = (rByte==3'b001) ? pp3Data : wDataWay3Data[ 63: 32];  
         rWrByte2 = (rByte==3'b010) ? pp3Data : wDataWay3Data[ 95: 64];  
         rWrByte3 = (rByte==3'b011) ? pp3Data : wDataWay3Data[127: 96];  
         rWrByte4 = (rByte==3'b100) ? pp3Data : wDataWay3Data[159:128];  
         rWrByte5 = (rByte==3'b101) ? pp3Data : wDataWay3Data[191:160];  
         rWrByte6 = (rByte==3'b110) ? pp3Data : wDataWay3Data[223:192];  
         rWrByte7 = (rByte==3'b111) ? pp3Data : wDataWay3Data[255:224]; 
         rWrDataWay3 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
         rWrWay3     = 1'b1;
    end else begin 
         rWrWay0     = 1'b0;
         rWrWay1     = 1'b0;
         rWrWay2     = 1'b0;
         rWrWay3     = 1'b0;
         rWrWay0Tag  = 1'b0;
         rWrWay1Tag  = 1'b0;
         rWrWay2Tag  = 1'b0;
         rWrWay3Tag  = 1'b0;
    end 
end 
//Update the LRU module 
always @(*) begin 
     if (pp2LRU_Ready & rHit0) begin 
        if (rDataLRUOut[1:0] ==2'b00)  begin 
            rDataLRUIn[7:6] = rDataLRUOut[7:6] -1;
            rDataLRUIn[5:4] = rDataLRUOut[5:4] -1;
            rDataLRUIn[3:2] = rDataLRUOut[3:2] -1;
            rDataLRUIn[1:0] = 2'b11;
        end else if (rDataLRUOut[1:0] == 2'b01) begin 
            if (rDataLRUOut[7:6]==2'b00) rDataLRUIn[7:6] = rDataLRUOut[7:6] ; else rDataLRUIn[7:6] = rDataLRUOut[7:6] -1; 
            if (rDataLRUOut[5:4]==2'b00) rDataLRUIn[5:4] = rDataLRUOut[5:4] ; else rDataLRUIn[5:4] = rDataLRUOut[5:4] -1; 
            if (rDataLRUOut[3:2]==2'b00) rDataLRUIn[3:2] = rDataLRUOut[3:2] ; else rDataLRUIn[3:2] = rDataLRUOut[3:2] -1; 
            rDataLRUIn[1:0] = 2'b11;
        end else if (rDataLRUOut[1:0] ==2'b10) begin 
            if (rDataLRUOut[7:6]==2'b11) rDataLRUIn[7:6] = rDataLRUOut[7:6] -1; else rDataLRUIn[7:6] = rDataLRUOut[7:6] ;
            if (rDataLRUOut[5:4]==2'b11) rDataLRUIn[5:4] = rDataLRUOut[5:4] -1; else rDataLRUIn[5:4] = rDataLRUOut[5:4] ;
            if (rDataLRUOut[3:2]==2'b11) rDataLRUIn[3:2] = rDataLRUOut[3:2] -1; else rDataLRUIn[3:2] = rDataLRUOut[3:2] ;
            rDataLRUIn[1:0] = 2'b11;
        end else begin 
            rDataLRUIn[7:6] = rDataLRUOut[7:6] ;
            rDataLRUIn[5:4] = rDataLRUOut[5:4] ;
            rDataLRUIn[3:2] = rDataLRUOut[3:2] ;
            rDataLRUIn[1:0] = rDataLRUOut[1:0] ;
        end 
     end  else if (ppLRU_Ready & rHit1) begin 
        if (rDataLRUOut[3:2] ==2'b00)  begin 
            rDataLRUIn[7:6] = rDataLRUOut[7:6] -1;
            rDataLRUIn[5:4] = rDataLRUOut[5:4] -1;
            rDataLRUIn[1:0] = rDataLRUOut[1:0] -1;
            rDataLRUIn[3:2] = 2'b11;
        end else if (rDataLRUOut[3:2] == 2'b01) begin 
            if (rDataLRUOut[7:6]==2'b00) rDataLRUIn[7:6] = rDataLRUOut[7:6] ; else rDataLRUIn[7:6] = rDataLRUOut[7:6] -1; 
            if (rDataLRUOut[5:4]==2'b00) rDataLRUIn[5:4] = rDataLRUOut[5:4] ; else rDataLRUIn[5:4] = rDataLRUOut[5:4] -1; 
            if (rDataLRUOut[1:0]==2'b00) rDataLRUIn[1:0] = rDataLRUOut[1:0] ; else rDataLRUIn[1:0] = rDataLRUOut[1:0] -1; 
            rDataLRUIn[3:2] = 2'b11;
        end else if (rDataLRUOut[3:2] ==2'b10) begin 
            if (rDataLRUOut[7:6]==2'b11) rDataLRUIn[7:6] = rDataLRUOut[7:6] -1; else rDataLRUIn[7:6] = rDataLRUOut[7:6] ;
            if (rDataLRUOut[5:4]==2'b11) rDataLRUIn[5:4] = rDataLRUOut[5:4] -1; else rDataLRUIn[5:4] = rDataLRUOut[5:4] ;
            if (rDataLRUOut[1:0]==2'b11) rDataLRUIn[1:0] = rDataLRUOut[1:0] -1; else rDataLRUIn[1:0] = rDataLRUOut[1:0] ;
            rDataLRUIn[3:2] = 2'b11;
        end else begin 
            rDataLRUIn[7:6] = rDataLRUOut[7:6] ;
            rDataLRUIn[5:4] = rDataLRUOut[5:4] ;
            rDataLRUIn[3:2] = rDataLRUOut[3:2] ;
            rDataLRUIn[1:0] = rDataLRUOut[1:0] ;
        end 
     end else if (ppLRU_Ready & rHit2) begin 
        if (rDataLRUOut[5:4] ==2'b00)  begin 
            rDataLRUIn[7:6] = rDataLRUOut[7:6] -1;
            rDataLRUIn[1:0] = rDataLRUOut[5:4] -1;
            rDataLRUIn[3:2] = rDataLRUOut[3:2] -1;
            rDataLRUIn[5:4] = 2'b11;
        end else if (rDataLRUOut[5:4] == 2'b01) begin 
            if (rDataLRUOut[7:6]==2'b00) rDataLRUIn[7:6] = rDataLRUOut[7:6] ; else rDataLRUIn[7:6] = rDataLRUOut[7:6] -1; 
            if (rDataLRUOut[1:0]==2'b00) rDataLRUIn[1:0] = rDataLRUOut[1:0] ; else rDataLRUIn[1:0] = rDataLRUOut[1:0] -1; 
            if (rDataLRUOut[3:2]==2'b00) rDataLRUIn[3:2] = rDataLRUOut[3:2] ; else rDataLRUIn[3:2] = rDataLRUOut[3:2] -1; 
            rDataLRUIn[5:4] = 2'b11;
        end else if (rDataLRUOut[5:4] ==2'b10) begin 
            if (rDataLRUOut[7:6]==2'b11) rDataLRUIn[7:6] = rDataLRUOut[7:6] -1; else rDataLRUIn[7:6] = rDataLRUOut[7:6] ;
            if (rDataLRUOut[1:0]==2'b11) rDataLRUIn[1:0] = rDataLRUOut[1:0] -1; else rDataLRUIn[1:0] = rDataLRUOut[1:0] ;
            if (rDataLRUOut[3:2]==2'b11) rDataLRUIn[3:2] = rDataLRUOut[3:2] -1; else rDataLRUIn[3:2] = rDataLRUOut[3:2] ;
            rDataLRUIn[5:4] = 2'b11;
        end else begin 
            rDataLRUIn[7:6] = rDataLRUOut[7:6] ;
            rDataLRUIn[5:4] = rDataLRUOut[5:4] ;
            rDataLRUIn[3:2] = rDataLRUOut[3:2] ;
            rDataLRUIn[1:0] = rDataLRUOut[1:0] ;
        end 
     end else if (ppLRU_Ready & rHit3) begin 
        if (rDataLRUOut[7:6] ==2'b00)  begin 
            rDataLRUIn[1:0] = rDataLRUOut[1:0] -1;
            rDataLRUIn[5:4] = rDataLRUOut[5:4] -1;
            rDataLRUIn[3:2] = rDataLRUOut[3:2] -1;
            rDataLRUIn[1:0] = 2'b11;
        end else if (rDataLRUOut[7:6] == 2'b01) begin 
            if (rDataLRUOut[1:0]==2'b00) rDataLRUIn[1:0] = rDataLRUOut[1:0] ; else rDataLRUIn[1:0] = rDataLRUOut[1:0] -1; 
            if (rDataLRUOut[5:4]==2'b00) rDataLRUIn[5:4] = rDataLRUOut[5:4] ; else rDataLRUIn[5:4] = rDataLRUOut[5:4] -1; 
            if (rDataLRUOut[3:2]==2'b00) rDataLRUIn[3:2] = rDataLRUOut[3:2] ; else rDataLRUIn[3:2] = rDataLRUOut[3:2] -1; 
            rDataLRUIn[7:6] = 2'b11;
        end else if (rDataLRUOut[7:6] ==2'b10) begin 
            if (rDataLRUOut[1:0]==2'b11) rDataLRUIn[1:0] = rDataLRUOut[1:0] -1; else rDataLRUIn[1:0] = rDataLRUOut[1:0] ;
            if (rDataLRUOut[5:4]==2'b11) rDataLRUIn[5:4] = rDataLRUOut[5:4] -1; else rDataLRUIn[5:4] = rDataLRUOut[5:4] ;
            if (rDataLRUOut[3:2]==2'b11) rDataLRUIn[3:2] = rDataLRUOut[3:2] -1; else rDataLRUIn[3:2] = rDataLRUOut[3:2] ;
            rDataLRUIn[7:6] = 2'b11;
        end else begin 
            rDataLRUIn[7:6] = rDataLRUOut[7:6] ;
            rDataLRUIn[5:4] = rDataLRUOut[5:4] ;
            rDataLRUIn[3:2] = rDataLRUOut[3:2] ;
            rDataLRUIn[1:0] = rDataLRUOut[1:0] ;
        end 
     end 
end

//Write Miss 
//FIXME: Should fetch the memory and write back. here we just test.  
always @(*) begin 
     if (pp2LRU_Ready & wMiss) begin 
         rWrByte0 = (rByte==3'b000) ? pp3Data : 32'b0;
         rWrByte1 = (rByte==3'b001) ? pp3Data : 32'b0;  
         rWrByte2 = (rByte==3'b010) ? pp3Data : 32'b0;  
         rWrByte3 = (rByte==3'b011) ? pp3Data : 32'b0;  
         rWrByte4 = (rByte==3'b100) ? pp3Data : 32'b0;  
         rWrByte5 = (rByte==3'b101) ? pp3Data : 32'b0;  
         rWrByte6 = (rByte==3'b110) ? pp3Data : 32'b0;  
         rWrByte7 = (rByte==3'b111) ? pp3Data : 32'b0; 
         if (~wDataWay0Tag[0]) begin 
             rWrDataWay0 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
             rWrWay0     = 1'b1;
             rWrDataWay0Tag = {pp2Tag,1'b1};
             rWrWay0Tag  = 1'b1;
         end else if (~wDataWay1Tag[0]) begin 
             rWrDataWay1 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
             rWrWay1     = 1'b1;
             rWrDataWay1Tag = {pp2Tag, 1'b1};
             rWrWay1Tag  = 1'b1;
         end else if (~wDataWay2Tag[0]) begin 
             rWrDataWay2 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
             rWrWay2     = 1'b1;
             rWrDataWay2Tag = {pp2Tag, 1'b1};
             rWrWay2Tag  = 1'b1;
         end else if (~wDataWay3Tag[0]) begin 
             rWrDataWay3 = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
             rWrWay3     = 1'b1;
             rWrDataWay3Tag = {pp2Tag, 1'b1};
             rWrWay3Tag  = 1'b1;
         end else begin //Look aside the LRU
             if (rDataLRUOut[1:0] ==2'b00)  begin 
                rDataLRUIn[7:6] = rDataLRUOut[7:6] -1;
                rDataLRUIn[5:4] = rDataLRUOut[5:4] -1;
                rDataLRUIn[3:2] = rDataLRUOut[3:2] -1;
                rDataLRUIn[1:0] = 2'b11;
                rWrDataWay0     = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
                rWrWay0         = 1'b1;
                rWrDataWay0Tag  = {pp2Tag, 1'b1};
                rWrWay0Tag      = 1'b1;
             end else if (rDataLRUOut[3:2] ==2'b00) begin 
                rDataLRUIn[7:6] = rDataLRUOut[7:6] -1;
                rDataLRUIn[5:4] = rDataLRUOut[5:4] -1;
                rDataLRUIn[3:2] = 2'b11;
                rDataLRUIn[1:0] = rDataLRUOut[1:0] -1;
                rWrDataWay1     = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
                rWrWay1         = 1'b1;
                rWrDataWay1Tag  = {pp2Tag, 1'b1};
                rWrWay1Tag      = 1'b1;
             end else if (rDataLRUOut[5:4] ==2'b00) begin 
                rDataLRUIn[7:6] = rDataLRUOut[7:6] -1;
                rDataLRUIn[5:4] = 2'b11;
                rDataLRUIn[3:2] = rDataLRUOut[3:2] -1;
                rDataLRUIn[1:0] = rDataLRUOut[1:0] -1;
                rWrDataWay2     = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
                rWrWay2         = 1'b1;
                rWrDataWay2Tag  = {pp2Tag, 1'b1};
                rWrWay2Tag      = 1'b1;
             end else if (rDataLRUOut[7:6] ==2'b00) begin 
                rDataLRUIn[7:6] = 2'b11;
                rDataLRUIn[5:4] = rDataLRUOut[5:4] -1;
                rDataLRUIn[3:2] = rDataLRUOut[3:2] -1;
                rDataLRUIn[1:0] = rDataLRUOut[1:0] -1;
                rWrDataWay3     = {rWrByte7,rWrByte6,rWrByte5,rWrByte4,rWrByte3,rWrByte2,rWrByte1,rWrByte0};
                rWrWay3         = 1'b1;
                rWrDataWay3Tag  = {pp2Tag, 1'b1};
                rWrWay3Tag      = 1'b1;
             end
         end 
     end
end 

//Data Cache line is 256 bit
ssram #(.AW(`INDEX_W), .DW(`CL_W)) way0_data_ram (
  .clk(clk),
  .iEnable(rEnWay0 | pp2Ready[0]),
  .iWr(rWrWay0),
  .iAddr(rAddrWay0),
  .iData(rWrDataWay0),
  .oData(wDataWay0Data)
);
ssram #(.AW(`INDEX_W), .DW(`CL_W)) way1_data_ram (
  .clk(clk),
  .iEnable(rEnWay1 | pp2Ready[0]),
  .iWr(rWrWay1),
  .iAddr(rAddrWay1),
  .iData(rWrDataWay1),
  .oData(wDataWay1Data)
);
ssram #(.AW(`INDEX_W), .DW(`CL_W)) way2_data_ram (
  .clk(clk),
  .iEnable(rEnWay2 | pp2Ready[0]),
  .iWr(rWrWay2),
  .iAddr(rAddrWay2),
  .iData(rWrDataWay2),
  .oData(wDataWay2Data)
);
ssram #(.AW(`INDEX_W), .DW(`CL_W)) way3_data_ram (
  .clk(clk),
  .iEnable(rEnWay3 | pp2Ready[0]),
  .iWr(rWrWay3),
  .iAddr(rAddrWay3),
  .iData(rWrDataWay3),
  .oData(wDataWay3Data)
);


//Tag+Valid is Data of Tag TLB
ssram #(.AW(`INDEX_W), .DW(`TAG_W+1) ) way0_tag_ram (
  .clk(clk),
  .iEnable(rEnWay0 | pp2Ready[0]),
  .iWr(rWrWay0Tag),
  .iAddr(rAddrWay0),
  .iData(rWrDataWay0Tag),
  .oData(wDataWay0Tag)
);
ssram #(.AW(`INDEX_W), .DW(`TAG_W+1) ) way1_tag_ram (
  .clk(clk),
  .iEnable(rEnWay1| pp2Ready[0]),
  .iWr(rWrWay1Tag),
  .iAddr(rAddrWay1),
  .iData(rWrDataWay1Tag),
  .oData(wDataWay1Tag)
);
ssram #(.AW(`INDEX_W), .DW(`TAG_W+1) ) way2_tag_ram (
  .clk(clk),
  .iEnable(rEnWay2| pp2Ready[0]),
  .iWr(rWrWay2Tag),
  .iAddr(rAddrWay2),
  .iData(rWrDataWay2Tag),
  .oData(wDataWay2Tag)
);
ssram #(.AW(`INDEX_W), .DW(`TAG_W+1) ) way3_tag_ram (
  .clk(clk),
  .iEnable(rEnWay3| pp2Ready[0]),
  .iWr(rWrWay3Tag),
  .iAddr(rAddrWay3),
  .iData(rWrDataWay3Tag),
  .oData(wDataWay3Tag)
);

ssram #(.AW(`INDEX_W), .DW(8)) pseudo_LRU_ram(
  .clk(clk),
  .iEnable(rEnLRU),
  .iWr(rWrLRU | (wMiss & pp2LRU_Ready)),
  .iAddr(rAddrLRU),
  .iData(rDataLRUIn),
  .oData(rDataLRUOut)
);
endmodule 
