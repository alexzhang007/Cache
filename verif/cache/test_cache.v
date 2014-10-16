module test;
reg aclk;
reg resetn;
reg cclk;
event start_sim_evt;
event end_sim_evt;

reg          req_valid;
reg  [31:0]  req_address;
reg  [1:0]   req_op;     
reg  [31:0]  req_wdata;  
wire [31:0]  resp_rdata; 
wire         resp_valid ;
wire         resp_status;
//Cache to Memory fetch(re
reg          cm_arready ;
wire         cm_arvalid ;
wire [5:0]   cm_arid    ;
wire [31:0]  cm_araddr  ;
wire [3:0]   cm_arlen   ;
wire [2:0]   cm_arsize  ;
wire [1:0]   cm_arburst ;
wire [1:0]   cm_arlock  ;
wire [3:0]   cm_arcache ;
wire [2:0]   cm_arprot  ;

wire         mc_rready  ;
reg          mc_rvalid  ;
reg  [31:0]  mc_rdata   ;
reg  [5:0]   mc_rid     ;
reg  [1:0]   mc_rresp   ;
reg          mc_rlast   ;
//Cache to Memory write in
reg          cm_awready ;
wire         cm_awvalid ;
wire [5:0]   cm_awid    ;
wire [31:0]  cm_awaddr  ;
wire [3:0]   cm_awlen   ;
wire [2:0]   cm_awsize  ;
wire [1:0]   cm_awburst ;
wire [1:0]   cm_awlock  ;
wire [3:0]   cm_awcache ;
wire [2:0]   cm_awprot  ;
wire [5:0]   cm_wid     ;
wire [31:0]  cm_wdata   ;
wire [3:0]   cm_wstrb   ;
wire         cm_wlast   ;
wire         cm_wvalid  ;
reg          cm_wready  ;
reg  [5:0]   mc_bid     ;
reg  [1:0]   mc_bresp   ;
reg          mc_bvalid  ;
wire         mc_bready  ;

cache_top dut_top(
  .cclk       (cclk),
  .cresetn    (resetn),
//Read/Write to cache interface
  .req_valid  (req_valid),
  .req_address(req_address),
  .req_op     (req_op),  //2'b10 - write request; 2'b01 - read request
  .req_wdata  (req_wdata),
  .resp_rdata (resp_rdata),
  .resp_valid (resp_valid),
  .resp_status(resp_status),
//Cache to Memory fetch(read) interface
  .aclk       (aclk),    //connect to the MC clock
  .aresetn    (resetn), 
  .cm_arready (cm_arready),
  .cm_arvalid (cm_arvalid),
  .cm_arid    (cm_arid),
  .cm_araddr  (cm_araddr),
  .cm_arlen   (cm_arlen),
  .cm_arsize  (cm_arsize),
  .cm_arburst (cm_arburst),
  .cm_arlock  (cm_arlock),
  .cm_arcache (cm_arcache),
  .cm_arprot  (cm_arprot),
  .mc_rready  (mc_rready),
  .mc_rvalid  (mc_rvalid),
  .mc_rdata   (mc_rdata),
  .mc_rid     (mc_rid),
  .mc_rresp   (mc_rresp),
  .mc_rlast   (mc_rlast),
//Cache to Memory write interface
  .cm_awready (cm_awready),
  .cm_awvalid (cm_awvalid),
  .cm_awid    (cm_awid),
  .cm_awaddr  (cm_awaddr),
  .cm_awlen   (cm_awlen),
  .cm_awsize  (cm_awsize),
  .cm_awburst (cm_awburst),
  .cm_awlock  (cm_awlock),
  .cm_awcache (cm_awcache),
  .cm_awprot  (cm_awprot),
  .cm_wid     (cm_wid),
  .cm_wdata   (cm_wdata),
  .cm_wstrb   (cm_wstrb),
  .cm_wlast   (cm_wlast),
  .cm_wvalid  (cm_wvalid),
  .cm_wready  (cm_wready),
  .mc_bid     (mc_bid),
  .mc_bresp   (mc_bresp),
  .mc_bvalid  (mc_bvalid),
  .mc_bready  (mc_bready)
);

initial begin 
    basic;
end 
initial begin 
    $fsdbDumpfile("./test_cache.fsdb");
    $fsdbDumpvars(0, test);
end 

task basic ;
    begin 
        $display("This is the compile test for the cache.");
        #1;
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
        #20;
        resetn = 1;
        ->start_sim_evt;
        $display("Reset is done");
        end
endtask 
task  drive_clock;
    begin 
        cclk = 0;
        aclk = 0;
        forever begin 
        #5 cclk = ~cclk;
        #3.3 aclk = ~aclk;
        end 
    end 
endtask
task  drive_sim;
    @(start_sim_evt);
   
    @(posedge cclk);
    //        0    1     2   3    4    5    6     7
    //Same exp, overflow, unsigned A,B, Add
    req_valid   <= 1'b1;
    req_address <= 32'h3001_8000;
    req_op      <= 2'b10; //Write request
    req_wdata   <= 32'h1800_32de;
    cm_arready  <= 1'b1;
    mc_rvalid   <= 1'b0;
    cm_awready  <= 1'b1;
    mc_bvalid   <= 1'b0;
    cm_wready   <= 1'b1;
    @(posedge cclk);
    req_valid   <= 1'b0;
    repeat (100) @(posedge cclk);
    ->end_sim_evt;
endtask 

endmodule 
