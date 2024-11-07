// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on

module SNN(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	img,
	ker,
	weight,

	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input cg_en;
input [7:0] img;
input [7:0] ker;
input [7:0] weight;

output reg out_valid;
output reg [9:0] out_data;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
parameter s_idle         =4'd0;
parameter s_input        =4'd1;
parameter s_convolution  =4'd2;
parameter s_quantization =4'd3;
parameter s_pooling      =4'd4;
parameter s_fully        =4'd5;
parameter s_distance     =4'd6;
parameter s_actfunc      =4'd7;
parameter s_output       =4'd8;

//integer i, j;
integer k;

//==============================================//
//           reg & wire declaration             //
//==============================================//
reg [3:0] current_state, next_state;

reg [6:0] cnt;

reg [7:0] img_map1[0:5][0:5];
reg [7:0] img_map2[0:5][0:5];
reg [7:0] ker_map[0:8];
reg [7:0] weight_map[0:3];

reg [2:0] col, row;
wire [2:0] col1, col2, row1, row2;

reg [19:0] feature_map1 [0:15];
reg [19:0] feature_map2 [0:15];

wire [15:0] mul_r[0:8];
reg [7:0] mul_a[0:8];
//wire [19:0] con_1, con_2;
reg [19:0] con_r;

reg flag_quan;
wire [11:0] quan_c;
wire [7:0] quan_1, quan_2;

reg [7:0] max_a1, max_b1, max_a2, max_b2;
wire [7:0] max_1, max_2;

wire [16:0] ful_a1, ful_a2, ful_b1, ful_b2, ful_c1, ful_c2, ful_d1, ful_d2;

wire [7:0] dis_a, dis_b, dis_c, dis_d, dis_e, dis_f, dis_g, dis_h;
wire [9:0] dis;

//==============================================//
//                 GATED_OR                     //
//==============================================//
wire cg_en0, cg_en1;
wire G_clk_ker, G_clk_wei, G_clk_idx, G_clk_cnt, G_clk_con, G_clk_flq, G_clk_out;
wire G_sleep_ker, G_sleep_wei, G_sleep_idx, G_sleep_cnt, G_sleep_con, G_sleep_flq, G_sleep_out;

// G_sleep Control
assign cg_en0 = cg_en & 1'd0;
assign cg_en1 = cg_en & 1'd1;

assign G_sleep_ker = ((current_state==s_idle) || (current_state==s_input && cnt<4'd9)) ? cg_en0 : cg_en1;
assign G_sleep_wei = ((current_state==s_idle) || (current_state==s_input && cnt<3'd4)) ? cg_en0 : cg_en1;
assign G_sleep_idx = ((current_state==s_idle) || (current_state==s_input) || (current_state==s_convolution)) ? cg_en0 : cg_en1;
assign G_sleep_cnt = ((current_state==s_fully) || (current_state==s_distance) || (current_state==s_actfunc)) ? cg_en1 : cg_en0;
assign G_sleep_con = (current_state==s_convolution) ? cg_en0 : cg_en1;
assign G_sleep_flq = (current_state==s_quantization) ? cg_en0 : cg_en1;
assign G_sleep_out = ((current_state==s_output)) ? cg_en0 : cg_en1;

GATED_OR  
	GATED_ker(.CLOCK(clk), .SLEEP_CTRL(G_sleep_ker), .RST_N(rst_n), .CLOCK_GATED(G_clk_ker)),
	GATED_wei(.CLOCK(clk), .SLEEP_CTRL(G_sleep_wei), .RST_N(rst_n), .CLOCK_GATED(G_clk_wei)),
	GATED_idx(.CLOCK(clk), .SLEEP_CTRL(G_sleep_idx), .RST_N(rst_n), .CLOCK_GATED(G_clk_idx)),
	GATED_cnt(.CLOCK(clk), .SLEEP_CTRL(G_sleep_cnt), .RST_N(rst_n), .CLOCK_GATED(G_clk_cnt)),
	GATED_con(.CLOCK(clk), .SLEEP_CTRL(G_sleep_con), .RST_N(rst_n), .CLOCK_GATED(G_clk_con)),
	GATED_flq(.CLOCK(clk), .SLEEP_CTRL(G_sleep_flq), .RST_N(rst_n), .CLOCK_GATED(G_clk_flq)),
	GATED_out(.CLOCK(clk), .SLEEP_CTRL(G_sleep_out), .RST_N(rst_n), .CLOCK_GATED(G_clk_out));


wire G_clk_img[0:5];
wire G_sleep_img[0:5];
genvar m;
generate
	for(m=0; m<6; m=m+1) begin: gen_GATED_img
		assign G_sleep_img[m] = ((current_state==s_idle) || (current_state==s_input)) ? cg_en0 : cg_en1;
		GATED_OR GATED_img_g (.CLOCK(clk), .SLEEP_CTRL(G_sleep_img[m]), .RST_N(rst_n), .CLOCK_GATED(G_clk_img[m]));
	end
endgenerate

wire G_clk_fe1[0:15];
wire G_sleep_fe1[0:15];
genvar n;
generate
for(n=0; n<16; n=n+1) begin: gen_GATED_fe1
		if(n==0 || n==2) begin
			assign G_sleep_fe1[n] = ((current_state==s_convolution) || (current_state==s_quantization) || (current_state==s_pooling) || (current_state==s_fully)) ? cg_en0 : cg_en1;
		end
		else if(n==1 || n==3) begin
			assign G_sleep_fe1[n] = ((current_state==s_convolution) || (current_state==s_quantization) || (current_state==s_fully)) ? cg_en0 : cg_en1;
		end
		else if(n==4 || n==5) begin
			assign G_sleep_fe1[n] = ((current_state==s_convolution) || (current_state==s_quantization) || (current_state==s_distance) || (current_state==s_actfunc)) ? cg_en0 : cg_en1;
		end
		else if(n==6 || n==7) begin
			assign G_sleep_fe1[n] = ((current_state==s_convolution) || (current_state==s_quantization)) ? cg_en0 : cg_en1;
		end
		else if(n==8 || n==10) begin
			assign G_sleep_fe1[n] = ((current_state==s_convolution) || (current_state==s_quantization) || (current_state==s_pooling)) ? cg_en0 : cg_en1;
		end
		else begin
			assign G_sleep_fe1[n] = ((current_state==s_convolution) || (current_state==s_quantization)) ? cg_en0 : cg_en1;
		end
		GATED_OR GATED_fe1_g (.CLOCK(clk), .SLEEP_CTRL(G_sleep_fe1[n]), .RST_N(rst_n), .CLOCK_GATED(G_clk_fe1[n]));
	end
endgenerate

wire G_clk_fe2[0:15];
wire G_sleep_fe2[0:15];
genvar p;
generate
for(p=0; p<16; p=p+1) begin: gen_GATED_fe2
		if(p==0 || p==2) begin
			assign G_sleep_fe2[p] = ((current_state==s_convolution) || (current_state==s_quantization) || (current_state==s_pooling) || (current_state==s_fully)) ? cg_en0 : cg_en1;
		end
		else if(p==1 || p==3) begin
			assign G_sleep_fe2[p] = ((current_state==s_convolution) || (current_state==s_quantization) || (current_state==s_fully)) ? cg_en0 : cg_en1;
		end
		else if(p==8 || p==10) begin
			assign G_sleep_fe2[p] = ((current_state==s_convolution) || (current_state==s_quantization) || (current_state==s_pooling)) ? cg_en0 : cg_en1;
		end
		else begin
			assign G_sleep_fe2[p] = ((current_state==s_convolution) || (current_state==s_quantization)) ? cg_en0 : cg_en1;
		end
		GATED_OR GATED_fe2_g (.CLOCK(clk), .SLEEP_CTRL(G_sleep_fe2[p]), .RST_N(rst_n), .CLOCK_GATED(G_clk_fe2[p]));
	end
endgenerate

//==============================================//
//                  design                      //
//==============================================//
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
		else next_state = s_convolution;
	end
	s_convolution: begin
		if(cnt==6'd33) next_state = s_quantization;
		else next_state = s_convolution;
	end
	s_quantization: begin
		if(!flag_quan && cnt==4'd15) next_state = s_pooling;
		else if(flag_quan && cnt==2'd3) next_state = s_distance;
		else next_state = s_quantization;
	end
	s_pooling: begin
		if(cnt==4'd10) next_state = s_fully;
		else next_state = s_pooling;
	end
	s_fully: begin
		next_state = s_quantization;
	end
	s_distance: begin
		next_state = s_actfunc;
	end
	s_actfunc: begin
		next_state = s_output;
	end
	s_output: begin
		next_state = s_idle;
	end
	default: next_state = current_state;
	endcase
end

//counter
always @(posedge G_clk_cnt or negedge rst_n) begin
	if(!rst_n) cnt <= 7'd0;
	else if(in_valid && cnt==7'd72) cnt <= 7'd0;
	else if(in_valid) cnt <= cnt + 1'd1;
	else begin
		case(current_state)
		s_convolution: begin
			if(cnt==6'd33) cnt <= 7'd0;
			else cnt <= cnt + 1'd1;
		end
		s_quantization: begin
			if(!flag_quan) begin
				if(cnt==4'd15) cnt <= 7'd0;
				else cnt <= cnt + 1'd1;
			end
			else begin
				if(cnt==2'd3) cnt <= 7'd0;
				else cnt <= cnt + 1'd1;
			end
		end
		s_pooling: begin
			if(cnt==4'd10) cnt <= 7'd0;
			else if(cnt==4'd8) cnt<= 4'd10;
			else if(cnt==2'd2) cnt<= 4'd8;
			else if(cnt==1'd0) cnt<= 2'd2;
			else cnt <= cnt;
		end
		default: cnt <= 7'd0;
		endcase
	end
end


// s_input
// kernel map
always @(posedge G_clk_ker or negedge rst_n) begin
	if(!rst_n) begin
		for(k=0; k<9; k=k+1) ker_map[k] <= 8'd0;
	end
	else if(in_valid && cnt<4'd9) begin
		ker_map[8] <= ker;
		for(k=0; k<8; k=k+1) ker_map[k] <= ker_map[k+1];
	end
	else begin
		for(k=0; k<9; k=k+1) ker_map[k] <= ker_map[k];
	end
end

//weight map
always @(posedge G_clk_wei or negedge rst_n) begin
	if(!rst_n) begin
		for(k=0; k<4; k=k+1) weight_map[k] <= 8'd0;
	end
	else if(in_valid && cnt<3'd4) begin
		weight_map[3] <= weight;
		for(k=0; k<3; k=k+1) weight_map[k] <= weight_map[k+1];
	end
	else begin
		for(k=0; k<4; k=k+1) weight_map[k] <= weight_map[k];
	end
end

// image map
genvar i, j;
generate
	for(i=0; i<6; i=i+1) begin
			always @(posedge G_clk_img[i] or negedge rst_n) begin
				if(!rst_n) begin
					for(k=0; k<6; k=k+1) img_map1[i][k] <= 8'd0;
				end
				else if(in_valid && cnt<6'd36 && row==i) begin
					img_map1[i][col] <= img;
				end
				else begin
					for(k=0; k<6; k=k+1) img_map1[i][k] <= img_map1[i][k];
				end
			end

			always @(posedge G_clk_img[i] or negedge rst_n) begin
				if(!rst_n) begin
					for(k=0; k<6; k=k+1) img_map2[i][k] <= 8'd0;
				end
				else if(in_valid && cnt>=6'd36 && row==i) begin
					img_map2[i][col] <= img;
				end
				else begin
					for(k=0; k<6; k=k+1) img_map2[i][k] <= img_map2[i][k];
				end
			end
	end
endgenerate

// index
// for image
always @(posedge G_clk_idx or negedge rst_n) begin
	if(!rst_n) begin
		col <= 3'd0;
		row <= 3'd0;
	end
	else if(in_valid) begin
		if(row==3'd5 && col==3'd5) begin
			col <= 3'd0;
			row <= 3'd0;
		end
		else if(col==3'd5) begin
			col <= 3'd0;
			row <= row + 1'd1;
		end
		else begin
			col <= col + 1'd1;
			row <= row;
		end
	end
	else if(current_state==s_convolution) begin
		if(row==2'd3 && col==2'd3) begin
			col <= 3'd0;
			row <= 3'd0;
		end
		else if(col==2'd3) begin
			col <= 3'd0;
			row <= row + 1'd1;
		end
		else begin
			col <= col + 1'd1;
			row <= row;
		end
	end
	else begin
		col <= 3'd0;
		row <= 3'd0;
	end
end


// s_convolution
assign row1 = row + 1'd1;
assign row2 = row + 2'd2;
assign col1 = col + 1'd1;
assign col2 = col + 2'd2;

assign mul_r[0] = mul_a[0] * ker_map[0];
assign mul_r[1] = mul_a[1] * ker_map[1];
assign mul_r[2] = mul_a[2] * ker_map[2];
assign mul_r[3] = mul_a[3] * ker_map[3];
assign mul_r[4] = mul_a[4] * ker_map[4];
assign mul_r[5] = mul_a[5] * ker_map[5];
assign mul_r[6] = mul_a[6] * ker_map[6];
assign mul_r[7] = mul_a[7] * ker_map[7];
assign mul_r[8] = mul_a[8] * ker_map[8];

always @(posedge G_clk_con or negedge rst_n) begin
	if(!rst_n) begin
		for(k=0; k<9; k=k+1) mul_a[k] <= 8'd0;
	end
	else if(current_state==s_convolution && cnt<5'd16) begin
		mul_a[0] <= img_map1[row ][col ]; 
		mul_a[1] <= img_map1[row ][col1]; 
		mul_a[2] <= img_map1[row ][col2]; 
		mul_a[3] <= img_map1[row1][col ]; 
		mul_a[4] <= img_map1[row1][col1]; 
		mul_a[5] <= img_map1[row1][col2]; 
		mul_a[6] <= img_map1[row2][col ]; 
		mul_a[7] <= img_map1[row2][col1]; 
		mul_a[8] <= img_map1[row2][col2]; 
	end
	else if(current_state==s_convolution && cnt>=5'd16) begin
		mul_a[0] <= img_map2[row ][col ]; 
		mul_a[1] <= img_map2[row ][col1]; 
		mul_a[2] <= img_map2[row ][col2]; 
		mul_a[3] <= img_map2[row1][col ]; 
		mul_a[4] <= img_map2[row1][col1]; 
		mul_a[5] <= img_map2[row1][col2]; 
		mul_a[6] <= img_map2[row2][col ]; 
		mul_a[7] <= img_map2[row2][col1]; 
		mul_a[8] <= img_map2[row2][col2]; 
	end
	else begin
		for(k=0; k<9; k=k+1) mul_a[k] <= 8'd0;
	end
end

always @(posedge G_clk_con or negedge rst_n) begin
	if(!rst_n) con_r <= 20'd0;
	else if(current_state==s_convolution) con_r <= mul_r[0] + mul_r[1] + mul_r[2] + mul_r[3] + mul_r[4] + mul_r[5] + mul_r[6] + mul_r[7] + mul_r[8];
	else con_r <= 20'd0;
end

// s_quantization
// flag to know 1st time or 2nd
always @(posedge G_clk_flq or negedge rst_n) begin
	if(!rst_n) flag_quan <= 1'd0;
	else if(current_state==s_quantization && !flag_quan && cnt==4'd15) flag_quan <= 1'd1;
	else if(current_state==s_quantization && flag_quan && cnt==2'd3) flag_quan <= 1'd0;
	else flag_quan <= flag_quan;
end

assign quan_c = (current_state==s_quantization && !flag_quan) ? 12'd2295: 9'd510;

assign quan_1 = (current_state==s_quantization) ? (feature_map1[cnt] / quan_c) : 8'd0;
assign quan_2 = (current_state==s_quantization) ? (feature_map2[cnt] / quan_c) : 8'd0;

// s_pooling, s_distance
always @(*) begin
	if(current_state==s_pooling && (feature_map1[cnt]>=feature_map1[cnt+1])) max_a1 = feature_map1[cnt];
	else if(current_state==s_pooling && (feature_map1[cnt]<feature_map1[cnt+1])) max_a1 = feature_map1[cnt+1];
	else if(current_state==s_distance && (feature_map1[0]>=feature_map2[0])) max_a1 = 1'd0;
	else if(current_state==s_distance && (feature_map1[0]<feature_map2[0])) max_a1 = 1'd1;
	else max_a1 ='d0;
end
always @(*) begin
	if(current_state==s_pooling && (feature_map1[cnt+4]>=feature_map1[cnt+5])) max_b1 = feature_map1[cnt+4];
	else if(current_state==s_pooling && (feature_map1[cnt+4]<feature_map1[cnt+5])) max_b1 = feature_map1[cnt+5];
	else if(current_state==s_distance && (feature_map1[1]>=feature_map2[1])) max_b1 = 1'd0;
	else if(current_state==s_distance && (feature_map1[1]<feature_map2[1])) max_b1 = 1'd1;
	else max_b1 = 8'd0;
end
assign max_1 = ((current_state==s_pooling) && (max_a1>=max_b1)) ? max_a1: max_b1;

always @(*) begin
	if(current_state==s_pooling && (feature_map2[cnt]>=feature_map2[cnt+1])) max_a2 = feature_map2[cnt];
	else if(current_state==s_pooling && (feature_map2[cnt]<feature_map2[cnt+1])) max_a2 = feature_map2[cnt+1];
	else if(current_state==s_distance && (feature_map1[2]>=feature_map2[2])) max_a2 = 1'd0;
	else if(current_state==s_distance && (feature_map1[2]<feature_map2[2])) max_a2 = 1'd1;
	else max_a2 = 8'd0;
end
always @(*) begin
	if(current_state==s_pooling && (feature_map2[cnt+4]>=feature_map2[cnt+5])) max_b2 = feature_map2[cnt+4];
	else if(current_state==s_pooling && (feature_map2[cnt+4]<feature_map2[cnt+5])) max_b2 = feature_map2[cnt+5];
	else if(current_state==s_distance && (feature_map1[3]>=feature_map2[3])) max_b2 = 1'd0;
	else if(current_state==s_distance && (feature_map1[3]<feature_map2[3])) max_b2 = 1'd1;
	else max_b2 = 8'd0;
end
assign max_2 = ((current_state==s_pooling) && (max_a2>=max_b2)) ? max_a2: max_b2;

// s_fully
assign ful_a1 = (current_state==s_fully) ? 
				( feature_map1[ 0]*weight_map[0] 
				+ feature_map1[ 2]*weight_map[2]) : 17'd0;
assign ful_b1 = (current_state==s_fully) ? 
				( feature_map1[ 0]*weight_map[1] 
				+ feature_map1[ 2]*weight_map[3]) : 17'd0;
assign ful_c1 = (current_state==s_fully) ? 
				( feature_map1[ 8]*weight_map[0] 
				+ feature_map1[10]*weight_map[2]) : 17'd0;
assign ful_d1 = (current_state==s_fully) ? 
				( feature_map1[ 8]*weight_map[1] 
				+ feature_map1[10]*weight_map[3]) : 17'd0;

assign ful_a2 = (current_state==s_fully) ? 
				( feature_map2[ 0]*weight_map[0] 
				+ feature_map2[ 2]*weight_map[2]) : 17'd0;
assign ful_b2 = (current_state==s_fully) ? 
				( feature_map2[ 0]*weight_map[1] 
				+ feature_map2[ 2]*weight_map[3]) : 17'd0;
assign ful_c2 = (current_state==s_fully) ? 
				( feature_map2[ 8]*weight_map[0] 
				+ feature_map2[10]*weight_map[2]) : 17'd0;
assign ful_d2 = (current_state==s_fully) ? 
				( feature_map2[ 8]*weight_map[1] 
				+ feature_map2[10]*weight_map[3]) : 17'd0;

// s_distance
assign dis_a = (current_state==s_distance && !max_a1) ? feature_map1[0] : feature_map2[0];
assign dis_b = (current_state==s_distance && !max_b1) ? feature_map1[1] : feature_map2[1];
assign dis_c = (current_state==s_distance && !max_a2) ? feature_map1[2] : feature_map2[2];
assign dis_d = (current_state==s_distance && !max_b2) ? feature_map1[3] : feature_map2[3];
assign dis_e = (current_state==s_distance && !max_a1) ? feature_map2[0] : feature_map1[0];
assign dis_f = (current_state==s_distance && !max_b1) ? feature_map2[1] : feature_map1[1];
assign dis_g = (current_state==s_distance && !max_a2) ? feature_map2[2] : feature_map1[2];
assign dis_h = (current_state==s_distance && !max_b2) ? feature_map2[3] : feature_map1[3];

assign dis = (current_state==s_distance) ? ((dis_a + dis_b + dis_c + dis_d) - (dis_e + dis_f + dis_g + dis_h)) : 10'd0;


// Feature Map
// feature map 1 [0to3]
always @(posedge G_clk_fe1[0] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[0] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18)	feature_map1[0] <= feature_map1[1];
	else if(current_state==s_quantization && cnt==1'd0) feature_map1[0] <= quan_1;
	else if(current_state==s_pooling && cnt==1'd0) 		feature_map1[0] <= max_1;
	else if(current_state==s_fully) 					feature_map1[0] <= ful_a1;
	else  												feature_map1[0] <= feature_map1[0];
end

always @(posedge G_clk_fe1[1] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[1] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 	feature_map1[1] <= feature_map1[2];
	else if(current_state==s_quantization && cnt==1'd1) feature_map1[1] <= quan_1;
	else if(current_state==s_fully)						feature_map1[1] <= ful_b1;
	else 												feature_map1[1] <= feature_map1[1];
end

always @(posedge G_clk_fe1[2] or negedge rst_n) begin
	if(!rst_n)											feature_map1[2] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 	feature_map1[2] <= feature_map1[3];
	else if(current_state==s_quantization && cnt==2'd2) feature_map1[2] <= quan_1;
	else if(current_state==s_pooling && cnt==2'd2) 		feature_map1[2] <= max_1;
	else if(current_state==s_fully) 					feature_map1[2] <= ful_c1;
	else 												feature_map1[2] <= feature_map1[2];
end

always @(posedge G_clk_fe1[3] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[3] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18)	feature_map1[3] <= feature_map1[4];
	else if(current_state==s_quantization && cnt==2'd3) feature_map1[3] <= quan_1;
	else if(current_state==s_fully)						feature_map1[3] <= ful_d1;
	else 												feature_map1[3] <= feature_map1[3];
end

// feature map 1 [4to7]
always @(posedge G_clk_fe1[4] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[4] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18)	feature_map1[4] <= feature_map1[5];
	else if(current_state==s_quantization && cnt==3'd4) feature_map1[4] <= quan_1;
	else if(current_state==s_distance) 					feature_map1[4] <= dis;
	else 												feature_map1[4] <= feature_map1[4];
end

always @(posedge G_clk_fe1[5] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[5] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 	feature_map1[5] <= feature_map1[6];
	else if(current_state==s_quantization && cnt==3'd5)	feature_map1[5] <= quan_1;
	else if(current_state==s_actfunc) begin
		if(feature_map1[4]<5'd16) 						feature_map1[5] <= 20'd0;
		else 											feature_map1[5] <= feature_map1[4];
	end
	else 												feature_map1[5] <= feature_map1[5];		
end

always @(posedge G_clk_fe1[6] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[6] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 	feature_map1[6] <= feature_map1[7];
	else if(current_state==s_quantization && cnt==3'd6)	feature_map1[6] <= quan_1;
	else 												feature_map1[6] <= feature_map1[6];
end

always @(posedge G_clk_fe1[7] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[7] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 	feature_map1[7] <= feature_map1[8];
	else if(current_state==s_quantization && cnt==3'd7)	feature_map1[7] <= quan_1;
	else 												feature_map1[7] <= feature_map1[7];
end

// feature map 1 [8to11]
always @(posedge G_clk_fe1[8] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[8] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 	feature_map1[8] <= feature_map1[9];
	else if(current_state==s_quantization && cnt==4'd8)	feature_map1[8] <= quan_1;
	else if(current_state==s_pooling && cnt==4'd8) 		feature_map1[8] <= max_1;
	else  												feature_map1[8] <= feature_map1[8];
end

always @(posedge G_clk_fe1[9] or negedge rst_n) begin
	if(!rst_n) 											feature_map1[9] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 	feature_map1[9] <= feature_map1[10];
	else if(current_state==s_quantization && cnt==4'd9)	feature_map1[9] <= quan_1;
	else  												feature_map1[9] <= feature_map1[9];
end

always @(posedge G_clk_fe1[10] or negedge rst_n) begin
	if(!rst_n) 												feature_map1[10] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 		feature_map1[10] <= feature_map1[11];
	else if(current_state==s_quantization && cnt==4'd10)	feature_map1[10] <= quan_1;
	else if(current_state==s_pooling && cnt==4'd10) 		feature_map1[10] <= max_1;
	else  													feature_map1[10] <= feature_map1[10];
end

always @(posedge G_clk_fe1[11] or negedge rst_n) begin
	if(!rst_n) 												feature_map1[11] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 		feature_map1[11] <= feature_map1[12];
	else if(current_state==s_quantization && cnt==4'd11)	feature_map1[11] <= quan_1;
	else  													feature_map1[11] <= feature_map1[11];
end

// feature map 1 [12to15]
always @(posedge G_clk_fe1[12] or negedge rst_n) begin
	if(!rst_n)  											feature_map1[12] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18)		feature_map1[12] <= feature_map1[13];
	else if(current_state==s_quantization && cnt==4'd12)	feature_map1[12] <= quan_1;
	else 													feature_map1[12] <= feature_map1[12];
end

always @(posedge G_clk_fe1[13] or negedge rst_n) begin
	if(!rst_n)  											feature_map1[13] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18)		feature_map1[13] <= feature_map1[14];
	else if(current_state==s_quantization && cnt==4'd13)	feature_map1[13] <= quan_1;
	else 													feature_map1[13] <= feature_map1[13];
end

always @(posedge G_clk_fe1[14] or negedge rst_n) begin
	if(!rst_n)  											feature_map1[14] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18)		feature_map1[14] <= feature_map1[15];
	else if(current_state==s_quantization && cnt==4'd14)	feature_map1[14] <= quan_1;
	else 													feature_map1[14] <= feature_map1[14];
end

always @(posedge G_clk_fe1[15] or negedge rst_n) begin
	if(!rst_n)												feature_map1[15] <= 20'd0;
	else if(current_state==s_convolution && cnt<5'd18) 		feature_map1[15] <= con_r;
	else if(current_state==s_quantization && cnt==4'd15)	feature_map1[15] <= quan_1;
	else 													feature_map1[15] <= feature_map1[15];
end

// feature map 2 [0to3]
always @(posedge G_clk_fe2[0] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[0] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[0] <= feature_map2[1];
	else if(current_state==s_quantization && cnt==1'd0) feature_map2[0] <= quan_2;
	else if(current_state==s_pooling && cnt==1'd0) 		feature_map2[0] <= max_2;
	else if(current_state==s_fully) 					feature_map2[0] <= ful_a2;
	else 												feature_map2[0] <= feature_map2[0];
end

always @(posedge G_clk_fe2[1] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[1] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[1] <= feature_map2[2];
	else if(current_state==s_quantization && cnt==1'd1) feature_map2[1] <= quan_2;
	else if(current_state==s_fully) 					feature_map2[1] <= ful_b2;
	else 												feature_map2[1] <= feature_map2[1];
end

always @(posedge G_clk_fe2[2] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[2] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[2] <= feature_map2[3];
	else if(current_state==s_quantization && cnt==2'd2) feature_map2[2] <= quan_2;
	else if(current_state==s_pooling && cnt==2'd2) 		feature_map2[2] <= max_2;
	else if(current_state==s_fully) 					feature_map2[2] <= ful_c2;
	else 												feature_map2[2] <= feature_map2[2];
end

always @(posedge G_clk_fe2[3] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[3] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[3] <= feature_map2[4];
	else if(current_state==s_quantization && cnt==2'd3) feature_map2[3] <= quan_2;
	else if(current_state==s_fully) 					feature_map2[3] <= ful_d2;
	else 												feature_map2[3] <= feature_map2[3];
end

// feature map 2 [4to7]
always @(posedge G_clk_fe2[4] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[4] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[4] <= feature_map2[5];
	else if(current_state==s_quantization && cnt==3'd4) feature_map2[4] <= quan_2;
	else 												feature_map2[4] <= feature_map2[4];
end

always @(posedge G_clk_fe2[5] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[5] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[5] <= feature_map2[6];
	else if(current_state==s_quantization && cnt==3'd5) feature_map2[5] <= quan_2;
	else 												feature_map2[5] <= feature_map2[5];
end
always @(posedge G_clk_fe2[6] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[6] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[6] <= feature_map2[7];
	else if(current_state==s_quantization && cnt==3'd6) feature_map2[6] <= quan_2;
	else 												feature_map2[6] <= feature_map2[6];
end
always @(posedge G_clk_fe2[7] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[7] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[7] <= feature_map2[8];
	else if(current_state==s_quantization && cnt==3'd7) feature_map2[7] <= quan_2;
	else 												feature_map2[7] <= feature_map2[7];
end

// feature map 2 [8to11]
always @(posedge G_clk_fe2[8] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[8] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[8] <= feature_map2[9];
	else if(current_state==s_quantization && cnt==4'd8) feature_map2[8] <= quan_2;
	else if(current_state==s_pooling && cnt==4'd8) 		feature_map2[8] <= max_2;
	else 												feature_map2[8] <= feature_map2[8];
end

always @(posedge G_clk_fe2[9] or negedge rst_n) begin
	if(!rst_n) 											feature_map2[9] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) feature_map2[9] <= feature_map2[10];
	else if(current_state==s_quantization && cnt==4'd9) feature_map2[9] <= quan_2;
	else 												feature_map2[9] <= feature_map2[9];
end

always @(posedge G_clk_fe2[10] or negedge rst_n) begin
	if(!rst_n) 												feature_map2[10] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) 	feature_map2[10] <= feature_map2[11];
	else if(current_state==s_quantization && cnt==4'd10) 	feature_map2[10] <= quan_2;
	else if(current_state==s_pooling && cnt==4'd10) 		feature_map2[10] <= max_2;
	else 													feature_map2[10] <= feature_map2[10];
end

always @(posedge G_clk_fe2[11] or negedge rst_n) begin
	if(!rst_n) 												feature_map2[11] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) 	feature_map2[11] <= feature_map2[12];
	else if(current_state==s_quantization && cnt==4'd11) 	feature_map2[11] <= quan_2;
	else 													feature_map2[11] <= feature_map2[11];
end

// feature map 2 [12to15]
always @(posedge G_clk_fe2[12] or negedge rst_n) begin
	if(!rst_n) 												feature_map2[12] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) 	feature_map2[12] <= feature_map2[13];
	else if(current_state==s_quantization && cnt==4'd12) 	feature_map2[12] <= quan_2;
	else 													feature_map2[12] <= feature_map2[12];
end

always @(posedge G_clk_fe2[13] or negedge rst_n) begin
	if(!rst_n) 												feature_map2[13] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) 	feature_map2[13] <= feature_map2[14];
	else if(current_state==s_quantization && cnt==4'd13) 	feature_map2[13] <= quan_2;
	else 													feature_map2[13] <= feature_map2[13];
end

always @(posedge G_clk_fe2[14] or negedge rst_n) begin
	if(!rst_n) 												feature_map2[14] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) 	feature_map2[14] <= feature_map2[15];
	else if(current_state==s_quantization && cnt==4'd14) 	feature_map2[14] <= quan_2;
	else 													feature_map2[14] <= feature_map2[14];
end

always @(posedge G_clk_fe2[15] or negedge rst_n) begin
	if(!rst_n) 												feature_map2[15] <= 20'd0;
	else if(current_state==s_convolution && cnt>=5'd18) 	feature_map2[15] <= con_r;
	else if(current_state==s_quantization && cnt==4'd15) 	feature_map2[15] <= quan_2;
	else 													feature_map2[15] <= feature_map2[15];
end


// s_output
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 1'd0;
	else if(current_state==s_output) out_valid <= 1'd1;
	else out_valid <= 1'd0;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_data <= 10'd0;
	else if(current_state==s_output) out_data <= feature_map1[5];
	else out_data <= 10'd0;
end


endmodule