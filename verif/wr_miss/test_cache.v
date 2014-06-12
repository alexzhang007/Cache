//Author      : Alex Zhang (cgzhangwei@gmail.com)
//Date        : Jun. 04. 2014
//Description : Create the testbench
//              Fix Bug7: Loading the register_file with 0 data. Sequential logic should be used in that block. But i notice that when computer is sleeping, resuming can call back the original data. So i try to use the loading. 
module test;
reg         clk;
reg         resetn;
reg         rRd;
reg         rWr;
reg  [31:0] rData;
reg  [31:0] rAddr;
wire [31:0] wData;
wire        wReady;
wire        wHit;

event start_sim_evt;
event end_sim_evt;

cache_4way_64KB  cache(
  .clk(clk),
  .resetn(resetn),
  .iRd(rRd),
  .iWr(rWr),
  .iData(rData),
  .iAddr(rAddr),
  .oData(wData),
  .oReady(wReady),
  .oHit(wHit)
);
initial begin 
    basic;
end 
initial begin 
    $fsdbDumpfile("./out/cache.fsdb");
    $fsdbDumpvars(0, test);
end 

always @(posedge clk) begin 
    $fsdbDumpMem(cache.way0_tag_ram.mem);
    $fsdbDumpMem(cache.way1_tag_ram.mem);
    $fsdbDumpMem(cache.way2_tag_ram.mem);
    $fsdbDumpMem(cache.way3_tag_ram.mem);
end 

task basic ;
    begin 
        $display("Start cache IP testing.");
        #1;
        $readmemh("way0_dmem.rom",cache.way0_data_ram.mem );
        $readmemh("way0_tmem.rom",cache.way0_tag_ram.mem );
        $readmemh("way1_tmem.rom",cache.way1_tag_ram.mem );
        $readmemh("way2_tmem.rom",cache.way2_tag_ram.mem );
        $readmemh("way3_tmem.rom",cache.way3_tag_ram.mem );
        fork
            drive_clock;
            reset_unit;
            drive_sim;
            monitor_sim;
        join 
    end 
endtask 
task monitor_sim;
   begin 
   @(end_sim_evt);
   #10;
   $display("Test End");
   $finish;
   end 
endtask
task reset_unit;
    begin 
        #5;
        resetn = 1;
        #10;
        resetn = 0;
        rRd    = 0;
        rWr    = 0;
        rData  = 0;
        rAddr  = 0;
        #20;
        resetn = 1;
        ->start_sim_evt;
        $display("Reset is done");
        end
endtask 
task  drive_clock;
    begin 
        clk = 0;
        forever begin 
        #5 clk = ~clk;
        end 
    end 
endtask
task  drive_sim;
    @(start_sim_evt);
   
    @(posedge clk);
    rRd    = 0;
    rWr    = 1;
    rData  = 32'h1234_5678;
    rAddr  = 32'hFDEF_1000;
    @(posedge clk);
    rRd    = 0;
    rWr    = 0;
    rData  = 0;
    rAddr  = 0;
    @(posedge clk);
    rRd    = 1;
    rWr    = 0;
    rData  = 32'b0;
    rAddr  = 32'hFDEF_1000;
    @(posedge clk);
    rRd    = 0;
    rWr    = 0;
    rData  = 0;
    rAddr  = 0;
    repeat (100) @(posedge clk);

    ->end_sim_evt;
endtask 

endmodule 
