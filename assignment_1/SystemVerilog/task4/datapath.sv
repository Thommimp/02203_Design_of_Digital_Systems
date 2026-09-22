module datapath (
    input  logic          clk,
    input  logic [15 : 0] AB,  
    input  logic          ABorALU,
    input  logic [1 : 0]  fn,
    input  logic          en_a, 
    input  logic          en_b,
    output logic [15 : 0] C, 
    output logic         Z,
    output logic         N 
);

    logic [15:0] C_int, regA_out, regB_out, Y;

    c_mux u_mux(
        .data_in1(AB),
        .data_in2(Y),
        .s(ABorALU),
        .data_out(C_int)
    );

    c_reg u_regA(
        .clk(clk),
        .en(en_a),
        .data_in(C_int),
        .data_out(regA_out)
    );

    c_reg u_regB(
        .clk(clk),
        .en(en_b),
        .data_in(C_int),
        .data_out(regB_out)
    );

    c_alu u_alu(
        .A(regA_out),
        .B(regB_out),
        .fn(fn),
        .C(Y),
        .Z(Z),
        .N(N)
    );

    c_buf u_buf(
        .data_in(C_int),
        .data_out(C)
    );

endmodule