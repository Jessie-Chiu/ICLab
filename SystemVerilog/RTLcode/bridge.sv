module bridge(input clk, INF.bridge_inf inf);

//================================================================
// logic 
//================================================================

//================================================================
// state 
//================================================================


// -----------------------------------------------------
//                Data Type Declaration
// -----------------------------------------------------
typedef enum logic [2:0]{
    s_idle,
    s_input,
    s_r_dram_addr,
    s_r_dram_data,
    s_w_dram_addr,
    s_w_dram_data,
    s_w_dram_res,
    s_output
} state_b;

state_b current_state, next_state;
logic [0:0] read_complete, write_complete;

logic [2:0] cnt;

logic [16:0] addr;
logic [7:0] address_no;
logic [0:0] operation;
logic [63:0] data;

// -----------------------------------------------------
//                       Design
// -----------------------------------------------------
// FSM
always_ff @(posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) current_state <= s_idle;
	else current_state <= next_state;
end

always_comb begin
    case(current_state)
    s_idle: begin
       if(inf.C_in_valid) next_state = s_input;
       else next_state = s_idle;
    end
    s_input: begin
        if(inf.C_in_valid) next_state = s_input;
        else if(operation) next_state = s_r_dram_addr;
        else next_state = s_w_dram_addr;
    end
    s_r_dram_addr: begin
        if(inf.AR_READY && inf.AR_VALID) next_state = s_r_dram_data;
        else next_state = s_r_dram_addr;
    end
    s_r_dram_data: begin
        //if(cnt==3'd7 && read_complete) next_state = s_output;
        if(read_complete) next_state = s_output;
        else if(read_complete) next_state = s_r_dram_addr;
        else next_state = s_r_dram_data;
    end
    s_w_dram_addr: begin
        if(inf.AW_READY && inf.AW_VALID) next_state = s_w_dram_data;
        else next_state = s_w_dram_addr;
    end
    s_w_dram_data: begin
        if(inf.W_READY && inf.W_VALID) next_state = s_w_dram_res;
        else next_state = s_w_dram_data;
    end
    s_w_dram_res: begin
        //if(cnt==3'd7 && write_complete) next_state = s_idle;
        if(write_complete) next_state = s_output;
        else if(write_complete) next_state = s_w_dram_addr;
        else next_state = s_w_dram_res;
    end
    s_output: begin
        if(inf.C_out_valid) next_state = s_idle;
        else next_state = s_output;
    end
    default: next_state = current_state;
    endcase
end

always_comb begin
    if(!inf.rst_n) read_complete = 1'd0;
    else if(inf.R_VALID && !inf.R_RESP && inf.R_READY) read_complete = 1'd1;
    else read_complete = 1'd0;
end

always_comb begin
    if(!inf.rst_n) write_complete = 1'd0;
    else if(inf.B_READY && !inf.B_RESP && inf.B_VALID) write_complete = 1'd1;
    else write_complete = 1'd0;
end


// counter: 
// (it should read from DRAM 8 times for AXI4-Lite)
//always_ff @(posedge clk or negedge inf.rst_n) begin
//    if(!inf.rst_n) cnt <= 3'd0;
//    else if(cnt==3'd7 && (read_complete || write_complete)) cnt <= 3'd0;
//    else if(read_complete || write_complete) cnt <= cnt + 1'd1;
//    else cnt <= cnt;
//end


// ------------------
// s_input
// ------------------
// operation: write or read
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) operation <= 1'd0;
    else if(inf.C_in_valid) operation <= inf.C_r_wb;
    else operation <= operation;
end

// address_no: that is ingridient box no.
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) address_no <= 8'd0;
    else if(inf.C_in_valid) address_no <= inf.C_addr;
    else address_no <= address_no;
end

assign addr = 17'h10000 + (address_no<<2'd3);
//always_comb begin
//    if(!inf.rst_n) addr = 17'd0;
//    else addr = 17'h10000 + (address_no<<2'd3) + cnt;
//end

// data: to write in DRAM or read from DRAM
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) data <= 64'd0;
    else if(inf.R_VALID) begin 
        //data[63:56] <= inf.R_DATA;
        //data[55:48] <= data[63:56]; 
        //data[47:40] <= data[55:48]; 
        //data[39:32] <= data[47:40]; 
        //data[31:24] <= data[39:32]; 
        //data[23:16] <= data[31:24]; 
        //data[15: 8] <= data[23:16]; 
        //data[ 7: 0] <= data[15: 8]; 
        data <= inf.R_DATA;
    end
    else if(inf.C_in_valid) data <= inf.C_data_w;
    else data <= data;
end


// ------------------
// s_r_dram_addr
// ------------------
// AR_VALID
always_comb begin
    if(current_state==s_r_dram_addr) inf.AR_VALID = 1'd1;
    else inf.AR_VALID = 1'd0;
end

// AR_ADDR
always_comb begin
    if(current_state==s_r_dram_addr) inf.AR_ADDR = addr;
    else inf.AR_ADDR = 17'd0;
end

// ------------------
// s_r_dram_data
// ------------------
// R_READY
always_comb begin
    if(current_state==s_r_dram_data) inf.R_READY = 1'd1;
    else inf.R_READY = 1'd0;
end


// ------------------
// s_w_dram_addr
// ------------------
// AW_VALID
always_comb begin
    if(current_state==s_w_dram_addr) inf.AW_VALID = 1'd1;
    else inf.AW_VALID = 1'd0;
end

// AW_ADDR
always_comb begin
    if(current_state==s_w_dram_addr) inf.AW_ADDR = addr;
    else inf.AW_ADDR = 17'd0;
end

// ------------------
// s_w_dram_data
// ------------------
// W_VALID
always_comb begin
    if(current_state==s_w_dram_data) inf.W_VALID = 1'd1;
    else inf.W_VALID = 1'd0;
end

// W_DATA
always_comb begin
    if(current_state==s_w_dram_data) begin 
        inf.W_DATA = data;
        //case(cnt)
        //3'd0: inf.W_DATA = data[ 7: 0];
        //3'd1: inf.W_DATA = data[15: 8];
        //3'd2: inf.W_DATA = data[23:16];
        //3'd3: inf.W_DATA = data[31:24];
        //3'd4: inf.W_DATA = data[39:32];
        //3'd5: inf.W_DATA = data[47:40];
        //3'd6: inf.W_DATA = data[55:48];
        //3'd7: inf.W_DATA = data[63:56];
        //default: inf.W_DATA = 64'd0;
        //endcase
    end
    else inf.W_DATA = 64'd0;
end

// ------------------
// s_w_dram_res
// ------------------
always_comb begin
    if(current_state==s_w_dram_res) inf.B_READY = 1'd1;
    else inf.B_READY = 1'd0;
end


// ------------------
// s_output
// ------------------
always_comb begin
    if(!inf.rst_n) inf.C_out_valid = 1'd0;
    else if(current_state==s_output) inf.C_out_valid = 1'd1;
    else inf.C_out_valid = 1'd0;
end

always_comb begin
    if(!inf.rst_n) inf.C_data_r = 64'd0;
    else if(current_state==s_output && operation==1'd1) inf.C_data_r = data;
    else if(current_state==s_output && operation==1'd0) inf.C_data_r = 64'd0;
    else inf.C_data_r = 64'd0;
end

endmodule