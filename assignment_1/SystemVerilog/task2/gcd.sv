// -----------------------------------------------------------------------------
//
//  Title      :  System Verilog FSMD implementation template for GCD
//             :
//  Developers :  Otto Westy Rasmussen
//             :
//  Purpose    :  This is a template for the FSMD (finite state machine with datapath) 
//             :  implementation of the GCD circuit
//             :
//  Revision   :  02203 fall 2025 v.1.0
//
// -----------------------------------------------------------------------------

module gcd (
    input  logic          clk,    // The clock signal.
    input  logic          reset,  // Reset the module.
    input  logic          req,    // Start computation.
    input  logic [15 : 0] AB,     // The two operands. One at a time.
    output logic          ack,    // Input received / Computation is complete.
    output logic [15 : 0] C       // The result.
);
    typedef enum logic [3 : 0] {
        IDLE, READ_A, ACK_A, WAIT_B, READ_B, COMPARE, B_SUB_A, A_SUB_B, DONE
    } state_t;

    shortint unsigned reg_a, next_reg_a, reg_b, next_reg_b;
    
    state_t state, next_state;
    
    // Combinatorial logic
    always_comb begin
        next_state = state;
        next_reg_a = reg_a;
        next_reg_b = reg_b;
        ack = 1'b0;
        C = 'z;
        case (state)
            IDLE: begin
                ack =0;
                if (req)
                    next_state = READ_A;
                else
                    next_state = IDLE;
            end

            READ_A: begin
                next_reg_a = AB;
                next_state = ACK_A;
            end

            ACK_A: begin
                ack = 1'b1;
                if(!req)
                    next_state = WAIT_B;
                else
                    next_state = ACK_A;
            end

            WAIT_B: begin
                ack = 1'b0;
                if(req)
                    next_state = READ_B;
                else
                    next_state = WAIT_B;
            end

            READ_B: begin
                next_reg_b = AB;
                next_state = COMPARE;
            end

            COMPARE: begin
                if(reg_a != reg_b)
                    if(reg_a < reg_b)
                        next_state = B_SUB_A;
                    else
                        next_state = A_SUB_B;
                else
                    next_state = DONE;
            end

            B_SUB_A: begin
                next_reg_b = reg_b - reg_a;
                next_state = COMPARE;
            end

            A_SUB_B: begin
                next_reg_a = reg_a - reg_b;
                next_state = COMPARE;
            end

            DONE: begin
                C = reg_a;
                ack = 1'b1;
                if(!req)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
        endcase
    end

        // Register
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            reg_a <= '0;
            reg_b <= '0;
        end
        else begin
            state <= next_state;
            reg_a <= next_reg_a;
            reg_b <= next_reg_b;
        end
    end

endmodule