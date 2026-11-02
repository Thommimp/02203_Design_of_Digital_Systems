// -----------------------------------------------------------------------------
//
//  Title      :  Edge-Detection design project - task 2.
//             :
//  Developers :  YOUR NAME HERE - s263523@student.dtu.dk
//             :  
//             :
//  Purpose    :  This design contains an entity for the edge detection accelerator 
//             :  that must be build in the Edge Detection design project. 
//             :  
//             :
//  Revision   :  1.0   01-11-26
//             :
//
// ----------------------------------------------------------------------------//

//------------------------------------------------------------------------------
//
// 
//------------------------------------------------------------------------------

module acc (
    input  logic        clk,        // The clock.
    input  logic        reset,      // The reset signal. Active high.
    output logic [15:0] addr,       // Address bus for data (halfword_t).
    input  logic [31:0] dataR,      // The data bus (word_t).
    output logic [31:0] dataW,      // The data bus (word_t).
    output logic        en,         // Request signal for data.
    output logic        we,         // Read/Write signal for data.
    input  logic        start,
    output logic        finish

);

function automatic logic [7:0] sobel(
    input logic [7:0] s11, s12, s13,
    input logic [7:0] s21,      s23,
    input logic [7:0] s31, s32, s33
);
    logic signed [10:0] dx, dy;
    logic        [10:0] adx, ady, sum;

    // expand to 11 bitów and convert to signed
    dx = $signed({3'b0, s13}) - $signed({3'b0, s11})
       + 2 * ($signed({3'b0, s23}) - $signed({3'b0, s21}))
       + $signed({3'b0, s33}) - $signed({3'b0, s31});

    dy = $signed({3'b0, s11}) - $signed({3'b0, s31})
       + 2 * ($signed({3'b0, s12}) - $signed({3'b0, s32}))
       + $signed({3'b0, s13}) - $signed({3'b0, s33});

    // |x|
    adx = (dx < 0) ? -dx : dx;
    ady = (dy < 0) ? -dy : dy;

    sum = adx + ady;   // 0 .. 2040

    return sum[10:3];
endfunction

  // ---------------------------------------------------
  // Insert your design here
  // ---------------------------------------------------
    localparam logic [15:0] START_ADDR = 16'd0;
    localparam logic [15:0] END_ADDR = 16'd25343;  // (352*288)/4 - 1
    localparam logic [15:0] WRITE_MEMORY_SHIFT = 16'd25256;  // (352*288)/4 - 88(1 row);
    localparam logic [15:0] PICTURE_WIDTH = 16'd352;
    localparam logic [8:0] LAST_ROW = 9'd287;
        
    typedef enum logic [3 : 0] {
        IDLE, REQ, READ_ONLY, READ_CALC, WRITE, FIN
    } state_t;
    
    logic [31:0] reg_data, next_reg_data;
    logic [31:0] reg_data_next, next_reg_data_next;
    logic [15:0] reg_addr, next_reg_addr;
    logic [8:0] row, next_row;            // 0..287 -> 9 bit
    logic [6:0] col, next_col;            // 0..87  -> 7 bit
    logic [1:0] top_row, next_top_row;    // 0..2   -> 2 bit
    logic [1:0] mid_row, next_mid_row;
    logic [1:0] bot_row, next_bot_row;
    logic [31:0] line_buf [0:2][0:87];
    logic [31:0] next_line_buf [0:2][0:87];
    logic [7:0] pix_0, pix_1, pix_2, pix_3;
    
    state_t state, next_state;
    
    assign addr = reg_addr;
    assign dataW = reg_data;
    
    // Combinatorial logic
    always_comb begin
        next_state          = state;
        next_reg_addr       = reg_addr;
        next_reg_data       = reg_data;
        next_reg_data_next  = reg_data_next;
        next_row            = row;
        next_col            = col;
        next_top_row        = top_row;
        next_mid_row        = mid_row;
        next_bot_row        = bot_row;
        next_line_buf       = line_buf;
        pix_0               = '0; 
        pix_1               = '0; 
        pix_2               = '0; 
        pix_3               = '0;
        en                  = '0;
        finish              = '0;
        we                  = '0;
        
        case (state)
            IDLE: begin
                next_reg_addr   = START_ADDR;
                next_reg_data   = 32'b0;
                en              = 1'b0;
                we              = 1'b0;
                finish          = 1'b0;
                next_row        = 9'd0;
                next_col        = 7'd0;
                next_top_row    = 2'd0;
                next_mid_row    = 2'd1;
                next_bot_row    = 2'd2;
                
                next_line_buf = '{default: '0};
                
                if (start) begin
                    next_state  = REQ;
                end
                else
                    next_state  = IDLE;
            end
            
            REQ: begin
                en              = 1'b1;
                we              = 1'b0;
                if (row == 1'd0) begin
                    next_state  = READ_ONLY;
                end
                else
                    next_state  = READ_CALC;
            end
            
            READ_ONLY: begin
                en              = 1'b1;
                we              = 1'b0;
                next_line_buf[top_row][col] = dataR;
                next_line_buf[mid_row][col] = dataR;
                next_reg_addr = reg_addr + 16'd1;
                next_col = col + 7'd1;
                if (next_col > (PICTURE_WIDTH/4 - 1)) begin
                    next_col = 0;
                    next_row = row + 9'd1;
                end
                next_state = REQ;
            end
            
            READ_CALC: begin
                en              = 1'b1;
                we              = 1'b0;
                next_line_buf[bot_row][col] = dataR;
                if (col == 0) begin
                    pix_0 = 0;
                    pix_1 = sobel(  line_buf[top_row][col][8*0 +: 8], line_buf[top_row][col][8*0 +: 8],   line_buf[top_row][col][8*1 +: 8],
                                    line_buf[mid_row][col][8*0 +: 8],                                     line_buf[mid_row][col][8*1 +: 8],
                                    dataR[8*0 +: 8],                  dataR[8*0 +: 8],                  dataR[8*1 +: 8]);
                end
                else begin
                    pix_0 = sobel(  line_buf[top_row][col-1][8*2 +: 8], line_buf[top_row][col-1][8*3 +: 8], line_buf[top_row][col][8*0 +: 8],
                                    line_buf[mid_row][col-1][8*2 +: 8],                                     line_buf[mid_row][col][8*0 +: 8],
                                    line_buf[bot_row][col-1][8*2 +: 8], line_buf[bot_row][col-1][8*3 +: 8], dataR[8*0 +: 8]);
                    pix_1 = sobel(  line_buf[top_row][col-1][8*3 +: 8], line_buf[top_row][col][8*0 +: 8],   line_buf[top_row][col][8*1 +: 8],
                                    line_buf[mid_row][col-1][8*3 +: 8],                                     line_buf[mid_row][col][8*1 +: 8],
                                    line_buf[bot_row][col-1][8*3 +: 8], dataR[8*0 +: 8],                    dataR[8*1 +: 8]);
                end
                pix_2 = sobel(  line_buf[top_row][col][8*0 +: 8],   line_buf[top_row][col][8*1 +: 8],   line_buf[top_row][col][8*2 +: 8],
                                line_buf[mid_row][col][8*0 +: 8],                                       line_buf[mid_row][col][8*2 +: 8],
                                dataR[8*0 +: 8],                    dataR[8*1 +: 8],                    dataR[8*2 +: 8]);

                pix_3 = sobel(  line_buf[top_row][col][8*1 +: 8],   line_buf[top_row][col][8*2 +: 8],   line_buf[top_row][col][8*3 +: 8],
                                line_buf[mid_row][col][8*1 +: 8],                                       line_buf[mid_row][col][8*3 +: 8],
                               dataR[8*1 +: 8],                     dataR[8*2 +: 8],                    dataR[8*3 +: 8]);

                next_reg_data = {pix_0, reg_data_next[23:0]};
                next_reg_data_next = {8'd0, pix_3, pix_2, pix_1};
                next_reg_addr = reg_addr + WRITE_MEMORY_SHIFT - 1;
                next_col = col + 7'd1;
                if (next_col > (PICTURE_WIDTH/4 - 1)) begin
                    next_col = 0;
                    next_row = row + 9'd1;
                    next_top_row = mid_row;
                    next_mid_row = bot_row;
                    next_bot_row = top_row;
                end
                next_state = WRITE;
            end
            
            WRITE: begin
                we = 1'b1;
                en = 1'b1;
                next_reg_addr = reg_addr - WRITE_MEMORY_SHIFT + 2;
                if (next_reg_addr > END_ADDR) begin
                    next_state = FIN;
                end
                else begin
                    if (row > LAST_ROW) begin
                        next_reg_data = {32'd0};
                        next_reg_addr = reg_addr + WRITE_MEMORY_SHIFT - 1;
                        next_state = WRITE;
                     end
                     else
                        next_state = REQ;
                end
            end
            
            FIN: begin
                we = 1'b0;
                en = 1'b0;
                finish = 1'b1;             
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Register
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= IDLE;
            row     <= 9'd0;
            col     <= 7'd0;
            top_row <= 2'd0;
            mid_row <= 2'd1;
            bot_row <= 2'd2;
        end
        else begin
            state           <= next_state;
            reg_addr        <= next_reg_addr;
            reg_data        <= next_reg_data;
            reg_data_next   <= next_reg_data_next;
            col             <= next_col;
            row             <= next_row;
            top_row         <= next_top_row;
            mid_row         <= next_mid_row;
            bot_row         <= next_bot_row;
            line_buf        <= next_line_buf;
        end
    end

endmodule
