`define CYCLE_TIME 5.0
`timescale 1ns/1ps

module PATTERN #(parameter WIDTH=16, parameter DEPTH=8);

reg clk, rst_n;
reg [WIDTH-1:0] wdata;
reg wpush;
wire wfull;

wire [WIDTH-1:0] rdata;
reg rpop;
wire rempty;

//-----------------------------------
// Instantiate Design Under Test
//-----------------------------------
SYNFIFO synfifo(
    .clk(clk),
    .rst_n(rst_n),
    .wdata(wdata),
    .wpush(wpush),
    .wfull(wfull),
    .rdata(rdata),
    .rpop(rpop),
    .rempty(rempty)
);

//-----------------------------------
// Signal Deaclration
//-----------------------------------
// User modification
parameter CYCLE = `CYCLE_TIME;
parameter PATNUM = 100;

// Pattern Control
integer pat;

// Random Range
parameter INPUT_MAX = 2**(WIDTH);
parameter INPUT_MIN = 0;

// Check Answer
integer i;
reg [WIDTH-1:0] p_wdata[0:DEPTH-1];
reg [WIDTH-1:0] p_rdata[0:DEPTH-1];

//-----------------------------------
// Create Clock Signal
//-----------------------------------
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//-----------------------------------
// Main
//-----------------------------------
initial begin
    //Dump Waves
    $dumpfile("SYN_FIFO.vcd");
    $dumpvars(0, PATTERN);

    reset_task;

    for(pat=0; pat<PATNUM; pat=pat+1) begin
		write_read_task;
        operation_rst_task;
        write_task;
		read_task;
        $display("PASS PATTERN NO.%4d", pat);
    end

    pass_task;
    $finish;
end



//-----------------------------------
// Task
//-----------------------------------
task reset_task; begin
    force clk = 0;
    rst_n = 1;
    wpush = 0;
    rpop = 0;
    wdata = 'dx;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;

    if(rdata!==0 || rempty!==1 || wfull!==0) begin
        $display("========================================");
        $display("  Output signal should be 0 at %4d ps   ", $time*1000);
        $display("========================================");
        repeat(5) #(CYCLE);
        $finish;
    end

    #(CYCLE/2.0) release clk;
    @(negedge clk);
end endtask


task write_read_task; begin
    for(i=0; i<DEPTH/2; i=i+1) begin
        wpush = 1;
        wdata = $urandom_range(INPUT_MAX, INPUT_MIN);
        p_wdata[i] = wdata;
        @(negedge clk);
    end

    for(i=0; i<DEPTH/2; i=i+1) begin
        wpush = 1;
        wdata = $urandom_range(INPUT_MAX, INPUT_MIN);
        p_wdata[i+(DEPTH/2)] = wdata;

        rpop = 1;
        @(negedge clk);
        p_rdata[i] = rdata;
    end

    for(i=0; i<DEPTH/2; i=i+1) begin
        wpush = 1;
        wdata = $urandom_range(INPUT_MAX, INPUT_MIN);
        p_wdata[i] = wdata;

        rpop = 1;
        @(negedge clk);
        p_rdata[i+(DEPTH/2)] = rdata;
    end

    wpush = 0;
    wdata = 'dx;

    for(i=0; i<DEPTH/2; i=i+1) begin
        rpop = 1;
        @(negedge clk); 
        p_rdata[i] = rdata;
    end

    rpop = 0;

    for(i=0; i<DEPTH; i=i+1) begin
        if(p_rdata[i]!==p_wdata[i]) begin
            $display("========================================");
            $display("   rdata[%1d](%h) should be %h at %4d ps     ", i, p_rdata[i], p_wdata[i], $time*1000);
            $display("========================================");
            repeat(5) #(CYCLE);
            $finish;
        end
    end

    if(rempty!==1) begin
        $display("========================================");
        $display("   rempty signal should be 1 at %4d ps   ", $time*1000);
        $display("========================================");
        repeat(5) #(CYCLE);
        $finish;
    end
    @(negedge clk);
end endtask


task operation_rst_task; begin
    for(i=0; i<DEPTH/2; i=i+1) begin
        wpush = 1;
        wdata = $urandom_range(INPUT_MAX, INPUT_MIN);
        p_wdata[i] = wdata;
        @(negedge clk);
    end

    for(i=0; i<DEPTH/4; i=i+1) begin
        wpush = 1;
        wdata = $urandom_range(INPUT_MAX, INPUT_MIN);
        p_wdata[i+(DEPTH/2)] = wdata;

        rpop = 1;
        @(negedge clk);
        p_rdata[i] = rdata;
    end

    rst_n = 0;
    wpush = 0;
    wdata = 'dx;
    rpop = 0;
    @(negedge clk);
    rst_n = 1;

    if(rdata!==0 || rempty!==1 || wfull!==0) begin
        $display("========================================");
        $display("  Output signal should be 0 at %4d ps   ", $time*1000);
        $display("========================================");
        repeat(5) #(CYCLE);
        $finish;
    end

end endtask


task write_task; begin
    for(i=0; i<DEPTH; i=i+1) begin
        wpush = 1;
        wdata = $urandom_range(INPUT_MAX, INPUT_MIN);
        p_wdata[i] = wdata;
        @(negedge clk);

        if(rempty!==0) begin
            $display("========================================");
            $display("  rempty signal should be 0 at %4d ps   ", $time*1000);
            $display("========================================");
            repeat(5) #(CYCLE);
            $finish;
        end
    end

    wpush = 0;
    wdata = 'dx;

    if(wfull!==1) begin
        $display("========================================");
        $display("   wfull signal should be 1 at %4d ps   ", $time*1000);
        $display("========================================");
        repeat(5) #(CYCLE);
        $finish;
    end
end endtask


task read_task; begin
    for(i=0; i<DEPTH; i=i+1) begin
        rpop = 1;
        @(negedge clk); //because rdata will delay one cycle from ram
        p_rdata[i] = rdata;

        if(wfull!==0) begin
            $display("========================================");
            $display("   wfull signal should be 0 at %4d ps   ", $time*1000);
            $display("========================================");
            repeat(5) #(CYCLE);
            $finish;
        end
    end

    rpop = 0;

    for(i=0; i<DEPTH; i=i+1) begin
        if(p_rdata[i]!==p_wdata[i]) begin
            $display("========================================");
            $display("   rdata[%1d](%h) should be %h at %4d ps     ", i, p_rdata[i], p_wdata[i], $time*1000);
            $display("========================================");
            repeat(5) #(CYCLE);
            $finish;
        end
    end

    if(rempty!==1) begin
        $display("========================================");
        $display("   rempty signal should be 1 at %4d ps   ", $time*1000);
        $display("========================================");
        repeat(5) #(CYCLE);
        $finish;
    end
    @(negedge clk);
end endtask


task pass_task; begin
    $display("========================================");
    $display("   congratulation!!!!   ");
    $display("========================================");
end endtask

    
endmodule