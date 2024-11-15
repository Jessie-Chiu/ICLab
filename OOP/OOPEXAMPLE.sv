class STUDENT; //Class
    int department;
    int year;
    logic [3:0] score1;
    logic [3:0] score2;
    logic [4:0] total_score;    

    function void ini_info(int i_department, int i_year, logic [3:0] i_score1, logic [3:0] i_score2);
        department = i_department;
        year = i_year;
        score1 = i_score1;
        score2 = i_score2;
    endfunction

    function void display_info;
        $display("Department: %1d, Year: %1d, Score1/2: %2d/ %2d", department, year, score1, score2);
    endfunction

    function void score_sum;
        total_score = score1 + score2;
        $display("Total Score: %d", total_score);
    endfunction
endclass


class STUDENT2 extends STUDENT;
    logic [3:0] average_score;

    function void score_ave;
        average_score = (score1 + score2) / 2;
        $display("Average Score: %d", average_score);
    endfunction 
endclass 


class STUDENT3 extends STUDENT2;
    logic [5:0] total_score2;

    function void score_sum(logic [3:0] score3);
        total_score2 = score1 + score2 + score3;
        $display("Total Score: %d  (with Score3:%2d)", total_score2, score3);
    endfunction
endclass 


program EXAMPLE;
    //parameter electronic = 1'd0;
    //parameter physics = 1'd1;

    STUDENT Jessie; //Object
    STUDENT2 Megan;
    STUDENT3 May;
    
    initial begin
        $display("Jessie");
        Jessie = new();
        Jessie.ini_info(1,3,4,4); //Encapsulation
        Jessie.display_info;
        Jessie.score_sum; 

        $display("Megan");
        Megan = new();
        Megan.ini_info(1,2,3,4); //Inheritance
        Megan.display_info;
        Megan.score_sum;
        Megan.score_ave;

        $display("May");
        May = new();
        May.ini_info(1,2,9,7); 
        May.display_info;
        May.score_sum(3); //Polymorphism
        May.score_ave; 
    end
endprogram
