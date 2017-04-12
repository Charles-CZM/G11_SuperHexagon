`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2017 07:40:48 PM
// Design Name: 
// Module Name: draw_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is the module responsible for drawing blocks
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module draw_block #
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
    
    // data signals from top-level
    input [31:0] lane0_in,
    input [31:0] lane1_in,
    input [31:0] lane2_in,
    input [31:0] lane3_in,
    input [31:0] lane4_in,
    input [31:0] lane5_in,
    input [31:0] angle_in,
    
    // control signals to/from DDR
    output txn_init,
    input txn_done,
    
    // data signals to DDR
    output [31:0] offset_addr,
    output [31:0] pixel_count
);  
     integer i;
    
    // Control FSM wires/regs
    reg draw_init_ff, draw_init_ff2; // pulse generator regs
    wire draw_pulse; // start signal
    reg [3:0] lane_counter;
    reg [6:0] block_position;
    
    reg [3:0] current_state, next_state; // control FSM states
    localparam [3:0] START = 4'b0000, LOAD = 4'b0001, SHIFT_LANE = 4'b0010, 
                     DRAW_BLOCK = 4'b0011, CHECK_LANE = 4'b0100,
                     DONE = 4'b0101, CALCULATE_COOR_1 = 4'b0110, CALCULATE_COOR_2 = 4'b0111,
                     CALCULATE_COOR_3 = 4'b1000, CALCULATE_COOR_4 = 4'b1001;
    
    reg [31:0] lane [0:5];
    reg signed [31:0] rotate_angle;
    reg signed [31:0] final_angle_0, final_angle_1, final_angle_2;
    reg signed [31:0] outer_radius, inner_radius;
    wire signed [31:0] outer_radius_from_LUT, inner_radius_from_LUT;
    reg signed [31:0] sin_0, cos_0, sin_1, cos_1;
    wire signed [31:0] sin_0_from_LUT, cos_0_from_LUT, sin_1_from_LUT, cos_1_from_LUT;
    reg signed [31:0] slope_0, slope_1, slope_2, slope_inv_0, slope_inv_1, slope_inv_2;
    wire signed [31:0] slope_0_from_LUT, slope_1_from_LUT, slope_2_from_LUT;
    wire signed [31:0] slope_inv_0_from_LUT, slope_inv_1_from_LUT, slope_inv_2_from_LUT;
    
    radius_LUT outer_radius_LUT(.block_position(block_position + 7'b1), .radius(outer_radius_from_LUT));
    radius_LUT inner_radius_LUT(.block_position(block_position - 7'b1), .radius(inner_radius_from_LUT));
    angle_LUT angle_0_LUT(.angle(final_angle_0), .sin(sin_0_from_LUT), .cos(cos_0_from_LUT));
    angle_LUT angle_1_LUT(.angle(final_angle_1), .sin(sin_1_from_LUT), .cos(cos_1_from_LUT));
    slope_LUT slope_0_LUT(.angle(final_angle_0), .tan(slope_inv_0_from_LUT), .cot(slope_0_from_LUT));
    slope_LUT slope_1_LUT(.angle(final_angle_1), .tan(slope_inv_1_from_LUT), .cot(slope_1_from_LUT));
    slope_LUT slope_2_LUT(.angle(final_angle_2), .tan(slope_inv_2_from_LUT), .cot(slope_2_from_LUT));
    
    // final vertices after calculation
    reg signed [31:0] x_a, y_a, x_b, y_b, x_c, y_c, x_d, y_d;
    
    // coordinate counters
    wire signed [31:0] x;
    wire signed [31:0] y;
    
    // block drawing algorithm instance
    wire bda_start;
    wire bda_done;
    block_drawing_algorithm #(
        .burst_len(burst_len)
    ) bda (
        .clk100(clk100),
        .resetn(resetn),
        .start(bda_start),
        .done(bda_done),
        .txn_init(txn_init),
        .txn_done(txn_done),
        .pixel_count(pixel_count),
        .x(x),
        .y(y),
        
        // vertices
        .x_a_in(x_a),
        .y_a_in(y_a),
        .x_b_in(x_b),
        .y_b_in(y_b),
        .x_c_in(x_c),
        .y_c_in(y_c),
        .x_d_in(x_d),
        .y_d_in(y_d),
        
        // slopes
        .m_0_in(slope_0),
        .m_1_in(slope_2),
        .m_2_in(slope_1),
        .m_3_in(slope_2),
        
        // inverse of slopes
        .m_inv_0_in(slope_inv_0),
        .m_inv_1_in(slope_inv_2),
        .m_inv_2_in(slope_inv_1),
        .m_inv_3_in(slope_inv_2)
    );
        
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
            START: next_state = draw_pulse ? LOAD : START;
            LOAD: next_state = SHIFT_LANE;
            SHIFT_LANE: next_state = lane[lane_counter] == 32'b0 ? CHECK_LANE : (lane[lane_counter][0] == 1'b1 ? CALCULATE_COOR_1 : SHIFT_LANE);
            CALCULATE_COOR_1: next_state = CALCULATE_COOR_2;
            CALCULATE_COOR_2: next_state = CALCULATE_COOR_3;
            CALCULATE_COOR_3: next_state = CALCULATE_COOR_4;
            CALCULATE_COOR_4: next_state = DRAW_BLOCK;
            DRAW_BLOCK: next_state = bda_done ? SHIFT_LANE : DRAW_BLOCK;
            CHECK_LANE: next_state = (lane_counter == 5) ? DONE: SHIFT_LANE;
            DONE: next_state = START;
            default: next_state = START;
        endcase
    end
    
    // lane logic (counts which block position has block to be drawn for each lane)
    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            for (i = 0; i < 6; i = i + 1)
                lane[i] <= 0;
            block_position <= 0;
            lane_counter <= 0;
        end
        else
        begin
            if (current_state == START || current_state == DONE)
            begin
                for (i = 0; i < 6; i = i + 1)
                    lane[i] <= 0;
                block_position <= 0;
                lane_counter <= 0;
                rotate_angle <= 0;
            end
            else if (current_state == LOAD)
            begin
                lane[0] <= lane0_in;
                lane[1] <= lane1_in;
                lane[2] <= lane2_in;
                lane[3] <= lane3_in;
                lane[4] <= lane4_in;
                lane[5] <= lane5_in;
                rotate_angle <= angle_in;
                block_position <= 0;
                lane_counter <= 0;
            end
            else if (current_state == SHIFT_LANE)
            begin
                for (i = 0; i < 6; i = i + 1)
                begin
                    if(i == lane_counter)
                        lane[i] <= lane[i] >> 1;
                    else
                        lane[i] <= lane[i];
                end
                block_position <= block_position + 1;
                lane_counter <= lane_counter;
                rotate_angle <= rotate_angle;
            end
            else if (current_state == CHECK_LANE)
            begin
                for (i = 0; i < 6; i = i + 1)
                    lane[i] <= lane[i];
                block_position <= 0;
                lane_counter <= lane_counter + 1;
                rotate_angle <= rotate_angle;
            end
            else
            begin
                for (i = 0; i < 6; i = i + 1)
                    lane[i] <= lane[i];
                block_position <= block_position;
                lane_counter <= lane_counter;
                rotate_angle <= rotate_angle;
            end
        end
    end
    
    // vertices logic (calculates vertices from block position)
    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            outer_radius <= 0;
            inner_radius <= 0;
            final_angle_0 <= 0;
            final_angle_1 <= 0;
            final_angle_2 <= 0;
            sin_0 <= 0;
            sin_1 <= 0;
            cos_0 <= 0;
            cos_1 <= 0;
            x_a <= 0;
            y_a <= 0;
            x_b <= 0;
            y_b <= 0;
            x_c <= 0;
            y_c <= 0;
            x_d <= 0;
            y_d <= 0;
            slope_0 <= 0;
            slope_1 <= 0;
            slope_2 <= 0;
            slope_inv_0 <= 0;
            slope_inv_1 <= 0;
            slope_inv_2 <= 0;
        end
        else
        begin
            if (current_state == START || current_state == DONE)
            begin
                outer_radius <= 0;
                inner_radius <= 0;
                final_angle_0 <= 0;
                final_angle_1 <= 0;
                final_angle_2 <= 0;
                sin_0 <= 0;
                sin_1 <= 0;
                cos_0 <= 0;
                cos_1 <= 0;
                x_a <= 0;
                y_a <= 0;
                x_b <= 0;
                y_b <= 0;
                x_c <= 0;
                y_c <= 0;
                x_d <= 0;
                y_d <= 0;
                slope_0 <= 0;
                slope_1 <= 0;
                slope_2 <= 0;
                slope_inv_0 <= 0;
                slope_inv_1 <= 0;
                slope_inv_2 <= 0;
            end
            else if (current_state == CALCULATE_COOR_1)
            begin
                outer_radius <= outer_radius_from_LUT;
                inner_radius <= inner_radius_from_LUT;
                case (lane_counter)
                    0: begin
                       final_angle_0 <= ((rotate_angle + 33) < 36) ? (rotate_angle + 33) : (rotate_angle - 3); // left side
                       final_angle_1 <= ((rotate_angle + 3) < 36) ? (rotate_angle + 3) : (rotate_angle - 33); // right side
                       final_angle_2 <= ((rotate_angle + 9) < 36) ? (rotate_angle + 9) : (rotate_angle - 27); // inner & outer side
                       end
                    1: begin
                       final_angle_0 <= ((rotate_angle + 3) < 36) ? (rotate_angle + 3) : (rotate_angle - 33);
                       final_angle_1 <= ((rotate_angle + 9) < 36) ? (rotate_angle + 9) : (rotate_angle - 27);
                       final_angle_2 <= ((rotate_angle + 15) < 36) ? (rotate_angle + 15) : (rotate_angle - 21);
                       end
                    2: begin
                       final_angle_0 <= ((rotate_angle + 9) < 36) ? (rotate_angle + 9) : (rotate_angle - 27);
                       final_angle_1 <= ((rotate_angle + 15) < 36) ? (rotate_angle + 15) : (rotate_angle - 21);
                       final_angle_2 <= ((rotate_angle + 21) < 36) ? (rotate_angle + 21) : (rotate_angle - 15);
                       end
                    3: begin
                       final_angle_0 <= ((rotate_angle + 15) < 36) ? (rotate_angle + 15) : (rotate_angle - 21);
                       final_angle_1 <= ((rotate_angle + 21) < 36) ? (rotate_angle + 21) : (rotate_angle - 15);
                       final_angle_2 <= ((rotate_angle + 27) < 36) ? (rotate_angle + 27) : (rotate_angle - 9);
                       end
                    4: begin
                       final_angle_0 <= ((rotate_angle + 21) < 36) ? (rotate_angle + 21) : (rotate_angle - 15);
                       final_angle_1 <= ((rotate_angle + 27) < 36) ? (rotate_angle + 27) : (rotate_angle - 9);
                       final_angle_2 <= ((rotate_angle + 33) < 36) ? (rotate_angle + 33) : (rotate_angle - 3);
                       end
                    5: begin
                       final_angle_0 <= ((rotate_angle + 27) < 36) ? (rotate_angle + 27) : (rotate_angle - 9);
                       final_angle_1 <= ((rotate_angle + 33) < 36) ? (rotate_angle + 33) : (rotate_angle - 3);
                       final_angle_2 <= ((rotate_angle + 3) < 36) ? (rotate_angle + 3) : (rotate_angle - 33);
                       end
                    default: begin
                       final_angle_0 <= 0;
                       final_angle_1 <= 0;
                       final_angle_2 <= 0;
                       end
                endcase
            end
            else if (current_state == CALCULATE_COOR_2)
            begin
                sin_0 <= sin_0_from_LUT;
                sin_1 <= sin_1_from_LUT;
                cos_0 <= cos_0_from_LUT;
                cos_1 <= cos_1_from_LUT;

                slope_0 <= slope_0_from_LUT;
                slope_1 <= slope_1_from_LUT;
                slope_2 <= slope_2_from_LUT;
                slope_inv_0 <= slope_inv_0_from_LUT;
                slope_inv_1 <= slope_inv_1_from_LUT;
                slope_inv_2 <= slope_inv_2_from_LUT;
            end
            else if (current_state == CALCULATE_COOR_3)
            begin
                x_a <= outer_radius * sin_0;
                y_a <= outer_radius * cos_0;
                x_b <= outer_radius * sin_1;
                y_b <= outer_radius * cos_1;
                x_c <= inner_radius * sin_1;
                y_c <= inner_radius * cos_1;
                x_d <= inner_radius * sin_0;
                y_d <= inner_radius * cos_0;
            end
            else if (current_state == CALCULATE_COOR_4)
            begin
                x_a <= x_a >>> 20;
                y_a <= y_a >>> 20;
                x_b <= x_b >>> 20;
                y_b <= y_b >>> 20;
                x_c <= x_c >>> 20;
                y_c <= y_c >>> 20;
                x_d <= x_d >>> 20;
                y_d <= y_d >>> 20;
            end
        end
    end
    
    assign offset_addr = ((240 - y) << 12) + ((x + 320) << 2); // convert to corner coordinates
    assign bda_start = (current_state == DRAW_BLOCK);
    assign draw_done = (current_state == DONE);

endmodule

module radius_LUT(
    input [6:0] block_position,
    output reg [31:0] radius
    );
    always @ (*)
    begin
        case (block_position)
            0: radius = 0;
            1: radius = 4736;
            2: radius = 9472;
            3: radius = 14208;
            4: radius = 18944;
            5: radius = 23680;
            6: radius = 28416;
            7: radius = 33152;
            8: radius = 37888;
            9: radius = 42624;
            10: radius = 47360;
            11: radius = 52096;
            12: radius = 56832;
            13: radius = 61568;
            14: radius = 66304;
            15: radius = 71040;
            default: radius = 100; // this should never happen, for Debug only
        endcase
    end
endmodule

module angle_LUT(
    input [31:0] angle,
    output reg signed [31:0] sin,
    output reg signed [31:0] cos
    );
    always @ (*)
    begin
        case (angle)
            // 0: begin sin = 0; end
            // 1: begin sin = 44; end
            // 2: begin sin = 88; end
            // 3: begin sin = 128; end
            // 4: begin sin = 165; end
            // 5: begin sin = 196; end
            // 6: begin sin = 222; end
            // 7: begin sin = 241; end
            // 8: begin sin = 252; end
            // 9: begin sin = 256; end
            // 10: begin sin = 252; end
            // 11: begin sin = 241; end
            // 12: begin sin = 222; end
            // 13: begin sin = 196; end
            // 14: begin sin = 165; end
            // 15: begin sin = 128; end
            // 16: begin sin = 88; end
            // 17: begin sin = 44; end
            // 18: begin sin = 0; end
            // 19: begin sin = -44; end
            // 20: begin sin = -88; end
            // 21: begin sin = -128; end
            // 22: begin sin = -165; end
            // 23: begin sin = -196; end
            // 24: begin sin = -222; end
            // 25: begin sin = -241; end
            // 26: begin sin = -252; end
            // 27: begin sin = -256; end
            // 28: begin sin = -252; end
            // 29: begin sin = -241; end
            // 30: begin sin = -222; end
            // 31: begin sin = -196; end
            // 32: begin sin = -165; end
            // 33: begin sin = -128; end
            // 34: begin sin = -88; end
            // 35: begin sin = -44; end
            0: begin sin = 0; end
            1: begin sin = 711; end
            2: begin sin = 1401; end
            3: begin sin = 2048; end
            4: begin sin = 2633; end
            5: begin sin = 3138; end
            6: begin sin = 3547; end
            7: begin sin = 3849; end
            8: begin sin = 4034; end
            9: begin sin = 4096; end
            10: begin sin = 4034; end
            11: begin sin = 3849; end
            12: begin sin = 3547; end
            13: begin sin = 3138; end
            14: begin sin = 2633; end
            15: begin sin = 2048; end
            16: begin sin = 1401; end
            17: begin sin = 711; end
            18: begin sin = 0; end
            19: begin sin = -711; end
            20: begin sin = -1401; end
            21: begin sin = -2048; end
            22: begin sin = -2633; end
            23: begin sin = -3138; end
            24: begin sin = -3547; end
            25: begin sin = -3849; end
            26: begin sin = -4034; end
            27: begin sin = -4096; end
            28: begin sin = -4034; end
            29: begin sin = -3849; end
            30: begin sin = -3547; end
            31: begin sin = -3138; end
            32: begin sin = -2633; end
            33: begin sin = -2048; end
            34: begin sin = -1401; end
            35: begin sin = -711; end
            default: begin sin = 0; end
        endcase
        
        case (angle)
            // 0: begin cos = 256; end
            // 1: begin cos = 252; end
            // 2: begin cos = 241; end
            // 3: begin cos = 222; end
            // 4: begin cos = 196; end
            // 5: begin cos = 165; end
            // 6: begin cos = 128; end
            // 7: begin cos = 88; end
            // 8: begin cos = 44; end
            // 9: begin cos = 0; end
            // 10: begin cos = -44; end
            // 11: begin cos = -88; end
            // 12: begin cos = -128; end
            // 13: begin cos = -165; end
            // 14: begin cos = -196; end
            // 15: begin cos = -222; end
            // 16: begin cos = -241; end
            // 17: begin cos = -252; end
            // 18: begin cos = -256; end
            // 19: begin cos = -252; end
            // 20: begin cos = -241; end
            // 21: begin cos = -222; end
            // 22: begin cos = -196; end
            // 23: begin cos = -165; end
            // 24: begin cos = -128; end
            // 25: begin cos = -88; end
            // 26: begin cos = -44; end
            // 27: begin cos = 0; end
            // 28: begin cos = 44; end
            // 29: begin cos = 88; end
            // 30: begin cos = 128; end
            // 31: begin cos = 165; end
            // 32: begin cos = 196; end
            // 33: begin cos = 222; end
            // 34: begin cos = 241; end
            // 35: begin cos = 252; end
            0: begin cos = 4096; end
            1: begin cos = 4034; end
            2: begin cos = 3849; end
            3: begin cos = 3547; end
            4: begin cos = 3138; end
            5: begin cos = 2633; end
            6: begin cos = 2048; end
            7: begin cos = 1401; end
            8: begin cos = 711; end
            9: begin cos = 0; end
            10: begin cos = -711; end
            11: begin cos = -1401; end
            12: begin cos = -2048; end
            13: begin cos = -2633; end
            14: begin cos = -3138; end
            15: begin cos = -3547; end
            16: begin cos = -3849; end
            17: begin cos = -4034; end
            18: begin cos = -4096; end
            19: begin cos = -4034; end
            20: begin cos = -3849; end
            21: begin cos = -3547; end
            22: begin cos = -3138; end
            23: begin cos = -2633; end
            24: begin cos = -2048; end
            25: begin cos = -1401; end
            26: begin cos = -711; end
            27: begin cos = 0; end
            28: begin cos = 711; end
            29: begin cos = 1401; end
            30: begin cos = 2048; end
            31: begin cos = 2633; end
            32: begin cos = 3138; end
            33: begin cos = 3547; end
            34: begin cos = 3849; end
            35: begin cos = 4034; end
            default: begin cos = 0; end
        endcase
    end
endmodule

module slope_LUT(
    input [31:0] angle,
    output reg signed [31:0] tan,
    output reg signed [31:0] cot
    );
    always @ (*)
    begin
        case (angle)
            // 0: begin cot = 100000; end
            // 1: begin cot = 1452; end
            // 2: begin cot = 703; end
            // 3: begin cot = 443; end
            // 4: begin cot = 305; end
            // 5: begin cot = 215; end
            // 6: begin cot = 148; end
            // 7: begin cot = 93; end
            // 8: begin cot = 45; end
            // 9: begin cot = 0; end
            // 10: begin cot = -45; end
            // 11: begin cot = -93; end
            // 12: begin cot = -148; end
            // 13: begin cot = -215; end
            // 14: begin cot = -305; end
            // 15: begin cot = -443; end
            // 16: begin cot = -703; end
            // 17: begin cot = -1452; end
            // 18: begin cot = -100000; end
            // 19: begin cot = 1452; end
            // 20: begin cot = 703; end
            // 21: begin cot = 443; end
            // 22: begin cot = 305; end
            // 23: begin cot = 215; end
            // 24: begin cot = 148; end
            // 25: begin cot = 93; end
            // 26: begin cot = 45; end
            // 27: begin cot = 0; end
            // 28: begin cot = -45; end
            // 29: begin cot = -93; end
            // 30: begin cot = -148; end
            // 31: begin cot = -215; end
            // 32: begin cot = -305; end
            // 33: begin cot = -443; end
            // 34: begin cot = -703; end
            // 35: begin cot = -1452; end
            0: begin cot = 0; end
            1: begin cot = 23230; end
            2: begin cot = 11254; end
            3: begin cot = 7094; end
            4: begin cot = 4881; end
            5: begin cot = 3437; end
            6: begin cot = 2365; end
            7: begin cot = 1491; end
            8: begin cot = 722; end
            9: begin cot = 0; end
            10: begin cot = -722; end
            11: begin cot = -1491; end
            12: begin cot = -2365; end
            13: begin cot = -3437; end
            14: begin cot = -4881; end
            15: begin cot = -7094; end
            16: begin cot = -11254; end
            17: begin cot = -23230; end
            18: begin cot = 0; end
            19: begin cot = 23230; end
            20: begin cot = 11254; end
            21: begin cot = 7094; end
            22: begin cot = 4881; end
            23: begin cot = 3437; end
            24: begin cot = 2365; end
            25: begin cot = 1491; end
            26: begin cot = 722; end
            27: begin cot = 0; end
            28: begin cot = -722; end
            29: begin cot = -1491; end
            30: begin cot = -2365; end
            31: begin cot = -3437; end
            32: begin cot = -4881; end
            33: begin cot = -7094; end
            34: begin cot = -11254; end
            35: begin cot = -23230; end
            default: begin cot = 0; end
        endcase
        
        case (angle)
            // 0: begin tan = 0; end
            // 1: begin tan = 45; end
            // 2: begin tan = 93; end
            // 3: begin tan = 148; end
            // 4: begin tan = 215; end
            // 5: begin tan = 305; end
            // 6: begin tan = 443; end
            // 7: begin tan = 703; end
            // 8: begin tan = 1452; end
            // 9: begin tan = 100000; end
            // 10: begin tan = -1452; end
            // 11: begin tan = -703; end
            // 12: begin tan = -443; end
            // 13: begin tan = -305; end
            // 14: begin tan = -215; end
            // 15: begin tan = -148; end
            // 16: begin tan = -93; end
            // 17: begin tan = -45; end
            // 18: begin tan = 0; end
            // 19: begin tan = 45; end
            // 20: begin tan = 93; end
            // 21: begin tan = 148; end
            // 22: begin tan = 215; end
            // 23: begin tan = 305; end
            // 24: begin tan = 443; end
            // 25: begin tan = 703; end
            // 26: begin tan = 1452; end
            // 27: begin tan = 100000; end
            // 28: begin tan = -1452; end
            // 29: begin tan = -703; end
            // 30: begin tan = -443; end
            // 31: begin tan = -305; end
            // 32: begin tan = -215; end
            // 33: begin tan = -148; end
            // 34: begin tan = -93; end
            // 35: begin tan = -45; end
            0: begin tan = 0; end
            1: begin tan = 722; end
            2: begin tan = 1491; end
            3: begin tan = 2365; end
            4: begin tan = 3437; end
            5: begin tan = 4881; end
            6: begin tan = 7094; end
            7: begin tan = 11254; end
            8: begin tan = 23230; end
            9: begin tan = 0; end
            10: begin tan = -23230; end
            11: begin tan = -11254; end
            12: begin tan = -7094; end
            13: begin tan = -4881; end
            14: begin tan = -3437; end
            15: begin tan = -2365; end
            16: begin tan = -1491; end
            17: begin tan = -722; end
            18: begin tan = 0; end
            19: begin tan = 722; end
            20: begin tan = 1491; end
            21: begin tan = 2365; end
            22: begin tan = 3437; end
            23: begin tan = 4881; end
            24: begin tan = 7094; end
            25: begin tan = 11254; end
            26: begin tan = 23230; end
            27: begin tan = 0; end
            28: begin tan = -23230; end
            29: begin tan = -11254; end
            30: begin tan = -7094; end
            31: begin tan = -4881; end
            32: begin tan = -3437; end
            33: begin tan = -2365; end
            34: begin tan = -1491; end
            35: begin tan = -722; end
            default: begin tan = 0; end
        endcase
    end
endmodule

module draw_cursor # 
(
    parameter integer burst_len = 128
)
(
    input clk100,
    input resetn,
    input draw,
    output draw_done,
    output txn_init,
    input txn_done,
    output [31:0] offset_addr,
    output [31:0] pixel_count,
    input [31:0] position_in,
    input [31:0] angle_in
);
    // Control FSM wires/regs
    reg draw_init_ff, draw_init_ff2; // pulse generator regs
    wire draw_pulse; // start signal
    reg [3:0] current_state, next_state; // control FSM states
    localparam [3:0] START = 4'b0000, LOAD = 4'b0001, CALCULATE_ANGLE = 4'b0010, 
                     CALCULATE_COOR_1 = 4'b0011,  CALCULATE_COOR_2 = 4'b0100, 
                     CALCULATE_COOR_3 = 4'b0101, DRAW_LINE = 4'b0110, CHECK_SIDE = 4'b0111,
                     DONE = 4'b1000;
    
    // coordinate counters
    wire signed [31:0] x, y;
    reg signed [31:0] x_a, y_a, x_b, y_b, x_c, y_c;
    reg signed [31:0] position;
    reg signed [31:0] angle;
    reg signed [31:0] final_angle_a, final_angle_b, final_angle_c;
    reg signed [31:0] sin_a, cos_a, sin_b, cos_b, sin_c, cos_c;
    wire signed [31:0] sin_a_from_LUT, cos_a_from_LUT;
    wire signed [31:0] sin_b_from_LUT, cos_b_from_LUT;
    wire signed [31:0] sin_c_from_LUT, cos_c_from_LUT;
    
    angle_LUT angle_a_LUT(.angle(final_angle_a), .sin(sin_a_from_LUT), .cos(cos_a_from_LUT));
    angle_LUT angle_b_LUT(.angle(final_angle_b), .sin(sin_b_from_LUT), .cos(cos_b_from_LUT));
    angle_LUT angle_c_LUT(.angle(final_angle_c), .sin(sin_c_from_LUT), .cos(cos_c_from_LUT));
    
    reg signed [31:0] lda_x0, lda_y0, lda_x1, lda_y1;
    wire lda_start, lda_done;
    reg [31:0] side_counter;
    
    line_drawing_algorithm lda(
        .clk(clk100),
        .rst(resetn),
        .start(lda_start),
        .done_drawing(lda_done),
        .x0(lda_x0),
        .x1(lda_x1),
        .y0(lda_y0),
        .y1(lda_y1),
        .vga_x(x),
        .vga_y(y),
        .vga_plot(txn_init),
        .vga_done(txn_done)
     );
    
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
            START: next_state = draw_pulse ? LOAD : START;
            LOAD: next_state = CALCULATE_ANGLE;
            CALCULATE_ANGLE: next_state = CALCULATE_COOR_1;
            CALCULATE_COOR_1: next_state = CALCULATE_COOR_2;
            CALCULATE_COOR_2: next_state = CALCULATE_COOR_3;
            CALCULATE_COOR_3: next_state = DRAW_LINE;
            DRAW_LINE: next_state = lda_done ? CHECK_SIDE : DRAW_LINE;
            CHECK_SIDE: next_state = (side_counter == 2) ? DONE: DRAW_LINE;
            DONE: next_state = START;
            default: next_state = START;
        endcase
    end
    
    // counter logic
    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            x_a <= 0;
            y_a <= 0;
            x_b <= 0;
            y_b <= 0;
            x_c <= 0;
            y_c <= 0;
            sin_a <= 0;
            cos_a <= 0;
            sin_b <= 0;
            cos_b <= 0;
            sin_c <= 0;
            cos_c <= 0;
            position <= 0;
            angle <= 0;
            final_angle_a <= 0;
            final_angle_b <= 0;
            final_angle_c <= 0;
            side_counter <= 0;
        end
        else
        begin
            if (current_state == START || current_state == DONE)
            begin
                x_a <= 0;
                y_a <= 0;
                x_b <= 0;
                y_b <= 0;
                x_c <= 0;
                y_c <= 0;
                sin_a <= 0;
                cos_a <= 0;
                sin_b <= 0;
                cos_b <= 0;
                sin_c <= 0;
                cos_c <= 0;
                position <= 0;
                angle <= 0;
                final_angle_a <= 0;
                final_angle_b <= 0;
                final_angle_c <= 0;
                side_counter <= 0;
            end
            else if (current_state == LOAD)
            begin
                position <= position_in;
                angle <= angle_in;
            end
            else if (current_state == CALCULATE_ANGLE)
            begin
                final_angle_a <= ((position + angle) >= 36) ? (position + angle - 36) : (position + angle);
                final_angle_b <= ((position + angle - 1) >= 36) ? (position + angle - 37) : 
                                  (((position + angle - 1) < 0) ? (position + angle + 35) : (position + angle - 1));
                final_angle_c <= ((position + angle + 1) >= 36) ? (position + angle - 35) : (position + angle + 1);
            end
            else if (current_state == CALCULATE_COOR_1)
            begin
                sin_a <= sin_a_from_LUT;
                cos_a <= cos_a_from_LUT;
                sin_b <= sin_b_from_LUT;
                cos_b <= cos_b_from_LUT;
                sin_c <= sin_c_from_LUT;
                cos_c <= cos_c_from_LUT;
            end
            else if (current_state == CALCULATE_COOR_2)
            begin
                x_a <= 48 * sin_a;
                y_a <= 48 * cos_a;
                x_b <= 36 * sin_b;
                y_b <= 36 * cos_b;
                x_c <= 36 * sin_c;
                y_c <= 36 * cos_c;
            end
            else if (current_state == CALCULATE_COOR_3)
            begin
                x_a <= x_a >>> 12;
                y_a <= y_a >>> 12;
                x_b <= x_b >>> 12;
                y_b <= y_b >>> 12;
                x_c <= x_c >>> 12;
                y_c <= y_c >>> 12;
            end
            else if (current_state == CHECK_SIDE)
            begin
                side_counter <= side_counter + 1;
            end
        end
    end
    
    always @ (*)
    begin
        case (side_counter)
            0: begin lda_x0 = x_a; lda_x1 = x_b; lda_y0 = y_a; lda_y1 = y_b; end
            1: begin lda_x0 = x_a; lda_x1 = x_c; lda_y0 = y_a; lda_y1 = y_c; end
            2: begin lda_x0 = x_b; lda_x1 = x_c; lda_y0 = y_b; lda_y1 = y_c; end
            default: begin lda_x0 = 0; lda_x1 = 0; lda_y0 = 0; lda_y1 = 0; end
        endcase
    end
    
    assign lda_start = (current_state == DRAW_LINE);
    assign offset_addr = ((240 - y) << 12) + ((x + 320) << 2);
    assign draw_done = (current_state == DONE);
    assign pixel_count = 1;
endmodule

module draw_hexagon # 
(
    parameter integer burst_len = 128
)
(
    input clk100,
    input resetn,
    input draw,
    output draw_done,
    output txn_init,
    input txn_done,
    output [31:0] offset_addr,
    output [31:0] pixel_count,
    input [31:0] angle_in
);
    // Control FSM wires/regs
    reg draw_init_ff, draw_init_ff2; // pulse generator regs
    wire draw_pulse; // start signal
    reg [3:0] current_state, next_state; // control FSM states
    localparam [3:0] START = 4'b0000, LOAD = 4'b0001, CALCULATE_ANGLE = 4'b0010, 
                     CALCULATE_COOR_1 = 4'b0011,  CALCULATE_COOR_2 = 4'b0100, 
                     CALCULATE_COOR_3 = 4'b0101, DRAW_LINE = 4'b0110, CHECK_SIDE = 4'b0111,
                     DONE = 4'b1000;
    
    // coordinate counters
    wire signed [31:0] x, y;
    reg signed [31:0] x_a, y_a, x_b, y_b, x_c, y_c, x_d, y_d, x_e, y_e, x_f, y_f;
    reg signed [31:0] position;
    reg signed [31:0] angle;
    reg signed [31:0] final_angle_a, final_angle_b, final_angle_c, final_angle_d, final_angle_e, final_angle_f;
    reg signed [31:0] sin_a, cos_a, sin_b, cos_b, sin_c, cos_c, sin_d, cos_d, sin_e, cos_e, sin_f, cos_f;
    wire signed [31:0] sin_a_from_LUT, cos_a_from_LUT;
    wire signed [31:0] sin_b_from_LUT, cos_b_from_LUT;
    wire signed [31:0] sin_c_from_LUT, cos_c_from_LUT;
    wire signed [31:0] sin_d_from_LUT, cos_d_from_LUT;
    wire signed [31:0] sin_e_from_LUT, cos_e_from_LUT;
    wire signed [31:0] sin_f_from_LUT, cos_f_from_LUT;
    
    angle_LUT angle_a_LUT(.angle(final_angle_a), .sin(sin_a_from_LUT), .cos(cos_a_from_LUT));
    angle_LUT angle_b_LUT(.angle(final_angle_b), .sin(sin_b_from_LUT), .cos(cos_b_from_LUT));
    angle_LUT angle_c_LUT(.angle(final_angle_c), .sin(sin_c_from_LUT), .cos(cos_c_from_LUT));
    angle_LUT angle_d_LUT(.angle(final_angle_d), .sin(sin_d_from_LUT), .cos(cos_d_from_LUT));
    angle_LUT angle_e_LUT(.angle(final_angle_e), .sin(sin_e_from_LUT), .cos(cos_e_from_LUT));
    angle_LUT angle_f_LUT(.angle(final_angle_f), .sin(sin_f_from_LUT), .cos(cos_f_from_LUT));
    
    reg signed [31:0] lda_x0, lda_y0, lda_x1, lda_y1;
    wire lda_start, lda_done;
    reg [31:0] side_counter;
    
    line_drawing_algorithm lda(
        .clk(clk100),
        .rst(resetn),
        .start(lda_start),
        .done_drawing(lda_done),
        .x0(lda_x0),
        .x1(lda_x1),
        .y0(lda_y0),
        .y1(lda_y1),
        .vga_x(x),
        .vga_y(y),
        .vga_plot(txn_init),
        .vga_done(txn_done)
     );
    
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
            START: next_state = draw_pulse ? LOAD : START;
            LOAD: next_state = CALCULATE_ANGLE;
            CALCULATE_ANGLE: next_state = CALCULATE_COOR_1;
            CALCULATE_COOR_1: next_state = CALCULATE_COOR_2;
            CALCULATE_COOR_2: next_state = CALCULATE_COOR_3;
            CALCULATE_COOR_3: next_state = DRAW_LINE;
            DRAW_LINE: next_state = lda_done ? CHECK_SIDE : DRAW_LINE;
            CHECK_SIDE: next_state = (side_counter == 5) ? DONE: DRAW_LINE;
            DONE: next_state = START;
            default: next_state = START;
        endcase
    end
    
    // counter logic
    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            x_a <= 0;
            y_a <= 0;
            x_b <= 0;
            y_b <= 0;
            x_c <= 0;
            y_c <= 0;
            x_d <= 0;
            y_d <= 0;
            x_e <= 0;
            y_e <= 0;
            x_f <= 0;
            y_f <= 0;
            sin_a <= 0;
            cos_a <= 0;
            sin_b <= 0;
            cos_b <= 0;
            sin_c <= 0;
            cos_c <= 0;
            sin_d <= 0;
            cos_d <= 0;
            sin_e <= 0;
            cos_e <= 0;
            sin_f <= 0;
            cos_f <= 0;
            angle <= 0;
            final_angle_a <= 0;
            final_angle_b <= 0;
            final_angle_c <= 0;
            final_angle_d <= 0;
            final_angle_e <= 0;
            final_angle_f <= 0;
            side_counter <= 0;
        end
        else
        begin
            if (current_state == START || current_state == DONE)
            begin
                x_a <= 0;
                y_a <= 0;
                x_b <= 0;
                y_b <= 0;
                x_c <= 0;
                y_c <= 0;
                x_d <= 0;
                y_d <= 0;
                x_e <= 0;
                y_e <= 0;
                x_f <= 0;
                y_f <= 0;
                sin_a <= 0;
                cos_a <= 0;
                sin_b <= 0;
                cos_b <= 0;
                sin_c <= 0;
                cos_c <= 0;
                sin_d <= 0;
                cos_d <= 0;
                sin_e <= 0;
                cos_e <= 0;
                sin_f <= 0;
                cos_f <= 0;
                angle <= 0;
                final_angle_a <= 0;
                final_angle_b <= 0;
                final_angle_c <= 0;
                final_angle_d <= 0;
                final_angle_e <= 0;
                final_angle_f <= 0;
                side_counter <= 0;
            end
            else if (current_state == LOAD)
            begin
                angle <= angle_in;
            end
            else if (current_state == CALCULATE_ANGLE)
            begin
                final_angle_a <= ((angle + 33) < 36) ? (angle + 33) : (angle - 3);
                final_angle_b <= ((angle + 3) < 36) ? (angle + 3) : (angle - 33);
                final_angle_c <= ((angle + 9) < 36) ? (angle + 9) : (angle - 27);
                final_angle_d <= ((angle + 15) < 36) ? (angle + 15) : (angle - 21);
                final_angle_e <= ((angle + 21) < 36) ? (angle + 21) : (angle - 15);
                final_angle_f <= ((angle + 27) < 36) ? (angle + 27) : (angle - 9);
            end
            else if (current_state == CALCULATE_COOR_1)
            begin
                sin_a <= sin_a_from_LUT;
                cos_a <= cos_a_from_LUT;
                sin_b <= sin_b_from_LUT;
                cos_b <= cos_b_from_LUT;
                sin_c <= sin_c_from_LUT;
                cos_c <= cos_c_from_LUT;
                sin_d <= sin_d_from_LUT;
                cos_d <= cos_d_from_LUT;
                sin_e <= sin_e_from_LUT;
                cos_e <= cos_e_from_LUT;
                sin_f <= sin_f_from_LUT;
                cos_f <= cos_f_from_LUT;
            end
            else if (current_state == CALCULATE_COOR_2)
            begin
                x_a <= 32 * sin_a;
                y_a <= 32 * cos_a;
                x_b <= 32 * sin_b;
                y_b <= 32 * cos_b;
                x_c <= 32 * sin_c;
                y_c <= 32 * cos_c;
                x_d <= 32 * sin_d;
                y_d <= 32 * cos_d;
                x_e <= 32 * sin_e;
                y_e <= 32 * cos_e;
                x_f <= 32 * sin_f;
                y_f <= 32 * cos_f;
            end
            else if (current_state == CALCULATE_COOR_3)
            begin
                x_a <= x_a >>> 12;
                y_a <= y_a >>> 12;
                x_b <= x_b >>> 12;
                y_b <= y_b >>> 12;
                x_c <= x_c >>> 12;
                y_c <= y_c >>> 12;
                x_d <= x_d >>> 12;
                y_d <= y_d >>> 12;
                x_e <= x_e >>> 12;
                y_e <= y_e >>> 12;
                x_f <= x_f >>> 12;
                y_f <= y_f >>> 12;
            end
            else if (current_state == CHECK_SIDE)
            begin
                side_counter <= side_counter + 1;
            end
        end
    end
    
    always @ (*)
    begin
        case (side_counter)
            0: begin lda_x0 = x_a; lda_x1 = x_b; lda_y0 = y_a; lda_y1 = y_b; end
            1: begin lda_x0 = x_b; lda_x1 = x_c; lda_y0 = y_b; lda_y1 = y_c; end
            2: begin lda_x0 = x_c; lda_x1 = x_d; lda_y0 = y_c; lda_y1 = y_d; end
            3: begin lda_x0 = x_d; lda_x1 = x_e; lda_y0 = y_d; lda_y1 = y_e; end
            4: begin lda_x0 = x_e; lda_x1 = x_f; lda_y0 = y_e; lda_y1 = y_f; end
            5: begin lda_x0 = x_f; lda_x1 = x_a; lda_y0 = y_f; lda_y1 = y_a; end
            default: begin lda_x0 = 0; lda_x1 = 0; lda_y0 = 0; lda_y1 = 0; end
        endcase
    end
    
    assign lda_start = (current_state == DRAW_LINE);
    assign offset_addr = ((240 - y) << 12) + ((x + 320) << 2);
    assign draw_done = (current_state == DONE);
    assign pixel_count = 1;
endmodule
