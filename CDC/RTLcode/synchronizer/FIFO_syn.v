module FIFO_syn #(parameter WIDTH=8, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk1,
	flag_clk1_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output  flag_fifo_to_clk2;
input flag_clk2_to_fifo;

output reg flag_fifo_to_clk1;
input flag_clk1_to_fifo;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;


// ============================================================
//                        My Design
// ============================================================
// ------------------------------------------------------------
// Signal Deaclration
// ------------------------------------------------------------
integer i;

wire wean, rean;

reg [$clog2(WORDS):0] rq2_wptr, wq2_rptr;

reg [6:0] waddr, raddr;

reg r_temp_valid;

reg csb;

// ------------------------------------------------------------
// RTL Code
// ------------------------------------------------------------
// ---------------
// Write
// ---------------
assign wean = ~(!wfull & winc);

// write full
always @(*) begin
    if(wptr[$clog2(WORDS):$clog2(WORDS)-1]==(~wq2_rptr[$clog2(WORDS):$clog2(WORDS)-1]) && wptr[$clog2(WORDS)-2:0]==wq2_rptr[$clog2(WORDS)-2:0]) wfull = 1'd1;
    else wfull = 1'd0;
end

// write address
always @(posedge wclk or negedge rst_n) begin
    if(!rst_n) waddr <= 7'd0;
    else if(!wean) waddr <= waddr + 1'd1;
    else waddr <= waddr;
end

// write pointer
always @(*) begin
    wptr[6] = waddr[6];
    for(i=0; i<6; i=i+1) wptr[i] = waddr[i+1] ^ waddr[i];
end


// ---------------
// Read
// ---------------
assign rean = (!empty & rinc);

// read empty in FIFO
always @(*) begin
    if(rptr==rq2_wptr) rempty = 1'd1;
    else rempty = 1'd0;
end

// read address
always @(posedge rclk or negedge rst_n) begin
    if(!rst_n) raddr <= 7'd0;
    else if(rean) raddr <= raddr + 1'd1;
    else raddr <= raddr;
end

// read pointer in FIFO
always @(*) begin
    rptr[6] = raddr[6];
    for(i=0; i<6; i=i+1) rptr[i] = raddr[i+1] ^ raddr[i];
end

// read temp valid
always @(posedge rclk or negedge rst_n) begin
    if(!rst_n) r_temp_valid <= 1'd0;
    else r_temp_valid <= rean;
end

// rdata
//  Add one more register stage to rdata
always @(posedge rclk, negedge rst_n) begin
    if (!rst_n) rdata <= 8'd0;
    else begin
        if (r_temp_valid) rdata <= rdata_q;
        else rdata <= rdata;
    end
end

// SRAM csb
always @(*) begin
    if(rean) csb = 1'b1;
    else csb = 1'b0;
end


// ------------------------
// IP (I've changed WIDTH)
// ------------------------
NDFF_BUS_syn #(7) 
    BUS_w(wptr, rq2_wptr, rclk, rst_n),
    BUS_r(rptr, wq2_rptr, wclk, rst_n);

// ============================================================
//                      Dual Port SRAM
// ============================================================
DUAL_64X8X1BM1 u_dual_sram (
    .CKA(wclk),
    .CKB(rclk),
    .WEAN(wean),
    .WEBN(1'b1),
    .CSA(1'b1),
    .CSB(csb),
    .OEA(1'b1),
    .OEB(1'b1),
    .A0(waddr[0]),
    .A1(waddr[1]),
    .A2(waddr[2]),
    .A3(waddr[3]),
    .A4(waddr[4]),
    .A5(waddr[5]),
    .B0(raddr[0]),
    .B1(raddr[1]),
    .B2(raddr[2]),
    .B3(raddr[3]),
    .B4(raddr[4]),
    .B5(raddr[5]),
    .DIA0(wdata[0]),
    .DIA1(wdata[1]),
    .DIA2(wdata[2]),
    .DIA3(wdata[3]),
    .DIA4(wdata[4]),
    .DIA5(wdata[5]),
    .DIA6(wdata[6]),
    .DIA7(wdata[7]),
    .DIB0(1'b0),
    .DIB1(1'b0),
    .DIB2(1'b0),
    .DIB3(1'b0),
    .DIB4(1'b0),
    .DIB5(1'b0),
    .DIB6(1'b0),
    .DIB7(1'b0),
    .DOB0(rdata_q[0]),
    .DOB1(rdata_q[1]),
    .DOB2(rdata_q[2]),
    .DOB3(rdata_q[3]),
    .DOB4(rdata_q[4]),
    .DOB5(rdata_q[5]),
    .DOB6(rdata_q[6]),
    .DOB7(rdata_q[7])
);



endmodule
