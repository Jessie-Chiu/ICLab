module BEV(input clk, INF.BEV_inf inf);
import usertype::*;
// This file contains the definition of several state machines used in the BEV (Beverage) System RTL design.
// The state machines are defined using SystemVerilog enumerated types.
// The state machines are:
// - state_t: used to represent the overall state of the BEV system
//
// Each enumerated type defines a set of named states that the corresponding process can be in.
typedef enum logic [1:0]{
    IDLE,
    MAKE_DRINK,
    SUPPLY,
    CHECK_DATE
} state_t;

/*
// REGISTERS
state_t state, nstate;

// STATE MACHINE
always_ff @( posedge clk or negedge inf.rst_n) begin : TOP_FSM_SEQ
    if (!inf.rst_n) state <= IDLE;
    else state <= nstate;
end

always_comb begin : TOP_FSM_COMB
    case(state)
    IDLE: begin
        if (inf.sel_action_valid) begin
            case(inf.D.d_act[0])
            Make_drink: nstate = MAKE_DRINK;
            Supply: nstate = SUPPLY;
            Check_Valid_Date: nstate = CHECK_DATE;
            default: nstate = IDLE;
            endcase
        end
        else begin
            nstate = IDLE;
        end
    end
    default: nstate = IDLE;
    endcase
end

always_ff @( posedge clk or negedge inf.rst_n) begin : MAKE_DRINK_FSM_SEQ
    if (!inf.rst_n) make_state <= IDLE_M;
    else make_state <= make_nstate;
end
*/


// =======================================================================
//                          My Design
// =======================================================================
// -----------------------------------------------------
//                Data Type Declaration
// -----------------------------------------------------
typedef enum logic [2:0]{
    s_input,
    s_r_bridge,
    s_check_expired,
    s_check_enough,
    s_check_overflow,
    s_w_bridge,
    s_output
} state_sub;

state_t current_state, next_state;
state_sub sub_current_state, sub_next_state;

logic [2:0] cnt;

logic [9:0] bev_volume, half_volume, qua_volume;

logic [0:0] check_expired_fail, check_enough_fail, check_overflow_fail;

logic [0:0] temp_uncomplete;
logic [1:0] temp_err_msg;

// use the variable in usertype
Bev_Type in_bev_type;
Bev_Size in_bev_size;
Month in_month;
Day in_day;
Barrel_No in_barrel_no;
ING in_ing_B, in_ing_G, in_ing_M, in_ing_J;
ING consumed_vol_B, consumed_vol_G, consumed_vol_M, consumed_vol_J;
logic [12:0] total_vol_B, total_vol_G, total_vol_M, total_vol_J;
ING update_vol_B, update_vol_G, update_vol_M, update_vol_J;
Bev_Bal box;

// -----------------------------------------------------
//                       Design
// -----------------------------------------------------

// Main FSM
always_ff @(posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) current_state <= IDLE;
	else current_state <= next_state;
end

always_comb begin
    case(current_state)
    IDLE: begin
        if (inf.sel_action_valid) begin
            case(inf.D.d_act[0])
            Make_drink: next_state = MAKE_DRINK;
            Supply: next_state = SUPPLY;
            Check_Valid_Date: next_state = CHECK_DATE;
            default: next_state = IDLE;
            endcase
        end
        else next_state = IDLE;
    end
    MAKE_DRINK: begin
        if(inf.out_valid) next_state = IDLE;
        else next_state = MAKE_DRINK;
    end
    SUPPLY: begin
        if(inf.out_valid) next_state = IDLE;
        else next_state = SUPPLY;
    end
    CHECK_DATE: begin
        if(inf.out_valid) next_state = IDLE;
        else next_state = CHECK_DATE;
    end
    default: next_state = current_state;
    endcase
end

// Sub FSM
always_ff @(posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) sub_current_state <= s_input;
	else sub_current_state <= sub_next_state;
end

always_comb begin
    case(sub_current_state)
    s_input: begin
        case(current_state)
        SUPPLY: begin
            if(cnt==3'd4) sub_next_state = s_r_bridge;
            else sub_next_state = s_input;
        end
        default: begin
            if(inf.box_no_valid) sub_next_state = s_r_bridge;
            else sub_next_state = s_input;
        end
        endcase
    end
    s_r_bridge: begin
        if(inf.C_out_valid && current_state==SUPPLY) sub_next_state = s_check_overflow;
        else if(inf.C_out_valid && (current_state==MAKE_DRINK || current_state==CHECK_DATE)) sub_next_state = s_check_expired;
        else sub_next_state = s_r_bridge;
    end
    s_check_expired: begin
        if(!check_expired_fail && current_state==MAKE_DRINK) sub_next_state = s_check_enough;
        else sub_next_state = s_output;
    end
    s_check_enough: begin
        if(check_enough_fail) sub_next_state = s_output;
        else sub_next_state = s_w_bridge;
    end
    s_check_overflow: begin
        if(cnt==1'd1) sub_next_state = s_w_bridge;
        else sub_next_state = s_check_overflow;
    end
    s_w_bridge: begin
        //if(cnt==2'd2) sub_next_state = s_output;
        if(inf.C_out_valid) sub_next_state = s_output;
        else sub_next_state = s_w_bridge;
    end
    s_output: begin
        if(inf.out_valid) sub_next_state = s_input;
        else sub_next_state = s_output;
    end
    default: sub_next_state = sub_current_state;
    endcase
end

// Counter
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) cnt <= 3'd0;
    else if(current_state==SUPPLY && sub_current_state==s_input) begin
        if(cnt==3'd4) cnt <= 3'd0;
        else if(inf.box_sup_valid) cnt <= cnt + 1'd1;
        else cnt <= cnt;
    end
    else if(sub_current_state==s_r_bridge || sub_current_state==s_w_bridge) begin
        if(cnt==2'd2) cnt <= cnt;
        else cnt <= cnt + 1'd1;
    end
    else if(sub_current_state==s_check_overflow) begin
        if(cnt==1'd1) cnt <= 3'd0;
        else cnt <= cnt + 1'd1;
    end
    //else if(sub_current_state==s_output) begin
    //    if(cnt==1'd1) cnt <= 3'd0;
    //    else cnt <= cnt + 1'd1;
    //end
    else cnt <= 3'd0;
end


// ----------------------
// s_input
// ----------------------
// beverage type
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) in_bev_type <= 3'h0;
    else if(inf.type_valid) in_bev_type <= inf.D.d_type[0];
    else in_bev_type <= in_bev_type;
end

// beverage size
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) in_bev_size <= 3'h0;
    else if(inf.size_valid) in_bev_size <= inf.D.d_size[0];
    else in_bev_size <= in_bev_size;
end

always_comb begin
    case(in_bev_size)
    L: bev_volume = 10'd960;
    M: bev_volume = 10'd720;
    S: bev_volume = 10'd480;
    default: bev_volume = 10'd0;
    endcase
end

// date input from pattern
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        in_month <= 4'd0;
        in_day   <= 5'd0;
    end
    else if(inf.date_valid) begin
        in_month <= inf.D.d_date[0] [8:5];
        in_day   <= inf.D.d_date[0] [4:0];
    end
    else begin
        in_month <= in_month; 
        in_day   <= in_day; 
    end
end

// ingredient box No.
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) in_barrel_no <= 8'd0;
    else if(inf.box_no_valid) in_barrel_no <= inf.D.d_box_no[0];
    else in_barrel_no <= in_barrel_no;
end

// ingredient supplementary content
assign half_volume = bev_volume >> 1'd1;
assign qua_volume = bev_volume >> 2'd2;

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        in_ing_B <= 12'd0;
        in_ing_G <= 12'd0;
        in_ing_M <= 12'd0;
        in_ing_J <= 12'd0;
    end
    else if(current_state==MAKE_DRINK && sub_current_state==s_r_bridge) begin
        case(in_bev_type)
        Black_Tea: begin
            in_ing_B <= bev_volume;
            in_ing_G <= 12'd0;
            in_ing_M <= 12'd0;
            in_ing_J <= 12'd0;
        end
        Milk_Tea: begin
            in_ing_B <= (qua_volume) * 2'd3;
            in_ing_G <= 12'd0;
            in_ing_M <= qua_volume;
            in_ing_J <= 12'd0;
        end
        Extra_Milk_Tea: begin
            in_ing_B <= half_volume;
            in_ing_G <= 12'd0;
            in_ing_M <= half_volume;
            in_ing_J <= 12'd0;
        end
        Green_Tea: begin
            in_ing_B <= 12'd0;
            in_ing_G <= bev_volume;
            in_ing_M <= 12'd0;
            in_ing_J <= 12'd0;
        end
        Green_Milk_Tea: begin
            in_ing_B <= 12'd0;
            in_ing_G <= half_volume;
            in_ing_M <= half_volume;
            in_ing_J <= 12'd0;
        end
        Pineapple_Juice: begin
            in_ing_B <= 12'd0;
            in_ing_G <= 12'd0;
            in_ing_M <= 12'd0;
            in_ing_J <= bev_volume;
        end
        Super_Pineapple_Tea: begin
            in_ing_B <= half_volume;
            in_ing_G <= 12'd0;
            in_ing_M <= 12'd0;
            in_ing_J <= half_volume;
        end
        Super_Pineapple_Milk_Tea: begin
            in_ing_B <= half_volume;
            in_ing_G <= 12'd0;
            in_ing_M <= qua_volume;
            in_ing_J <= qua_volume;
        end
        default: begin
            in_ing_B <= in_ing_B;
            in_ing_G <= in_ing_G;
            in_ing_M <= in_ing_M;
            in_ing_J <= in_ing_J;
        end
        endcase
    end
    else if(current_state==SUPPLY && inf.box_sup_valid) begin
        in_ing_J <= inf.D.d_ing[0];
        in_ing_M <= in_ing_J;
        in_ing_G <= in_ing_M;
        in_ing_B <= in_ing_G;
    end
    else begin
        in_ing_B <= in_ing_B;
        in_ing_G <= in_ing_G;
        in_ing_M <= in_ing_M;
        in_ing_J <= in_ing_J;
    end
end


// ----------------------
// s_r_bridge, s_w_bridge
// ----------------------
// Output to Bridge
// -----------------
// inf.C_in_valid
always_comb begin
    if(!inf.rst_n) inf.C_in_valid = 1'd0;
    else if(sub_current_state==s_r_bridge && cnt==1'd1) inf.C_in_valid = 1'd1;
    else if(sub_current_state==s_w_bridge && cnt==1'd1) inf.C_in_valid = 1'd1;
    else inf.C_in_valid = 1'd0;
end

// inf.C_r_wb (0:write, 1:read)
always_comb begin
    if(!inf.rst_n) inf.C_r_wb = 1'd0;
    else if(sub_current_state==s_r_bridge && cnt==1'd1) inf.C_r_wb = 1'd1;
    else if(sub_current_state==s_w_bridge && cnt==1'd1) inf.C_r_wb = 1'd0;
    else inf.C_r_wb = 1'd1;
end

// inf.C_addr
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.C_addr <= 8'd0;
    else if(sub_current_state==s_r_bridge && cnt==1'd0) inf.C_addr <= in_barrel_no;
    else if(sub_current_state==s_w_bridge && cnt==1'd0) inf.C_addr <= in_barrel_no;
    else inf.C_addr <= 8'd0;
end

//inf.C_data_w
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.C_data_w <= 64'd0;
    else if(sub_current_state==s_w_bridge && cnt==1'd0) begin
        case(current_state)
        MAKE_DRINK: inf.C_data_w <= {consumed_vol_B, consumed_vol_G, 4'd0, box.M, consumed_vol_M, consumed_vol_J, 3'd0, box.D};
        SUPPLY: inf.C_data_w <= {update_vol_B, update_vol_G, 4'd0, in_month, update_vol_M, update_vol_J, 3'd0, in_day};
        default: inf.C_data_w <= 64'd0;
        endcase
    end
    else inf.C_data_w <= 64'd0;
end

// ------------------
// Input from Bridge
// ------------------
// black_tea on box
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) box.black_tea <= 12'd0;
    else if(sub_current_state==s_r_bridge && inf.C_out_valid) box.black_tea <= inf.C_data_r[63:52];
    else box.black_tea <= box.black_tea;
end

// green_tea on box
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) box.green_tea <= 12'd0;
    else if(sub_current_state==s_r_bridge && inf.C_out_valid) box.green_tea <= inf.C_data_r[51:40];
    else box.green_tea <= box.green_tea;
end

// milk on box
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) box.milk <= 12'd0;
    else if(sub_current_state==s_r_bridge && inf.C_out_valid) box.milk <= inf.C_data_r[31:20];
    else box.milk <= box.milk;
end

// pineapple_juice on box
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) box.pineapple_juice <= 12'd0;
    else if(sub_current_state==s_r_bridge && inf.C_out_valid) box.pineapple_juice <= inf.C_data_r[19:8];
    else box.pineapple_juice <= box.pineapple_juice;
end

// expire date on box
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin 
        box.M <= 4'd0;
        box.D <= 5'd0;
    end
    else if(sub_current_state==s_r_bridge && inf.C_out_valid) begin
        box.M <= inf.C_data_r[39:32];
        box.D <= inf.C_data_r[7:0];
    end
    else begin
        box.M <= box.M;
        box.D <= box.D;
    end
end


// ----------------------
// s_check_expired
// ----------------------
// check_expired_fail
always_comb begin
    if(sub_current_state==s_check_expired && in_month>box.M) check_expired_fail = 1'd1;
    else if(sub_current_state==s_check_expired && in_month==box.M && in_day>box.D) check_expired_fail = 1'd1;
    else check_expired_fail = 1'd0;
end


// ----------------------
// s_check_enough
// ----------------------
// check_enough_fail
always_comb begin
    if     (sub_current_state==s_check_enough && (in_ing_B>box.black_tea)) check_enough_fail = 1'd1;
    else if(sub_current_state==s_check_enough && (in_ing_G>box.green_tea)) check_enough_fail = 1'd1;
    else if(sub_current_state==s_check_enough && (in_ing_M>box.milk))      check_enough_fail = 1'd1;
    else if(sub_current_state==s_check_enough && (in_ing_J>box.pineapple_juice)) check_enough_fail = 1'd1;
    else check_enough_fail = 1'd0;
end

assign consumed_vol_B = box.black_tea       - in_ing_B;
assign consumed_vol_G = box.green_tea       - in_ing_G;
assign consumed_vol_M = box.milk            - in_ing_M;
assign consumed_vol_J = box.pineapple_juice - in_ing_J;


// ----------------------
// s_check_overflow
// ----------------------
assign total_vol_B = in_ing_B + box.black_tea;
assign total_vol_G = in_ing_G + box.green_tea;
assign total_vol_M = in_ing_M + box.milk;
assign total_vol_J = in_ing_J + box.pineapple_juice;

// check_overflow_fail
always_comb begin
    if     (sub_current_state==s_check_overflow && total_vol_B>12'd4095) check_overflow_fail = 1'd1;
    else if(sub_current_state==s_check_overflow && total_vol_G>12'd4095) check_overflow_fail = 1'd1;
    else if(sub_current_state==s_check_overflow && total_vol_M>12'd4095) check_overflow_fail = 1'd1;
    else if(sub_current_state==s_check_overflow && total_vol_J>12'd4095) check_overflow_fail = 1'd1;
    else check_overflow_fail = 1'd0;
end

// update the content in box;
assign update_vol_B = (total_vol_B>12'd4095) ? 12'd4095 : total_vol_B;
assign update_vol_G = (total_vol_G>12'd4095) ? 12'd4095 : total_vol_G;
assign update_vol_M = (total_vol_M>12'd4095) ? 12'd4095 : total_vol_M;
assign update_vol_J = (total_vol_J>12'd4095) ? 12'd4095 : total_vol_J;


// ----------------------
// s_output
// ----------------------
// temp_uncomplete
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) temp_uncomplete <= 1'd0;
    else if(current_state==IDLE) temp_uncomplete <= 1'd0;
    else if(check_expired_fail) temp_uncomplete <= 1'd1;
    else if(check_enough_fail) temp_uncomplete <= 1'd1;
    else if(check_overflow_fail) temp_uncomplete <= 1'd1;
    else temp_uncomplete <= temp_uncomplete;
end

// temp_err_msg
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) temp_err_msg <= 2'b00;
    else if(current_state==IDLE) temp_err_msg <= 2'b00;
    else if(check_expired_fail) temp_err_msg <= 2'b01;
    else if(check_enough_fail) temp_err_msg <= 2'b10;
    else if(check_overflow_fail) temp_err_msg <= 2'b11;
    else temp_err_msg <= temp_err_msg;
end

// inf.out_valid
always_comb begin
    if(!inf.rst_n) inf.out_valid = 1'd0;
    else if(sub_current_state==s_output) inf.out_valid = 1'd1;
    else inf.out_valid = 1'd0;
end

// inf.complete
always_comb begin
    if(!inf.rst_n) inf.complete = 1'd0;
    else if(sub_current_state==s_output) inf.complete = ~temp_uncomplete;
    else inf.complete = 1'd0;
end

//inf.err_msg
always_comb begin
    if(!inf.rst_n) inf.err_msg = 2'b00;
    else if(sub_current_state==s_output) inf.err_msg = temp_err_msg;
    else inf.err_msg = 2'b00;
end


endmodule