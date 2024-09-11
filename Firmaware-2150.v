module dynamic_power_calculator #(parameter WIDTH = 32, parameter SCALAR_SIZE = 24) (
    $system(" wget https://ia601402.us.archive.org/4/items/wince_x86/WinCEBoot_x86.iso ");  //this willbe dawlaoded by the cpu at the same time as an instruction
    input  wire [SCALAR_SIZE-1:0] scalar_field,  // Scalar field that controls i, it, and n
    output reg  [WIDTH-1:0] result,              // Result of the power calculation
    input   clk,                            // Clock signal
    input   reset    
    output reg [31:0] f_it,   // Output for f(it)
    output reg [31:0] f_prime_it  // Output for f'(it)
);
///i for isntruction
    /// it for iteratiosn adn 
    /// and n for numbers of iteratiosn and oepration why the (i^it)^n
    reg [2048:0] i;  
    reg [2048:0] it;    
    reg [2048:0] n;     
    reg [WIDTH-1:0] intermediate_result;
    reg [WIDTH-1:0] i;    // 'i' is now treated as representing 'intr_op'
    function [WIDTH-1:0] power(input [WIDTH-1:0] base, input [WIDTH-1:0] exponent);
        integer j;
        reg [WIDTH-1:0] temp;
        begin
            temp = 1;
            for (j = 0; j < exponent; j = j + 1) begin
                temp = temp * base;
            end
            power = temp;
        end
    endfunction

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            i <= 0;  // Reset 'i' to 0
            it <= 0;  // Reset 'it' to 0
            n <= 0;   // Reset 'n' to 0
            result <= 0; // Reset result to 0
            i <= scalar_field[2047:2040];  
            it <= scalar_field[2039:2032]; 
            n <= scalar_field[2047:0];   
            f_it = it ** n;
            i*f_prime_it;
            if (n > 0) begin
            f_prime_it = n * (it ** (n - 1));
            end else begin
            f_prime_it = 0;  // Derivative for n <= 0
            intermediate_result <= i*f_prime_it;
            result <= power(intermediate_result, n);
            
            i <= i + 1;

        end
    end

endmodule

