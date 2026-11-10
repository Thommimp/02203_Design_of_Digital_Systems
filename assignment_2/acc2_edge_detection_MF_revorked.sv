// -----------------------------------------------------------------------------
//
//  Title      :  Edge-Detection design project - task 2.
//             :
//  Developers :  Vladimir Deriugin - s260213@student.dtu.dk
//             :
//  Purpose    :  This design contains an entity for the accelerator that must be build
//             :  in task two of the Edge Detection design project. It contains an
//             :  architecture skeleton for the entity as well.
//             :
//  Revision   :  1.1  10-11-26
//             :
//
// ----------------------------------------------------------------------------//

//------------------------------------------------------------------------------
// The module for task two. Notice the additional signals for the memory.
// reset is active high.
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

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    localparam int IMG_W                = 352;
    localparam int IMG_H                = 288;
    localparam int ROW_WORDS            = IMG_W / 4;            // 88
    localparam int N_WORDS              = IMG_W * IMG_H / 4;    // 25344
    localparam logic [15:0] OUT_BASE    = N_WORDS;              // first output word

    // -------------------------------------------------------------------------
    //   p11 p12 p13        Gx = (p13 + 2*p23 + p33) - (p11 + 2*p21 + p31)
    //   p21  X  p23        Gy = (p11 + 2*p12 + p13) - (p31 + 2*p32 + p33)
    //   p31 p32 p33        G  = |Gx| + |Gy|
    // -------------------------------------------------------------------------
    function automatic logic [7:0] sobel(
        input logic [7:0] p11, p12, p13,
        input logic [7:0] p21,      p23,
        input logic [7:0] p31, p32, p33
    );
        logic signed [10:0] gx, gy;
        logic        [10:0] g;

        gx = $signed({3'b0, p13}) + 2*$signed({3'b0, p23}) + $signed({3'b0, p33})
           - $signed({3'b0, p11}) - 2*$signed({3'b0, p21}) - $signed({3'b0, p31});

        gy = $signed({3'b0, p11}) + 2*$signed({3'b0, p12}) + $signed({3'b0, p13})
           - $signed({3'b0, p31}) - 2*$signed({3'b0, p32}) - $signed({3'b0, p33});

        g  = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);
        return g[10:3];
    endfunction

    typedef enum logic [2:0] {
        IDLE, WR_BORDER, RD_REQ, RD_STORE, WR_CALC, DONE
    } state_t;

    state_t state, next_state;

    logic [15:0] rd_addr, next_rd_addr;                 // next input word to read
    logic [15:0] wr_addr, next_wr_addr;                 // next output word to write
    logic [8:0]  y_in,    next_y_in;                    // input row being read, 0..287
    logic [6:0]  col,     next_col;                     // word inside the row, 0..87
    logic        bottom_done, next_bottom_done;         // 0: border row 0, 1: row 287

    logic [1:0]  top, next_top;
    logic [1:0]  mid, next_mid;
    logic [1:0]  bot, next_bot;

    logic [31:0] lb [0:2][0:ROW_WORDS-1];
    logic        lb_we;

    // -------------------------------------------------------------------------
    //   idx:      0          1  2  3  4           5
    //          word col-1 | word col (4 bytes) | word col+1
    //           byte 3    |                    |  byte 0
    // -------------------------------------------------------------------------
    logic [7:0] win [0:2][0:5];
    logic [1:0] slot [0:2];
    logic [7:0] pix [0:3];

    always_comb begin

        slot = '{top, mid, bot};
        win  = '{default: '0};
        for (int r = 0; r < 3; r++) begin
            if (col != 0)
                win[r][0] = lb[slot[r]][col-1][31:24]; 
            for (int i = 0; i < 4; i++)
                win[r][i+1] = lb[slot[r]][col][8*i +: 8]; 
            if (col != ROW_WORDS-1)
                win[r][5] = lb[slot[r]][col+1][7:0]; 
        end

        // Output pixel k is centred on win[1][k+1].
        for (int k = 0; k < 4; k++)
            pix[k] = sobel(win[0][k], win[0][k+1], win[0][k+2],
                           win[1][k],              win[1][k+2],
                           win[2][k], win[2][k+1], win[2][k+2]);

        // Left (x = 0) and right (x = 351) image border.
        if (col == 0)
            pix[0] = '0;
        if (col == ROW_WORDS-1)
            pix[3] = '0;
    end

    // -------------------------------------------------------------------------
    // Next-state logic
    // -------------------------------------------------------------------------
    always_comb begin
        next_state       = state;
        next_rd_addr     = rd_addr;
        next_wr_addr     = wr_addr;
        next_y_in        = y_in;
        next_col         = col;
        next_bottom_done = bottom_done;
        next_top         = top;
        next_mid         = mid;
        next_bot         = bot;

        addr   = '0;
        dataW  = '0;
        en     = 1'b0;
        we     = 1'b0;
        finish = 1'b0;
        lb_we  = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_rd_addr     = '0;
                    next_wr_addr     = OUT_BASE;
                    next_y_in        = '0;
                    next_col         = '0;
                    next_bottom_done = 1'b0;
                    next_top         = 2'd0;
                    next_mid         = 2'd1;
                    next_bot         = 2'd2;
                    next_state       = WR_BORDER;
                end
            end

            WR_BORDER: begin
                addr         = wr_addr;
                dataW        = '0;
                en           = 1'b1;
                we           = 1'b1;
                next_wr_addr = wr_addr + 16'd1;

                if (col != ROW_WORDS-1) begin
                    next_col = col + 7'd1;
                end
                else begin
                    next_col   = '0;
                    next_state = bottom_done ? DONE : RD_REQ;
                end
            end

            RD_REQ: begin
                addr = rd_addr;
                en   = 1'b1;
                we   = 1'b0;
                next_state = RD_STORE;
            end

            RD_STORE: begin
                lb_we        = 1'b1;
                next_rd_addr = rd_addr + 16'd1;

                if (col != ROW_WORDS-1) begin
                    next_col   = col + 7'd1;
                    next_state = RD_REQ;
                end
                else begin
                    next_col = '0;
                    if (y_in < 2) begin
                        next_top   = mid;
                        next_mid   = bot;
                        next_bot   = top;
                        next_y_in  = y_in + 9'd1;
                        next_state = RD_REQ;
                    end
                    else begin
                        next_state = WR_CALC;
                    end
                end
            end

            WR_CALC: begin
                addr         = wr_addr;
                dataW        = {pix[3], pix[2], pix[1], pix[0]};
                en           = 1'b1;
                we           = 1'b1;
                next_wr_addr = wr_addr + 16'd1;

                if (col != ROW_WORDS-1) begin
                    next_col = col + 7'd1;
                end
                else begin
                    next_col = '0;
                    next_top = mid;
                    next_mid = bot;
                    next_bot = top;
                    if (y_in != IMG_H-1) begin
                        next_y_in  = y_in + 9'd1;
                        next_state = RD_REQ;
                    end
                    else begin
                        next_bottom_done = 1'b1;
                        next_state       = WR_BORDER;
                    end
                end
            end

            DONE: begin
                finish = 1'b1;
                if(!start) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            rd_addr     <= '0;
            wr_addr     <= OUT_BASE;
            y_in        <= '0;
            col         <= '0;
            bottom_done <= 1'b0;
            top         <= 2'd0;
            mid         <= 2'd1;
            bot         <= 2'd2;
        end
        else begin
            state       <= next_state;
            rd_addr     <= next_rd_addr;
            wr_addr     <= next_wr_addr;
            y_in        <= next_y_in;
            col         <= next_col;
            bottom_done <= next_bottom_done;
            top         <= next_top;
            mid         <= next_mid;
            bot         <= next_bot;
        end
    end

    always_ff @(posedge clk) begin
        if (lb_we)
            lb[bot][col] <= dataR;
    end

endmodule
