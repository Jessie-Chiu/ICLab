module Handshake_syn #(parameter WIDTH=8) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output reg flag_handshake_to_clk1;
input flag_clk1_to_handshake;

output flag_handshake_to_clk2;
input flag_clk2_to_handshake;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;


// ============================================================
//                        My Design
// ============================================================
// ------------------------------------------------------------
// Signal Deaclration
// ------------------------------------------------------------
reg [7:0] data;

reg sack_p;

reg [7:0] temp_dout;

// ------------------------------------------------------------
// RTL Code
// ------------------------------------------------------------

assign sidle = (!sack && sack_p) ? 1'd1 : 1'd0;

// input data from CLK1
always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) data <= 8'd0;
    else if(sready) data <= din;
    else data <= data;
end

// send request form clk1 to clk2
always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) sreq <= 1'd0;
    else if(sready) sreq <= 1'd1;
    else if(sack) sreq <= 1'd0;
    else sreq <= sreq;
end

// add one stage for sack to make sidle be a pulse
always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) sack_p <= 1'd0;
    else sack_p <= sack;
end

// Acknowledge from clk2 to clk1
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) dack <= 1'd0;
    else if(dreq) dack <= 1'd1;
    else dack <= 1'd0;
end

// output data to CLK2 is valid
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) dvalid <= 1'd0;
    else if(dreq) dvalid <= 1'd1;
    else dvalid <= 1'd0;
end

// output data to CLK2
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) dout <= 8'd0;
    else if(dreq) dout <= temp_dout;
    else dout <= 8'd0;
end


// IP
NDFF_syn 
    req_NDFF_syn (.D(sreq), .Q(dreq), .clk(dclk), .rst_n(rst_n)),
    ack_NDFF_syn (.D(dack), .Q(sack), .clk(sclk), .rst_n(rst_n));

NDFF_BUS_syn #(8) 
    matrix_bus (.D(data), .Q(temp_dout), .clk(dclk), .rst_n(rst_n));


endmodule