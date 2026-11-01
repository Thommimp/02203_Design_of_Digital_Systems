// -----------------------------------------------------------------------------
//
//  Title      :  Edge-Detection design project - task 2.
//             :
//  Developers :  YOUR NAME HERE - s??????@student.dtu.dk
//             :  YOUR NAME HERE - s??????@student.dtu.dk
//             :
//  Purpose    :  This design contains an entity for the accelerator that must be build
//             :  in task two of the Edge Detection design project. It contains an
//             :  architecture skeleton for the entity as well.
//             :
//  Revision   :  1.0   ??-??-??     Final version
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
logic [31:0] row_reg [0:87];    // register for one row
logic [7:0] word_idx;          // word index within the current row, 0..87
logic [8:0] row;               // row number, 0..287
typedef enum logic [2:0] {
  IDLE,
  READ_ISSUE,
  INVERT,
  WRITE_ISSUE,
  READ_CAPTURE,
  DONE
} state_t;
state_t state;
always_ff @(posedge clk) begin
  if (reset) begin
    state       <= IDLE;
    addr        <= '0;
    dataW       <= '0;
    en <= 1'b0;
    we          <= 1'b0;
    finish      <= 1'b0;
    word_idx    <= '0;
    row         <= '0;
  end else begin
    case (state)
      IDLE: begin
        en <= 1'b0;
        we          <= 1'b0;
        finish      <= 1'b0;
        word_idx    <= '0;
        row         <= '0;
        if (start) begin
          addr        <= 16'd0;
          en <= 1'b1;
          state       <= READ_ISSUE;
        end
      end
      // Memory captures memory[addr] on this edge.
      // dataR still holds the previous value, so do not sample it here.
      READ_ISSUE: begin
        state <= READ_CAPTURE;
      end
      READ_CAPTURE: begin
        row_reg[word_idx] <= dataR;
        if (word_idx == 8'd87) begin
          en <= 1'b0;
          word_idx    <= 8'd0;
          state       <= INVERT;
        end else begin
          addr     <= addr + 16'd1;
          word_idx <= word_idx + 8'd1;
          state    <= READ_CAPTURE;
        end
      end
      INVERT: begin
        row_reg[word_idx] <= ~row_reg[word_idx];
        if (word_idx == 8'd87) begin
          // Present the first inverted word of this row. The output
          // image starts at address 25344, with 88 words per row.
          addr        <= 16'd25344 + row * 16'd88;
          dataW       <= row_reg[0];
          word_idx    <= 8'd0;
          en <= 1'b1;
          we          <= 1'b1;
          state       <= WRITE_ISSUE;
        end else begin
          word_idx <= word_idx + 8'd1;
          state    <= INVERT;
        end
      end
      WRITE_ISSUE: begin
        if (word_idx == 8'd87) begin
          if (row == 9'd287) begin
            en <= 1'b0;
            we          <= 1'b0;
            state       <= DONE;
          end else begin
            row         <= row + 9'd1;
            word_idx    <= 8'd0;
            addr        <= (row + 9'd1) * 16'd88;
            en <= 1'b1;
            we          <= 1'b0;
            state       <= READ_ISSUE;
          end
        end else begin
          word_idx <= word_idx + 8'd1;
          dataW    <= row_reg[word_idx + 8'd1];
          addr     <= addr + 16'd1;
        end
      end
      DONE: begin
        we <= 1'b0;
        en <= 1'b0;
        finish <= 1'b1;
      end
      default: state <= IDLE;
    endcase
  end
end

endmodule
