/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2024 Spring IC Design Laboratory 
Lab09: SystemVerilog Design and Verification 
File Name   : PATTERN.sv
Module Name : PATTERN
Release version : v1.0 (Release Date: Apr-2024)
Author : Jui-Huang Tsai (erictsai.ee12@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";

`define CYCLE_TIME 2.8
parameter PATNUM = 2200; //2400;
//integer   SEED = 587;
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 1000;
parameter OUT_NUM = 1;

integer pat;
integer tot_lat, exe_lat, out_lat;

integer golden_DRAM_addr;

//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  // 256 box
//logic [7:0] process_DRAM [((8*256)-1):0];

// success to randomize
logic [0:0] success_rand_act, success_rand_type, success_rand_size, success_rand_date;
logic [0:0] success_rand_box, success_rand_supply_B, success_rand_supply_G, success_rand_supply_M, success_rand_supply_J;

logic [63:0] barrel_data;
logic [63:0] new_barrel_data;
Bev_Bal barrel;
ING make_B, make_G, make_M, make_J;
logic [9:0] make_volume;
ING update_B, update_G, update_M, update_J;
logic [12:0] supply_B, supply_G, supply_M, supply_J;
logic [0:0] flag_expire, flag_enough, flag_overflow;
logic [0:0] golden_complete;
logic [1:0] golden_err_msg;

logic [0:0] flag_complete_Err, flag_err_msg_Err;
logic [0:0] your_complete;
logic [1:0] your_err_msg;
logic [0:0] your_ans_Err;

// String control
// Should use %0s
logic [9*8:1]  reset_color       = "\033[1;0m";
logic [10*8:1] txt_black_prefix  = "\033[1;30m";
logic [10*8:1] txt_red_prefix    = "\033[1;31m";
logic [10*8:1] txt_green_prefix  = "\033[1;32m";
logic [10*8:1] txt_yellow_prefix = "\033[1;33m";
logic [10*8:1] txt_blue_prefix   = "\033[1;34m";


//================================================================
// class random
//================================================================

// Class for a random action (TA)
class random_act;
    randc Action act_id;
    constraint range{
        act_id inside{Make_drink, Supply, Check_Valid_Date};
    }
endclass

// Class for a random beverage type
class random_type;
    randc Bev_Type type_id;
    constraint range{
        type_id inside{Black_Tea, Milk_Tea, Extra_Milk_Tea, Green_Tea, Green_Milk_Tea, Pineapple_Juice, Super_Pineapple_Tea, Super_Pineapple_Milk_Tea};
    }
endclass

// Class for a random beverage size
class random_size;
    randc Bev_Size size_id;
    constraint range{
        size_id inside{L, M, S};
    }
endclass

// Class for a random date
class random_date;
    randc Date date_id;
    constraint range{
        date_id.M inside{[1:12]};
        (date_id.M== 1) -> date_id.D inside{[1:31]};
        (date_id.M== 2) -> date_id.D inside{[1:28]};
        (date_id.M== 3) -> date_id.D inside{[1:31]};
        (date_id.M== 4) -> date_id.D inside{[1:30]};
        (date_id.M== 5) -> date_id.D inside{[1:31]};
        (date_id.M== 6) -> date_id.D inside{[1:30]};
        (date_id.M== 7) -> date_id.D inside{[1:31]};
        (date_id.M== 8) -> date_id.D inside{[1:31]};
        (date_id.M== 9) -> date_id.D inside{[1:30]};
        (date_id.M==10) -> date_id.D inside{[1:31]};
        (date_id.M==11) -> date_id.D inside{[1:30]};
        (date_id.M==12) -> date_id.D inside{[1:31]};
    }
endclass

// Class for a random box from 0 to 31 (TA)
class random_box;
    randc logic [7:0] box_id;
    constraint range{
        box_id inside{[0:255]};
    }
endclass

// Class for a random box supply
class random_supply;
    randc ING supply_id;
    constraint range{
        supply_id inside{[0:4095]};
    }
endclass

random_act rand_act;
random_type rand_type;
random_size rand_size;
//random_date_m rand_date_m;
//random_date_d rand_date_d;
random_date rand_date;
random_box rand_box;
random_supply rand_supply_B, rand_supply_G, rand_supply_M, rand_supply_J;

//================================================================
// initial
//================================================================

initial $readmemh(DRAM_p_r, golden_DRAM);

initial exe_task;


// ======================================
// Task
// ======================================
task exe_task; begin
    reset_task;
    @(negedge clk);
    for (pat=0 ; pat<PATNUM ; pat=pat+1) begin
        input_task;
        process_task;
        wait_task;
        check_task;
        // Print Pass Info and accumulate the total latency
        $display("%0sPASS PATTERN NO.%4d, %0sCycles: %3d%0s",txt_blue_prefix, pat, txt_green_prefix, exe_lat, reset_color);
    end
    pass_task;
end endtask



// Reset
task reset_task; begin
    force clk = 0;
    inf.rst_n = 1;

    inf.sel_action_valid = 'd0;
    inf.type_valid = 'd0;
    inf.size_valid = 'd0;
    inf.date_valid = 'd0;
    inf.box_no_valid = 'd0;
    inf.box_sup_valid = 'd0;
    inf.D = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) inf.rst_n = 0;
    #(CYCLE/2.0) inf.rst_n = 1;
    if (inf.out_valid!==0 || inf.err_msg!==0 || inf.complete!==0) begin
        $display("                                           `:::::`                                                       ");
        $display("                                          .+-----++                                                      ");
        $display("                .--.`                    o:------/o                                                      ");
        $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
        $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
        $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
        $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
        $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
        $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
        $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
        $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
        $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
        $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
        $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
        $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
        $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
        $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
        $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
        $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
        $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
        $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
        $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
        $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
        $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
        $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
        $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
        $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
        $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     after the reset signal is asserted");
        $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
        $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
        $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
        $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
        $display("                       `s--------------------------::::::::-----:o                                       ");
        $display("                       +:----------------------------------------y`                                      ");
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask


// Input
task random_input; begin
    rand_act = new();
    rand_type = new();
    rand_size = new();
    //rand_date_m = new();
    //rand_date_d = new();
    rand_date = new();
    rand_box = new();
    rand_supply_B = new();
    rand_supply_G = new();
    rand_supply_M = new();
    rand_supply_J = new();

    
    success_rand_act = rand_act.randomize();
    success_rand_type = rand_type.randomize();
    success_rand_size = rand_size.randomize();
    //success_rand_date_m = rand_date_m.randomize();
    //success_rand_date_d = rand_date_d.randomize();
    success_rand_date = rand_date.randomize();
    success_rand_box = rand_box.randomize();
    success_rand_supply_B = rand_supply_B.randomize();
    success_rand_supply_G = rand_supply_G.randomize();
    success_rand_supply_M = rand_supply_M.randomize();
    success_rand_supply_J = rand_supply_J.randomize();
end endtask

task input_task; begin
    random_input;
    repeat($random()%4) @(negedge clk);

    inf.sel_action_valid = 1'd1;
    inf.D.d_act[0] = rand_act.act_id;
    @(negedge clk);
    inf.sel_action_valid = 1'd0;
    inf.D.d_act[0] = 'bx;
    repeat($random()%4) @(negedge clk);

    if(rand_act.act_id==Make_drink) begin
        inf.type_valid = 1'd1;
        inf.D.d_type[0] = rand_type.type_id;
        @(negedge clk);
        inf.type_valid = 1'd0;
        inf.D.d_type[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.size_valid = 1'd1;
        inf.D.d_size[0] = rand_size.size_id;
        @(negedge clk);
        inf.size_valid = 1'd0;
        inf.D.d_size[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.date_valid = 1'd1;
        inf.D.d_date[0] = rand_date.date_id; 
        @(negedge clk);
        inf.date_valid = 1'd0;
        inf.D.d_date[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.box_no_valid = 1'd1;
        inf.D.d_box_no[0] = rand_box.box_id; 
        @(negedge clk);
        inf.box_no_valid = 1'd0;
        inf.D.d_box_no[0] = 'bx;
    end
    else if(rand_act.act_id==Supply) begin
        inf.date_valid = 1'd1;
        inf.D.d_date[0] = rand_date.date_id;
        @(negedge clk);
        inf.date_valid = 1'd0;
        inf.D.d_date[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.box_no_valid = 1'd1;
        inf.D.d_box_no[0] = rand_box.box_id;
        @(negedge clk);
        inf.box_no_valid = 1'd0;
        inf.D.d_box_no[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.box_sup_valid = 1'd1;
        inf.D.d_ing[0] = rand_supply_B.supply_id;
        @(negedge clk);
        inf.box_sup_valid = 1'd0;
        inf.D.d_ing[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.box_sup_valid = 1'd1;
        inf.D.d_ing[0] = rand_supply_G.supply_id;
        @(negedge clk);
        inf.box_sup_valid = 1'd0;
        inf.D.d_ing[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.box_sup_valid = 1'd1;
        inf.D.d_ing[0] = rand_supply_M.supply_id;
        @(negedge clk);
        inf.box_sup_valid = 1'd0;
        inf.D.d_ing[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.box_sup_valid = 1'd1;
        inf.D.d_ing[0] = rand_supply_J.supply_id;
        @(negedge clk);
        inf.box_sup_valid = 1'd0;
        inf.D.d_ing[0] = 'bx;
    end
    else if(rand_act.act_id==Check_Valid_Date) begin
        inf.date_valid = 1'd1;
        inf.D.d_date[0] = rand_date.date_id;
        @(negedge clk);
        inf.date_valid = 1'd0;
        inf.D.d_date[0] = 'bx;
        repeat($random()%4) @(negedge clk);

        inf.box_no_valid = 1'd1;
        inf.D.d_box_no[0] = rand_box.box_id;
        @(negedge clk);
        inf.box_no_valid = 1'd0;
        inf.D.d_box_no[0] = 'bx;
    end
end endtask


// Process golden answer
task process_task; begin
    golden_DRAM_addr = rand_box.box_id * 8 + 65536;
    //$display("box no.:  %h(h) / %d(d)", rand_box.box_id, rand_box.box_id);
    //$display("box addr: %d", golden_DRAM_addr);

    barrel_data = {golden_DRAM[golden_DRAM_addr+7], 
                   golden_DRAM[golden_DRAM_addr+6], 
                   golden_DRAM[golden_DRAM_addr+5],
                   golden_DRAM[golden_DRAM_addr+4],
                   golden_DRAM[golden_DRAM_addr+3],
                   golden_DRAM[golden_DRAM_addr+2],
                   golden_DRAM[golden_DRAM_addr+1],
                   golden_DRAM[golden_DRAM_addr  ]
                  };
    //$display("barrel_data: %h", barrel_data);
    barrel.black_tea       = barrel_data[63:52];
    barrel.green_tea       = barrel_data[51:40];
    barrel.M               = barrel_data[39:32];
    barrel.milk            = barrel_data[31:20];
    barrel.pineapple_juice = barrel_data[19: 8];
    barrel.D               = barrel_data[ 7: 0];
    //$display("barrel.black_tea: %d", barrel.black_tea);
    //$display("barrel.green_tea: %d", barrel.green_tea);
    //$display("barrel.milk: %d", barrel.milk);
    //$display("barrel.pineapple_juice: %d", barrel.pineapple_juice);

    if(rand_act.act_id==Make_drink) begin
        // expire
        if(rand_date.date_id.M>barrel.M) flag_expire = 1'd1;
        else if(rand_date.date_id.M==barrel.M) begin
            if(rand_date.date_id.D>barrel.D) flag_expire = 1'd1;
            else flag_expire = 1'd0;
        end
        else flag_expire = 1'd0;

        // enough
        case(rand_size.size_id)
        L: make_volume = 960;
        M: make_volume = 720;
        S: make_volume = 480;
        endcase

        case(rand_type.type_id)
        Black_Tea: begin
            make_B = make_volume;
            make_G = 12'd0;
            make_M = 12'd0;
            make_J = 12'd0;
        end
        Milk_Tea: begin
            make_B = (make_volume/4)*3;
            make_G = 12'd0;
            make_M = make_volume/4;
            make_J = 12'd0;
        end
        Extra_Milk_Tea: begin
            make_B = make_volume/2;
            make_G = 12'd0;
            make_M = make_volume/2;
            make_J = 12'd0;
        end
        Green_Tea: begin
            make_B = 12'd0;
            make_G = make_volume;
            make_M = 12'd0;
            make_J = 12'd0;
        end
        Green_Milk_Tea: begin
            make_B = 12'd0;
            make_G = make_volume/2;
            make_M = make_volume/2;
            make_J = 12'd0;
        end
        Pineapple_Juice: begin
            make_B = 12'd0;
            make_G = 12'd0;
            make_M = 12'd0;
            make_J = make_volume;
        end
        Super_Pineapple_Tea: begin
            make_B = make_volume/2;
            make_G = 12'd0;
            make_M = 12'd0;
            make_J = make_volume/2;
        end
        Super_Pineapple_Milk_Tea: begin
            make_B = make_volume/2;
            make_G = 12'd0;
            make_M = make_volume/4;
            make_J = make_volume/4;
        end
        default: begin
            make_B = 12'd0;
            make_G = 12'd0;
            make_M = 12'd0;
            make_J = 12'd0;
        end
        endcase

        if(make_B<=barrel.black_tea && make_G<=barrel.green_tea && make_M<=barrel.milk && make_J<=barrel.pineapple_juice) flag_enough = 1'd0;
        else flag_enough = 1'd1;
        //$display("make_vol:  %d", make_volume);
        //$display("make_type: %d", rand_type.type_id);
        //$display("make_b/g/m/j: %d/ %d/ %d/ %d", make_B, make_G, make_M, make_J);
        //$display("box_b/g/m/j:  %d/ %d/ %d/ %d", barrel.black_tea, barrel.green_tea, barrel.milk, barrel.pineapple_juice);

        //golden answer
        golden_complete = ~(flag_expire | flag_enough);
        if(flag_expire) golden_err_msg = 2'b01;
        else if(flag_enough) golden_err_msg = 2'b10;
        else golden_err_msg = 2'b00;

        // write in dram
        if(golden_complete) begin
            update_B = barrel.black_tea - make_B;
            update_G = barrel.green_tea - make_G;
            update_M = barrel.milk      - make_M;
            update_J = barrel.pineapple_juice - make_J;
        end
        //$display("update_b/g/m/j: %h/ %h/ %h/ %h", update_B, update_G, update_M, update_J);

        if(golden_complete) begin
            golden_DRAM[golden_DRAM_addr+7] = update_B[11:4];
            golden_DRAM[golden_DRAM_addr+6] = {update_B[3:0], update_G[11:8]};
            golden_DRAM[golden_DRAM_addr+5] = update_G[7:0];
            golden_DRAM[golden_DRAM_addr+4] = barrel.M;
            golden_DRAM[golden_DRAM_addr+3] = update_M[11:4];
            golden_DRAM[golden_DRAM_addr+2] = {update_M[3:0], update_J[11:8]};
            golden_DRAM[golden_DRAM_addr+1] = update_J[7:0];
            golden_DRAM[golden_DRAM_addr  ] = barrel.D;
        end
        new_barrel_data = {golden_DRAM[golden_DRAM_addr+7], 
                   golden_DRAM[golden_DRAM_addr+6], 
                   golden_DRAM[golden_DRAM_addr+5],
                   golden_DRAM[golden_DRAM_addr+4],
                   golden_DRAM[golden_DRAM_addr+3],
                   golden_DRAM[golden_DRAM_addr+2],
                   golden_DRAM[golden_DRAM_addr+1],
                   golden_DRAM[golden_DRAM_addr  ]
                  };
        //$display("new barrel: %h", new_barrel_data);
    end
    else if(rand_act.act_id==Supply) begin
        // overflow
        supply_B = rand_supply_B.supply_id + barrel.black_tea;
        supply_G = rand_supply_G.supply_id + barrel.green_tea;
        supply_M = rand_supply_M.supply_id + barrel.milk;
        supply_J = rand_supply_J.supply_id + barrel.pineapple_juice;
        //$display("bar_b/g/m/j: %d / %d / %d / %d",barrel.black_tea, barrel.green_tea, barrel.milk, barrel.pineapple_juice);
        //$display("ran_b/g/m/j: %d / %d / %d / %d",rand_supply_B.supply_id, rand_supply_G.supply_id, rand_supply_M.supply_id, rand_supply_J.supply_id);
        //$display("sup_b/g/m/j: %d / %d / %d / %d",supply_B, supply_G, supply_M, supply_J);

        if(supply_B<=4095 && supply_G<=4095 && supply_M<=4095 && supply_J<=4095) flag_overflow = 1'd0;
        else flag_overflow = 1'd1;

        // golden answer
        golden_complete = ~flag_overflow;
        if(flag_overflow) golden_err_msg = 2'b11;
        else golden_err_msg = 2'b00;

        // write in dram (no matter it is overflow)
        if(supply_B<=4095) update_B = supply_B;
        else update_B = 12'd4095;
        if(supply_G<=4095) update_G = supply_G;
        else update_G = 12'd4095;
        if(supply_M<=4095) update_M = supply_M;
        else update_M = 12'd4095;
        if(supply_J<=4095) update_J = supply_J;
        else update_J = 12'd4095;

        golden_DRAM[golden_DRAM_addr+7] = update_B[11:4];
        golden_DRAM[golden_DRAM_addr+6] = {update_B[3:0], update_G[11:8]};
        golden_DRAM[golden_DRAM_addr+5] = update_G[7:0];
        golden_DRAM[golden_DRAM_addr+4] =rand_date.date_id.M;
        golden_DRAM[golden_DRAM_addr+3] = update_M[11:4];
        golden_DRAM[golden_DRAM_addr+2] = {update_M[3:0], update_J[11:8]};
        golden_DRAM[golden_DRAM_addr+1] = update_J[7:0];
        golden_DRAM[golden_DRAM_addr  ] = rand_date.date_id.D;
    end
    else if(rand_act.act_id==Check_Valid_Date) begin
        // expire
        if(rand_date.date_id.M>barrel.M) flag_expire = 1'd1;
        else if(rand_date.date_id.M==barrel.M) begin
            if(rand_date.date_id.D>barrel.D) flag_expire = 1'd1;
            else flag_expire = 1'd0;
        end
        else flag_expire = 1'd0;
        
        // golden answer
        golden_complete = ~flag_expire;
        if(flag_expire) golden_err_msg = 2'b01;
        else golden_err_msg = 2'b00;
    end
end endtask


// Wait Out_valid
task wait_task; begin
    //exe_lat = -1;
    exe_lat = 0;
    while(inf.out_valid!==1) begin
        if(inf.complete!==0 || inf.err_msg!==0) begin
            $display("                                           `:::::`                                                       ");
            $display("                                          .+-----++                                                      ");
            $display("                .--.`                    o:------/o                                                      ");
            $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
            $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
            $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
            $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
            $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
            $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
            $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
            $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
            $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
            $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
            $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
            $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
            $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
            $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
            $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
            $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
            $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
            $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
            $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
            $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
            $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
            $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
            $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
            $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
            $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     when the out_valid is pulled down ");
            $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
            $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
            $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
            $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
            $display("                       `s--------------------------::::::::-----:o                                       ");
            $display("                       +:----------------------------------------y`                                      ");
            //repeat(5) #(CYCLE);
            repeat(3) #(CYCLE);
            $finish;
        end
        if (exe_lat==DELAY) begin
            $display("                                   ..--.                                ");
            $display("                                `:/:-:::/-                              ");
            $display("                                `/:-------o                             ");
            $display("                                /-------:o:                             "); 
            $display("                                +-:////+s/::--..                        ");
            $display("    The execution latency      .o+/:::::----::::/:-.       at %-12d ps  ", $time*1000);
            $display("    is over %5d   cycles    `:::--:/++:----------::/:.                  ", DELAY);
            $display("                            -+:--:++////-------------::/-               ");
            $display("                            .+---------------------------:/--::::::.`   ");
            $display("                          `.+-----------------------------:o/------::.  ");
            $display("                       .-::-----------------------------:--:o:-------:  ");
            $display("                     -:::--------:/yy------------------/y/--/o------/-  ");
            $display("                    /:-----------:+y+:://:--------------+y--:o//:://-   ");
            $display("                   //--------------:-:+ssoo+/------------s--/. ````     ");
            $display("                   o---------:/:------dNNNmds+:----------/-//           ");
            $display("                   s--------/o+:------yNNNNNd/+--+y:------/+            ");
            $display("                 .-y---------o:-------:+sso+/-:-:yy:------o`            ");
            $display("              `:oosh/--------++-----------------:--:------/.            ");
            $display("              +ssssyy--------:y:---------------------------/            ");
            $display("              +ssssyd/--------/s/-------------++-----------/`           ");
            $display("              `/yyssyso/:------:+o/::----:::/+//:----------+`           ");
            $display("             ./osyyyysssso/------:/++o+++///:-------------/:            ");
            $display("           -osssssssssssssso/---------------------------:/.             ");
            $display("         `/sssshyssssssssssss+:---------------------:/+ss               ");
            $display("        ./ssssyysssssssssssssso:--------------:::/+syyys+               ");
            $display("     `-+sssssyssssssssssssssssso-----::/++ooooossyyssyy:                ");
            $display("     -syssssyssssssssssssssssssso::+ossssssssssssyyyyyss+`              ");
            $display("     .hsyssyssssssssssssssssssssyssssssssssyhhhdhhsssyssso`             ");
            $display("     +/yyshsssssssssssssssssssysssssssssyhhyyyyssssshysssso             ");
            $display("    ./-:+hsssssssssssssssssssssyyyyyssssssssssssssssshsssss:`           ");
            $display("    /---:hsyysyssssssssssssssssssssssssssssssssssssssshssssy+           ");
            $display("    o----oyy:-:/+oyysssssssssssssssssssssssssssssssssshssssy+-          ");
            $display("    s-----++-------/+sysssssssssssssssssssssssssssssyssssyo:-:-         ");
            $display("    o/----s-----------:+syyssssssssssssssssssssssyso:--os:----/.        ");
            $display("    `o/--:o---------------:+ossyysssssssssssyyso+:------o:-----:        ");
            $display("      /+:/+---------------------:/++ooooo++/:------------s:---::        ");
            $display("       `/o+----------------------------------------------:o---+`        ");
            $display("         `+-----------------------------------------------o::+.         ");
            $display("          +-----------------------------------------------/o/`          ");
            $display("          ::----------------------------------------------:-            ");
            //repeat(5) @(negedge clk);
            repeat(3) @(negedge clk);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask


// Check ouput answer
task check_task; begin
    out_lat = 0;
    while(inf.out_valid===1) begin
        if(out_lat>OUT_NUM) begin
            $display("                                                                                ");
            $display("                                                   ./+oo+/.                     ");
            $display("    Out cycles is more than %-2d                    /s:-----+s`     at %-12d ps ", OUT_NUM, $time*1000);
            $display("                                                  y/-------:y                   ");
            $display("                                             `.-:/od+/------y`                  ");
            $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
            $display("                              -m+:::::::---------------------::o+.              ");
            $display("                             `hod-------------------------------:o+             ");
            $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
            $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
            $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
            $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
            $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
            $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
            $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
            $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
            $display("                 s:----------------/s+///------------------------------o`       ");
            $display("           ``..../s------------------::--------------------------------o        ");
            $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
            $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
            $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
            $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
            $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
            $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
            $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
            $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
            $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
            $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
            $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
            $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
            $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
            $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
            $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
            $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
            $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
            $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
            $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
            $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
            $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
            $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
            $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   ");
            repeat(3) @(negedge clk);
            $finish;
        end
        
        your_complete = inf.complete;
        your_err_msg = inf.err_msg;

        out_lat = out_lat + 1;
        @(negedge clk);
    end

    if(your_complete!==golden_complete) flag_complete_Err = 1'd1;
    else flag_complete_Err = 1'd0;
    if(your_err_msg!==golden_err_msg) flag_err_msg_Err = 1'd1;
    else flag_err_msg_Err = 1'd0;
    your_ans_Err = flag_err_msg_Err | flag_complete_Err;

    // Check
    if(your_ans_Err!==0) begin
        $display("                                                                                ");
        $display("    Wrong Answer!!                                 ./+oo+/.                     ");
        $display("    Output is not correct!!!                      /s:-----+s`     at %-12d ps   ", $time*1000);
        $display("    golden err_msg: %d                            y/-------:y                   ", golden_err_msg);
        $display("                                             `.-:/od+/------y`                  ");
        $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
        $display("                              -m+:::::::---------------------::o+.              ");
        $display("                             `hod-------------------------------:o+             ");
        $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
        $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
        $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
        $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
        $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
        $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
        $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
        $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
        $display("                 s:----------------/s+///------------------------------o`       ");
        $display("           ``..../s------------------::--------------------------------o        ");
        $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
        $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
        $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
        $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
        $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
        $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
        $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
        $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
        $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
        $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
        $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
        $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
        $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
        $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
        $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
        $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
        $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
        $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
        $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
        $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
        $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
        $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
        $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   ");

        // TODO
        //$display("[Info] Dump debugging file...\n");
        
        repeat(3) @(negedge clk);
        $finish;
    end

    tot_lat = tot_lat + exe_lat;
end endtask


// Pass
task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulations!!! \033[1;0m                                  ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", tot_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(3) @(negedge clk);
    $finish;
end endtask



endprogram
