/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2024 Spring IC Design Laboratory 
Lab09: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: Apr-2024)
Author : Jui-Huang Tsai (erictsai.ee12@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;


//    Coverage Part

class BEV;
    Bev_Type bev_type;
    Bev_Size bev_size;
endclass

BEV bev_info = new();

always_ff @(posedge clk) begin
    if (inf.type_valid) begin
        bev_info.bev_type = inf.D.d_type[0];
    end
end 

always_ff @(posedge clk) begin
    if (inf.size_valid) begin
        bev_info.bev_size = inf.D.d_size[0];
    end
end 


// 1. Each case of Beverage_Type should be select at least 100 times.
covergroup Spec1 @(posedge clk);
    option.per_instance = 1;
    option.at_least = 100;
    btype: coverpoint bev_info.bev_type{
        bins b_bev_type [] = {Black_Tea, Milk_Tea, Extra_Milk_Tea, Green_Tea, Green_Milk_Tea, Pineapple_Juice, Super_Pineapple_Tea, Super_Pineapple_Milk_Tea};
    }
endgroup

// 2. Each case of Bererage_Size should be select at least 100 times.
covergroup Spec2 @(posedge clk);
    option.per_instance = 1;
    option.at_least = 100;
    bsize: coverpoint bev_info.bev_size{
        bins b_bev_size [] = {L, M, S};
        illegal_bins b_bev_size_ill = default;
    }
endgroup

// 3. Create a cross bin for the SPEC1 and SPEC2. Each combination should be selected at least 100 times. 
//(Black Tea, Milk Tea, Extra Milk Tea, Green Tea, Green Milk Tea, Pineapple Juice, Super Pineapple Tea, Super Pineapple Tea) x (L, M, S)
covergroup Spec3 @(posedge clk);
    option.per_instance = 1;
    option.at_least = 100;
    cbtype: coverpoint bev_info.bev_type{
        bins b_bev_type [] = {Black_Tea, Milk_Tea, Extra_Milk_Tea, Green_Tea, Green_Milk_Tea, Pineapple_Juice, Super_Pineapple_Tea, Super_Pineapple_Milk_Tea};
    }
    cbsize: coverpoint bev_info.bev_size{
        bins b_bev_size [] = {L, M, S};
        illegal_bins b_bev_size_ill = default;
    }
    cross cbtype, cbsize;
endgroup


// 4. Output signal inf.err_msg should be No_Err, No_Exp, No_Ing and Ing_OF, each at least 20 times. (Sample the value when inf.out_valid is high)
Error_Msg err_info;

always_ff @(posedge clk) begin
    if (inf.out_valid) begin
        err_info = inf.err_msg;
    end
end 

covergroup Spec4 @(posedge clk);
    option.per_instance = 1;
    option.at_least = 20;
    berr: coverpoint err_info{
        bins b_err_msg [] = {No_Err, No_Exp, No_Ing, Ing_OF};
    }
endgroup


// 5. Create the transitions bin for the inf.D.act[0] signal from [0:2] to [0:2]. Each transition should be hit at least 200 times. (sample the value at posedge clk iff inf.sel_action_valid)
Action act_info;

always_ff @(posedge clk) begin
    if (inf.sel_action_valid) begin
        act_info = inf.D.d_act[0];
    end
end 

covergroup Spec5 @(posedge clk iff(inf.sel_action_valid));
    option.per_instance = 1;
    option.at_least = 200;
    bact: coverpoint act_info{
        bins b_action [] = ([Make_drink:Check_Valid_Date]=>[Make_drink:Check_Valid_Date]);
        illegal_bins b_action_ill = default;
    }
endgroup

// 6. Create a covergroup for material of supply action with auto_bin_max = 32, and each bin have to hit at least one time.
logic [1:0] sup_cnt;
ING sup_B, sup_G, sup_M, sup_J;

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) sup_cnt <= 0;
    else if (inf.box_sup_valid) sup_cnt <= sup_cnt + 1;
    //else if(inf.sel_action_valid) sup_cnt <= 0;
    else sup_cnt <= sup_cnt;
end 

always_ff @(posedge clk) begin
    if (inf.box_sup_valid) begin
        case(sup_cnt)
        0: sup_B = inf.D.d_ing[0];
        1: sup_G = inf.D.d_ing[0];
        2: sup_M = inf.D.d_ing[0];
        3: sup_J = inf.D.d_ing[0];
        endcase
    end
end 

covergroup Spec6 @(posedge clk iff(inf.box_sup_valid));
    option.per_instance = 1;
    option.at_least = 1;
    option.auto_bin_max = 32;
    bsup_B: coverpoint sup_B{
        bins b_sup_B = {[1:4095]};
        ignore_bins b_sup_B_ig = {0};
    }
    bsup_G: coverpoint sup_G{
        bins b_sup_G = {[1:4095]};
        ignore_bins b_sup_G_ig = {0};
    }
    bsup_M: coverpoint sup_M{
        bins b_sup_M = {[1:4095]};
        ignore_bins b_sup_M_ig = {0};
    }
    bsup_J: coverpoint sup_J{
        bins b_sup_J = {[1:4095]};
        ignore_bins b_sup_J_ig = {0};
    }
endgroup


    //Create instances of Spec1, Spec2, Spec3, Spec4, Spec5, and Spec6
    //Spec1_2_3 cov_inst_1_2_3 = new();

Spec1 spec1 = new();
Spec2 spec2 = new();
Spec3 spec3 = new();
Spec4 spec4 = new();
Spec5 spec5 = new();
Spec6 spec6 = new();



    // Asseration
    // If you need, you can declare some FSM, logic, flag, and etc. here.
// Variable Declaration
typedef enum logic [1:0]{
    IDLE,
    MAKE_DRINK,
    SUPPLY,
    CHECK_DATE
} state_t;

state_t current_state, next_state;
integer lat_num, inv_cnt, next_op_cnt, cinv_cnt, a_sup_cnt;
logic [0:0] flag_input, flag_inv_o, flag_day;
Date date_info;

// FSM
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) current_state <= IDLE;
    else current_state <= next_state;
end

always_comb begin
   case(current_state)
    IDLE: begin
        if(inf.sel_action_valid) begin
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


// for assertion2
always_ff @(negedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) lat_num <= 0;
    else begin
        case(current_state)
        MAKE_DRINK: begin
            if(inf.box_no_valid) lat_num <= 0;
            else if(!inf.out_valid) lat_num <= lat_num + 1;
            else lat_num <= lat_num;
        end
        SUPPLY: begin
            if(inf.box_sup_valid) lat_num <= 0;
            else if(!inf.out_valid) lat_num <= lat_num + 1;
            else lat_num <= lat_num;
        end
        CHECK_DATE: begin
            if(inf.box_no_valid) lat_num <= 0;
            else if(!inf.out_valid) lat_num <= lat_num + 1;
            else lat_num <= lat_num;
        end
        default: lat_num <= 0;
        endcase
    end
end

// for assertion4
always_ff @(negedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) a_sup_cnt <= 0;
    else if(current_state==IDLE) a_sup_cnt <= 0;
    else if(inf.box_sup_valid) a_sup_cnt <= a_sup_cnt + 1;
    else a_sup_cnt <= a_sup_cnt;
end

// flag to know the last input valid
always_ff @(negedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) flag_input <= 1'd0;
    else begin
        case(current_state)
        MAKE_DRINK: begin
            if(inf.box_no_valid) flag_input <= 1'd1;
        end
        SUPPLY: begin
            if(inf.box_sup_valid && a_sup_cnt==2'd3) flag_input <= 1'd1;
        end
        CHECK_DATE: begin
            if(inf.box_no_valid) flag_input <= 1'd1;
        end
        default: flag_input = 1'd0;
        endcase
    end
end

always_ff @(negedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inv_cnt <= 0;
    else if(current_state!=IDLE && !flag_input) begin
        if(!inf.sel_action_valid && !inf.type_valid && !inf.size_valid && !inf.date_valid && !inf.box_no_valid && !inf.box_sup_valid) inv_cnt <= inv_cnt + 1;
        else inv_cnt <= 0;
    end
    else inv_cnt <= 0;
end

// for assertion5
always_comb begin
    if(!inf.rst_n) flag_inv_o = 1'd0;
    else if(!inf.sel_action_valid && !inf.type_valid && !inf.size_valid && !inf.date_valid && !inf.box_no_valid && !inf.box_sup_valid) flag_inv_o = 1'd0;
    else if( inf.sel_action_valid && !inf.type_valid && !inf.size_valid && !inf.date_valid && !inf.box_no_valid && !inf.box_sup_valid) flag_inv_o = 1'd0;
    else if(!inf.sel_action_valid &&  inf.type_valid && !inf.size_valid && !inf.date_valid && !inf.box_no_valid && !inf.box_sup_valid) flag_inv_o = 1'd0;
    else if(!inf.sel_action_valid && !inf.type_valid &&  inf.size_valid && !inf.date_valid && !inf.box_no_valid && !inf.box_sup_valid) flag_inv_o = 1'd0;
    else if(!inf.sel_action_valid && !inf.type_valid && !inf.size_valid &&  inf.date_valid && !inf.box_no_valid && !inf.box_sup_valid) flag_inv_o = 1'd0;
    else if(!inf.sel_action_valid && !inf.type_valid && !inf.size_valid && !inf.date_valid &&  inf.box_no_valid && !inf.box_sup_valid) flag_inv_o = 1'd0;
    else if(!inf.sel_action_valid && !inf.type_valid && !inf.size_valid && !inf.date_valid && !inf.box_no_valid &&  inf.box_sup_valid) flag_inv_o = 1'd0;
    else flag_inv_o = 1'd1;
end

// for assertion7
always_ff @(negedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) next_op_cnt <= 0;
    else if(inf.out_valid) next_op_cnt <= 0;
    else if(current_state==IDLE && !inf.out_valid && !inf.sel_action_valid) next_op_cnt <= next_op_cnt + 1;
    else next_op_cnt <= 0;
end

// for assertion8
always_ff @(posedge clk) begin
    if (inf.date_valid) begin
        date_info.M = inf.D.d_date[0][8:5];
        date_info.D = inf.D.d_date[0][4:0];
    end
end 

always_comb begin
    case(date_info.M)
    1,3,5,7,8,10,12: if(date_info.D<1 || date_info.D>31) flag_day = 1'd1;
    2: if(date_info.D<1 || date_info.D>28) flag_day = 1'd1;
    4,6,9,11: if(date_info.D<1 || date_info.D>30) flag_day = 1'd1;
    default: flag_day = 1'd0;
    endcase
end

//for assertion9
always_ff @(negedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) cinv_cnt <= 0;
    else if(inf.C_out_valid) cinv_cnt <= 0;
    else if(inf.C_in_valid) cinv_cnt <= cinv_cnt + 1;
    else cinv_cnt <= cinv_cnt;
end


//1. All outputs signals (including BEV.sv and bridge.sv) should be zero after reset.
initial begin
    wait(!inf.rst_n);
    if(!inf.rst_n) begin
        a_reset: assert property(p_reset) //$display("Assertion 1 (bev) is passed"); 
                     else $fatal(0, "Assertion 1 is violated");
    end
end

property p_reset;
    @(negedge clk) ##1 (!inf.out_valid && !inf.complete && !inf.err_msg 
                        && !inf.C_addr && !inf.C_data_w && !inf.C_in_valid && !inf.C_r_wb && !inf.C_out_valid && !inf.C_data_r 
                        && !inf.AR_VALID && !inf.AR_ADDR && !inf.R_READY && !inf.AW_VALID && !inf.AW_ADDR && !inf.W_VALID && !inf.W_DATA && !inf.B_READY);
endproperty


//2. Latency should be less than 1000 cycles for each operation.
always_ff @(negedge clk) begin
    if(inf.out_valid || lat_num>1000)
        a_latency: assert property(lat_num<=1000) //$display("Assertion 2 is passed, latnum: %d", lat_num); 
                   else $fatal(0, "Assertion 2 is violated");
end

//3. If out_valid does not pull up, complete should be 0.
always_ff @(negedge clk) begin
    if(inf.complete) 
        a_complete: assert property(!inf.err_msg)
                    else $fatal(0, "Assertion 3 is violated");
end

//4. Next input valid will be valid 1-4 cycles after previous input valid fall.
always_ff @(negedge clk) begin
    if(current_state!=IDLE && !flag_input) begin
        a_invalid: assert property(@(negedge clk) ##1 inv_cnt<4) //$display("Assertion 4 is passed, input cnt: %d", inv_cnt);
                   else $fatal(0, "Assertion 4 is violated");
        a_invalid_sup: assert property(a_sup_cnt<4) 
                   else $fatal(0, "Assertion 4 is violated (sup)");
    end
end

//5. All input valid signals won't overlap with each other. 
always_ff @(negedge clk) begin
    if(current_state!=IDLE && !flag_input) 
        a_overlap: assert (!flag_inv_o)
                   else $fatal(0, "Assertion 5 is violated");
end

//6. Out_valid can only be high for exactly one cycle.
always_ff @(negedge clk) begin
    if(inf.out_valid) 
        a_outvalid: assert property(@(negedge clk) ##1 !inf.out_valid)
                    else $fatal(0, "Assertion 6 is violated");
end

//7. Next operation will be valid 1-4 cycles after out_valid fall.
always_ff @(negedge clk) begin
    a_next_op: assert property(@(negedge clk) ##1 next_op_cnt<5)
               else $fatal(0, "Assertion 7 is violated");
end

//8. The input date from pattern should adhere to the real calendar. (ex: 2/29, 3/0, 4/31, 13/1 are illegal cases)
always_ff @(negedge clk) begin
    if (inf.date_valid) begin
        a_date_m: assert (date_info.M>0 && date_info.M<13) 
                  else $fatal(0, "Assertion 8 is violated (month)");
        a_date_d: assert (!flag_day) //$display("flag day: %d", flag_day);
                  else $fatal(0, "Assertion 8 is violated (day)");
    end
end

//9. C_in_valid can only be high for one cycle and can't be pulled high again before C_out_valid
always_ff @(negedge clk) begin
    if(current_state==MAKE_DRINK || current_state==SUPPLY || current_state==CHECK_DATE)
        a_C_invalid: assert (cinv_cnt<2)
                     else $fatal(0, "Assertion 9 is violated");
end


endmodule
