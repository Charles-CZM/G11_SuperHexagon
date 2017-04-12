module register
#(
	parameter SIZE = 1
)
(
	input clk,
	input rst,
	input ena,
	input [SIZE-1:0] d,
	output reg [SIZE-1:0] q
);

	always@(posedge clk or negedge rst)
	begin
		if (~rst)
			q <= {SIZE{1'b0}};
		else if (ena)
			q <= d;
		else
			q <= q;
	end
endmodule
