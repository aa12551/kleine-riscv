module alu (
    input clk,

    input [31:0] input_a,
    input [31:0] input_b,

    input [2:0] function_select,
    input function_modifier,
    // for RV32M
    input function_select_I_M,
    // 1st cycle output
    output [31:0] add_result,
    // 2nd cycle output
    output reg [31:0] result
);

localparam ALU_ADD_SUB = 3'b000;
localparam ALU_SLL     = 3'b001;
localparam ALU_SLT     = 3'b010;
localparam ALU_SLTU    = 3'b011;
localparam ALU_XOR     = 3'b100;
localparam ALU_SRL_SRA = 3'b101;
localparam ALU_OR      = 3'b110;
localparam ALU_AND_CLR = 3'b111;

// for rv32m
localparam ALU_MUL = 3'b000;
localparam ALU_MULH = 3'b001;
localparam ALU_MULHSU = 3'b010;
localparam ALU_MULHU = 3'b011;
localparam ALU_DIV = 3'b100;
localparam ALU_DIVU = 3'b101;
localparam ALU_REM = 3'b110;
localparam ALU_REMU = 3'b111;

/* verilator lint_off UNUSED */ // The first bit [32] will intentionally be ignored
wire [32:0] tmp_shifted = $signed({function_modifier ? input_a[31] : 1'b0, input_a}) >>> input_b[4:0];
/* verilator lint_on UNUSED */

assign add_result = result_add_sub;

reg [31:0] result_add_sub;
reg [31:0] result_sll;
reg [31:0] result_slt;
reg [31:0] result_xor;
reg [31:0] result_srl_sra;
reg [31:0] result_or;
reg [31:0] result_and_clr;
reg [2:0] old_function;

// for rv32m - Set the register to save the result of the operation.
reg [63:0] result_mul;
/* verilator lint_off UNUSEDSIGNAL */ // I need 32 bit, but operator `*` must to malloc 64 bit register.
reg [63:0] result_mulhsu;
reg [63:0] result_mulhu;
/* verilator lint_on UNUSEDSIGNAL */
reg [31:0] result_div;
reg [31:0] result_divu;
reg [31:0] result_rem;
reg [31:0] result_remu;

// for rv32m - temp register
reg [63:0] unsigned_input_a;
reg [63:0] unsigned_input_b;
reg [63:0] signed_input_a;
reg [63:0] signed_input_b;

// for rv32m - extend 32 bit to 64 bit
assign unsigned_input_a = {32'b0,input_a};
assign unsigned_input_b = {32'b0,input_b};
assign signed_input_a = {{32{input_a[31]}}, {input_a}};
assign signed_input_b = {{32{input_b[31]}}, {input_b}};

always @(posedge clk) begin
    old_function <= function_select;
    result_add_sub <= input_a + (function_modifier ? -input_b : input_b);
    result_sll <= input_a << input_b[4:0];
    result_slt <= {
        {31{1'b0}},
        (
            $signed({function_select[0] ? 1'b0 : input_a[31], input_a})
            < $signed({function_select[0] ? 1'b0 : input_b[31], input_b})
        )
    }; 
    result_xor <= input_a ^ input_b;
    result_srl_sra <= tmp_shifted[31:0];
    result_or <= input_a | input_b;
    result_and_clr <= (function_modifier ? ~input_a : input_a) & input_b;
end

always @(posedge clk) begin
    result_mul <= signed_input_a * signed_input_b;
    result_mulhu <= unsigned_input_a * unsigned_input_b;
    result_mulhsu <= signed_input_a * unsigned_input_b;
    if(input_b == 32'h00000000) begin
    	result_divu <= -1;
    	result_remu <= input_a;
    end else begin
        result_divu <= input_a / input_b;
        result_remu <= input_a % input_b;
    end
    
end

// rv32m for signed operation of div and rem
always @(*) begin
    if(input_a[31] == 0) begin
        if(input_b[31] == 0) begin
            result_div = input_a / input_b;
            result_rem = input_a % input_b;
        end else begin
            result_div = -(input_a / (-input_b));
            result_rem = input_a % (-input_b);
        end
    end else begin
    	if(input_b[31] == 0) begin
    	    result_div = -(-input_a / input_b);
    	    result_rem = -(input_a % input_b);
    	end else begin
    	    result_div = (-input_a)/(-input_b);
    	    result_rem = -(input_a % (-input_b));
    	end
    end
    if(input_b == 32'h00000000) begin
    	result_div = -1;
    	result_rem = input_a;
    end
end

always @(*) begin
    if(!function_select_I_M) begin
        case (old_function)
            ALU_ADD_SUB: result = result_add_sub;
            ALU_SLL:     result = result_sll;
            ALU_SLT,
            ALU_SLTU:    result = result_slt; 
            ALU_XOR:     result = result_xor;
            ALU_SRL_SRA: result = result_srl_sra;
            ALU_OR:      result = result_or;
            ALU_AND_CLR: result = result_and_clr;
        endcase
    end else begin
    	case(old_function)
            ALU_MUL:     result = result_mul [31:0];
            ALU_MULH:    result = result_mul [63:32];
            ALU_MULHSU:  result = result_mulhsu [63:32];
            ALU_MULHU:   result = result_mulhu [63:32]; 
            ALU_DIV:     result = result_div;
            ALU_DIVU:    result = result_divu;
            ALU_REM:     result = result_rem;
            ALU_REMU:    result = result_remu;
    	endcase
    end  	
end

endmodule
