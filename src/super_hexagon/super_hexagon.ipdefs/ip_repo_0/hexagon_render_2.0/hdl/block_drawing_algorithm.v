module block_drawing_algorithm #
(
    parameter integer burst_len = 128
)
(
    input clk100,
    input resetn,
    input start,
    output done,
    output txn_init,
    input txn_done,
    output reg signed [31:0] pixel_count, // for burst control
    output reg signed [31:0] x,
    output reg signed [31:0] y,
    
    // vertices
    input [31:0] x_a_in,
    input [31:0] y_a_in,
    input [31:0] x_b_in,
    input [31:0] y_b_in,
    input [31:0] x_c_in,
    input [31:0] y_c_in,
    input [31:0] x_d_in,
    input [31:0] y_d_in,
    
    // slopes
    input [31:0] m_0_in,
    input [31:0] m_1_in,
    input [31:0] m_2_in,
    input [31:0] m_3_in,
    
    // inverse of slopes
    input [31:0] m_inv_0_in,
    input [31:0] m_inv_1_in,
    input [31:0] m_inv_2_in,
    input [31:0] m_inv_3_in
);

    // input registers
    // x, y registers are signed, abs versions are absolute values
    // sgn registers record the sign of each coordinate, 1 for positive, 0 for negative
    reg signed [31:0] x_a;
    reg signed [31:0] y_a;
    reg signed [31:0] x_b;
    reg signed [31:0] y_b;
    reg signed [31:0] x_c;
    reg signed [31:0] y_c;
    reg signed [31:0] x_d;
    reg signed [31:0] y_d;

    reg signed [31:0] m_0;
    reg signed [31:0] m_1;
    reg signed [31:0] m_2;
    reg signed [31:0] m_3;

    reg signed [31:0] m_inv_0;
    reg signed [31:0] m_inv_1;
    reg signed [31:0] m_inv_2;
    reg signed [31:0] m_inv_3;

    // intermediate registers
    reg signed [31:0] mx_0;
    reg signed [31:0] mx_1;
    reg signed [31:0] mx_2;
    reg signed [31:0] mx_3;
    reg signed [31:0] offset_0;
    reg signed [31:0] offset_1;
    reg signed [31:0] offset_2;
    reg signed [31:0] offset_3;
    reg signed [31:0] x_intersect_0;
    reg signed [31:0] x_intersect_1;
    reg signed [31:0] x_intersect_2;
    reg signed [31:0] x_intersect_3;
    reg signed [31:0] y_min, y_max;
    reg signed [31:0] x_min, x_max;
    reg signed [31:0] y_minus_b_0;
    reg signed [31:0] y_minus_b_1;
    reg signed [31:0] y_minus_b_2;
    reg signed [31:0] y_minus_b_3;
    reg valid_0;
    reg valid_1;
    reg valid_2;
    reg valid_3;
    reg horizontal_0;
    reg horizontal_1;
    reg horizontal_2;
    reg horizontal_3;
    reg vertical_0;
    reg vertical_1;
    reg vertical_2;
    reg vertical_3;    
    
    // Control FSM wires/regs
    reg start_init_ff, start_init_ff2; // pulse generator regs
    wire start_pulse; // start signal
    reg [3:0] current_state, next_state; // control FSM states
    localparam [3:0] START = 4'b0000, LOAD = 4'b0001, CALCULATE_OFFSET_1 = 4'b0010,
                     CALCULATE_OFFSET_2 = 4'b0011, FIND_Y_RANGE = 4'b0100, 
                     SET_Y = 4'b0101, FIND_INTERSECTION_1 = 4'b0110, FIND_INTERSECTION_2 = 4'b0111,
                     FIND_X_RANGE = 4'b1000, SET_X = 4'b1001, DRAW_POINT = 4'b1010, 
                     CHECK_X = 4'b1011, CHECK_Y = 4'b1100, DONE = 4'b1101, SET_BURST_LEN = 4'b1110;

    // generate a pulse for the drawing signal
    assign start_pulse = start_init_ff && (!(start_init_ff2));

    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            start_init_ff <= 0;
            start_init_ff2 <= 0;
        end
        else
        begin
            start_init_ff <= start;
            start_init_ff2 <= start_init_ff;
        end
    end

    // state transition
    always @ (posedge clk100)
    begin
        if (~resetn)
            current_state <= start;
        else
            current_state <= next_state;
    end
    
    // next state logic
    always @ (*)
    begin
        case (current_state)
            START: next_state = start_pulse ? LOAD : START;
            LOAD: next_state = CALCULATE_OFFSET_1;
            CALCULATE_OFFSET_1: next_state = CALCULATE_OFFSET_2;
            CALCULATE_OFFSET_2: next_state = FIND_Y_RANGE;
            FIND_Y_RANGE: next_state = SET_Y;
            SET_Y: next_state = FIND_INTERSECTION_1;
            FIND_INTERSECTION_1: next_state = FIND_INTERSECTION_2;
            FIND_INTERSECTION_2: next_state = FIND_X_RANGE;
            FIND_X_RANGE: next_state = SET_X;
            SET_X: next_state = SET_BURST_LEN;
            SET_BURST_LEN: next_state = DRAW_POINT;
            DRAW_POINT: next_state = txn_done ? CHECK_X : DRAW_POINT;
            CHECK_X: next_state = (x + burst_len <= x_max) ? SET_BURST_LEN : CHECK_Y;
            CHECK_Y: next_state = (y < y_max) ? FIND_INTERSECTION_1 : DONE;
            DONE: next_state = START;
            default: next_state = START;
        endcase
    end
    
    always @ (posedge clk100)
    begin
        if (~resetn)
        begin
            x <= 0;
            y <= 0;
        
            x_a <= 0;
            y_a <= 0;
            x_b <= 0;
            y_b <= 0;
            x_c <= 0;
            y_c <= 0;
            x_d <= 0;
            y_d <= 0;

            m_0 <= 0;
            m_1 <= 0;
            m_2 <= 0;
            m_3 <= 0;

            m_inv_0 <= 0;
            m_inv_1 <= 0;
            m_inv_2 <= 0;
            m_inv_3 <= 0;
            
            mx_0 <= 0;
            mx_1 <= 0;
            mx_2 <= 0;
            mx_3 <= 0;
            
            offset_0 <= 0;
            offset_1 <= 0;
            offset_2 <= 0;
            offset_3 <= 0;
            
            x_intersect_0 <= 0;
            x_intersect_1 <= 0;
            x_intersect_2 <= 0;
            x_intersect_3 <= 0;
            
            x_min <= 0;
            x_max <= 0;
            y_min <= 0;
            y_max <= 0;
            
            y_minus_b_0 <= 0;
            y_minus_b_1 <= 0;
            y_minus_b_2 <= 0;
            y_minus_b_3 <= 0;
            
            valid_0 <= 0;
            valid_1 <= 0;
            valid_2 <= 0;
            valid_3 <= 0;
            
            horizontal_0 <= 0;
            horizontal_1 <= 0;
            horizontal_2 <= 0;
            horizontal_3 <= 0;
            vertical_0 <= 0;
            vertical_1 <= 0;
            vertical_2 <= 0;
            vertical_3 <= 0;
            
            pixel_count <= 0;
        end
        else
        begin
            if (current_state == START || current_state == DONE)
            begin
                x <= 0;
                y <= 0;
                
                x_a <= 0;
                y_a <= 0;
                x_b <= 0;
                y_b <= 0;
                x_c <= 0;
                y_c <= 0;
                x_d <= 0;
                y_d <= 0;

                m_0 <= 0;
                m_1 <= 0;
                m_2 <= 0;
                m_3 <= 0;

                m_inv_0 <= 0;
                m_inv_1 <= 0;
                m_inv_2 <= 0;
                m_inv_3 <= 0;
                
                mx_0 <= 0;
                mx_1 <= 0;
                mx_2 <= 0;
                mx_3 <= 0;
                
                offset_0 <= 0;
                offset_1 <= 0;
                offset_2 <= 0;
                offset_3 <= 0;
                
                x_intersect_0 <= 0;
                x_intersect_1 <= 0;
                x_intersect_2 <= 0;
                x_intersect_3 <= 0;

                x_min <= 0;
                x_max <= 0;
                y_min <= 0;
                y_max <= 0;
                
                y_minus_b_0 <= 0;
                y_minus_b_1 <= 0;
                y_minus_b_2 <= 0;
                y_minus_b_3 <= 0;
                
                valid_0 <= 0;
                valid_1 <= 0;
                valid_2 <= 0;
                valid_3 <= 0;
                
                horizontal_0 <= 0;
                horizontal_1 <= 0;
                horizontal_2 <= 0;
                horizontal_3 <= 0;
                vertical_0 <= 0;
                vertical_1 <= 0;
                vertical_2 <= 0;
                vertical_3 <= 0;
                
                pixel_count <= 0;
            end
            else if(current_state == LOAD)
            begin
                x_a <= x_a_in;
                y_a <= y_a_in;
                x_b <= x_b_in;
                y_b <= y_b_in;
                x_c <= x_c_in;
                y_c <= y_c_in;
                x_d <= x_d_in;
                y_d <= y_d_in;

                m_0 <= m_0_in;
                m_1 <= m_1_in;
                m_2 <= m_2_in;
                m_3 <= m_3_in;

                m_inv_0 <= m_inv_0_in;
                m_inv_1 <= m_inv_1_in;
                m_inv_2 <= m_inv_2_in;
                m_inv_3 <= m_inv_3_in;
            end
            else if(current_state == CALCULATE_OFFSET_1)
            begin
                mx_0 <= m_0 * x_a;
                mx_1 <= m_1 * x_b;
                mx_2 <= m_2 * x_c;
                mx_3 <= m_3 * x_d;
            end
            else if(current_state == CALCULATE_OFFSET_2)
            begin
                offset_0 <= y_a - (mx_0 >>> 12);
                offset_1 <= y_b - (mx_1 >>> 12);
                offset_2 <= y_c - (mx_2 >>> 12);
                offset_3 <= y_d - (mx_3 >>> 12);
            end
            else if(current_state == FIND_Y_RANGE)
            begin
                if((y_a <= y_b) && (y_a <= y_c) && (y_a <= y_d))
                    y_min <= y_a;
                else if ((y_b <= y_a) && (y_b <= y_c) && (y_b <= y_d))
                    y_min <= y_b;
                else if ((y_c <= y_a) && (y_c <= y_b) && (y_c <= y_d))
                    y_min <= y_c;
                else if ((y_d <= y_a) && (y_d <= y_b) && (y_d <= y_c))
                    y_min <= y_d;
                else
                    y_min <= y_min;
                
                if((y_a >= y_b) && (y_a >= y_c) && (y_a >= y_d))
                    y_max <= y_a;
                else if ((y_b >= y_a) && (y_b >= y_c) && (y_b >= y_d))
                    y_max <= y_b;
                else if ((y_c >= y_a) && (y_c >= y_b) && (y_c >= y_d))
                    y_max <= y_c;
                else if ((y_d >= y_a) && (y_d >= y_b) && (y_d >= y_c))
                    y_max <= y_d;
                else
                    y_max <= y_max;
            end
            else if(current_state == SET_Y)
            begin
                y <= y_min + 1;
            end
            else if(current_state == FIND_INTERSECTION_1)
            begin
                y_minus_b_0 <= y - offset_0;
                y_minus_b_1 <= y - offset_1;
                y_minus_b_2 <= y - offset_2;
                y_minus_b_3 <= y - offset_3;
                
                vertical_0 <= (x_a == x_d);
                vertical_1 <= (x_b == x_a);
                vertical_2 <= (x_c == x_b);
                vertical_3 <= (x_d == x_c);
                
                horizontal_0 <= (y_a == y_d);
                horizontal_1 <= (y_b == y_a);
                horizontal_2 <= (y_c == y_b);
                horizontal_3 <= (y_d == y_c);
            end
            else if(current_state == FIND_INTERSECTION_2)
            begin
                if (y == y_a)
                    x_intersect_0 <= x_a;
                else if (y == y_d)
                    x_intersect_0 <= x_d;
                else
                    x_intersect_0 <= vertical_0 ? x_a : ((y_minus_b_0 * m_inv_0) >>> 12);
                    
                if (y == y_b)
                    x_intersect_1 <= x_b;
                else if (y == y_a)
                    x_intersect_1 <= x_a;
                else
                    x_intersect_1 <= vertical_1 ? x_b : ((y_minus_b_1 * m_inv_1) >>> 12);
                    
                if (y == y_c)
                    x_intersect_2 <= x_c;
                else if (y == y_b)
                    x_intersect_2 <= x_b;
                else
                    x_intersect_2 <= vertical_2 ? x_c : ((y_minus_b_2 * m_inv_2) >>> 12);
                
                if (y == y_d)
                    x_intersect_3 <= x_d;
                else if (y == y_c)
                    x_intersect_3 <= x_c;
                else
                    x_intersect_3 <= vertical_3 ? x_d : ((y_minus_b_3 * m_inv_3) >>> 12);
                
                valid_0 <= (~horizontal_0) && (((y <= y_a) && (y >= y_d)) || ((y >= y_a) && (y <= y_d)));
                valid_1 <= (~horizontal_1) && (((y <= y_b) && (y >= y_a)) || ((y >= y_b) && (y <= y_a)));
                valid_2 <= (~horizontal_2) && (((y <= y_c) && (y >= y_b)) || ((y >= y_c) && (y <= y_b)));
                valid_3 <= (~horizontal_3) && (((y <= y_d) && (y >= y_c)) || ((y >= y_d) && (y <= y_c)));
            end
            else if(current_state == FIND_X_RANGE)
            begin
                if(valid_0 && ((x_intersect_0 <= x_intersect_1) || ~valid_1) && ((x_intersect_0 <= x_intersect_2) || ~valid_2) && ((x_intersect_0 <= x_intersect_3) || ~valid_3))
                    x_min <= x_intersect_0;
                else if (valid_1 && ((x_intersect_1 <= x_intersect_0) || ~valid_0) && ((x_intersect_1 <= x_intersect_2) || ~valid_2) && ((x_intersect_1 <= x_intersect_3) || ~valid_3))
                    x_min <= x_intersect_1;
                else if (valid_2 && ((x_intersect_2 <= x_intersect_0) || ~valid_0) && ((x_intersect_2 <= x_intersect_1) || ~valid_1) && ((x_intersect_2 <= x_intersect_3) || ~valid_3))
                    x_min <= x_intersect_2;
                else if (valid_3 && ((x_intersect_3 <= x_intersect_0) || ~valid_0) && ((x_intersect_3 <= x_intersect_1) || ~valid_1) && ((x_intersect_3 <= x_intersect_2) || ~valid_2))
                    x_min <= x_intersect_3;
                
                if(valid_0 && ((x_intersect_0 >= x_intersect_1) || ~valid_1) && ((x_intersect_0 >= x_intersect_2) || ~valid_2) && ((x_intersect_0 >= x_intersect_3) || ~valid_3))
                    x_max <= x_intersect_0;
                else if (valid_1 && ((x_intersect_1 >= x_intersect_0) || ~valid_0) && ((x_intersect_1 >= x_intersect_2) || ~valid_2) && ((x_intersect_1 >= x_intersect_3) || ~valid_3))
                    x_max <= x_intersect_1;
                else if (valid_2 && ((x_intersect_2 >= x_intersect_0) || ~valid_0) && ((x_intersect_2 >= x_intersect_1) || ~valid_1) && ((x_intersect_2 >= x_intersect_3) || ~valid_3))
                    x_max <= x_intersect_2;
                else if (valid_3 && ((x_intersect_3 >= x_intersect_0) || ~valid_0) && ((x_intersect_3 >= x_intersect_1) || ~valid_1) && ((x_intersect_3 >= x_intersect_2) || ~valid_2))
                    x_max <= x_intersect_3;
            end
            else if(current_state == SET_X)
            begin
                x <= x_min;
            end
            else if(current_state == CHECK_X)
            begin
                x <= x + burst_len;
            end
            else if(current_state == CHECK_Y)
            begin
                y <= y + 1;
            end
            else if(current_state == SET_BURST_LEN)
            begin
                pixel_count <= ((x_max - x + 1) > burst_len) ? burst_len : (x_max - x + 1);
            end
        end
    end
    
    assign txn_init = (current_state == DRAW_POINT);
    assign done = (current_state == DONE);
    
endmodule