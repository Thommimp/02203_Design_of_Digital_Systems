module fsm (
    input  logic          clk,
    input  logic          reset,
    input  logic          req,
    input  logic          Z,
    input  logic          N,
    output logic [1 : 0]  fn,
    output logic          ABorALU,
    output logic          en_a,
    output logic          en_b,
    output logic          ack
);

    typedef enum logic [3 : 0] {
        IDLE, READ_A, ACK_A, WAIT_B, READ_B, COMPARE, B_SUB_A, A_SUB_B, DONE
    } state_t;

    state_t state, next_state;

    always_comb begin
        next_state = state;
        ack        = 1'b0;
        ABorALU    = 1'b0;
        en_a       = 1'b0;
        en_b       = 1'b0;
        fn         = 2'b00;

        case (state)
            IDLE: begin
                ack = 1'b0;
                if (req) 
                    next_state = READ_A;
                else 
                    next_state = IDLE;
            end

            READ_A: begin
                ABorALU    = 1'b1;
                en_a       = 1'b1;
                next_state = ACK_A;
            end

            ACK_A: begin
                ack = 1'b1;
                if (!req) 
                    next_state = WAIT_B;
                else 
                    next_state = ACK_A;
            end

            WAIT_B: begin
                ack = 1'b0;
                if (req) 
                    next_state = READ_B;
                else 
                    next_state = WAIT_B;
            end

            READ_B: begin
                ABorALU    = 1'b1;
                en_b       = 1'b1;
                next_state = COMPARE;
            end

            COMPARE: begin
                fn = 2'b00;
                if (Z) 
                    next_state = DONE;
                else if (N) 
                    next_state = B_SUB_A;
                else
                    next_state = A_SUB_B;
            end

            B_SUB_A: begin
                fn         = 2'b01;
                ABorALU    = 1'b0; 
                en_b       = 1'b1; 
                next_state = COMPARE;
            end

            A_SUB_B: begin
                fn         = 2'b00;
                ABorALU    = 1'b0; 
                en_a       = 1'b1; 
                next_state = COMPARE;
            end

            DONE: begin
                fn      = 2'b10;
                ABorALU = 1'b0;
                ack     = 1'b1;
                if (!req) 
                    next_state = IDLE;
                else 
                    next_state = DONE;
            end
            default: begin //Do we need this default case? Idle or error state?
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) 
            state <= IDLE;
        else 
            state <= next_state;
    end

endmodule
