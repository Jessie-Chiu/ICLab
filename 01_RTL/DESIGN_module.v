module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
	in_matrix_A,
    in_matrix_B,
    out_idle,
    handshake_sready,
    handshake_din,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

	fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_matrix,

    flag_clk1_to_fifo,
    flag_fifo_to_clk1
);
input clk;
input rst_n;
input in_valid;
input [3:0] in_matrix_A;
input [3:0] in_matrix_B;
input out_idle;
output reg handshake_sready;
output reg [7:0] handshake_din;
// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output reg flag_clk1_to_handshake;

input fifo_empty;
input [7:0] fifo_rdata;
output fifo_rinc;
output reg out_valid;
output reg [7:0] out_matrix;
// You can use the the custom flag ports for your design
output flag_clk1_to_fifo;
input flag_fifo_to_clk1;


// ============================================================
//                        My Design
// ============================================================
// ------------------------------------------------------------
// Signal Declaration
// ------------------------------------------------------------
parameter s_idle      = 3'd0;
parameter s_input     = 3'd1;
parameter s_handshake = 3'd2;
parameter s_fifo      = 3'd3;
parameter s_output    = 3'd4;

integer i;

reg [2:0] current_state, next_state;
reg [7:0] cnt;

reg [3:0] matrix_a[0:15];
reg [3:0] matrix_b[0:15];

reg [4:0] idx;

reg temp_valid1, temp_valid2;

// ------------------------------------------------------------
// RTL Code
// ------------------------------------------------------------
// FSM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) current_state <= s_idle;
    else current_state <= next_state;
end

always @(*) begin
    case(current_state)
    s_idle: begin
        if(in_valid) next_state = s_input;
        else next_state = s_idle;
    end
    s_input: begin
        if(in_valid) next_state = s_input;
        else next_state = s_handshake;
    end
    s_handshake: begin
        if(idx==4'd15 && out_idle) next_state = s_fifo;
        else next_state = s_handshake;
    end
    s_fifo: begin
        if(cnt==8'd255 && out_valid) next_state = s_idle;
        else next_state = s_fifo;
    end
    default: next_state = current_state;
    endcase
end

// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) cnt <= 8'd0;
    else begin
        case(current_state)
        s_handshake: begin
            if(out_idle) cnt <= 8'd0;
            else cnt <= cnt + 1'd1;
        end
        s_fifo: begin
            if(!rst_n) cnt <= 8'd0;
            else if(cnt==8'd255 && out_valid) cnt <= 8'd0;
            else if(out_valid) cnt <= cnt + 1'd1;
            else cnt <= cnt;
        end
        default: cnt <= 8'd0;
        endcase
    end
end

// ----------------------
// s_input
// ----------------------
// store input matrix
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0; i<16; i=i+1) matrix_a[i] <= 4'd0;
    end
    else if(in_valid) begin
         matrix_a[15] <= in_matrix_A;
         for(i=0; i<15; i=i+1) matrix_a[i] <= matrix_a[i+1];
    end
    else begin
        for(i=0; i<16; i=i+1) matrix_a[i] <= matrix_a[i];
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0; i<16; i=i+1) matrix_b[i] <= 4'd0;
    end
    else if(in_valid) begin
         matrix_b[15] <= in_matrix_B;
         for(i=0; i<15; i=i+1) matrix_b[i] <= matrix_b[i+1];
    end
    else begin
        for(i=0; i<16; i=i+1) matrix_b[i] <= matrix_b[i];
    end
end

// ----------------------
// s_handshake
// ----------------------
// index of matrix
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) idx <= 4'd0;
    else if(idx==4'd15 && out_idle) idx <= 4'd0;
    else if(out_idle) idx <= idx + 1'd1;
    else idx <= idx;
end

// ready to pass data from CLK1 to Handshake
always @(*) begin
    if(current_state==s_handshake && cnt==1'd1) handshake_sready = 1'd1;
    else handshake_sready = 1'd0;
end

// pass data from CLK1 to Handshake
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) handshake_din <= 8'd0;
    else if(current_state==s_handshake && cnt==1'd0) handshake_din <= {matrix_a[idx], matrix_b[idx]};
    else handshake_din <= 8'd0;
end


// ----------------------
// s_fifo (& output)
// ----------------------
// due to SRAM read out data will delay 2 cycle
assign fifo_rinc = temp_valid2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) temp_valid1 <= 1'd0;
    else if(current_state==s_fifo) temp_valid1 <= !fifo_empty;
    else temp_valid1 <= 1'd0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) temp_valid2 <= 1'd0;
    else if(current_state==s_fifo) temp_valid2 <= temp_valid1;
    else temp_valid2 <= 1'd0;
end

// output
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_valid <= 1'd0;
    else if(current_state==s_fifo && cnt==8'd255 && out_valid) out_valid <= 1'd0;
    else if(current_state==s_fifo) out_valid <= temp_valid2;
    else out_valid <= 1'd0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_matrix <= 8'd0;
    else if(current_state==s_fifo && cnt==8'd255 && out_valid) out_matrix <= 8'd0;
    else if(current_state==s_fifo && temp_valid2) out_matrix <= fifo_rdata;
    else out_matrix <= 8'd0;
end


endmodule







module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    in_matrix,
    out_valid,
    out_matrix,
    busy,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [7:0] in_matrix;
output reg out_valid;
output reg [7:0] out_matrix;
output reg busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;


// ============================================================
//                        My Design
// ============================================================
// ------------------------------------------------------------
// Signal Declaration
// ------------------------------------------------------------
parameter s_idle      = 3'd0;
parameter s_input     = 3'd1;
parameter s_calculate = 3'd2;
parameter s_output    = 3'd3;

integer i;

reg [2:0] current_state, next_state;
reg [7:0] cnt;

reg [4:0] input_cnt;
reg [3:0] matrix_a[0:15];
reg [3:0] matrix_b[0:15];

reg [3:0] idx_a, idx_b;
reg [7:0] matrix_c[0:255];

// ------------------------------------------------------------
// RTL Code
// ------------------------------------------------------------
// FSM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) current_state <= s_idle;
    else current_state <= next_state;
end

always @(*) begin
    case (current_state)
    s_idle: begin
        if(in_valid) next_state = s_input;
        else next_state = s_idle;
    end
    s_input: begin
        if(in_valid) next_state = s_input;
        else if(input_cnt==5'd16) next_state = s_calculate;
        else next_state = s_idle;
    end
    s_calculate: begin
        if(cnt==8'd255) next_state = s_output;
        else next_state = s_calculate;
    end
    s_output: begin
        if(cnt==8'd255 && out_valid) next_state = s_idle;
        else next_state = s_output;
    end
    default: next_state = current_state;
    endcase
end

// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) cnt <= 8'd0;
    else if(in_valid) cnt <= cnt + 1'd1;
    else if(current_state==s_calculate) begin
        if(cnt==8'd255) cnt <= 8'd0;
        else cnt <= cnt + 1'd1;
    end
    else if(current_state==s_output) begin
        if(cnt==8'd255 && out_valid) cnt <= 8'd0;
        else if(current_state==s_output && !fifo_full) cnt <= cnt + 1'd1;
        else cnt <= cnt;
    end
    else cnt <= 8'd0;
end


// busy signal from clk2 to handshake
always @(*) begin
    if(current_state==s_calculate) busy = 1'd1;
    else busy = 1'd0;
end

// -----------------------------
// s_input
// -----------------------------
// input counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) input_cnt <= 5'd0;
    else if(current_state==s_calculate) input_cnt <= 5'd0;
    else if(in_valid && !cnt) input_cnt <= input_cnt + 1'd1;
    else input_cnt <= input_cnt;
end

// store matrix
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0; i<16; i=i+1) matrix_a[i] <= 4'd0;
    end
    else if(in_valid && !cnt) begin
        matrix_a[15] <= in_matrix[7:4];
        for(i=0; i<15; i=i+1) matrix_a[i] <= matrix_a[i+1];
    end
    else begin
        for(i=0; i<16; i=i+1) matrix_a[i] <= matrix_a[i];
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0; i<16; i=i+1) matrix_b[i] <= 4'd0;
    end
    else if(in_valid && !cnt) begin
        matrix_b[15] <= in_matrix[3:0];
        for(i=0; i<15; i=i+1) matrix_b[i] <= matrix_b[i+1];
    end
    else begin
        for(i=0; i<16; i=i+1) matrix_b[i] <= matrix_b[i];
    end
end

// -----------------------------
// s_calculate
// -----------------------------
// index for matrix_a & b
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        idx_a <= 4'd0;
        idx_b <= 4'd0;
    end
    else if(current_state==s_calculate) begin
        if(idx_a==4'd15 && idx_b==4'd15) begin
            idx_a <= 4'd0;
            idx_b <= 4'd0;
        end
        else if(idx_a!=4'd15 && idx_b==4'd15) begin
            idx_a <= idx_a + 1'd1;
            idx_b <= 4'd0;
        end
        else begin
            idx_a <= idx_a;
            idx_b <= idx_b + 1'd1;
        end
    end
    else begin
        idx_a <= idx_a;
        idx_b <= idx_b;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0; i<256; i=i+1) matrix_c[i] <= 8'd0;
    end
    else if(current_state==s_calculate) begin
        matrix_c[cnt] <= matrix_a[idx_a] * matrix_b[idx_b];
    end
    else begin
        for(i=0; i<256; i=i+1) matrix_c[i] <= matrix_c[i];
    end
end

// -----------------------------
// s_output (write in dual SRAM)
// -----------------------------
// out valid (FIFO write valid)
always @(*) begin
    if(current_state==s_output && !fifo_full) out_valid = 1'd1;
    else out_valid = 1'd0;
end

// out data (FIFO write data)
always @(*) begin
    if(current_state==s_output && !fifo_full) out_matrix = matrix_c[cnt];
    else out_matrix = 8'd0;
end

endmodule