// -----------------------------------------------------------------------------
//
//  Title      :  Edge-Detection design project - task 2.
//             :
//  Developers :  YOUR NAME HERE - s263523@student.dtu.dk
//             :  
//             :
//  Purpose    :  This design contains an entity for the inversion accelerator 
//             :  that must be build in task zero of the Edge Detection design project. 
//             :  
//             :
//  Revision   :  1.0   01-11-26     Final version
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

  // ---------------------------------------------------
  // Insert your design here
  // ---------------------------------------------------
    localparam logic [15:0] START_ADDR = 16'd0;
    localparam logic [15:0] END_ADDR = 16'd25343;  // (352*288)/4 - 1
    localparam logic [15:0] WRITE_MEMORY_SHIFT = 16'd25344;  // (352*288)/4;
    
    typedef enum logic [3 : 0] {
        IDLE, REQ, READ_INV, WRITE, FIN
    } state_t;
    
    logic [31:0] reg_data, next_reg_data;
    logic [15:0] reg_addr, next_reg_addr;
    
    state_t state, next_state;
    
    assign addr = reg_addr;
    assign dataW = reg_data;
    
    // Combinatorial logic
    always_comb begin
        next_state      = state;
        next_reg_addr   = reg_addr;
        next_reg_data   = reg_data;
        
        case (state)
            IDLE: begin
                next_reg_addr   = START_ADDR;
                en              = 1'b0;
                we              = 1'b0;
                finish          = 1'b0;
                next_reg_data   = 32'b0;
                if (start) begin
                    next_state  = REQ;
                end
                else
                    next_state  = IDLE;
            end
            
            REQ: begin
                en              = 1'b1;
                we              = 1'b0;
                next_state      = READ_INV;
            end
            
           READ_INV: begin
                next_reg_data   = dataR;
                next_reg_addr   = next_reg_addr + WRITE_MEMORY_SHIFT;
                next_reg_data   = ~next_reg_data;
                next_state      = WRITE;
           end
           
           WRITE: begin
                we              = 1'b1;
                next_reg_addr   = reg_addr - WRITE_MEMORY_SHIFT + 1;
                if (next_reg_addr > END_ADDR) begin
                    next_state = FIN;
                end
                else
                    next_state = REQ;
           end
           
           FIN: begin
                en              = 1'b0;
                we              = 1'b0;
                finish          = 1'b1;
                next_state      = IDLE;
           end
           
           default: begin
                next_state = IDLE;
           end
        endcase
    end

    // Register
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end
        else begin
            state    <= next_state;
            reg_addr <= next_reg_addr;
            reg_data <= next_reg_data;
        end
    end

endmodule
