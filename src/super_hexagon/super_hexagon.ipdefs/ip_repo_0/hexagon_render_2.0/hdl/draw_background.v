`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2017 07:40:48 PM
// Design Name: 
// Module Name: draw_background
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is the module responsible for drawing the background
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module draw_background #
(
    parameter integer burst_len = 128
)
(
    // clock and reset
    input clk100,
    input resetn,
    
    // control signals to/from top-level
    input draw,
    output draw_done,
    
    // control signals to/from DDR
    output txn_init,
    input txn_done,
    
    // data signals to DDR
    output [31:0] offset_addr,
    output [31:0] pixel_count
);
    
    // Control FSM wires/regs
    reg draw_init_ff, draw_init_ff2; // pulse generator regs
    wire draw_pulse; // start signal
    reg [3:0] current_state, next_state; // control FSM states
    localparam [3:0] START = 4'b0000, DRAW_POINT = 4'b0001, CHECK_X = 4'b0010, CHECK_Y = 4'b0011, DONE = 4'b0100;
    
    // coordinate counters
    reg [31:0] x;
    reg [31:0] y;
    
    // generate a pulse for the drawing signal
    assign draw_pulse = draw_init_ff && (!(draw_init_ff2));
    
    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            draw_init_ff <= 0;
            draw_init_ff2 <= 0;
        end
        else
        begin
            draw_init_ff <= draw;
            draw_init_ff2 <= draw_init_ff;
        end
    end
    
    // state transition
    always @ (posedge clk100)
    begin
        if (~resetn)
            current_state <= START;
        else
            current_state <= next_state;
    end
    
    // next state logic
    always @ (*)
    begin
        case (current_state)
            START: next_state = draw_pulse ? DRAW_POINT : START;
            DRAW_POINT: next_state = txn_done ? CHECK_X : DRAW_POINT;
            CHECK_X: next_state = (x == 640 - burst_len) ? CHECK_Y : DRAW_POINT;
            CHECK_Y: next_state = (y == 479) ? DONE : DRAW_POINT;
            DONE: next_state = START;
            default: next_state = START;
        endcase
    end
    
    // counter logic
    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            x <= 0;
            y <= 0;
        end
        else
        begin
            if (current_state == START || current_state == DONE)
            begin
                x <= 0;
                y <= 0;
            end
            else if (current_state == CHECK_X)
            begin
                x <= x + burst_len;
                y <= y;
            end
            else if (current_state == CHECK_Y)
            begin
                x <= 0;
                y <= y + 1;
            end
            else
            begin
                x <= x;
                y <= y;
            end
        end
    end
    
    assign txn_init = (current_state == DRAW_POINT);
    assign offset_addr = (y << 12) + (x << 2);
    assign draw_done = (current_state == DONE);
    assign pixel_count = burst_len;
    
endmodule
