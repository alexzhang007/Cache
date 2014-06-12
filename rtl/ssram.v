//Author      : Alex Zhang (cgzhangwei@gmail.com)
//Date        : Jun. 10. 2014
//Description : Implement the cache with synchronous single-port RAM
module ssram (
clk,
iEnable,
iWr,
iAddr,
iData,
oData
);
parameter AW = 18;
parameter DW = 32;

input clk;
input iEnable;
input iWr;
input iAddr;
input iData;
output oData;

wire [AW-1:0] iAddr;
wire [DW-1:0] iData;
wire [DW-1:0] oData;

reg  [AW-1:0] rAddr;
reg  [DW-1:0] mem[(1<<AW)-1:0];

assign oData = mem[rAddr];
always @(posedge clk)
    if (iEnable)
        rAddr <= iAddr;

always @(posedge clk)
    if (iEnable & iWr)
        mem[iAddr] <= iData;

endmodule  

