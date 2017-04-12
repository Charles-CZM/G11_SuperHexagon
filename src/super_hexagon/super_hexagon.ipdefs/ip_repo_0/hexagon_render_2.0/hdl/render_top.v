`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2017 06:10:57 PM
// Design Name: 
// Module Name: render_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is the top-level control module for the render IP
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module render_top #
(
    parameter integer burst_len = 16
)
(
    // clock and reset
    input clk100,
    input resetn,
    
    // contorl signals to/from slave
    // these are used to communicate to MicroBlaze
    input draw,
    output draw_done, // this must only happend for one cycle (i.e. can't stay at 1)
    
    // data from slave
    input [31:0] slv_reg1, // this holds color information
    input [31:0] slv_reg3, // lane0
    input [31:0] slv_reg4, // lane1
    input [31:0] slv_reg5, // lane2
    input [31:0] slv_reg6, // lane3
    input [31:0] slv_reg7, // lane4
    input [31:0] slv_reg8, // lane5
    input [31:0] slv_reg9, // angle
    input [31:0] slv_reg10, // cursor position
    
    // contorl signals to/from master (DDR)
    // these control write transactions to DDR
    output reg TXN_INIT, // this is edge sensitive (i.e. staying at 1 is fine, as long as there was an edge)
    input TXN_DONE, // this only occurs for one cycle when the transaction is finished
    
    // data signals to master (DDR)
    output reg [31:0] offset_addr,
    output reg [11:0] color,
    output reg [31:0] pixel_count // for burst control
);
    
    // Main FSM wires/regs
    reg draw_init_ff, draw_init_ff2; // pulse generator regs
    wire draw_pulse; // master start signal
    reg [3:0] current_state, next_state; // control FSM states
    localparam [3:0] START = 4'b0000, DRAWING_BACKGROUND = 4'b0001, DRAWING_BLOCK = 4'b0010, 
                     DRAWING_CURSOR = 4'b0011, DRAWING_HEXAGON = 4'b0100, DONE = 4'b0101;
    
    // signals to Background FSM
    wire background_draw; // start drawing
    wire background_done; // drawing done
    wire background_txn_init; // txn_init signal to DDR
    wire [31:0] background_offset_addr; // offset_addr data to DDR
    wire [31:0] background_pixel_count; // number of transactions (pixels) in a burst
    
    // instantiate draw_background module
    draw_background # (
        .burst_len(burst_len)
    ) d_background (
        .clk100(clk100),
        .resetn(resetn),
        .draw(background_draw),
        .draw_done(background_done),
        .txn_init(background_txn_init),
        .txn_done(TXN_DONE),
        .offset_addr(background_offset_addr),
        .pixel_count(background_pixel_count)
    );
    
    // signals to Block FSM
    wire block_draw; // start drawing
    wire block_done; // drawing done
    wire block_txn_init; // txn_init signal to DDR
    wire [31:0] block_offset_addr; // offset_addr data to DDR
    wire [31:0] block_pixel_count; // number of transactions (pixels) in a burst
    
    // instantiate draw_background module
    draw_block # (
        .burst_len(burst_len)
    ) d_block (
        .clk100(clk100),
        .resetn(resetn),
        .draw(block_draw),
        .draw_done(block_done),
        .txn_init(block_txn_init),
        .txn_done(TXN_DONE),
        .offset_addr(block_offset_addr),
        .pixel_count(block_pixel_count),
        .lane0_in(slv_reg3),
        .lane1_in(slv_reg4),
        .lane2_in(slv_reg5),
        .lane3_in(slv_reg6),
        .lane4_in(slv_reg7),
        .lane5_in(slv_reg8),
        .angle_in(slv_reg9)
    );
    
    // signals to Cursor FSM
    wire cursor_draw; // start drawing
    wire cursor_done; // drawing done
    wire cursor_txn_init; // txn_init signal to DDR
    wire [31:0] cursor_offset_addr; // offset_addr data to DDR
    wire [31:0] cursor_pixel_count; // number of transactions (pixels) in a burst
    
    draw_cursor # (
        .burst_len(burst_len)
    ) d_cursor (
        .clk100(clk100),
        .resetn(resetn),
        .draw(cursor_draw),
        .draw_done(cursor_done),
        .txn_init(cursor_txn_init),
        .txn_done(TXN_DONE),
        .offset_addr(cursor_offset_addr),
        .pixel_count(cursor_pixel_count),
        .position_in(slv_reg10),
        .angle_in(slv_reg9)
    );
    
    // signals to Hexagon FSM
    wire hexagon_draw; // start drawing
    wire hexagon_done; // drawing done
    wire hexagon_txn_init; // txn_init signal to DDR
    wire [31:0] hexagon_offset_addr; // offset_addr data to DDR
    wire [31:0] hexagon_pixel_count; // number of transactions (pixels) in a burst
    
    draw_hexagon # (
        .burst_len(burst_len)
    ) d_hexagon (
        .clk100(clk100),
        .resetn(resetn),
        .draw(hexagon_draw),
        .draw_done(hexagon_done),
        .txn_init(hexagon_txn_init),
        .txn_done(TXN_DONE),
        .offset_addr(hexagon_offset_addr),
        .pixel_count(hexagon_pixel_count),
        .angle_in(slv_reg9)
    );
    
    // Output logics to DDR (these are just muxes based on current_state)
    always @ (*)
    begin
        case (current_state)
            DRAWING_BACKGROUND:
            begin
                TXN_INIT = background_txn_init;
                color = slv_reg1[11:0];
                offset_addr = background_offset_addr;
                pixel_count = background_pixel_count;
            end
            
            DRAWING_BLOCK: 
            begin
                TXN_INIT = block_txn_init;
                color = slv_reg1[23:12];
                offset_addr = block_offset_addr;
                pixel_count = block_pixel_count;
            end
            
            DRAWING_CURSOR: 
            begin
                TXN_INIT = cursor_txn_init;
                color = slv_reg1[23:12];
                offset_addr = cursor_offset_addr;
                pixel_count = cursor_pixel_count;
            end
            
            DRAWING_HEXAGON: 
            begin
                TXN_INIT = hexagon_txn_init;
                color = slv_reg1[23:12];
                offset_addr = hexagon_offset_addr;
                pixel_count = hexagon_pixel_count;
            end
            
            default:
            begin
                TXN_INIT = 0;
                color = 0;
                offset_addr = 0;
                pixel_count = 0;
            end
        endcase
    end
    
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
            START: next_state = draw_pulse ? DRAWING_BACKGROUND : START;
            DRAWING_BACKGROUND: next_state = background_done ? DRAWING_BLOCK : DRAWING_BACKGROUND;
            DRAWING_BLOCK: next_state = block_done ? DRAWING_CURSOR : DRAWING_BLOCK;
            DRAWING_CURSOR: next_state = cursor_done ? DRAWING_HEXAGON : DRAWING_CURSOR;
            DRAWING_HEXAGON: next_state = hexagon_done ? DONE : DRAWING_HEXAGON;
            DONE: next_state = START;
            default: next_state = START;
        endcase
    end
    
    assign background_draw = (current_state == DRAWING_BACKGROUND);
    assign block_draw = (current_state == DRAWING_BLOCK);
    assign cursor_draw = (current_state == DRAWING_CURSOR);
    assign hexagon_draw = (current_state == DRAWING_HEXAGON);
    assign draw_done = (current_state == DONE);
    
endmodule
