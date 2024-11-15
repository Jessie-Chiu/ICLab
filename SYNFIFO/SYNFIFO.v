module SYNFIFO #(parameter WIDTH=16, parameter DEPTH=8)(
    clk,
    rst_n,
    wdata,
    wpush,
    wfull,
    rdata,
    rpop,
    rempty
);

input       clk, rst_n;
input       [WIDTH-1:0] wdata;
input       wpush;
output      wfull;
output reg  [WIDTH-1:0] rdata;
input       rpop;
output      rempty;

// Signal Deaclration
wire wena, rena;

reg [$clog2(DEPTH):0] waddr, raddr;
wire waddr_msb = waddr[$clog2(DEPTH)];
wire raddr_msb = raddr[$clog2(DEPTH)];
wire [$clog2(DEPTH)-1:0] waddr_real = waddr[$clog2(DEPTH)-1:0];
wire [$clog2(DEPTH)-1:0] raddr_real = raddr[$clog2(DEPTH)-1:0];

reg [WIDTH-1:0] ram[0:DEPTH-1];

//=============================================
// Design
//------------------------
// Write
//------------------------
//wenable
assign wena = (!wfull & wpush);

//wfull
assign wfull = ((waddr_msb==!raddr_msb) && (waddr_real==raddr_real)) ? 1'd1 : 1'd0;


//waddr
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) waddr <= 0;
    else if(wena) waddr <= waddr + 1'b1;
    else waddr <= waddr;
end


//------------------------
// Read
//------------------------
//renable
assign rena = (!rempty & rpop);

//rempty
assign rempty = (waddr==raddr) ? 1'b1 : 1'b0;

//raddr
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) raddr <= 0;
    else if(rena) raddr <= raddr + 1'b1;
    else raddr <= raddr;
end

//rdata
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) rdata <= 0;
    else if(rena) rdata <= ram[raddr_real];
    else rdata <= rdata;
end


//------------------------
// RAM to store data
//------------------------
genvar i;
generate
    for(i=0; i<DEPTH-1; i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) ram[i] <= 0;
            else if(wena) ram[waddr_real] <= wdata;
            else ram[i] <= ram[i];
        end
    end
endgenerate


endmodule