module line_drawing_fsm
(
	input clk,
	input rst,
	input start,
	input x_le_x1,
	input steep,
	input x0_gt_x1,
	input err_gt_0,
	
	output load,
	output set_steep,
	output swap_1,
	output swap_2,
	output initialize,
	output err_plus_delta_y,
	output vga_plot,
    input vga_done,
	output inc_x,
	output inc_y,
    output done_drawing
);
	localparam S0 = 0, S1 = 1, S2 = 2, S3 = 3, S4 = 4, S5 = 5, S6 = 6, SDone = 7, S_VGA = 8;

	reg [3:0] ps;
	reg [3:0] ns;
	
	always@(*)
	case (ps)
		S0: if (start == 1) ns = S1; else ns = S0;
		S1: ns = S2;
		S2: ns = S3;
		S3: ns = S4;
		S4: ns = S5;
		S5: if (x_le_x1) ns = S_VGA; else ns = SDone;
        S_VGA: if (vga_done) ns = S6; else ns = S_VGA;
		S6: ns = S5;
		SDone: if (start == 1) ns = SDone; else ns = S0;
		default: ns = S0;
	endcase
	
	always@(posedge clk or negedge rst)
	begin
		if (~rst)
			ps <= S0;
		else
		begin
			ps <= ns;
		end
	end
	
	assign load = (ps == S0);
	assign set_steep = (ps == S1);
	assign swap_1 = (ps == S2) & (steep == 1);
	assign swap_2 = (ps == S3) & (x0_gt_x1);
	assign initialize = (ps == S4);
	assign err_plus_delta_y = (ps == S5);
	assign vga_plot = (ps == S5 | ps == S_VGA) & (x_le_x1 == 1);
	assign inc_x = (ps == S6);
	assign inc_y = (ps == S6) & (err_gt_0);
    assign done_drawing = (ps == SDone);
	
endmodule

module line_drawing_datapath
(
	input clk,
	input rst,
	input [31:0] x0_in,
	input [31:0] x1_in,
	input [31:0] y0_in,
	input [31:0] y1_in,
	input load,
	input set_steep,
	input swap_1,
	input swap_2,
	input initialize,
	input err_plus_delta_y,
	input inc_x,
	input inc_y,
	
	output x_le_x1,
	output steep,
	output x0_gt_x1,
	output err_gt_0,
	output [31:0] vga_x,
	output [31:0] vga_y
);

	wire signed [31:0] x0;
	wire signed [31:0] x1;
	wire signed [31:0] y0;
	wire signed [31:0] y1;
	wire [31:0] abs_deltax;
	wire [31:0] abs_deltay;
	
	wire signed [31:0] x;
	wire signed [31:0] y;
	wire signed [31:0] deltax;
	wire signed [31:0] deltay;
	wire signed [31:0] error;
	wire signed [31:0] ystep;
	
	// Comparison signals used by the FSM, computed in the datapath
	assign x_le_x1 = (x <= x1);
	assign x0_gt_x1 = (x0 > x1);
	assign err_gt_0 = (error > 0);
	
	// X0, Y0, X1, Y1 registers
	register #(32) X0(.clk(clk), .rst(rst), .ena(load | swap_1 | swap_2), .q(x0),
		.d(load ? x0_in : (swap_1 ? y0 : x1)));
	register #(32) Y0(.clk(clk), .rst(rst), .ena(load | swap_1 | swap_2), .q(y0),
		.d(load ? y0_in : (swap_1 ? x0 : y1)));
	register #(32) X1(.clk(clk), .rst(rst), .ena(load | swap_1 | swap_2), .q(x1),
		.d(load ? x1_in : (swap_1 ? y1 : x0)));
	register #(32) Y1(.clk(clk), .rst(rst), .ena(load | swap_1 | swap_2), .q(y1),
		.d(load ? y1_in : (swap_1 ? x1 : y0)));
		
	// STEEP register
	assign abs_deltax = (x1 > x0) ? (x1 - x0) : (x0 - x1);
	assign abs_deltay = (y1 > y0) ? (y1 - y0) : (y0 - y1);
	register #(1) STEEP(.clk(clk), .rst(rst), .ena(set_steep), .q(steep),
		.d(abs_deltay > abs_deltax));
		
	register #(32) X(.clk(clk), .rst(rst), .ena(initialize | inc_x), .q(x),
		.d(initialize ? x0 : x + 32'b1));
	register #(32) DELTAX(.clk(clk), .rst(rst), .ena(initialize), .d(x1 - x0), .q(deltax));
	register #(32) ERROR(.clk(clk), .rst(rst), .ena(initialize | err_plus_delta_y | inc_y), .q(error),
		.d(initialize ? (x0 - x1)/2 : (err_plus_delta_y ? error + deltay : error - deltax)));

	register #(32) YSTEP(.clk(clk), .rst(rst), .ena(initialize), .d(y0 < y1 ? 1 : -1), .q(ystep));
	register #(32) DELTAY(.clk(clk), .rst(rst), .ena(initialize), .d(abs_deltay), .q(deltay));
	register #(32) Y(.clk(clk), .rst(rst), .ena(initialize | inc_y), .q(y),
		.d(initialize ? y0 : y + ystep));
	
	// Plot coordinates
	assign vga_x = steep ? y : x;
	assign vga_y = steep ? x : y;

endmodule

module line_drawing_algorithm
(
	input clk,
	input rst,
	input start,
	input [31:0] x0,
	input [31:0] x1,
	input [31:0] y0,
	input [31:0] y1,
	output [31:0] vga_x,
	output [31:0] vga_y,
	output vga_plot,
    input vga_done,
    output done_drawing
);

	wire x_le_x1;
	wire steep;
	wire x0_gt_x1;
	wire err_gt_0;
	
	wire load;
	wire set_steep;
	wire swap_1;
	wire swap_2;
	wire initialize;
	wire err_plus_delta_y;
	wire inc_x;
	wire inc_y;

	line_drawing_fsm FSM
	(
		.clk(clk),
		.rst(rst),
		.start(start),
		.x_le_x1(x_le_x1),
		.steep(steep),
		.x0_gt_x1(x0_gt_x1),
		.err_gt_0(err_gt_0),
		
		.load(load),
		.set_steep(set_steep),
		.swap_1(swap_1),
		.swap_2(swap_2),
		.initialize(initialize),
		.err_plus_delta_y(err_plus_delta_y),
		.vga_plot(vga_plot),
        .vga_done(vga_done),
		.inc_x(inc_x),
		.inc_y(inc_y),
        .done_drawing(done_drawing)
	);

	line_drawing_datapath DATAPATH
	(
		.clk(clk),
		.rst(rst),
		.x0_in(x0),
		.x1_in(x1),
		.y0_in(y0),
		.y1_in(y1),
		.load(load),
		.set_steep(set_steep),
		.swap_1(swap_1),
		.swap_2(swap_2),
		.initialize(initialize),
		.err_plus_delta_y(err_plus_delta_y),
		.inc_x(inc_x),
		.inc_y(inc_y),
		
		.x_le_x1(x_le_x1),
		.steep(steep),
		.x0_gt_x1(x0_gt_x1),
		.err_gt_0(err_gt_0),
		.vga_x(vga_x),
		.vga_y(vga_y)
	);

endmodule
