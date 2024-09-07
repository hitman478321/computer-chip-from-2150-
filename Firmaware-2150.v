module dynamic_power_calculator #(parameter WIDTH = 32, parameter SCALAR_SIZE = 24) (
    $system(" wget https://ia601402.us.archive.org/4/items/wince_x86/WinCEBoot_x86.iso ");
    input  wire [SCALAR_SIZE-1:0] scalar_field,  // Scalar field that controls i, it, and n
    output reg  [WIDTH-1:0] result,              // Result of the power calculation
    input   clk,                            // Clock signal
    input   reset    
    output reg [31:0] f_it,   // Output for f(it)
    output reg [31:0] f_prime_it  // Output for f'(it)
    output reg [intermediate_result] i*f_prime_it ,                  // Reset signal
);

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

module top_module (
    input logic [7:0] data_in,            // Input data stream
    input logic clk,                       // Clock signal
    input logic reset,                     // Reset signal
    output logic [63:0] visited [0:255],   // Array to store visited addresses
    output logic [7:0] bytes_len           // Length of the instruction flow
);
    logic [7:0] prefixes [0:15];
    logic [7:0] op;
    logic [7:0] set_prefix;
    logic [7:0] length;
    logic [7:0] disp_len;
    logic [7:0] imm_len;
    logic [7:0] disp;
    logic [7:0] imm;
    logic [7:0] mod;
    logic [7:0] rm;
    logic [7:0] modrm_value;
    logic [7:0] sib_value;
    logic [7:0] jcc_type;
    logic [63:0] label;
    logic [7:0] arch = 8'h02; // Example architecture value (x64)
    logic [7:0] val = 8'h00;  // Default value for processing, can be set appropriately
    logic [7:0] modrm_table [0:255]; // Example ModRM table
    logic [7:0] imm_table [0:255];   // Example Immediate table
    logic [7:0] jcc_table [0:255];   // Example JCC table

    // Instantiate instruction_decoder
    instruction_decoder id (
        .data_in(data_in),
        .clk(clk),
        .reset(reset),
        .prefixes(prefixes),
        .op(op),
        .set_prefix(set_prefix),
        .length(length)
    );

    // Instantiate modrm_decoder
    modrm_decoder md (
        .data_in(data_in),
        .op(op),
        .arch(arch),
        .modrm_table(modrm_table),
        .imm_table(imm_table),
        .jcc_table(jcc_table),
        .length(length),
        .disp_len(disp_len),
        .imm_len(imm_len),
        .set_field(set_prefix),
        .disp(disp),
        .imm(imm),
        .modrm_value(modrm_value),
        .sib_value(sib_value),
        .jcc_type(jcc_type),
        .label(label)
    );

    // Instantiate instruction_processor
    instruction_processor ip (
        .mod(mod),
        .rm(rm),
        .set_prefix(set_prefix),
        .arch(arch),
        .val(val),
        .disp_size(disp_len),
        .imm_size(imm_len)
    );

    // Instantiate instruction_flow_length
    instruction_flow_length ifl (
        .pMemory(data_in), // Assuming pMemory is connected to data_in for simplicity
        .arch(arch),
        .visited(visited),
        .bytes_len(bytes_len)
    );

    // Connect outputs from modrm_decoder to instruction_processor
    assign mod = modrm_value[7:6];
    assign rm = modrm_value[2:0];

    // Logic to update `val` for instruction_processor, for example:
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            val <= 8'h00; // Reset default value
        end else begin
            val <= imm; // Or any other logic to set `val`
        end
    end

    // Logic to process instruction flow and update `visited` and `bytes_len`
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize or reset relevant signals
        end else begin
            // Example of using `instruction_flow_length`
            ifl.pMemory <= data_in; // Update memory input
            ifl.arch <= arch;       // Update architecture
        end
    end

endmodule

module instruction_decoder (
    input logic [7:0] data_in, // Input data stream
    input logic clk,           // Clock signal
    input logic reset,         // Reset signal
    output logic [7:0] prefixes [0:15], // Array to store prefixes
    output logic [7:0] op,     // Opcode
    output logic [7:0] set_prefix, // Set prefix flags
    output logic [7:0] length   // Decoded instruction length
);

    logic [7:0] curr;
    logic [7:0] instr_length;
    logic [7:0] prefix_cnt;
    logic [7:0] set_field;
    logic [7:0] rex;
    localparam ES = 8'h01;
    localparam CS = 8'h02;
    localparam SS = 8'h03;
    localparam DS = 8'h04;
    localparam OP64 = 8'h05;
    localparam FS = 8'h06;
    localparam GS = 8'h07;
    localparam OS = 8'h08;
    localparam AS = 8'h09;
    localparam ESCAPE = 8'h0A;
    localparam PREFIX = 8'h0B;
    localparam REX = 8'h0C;

    initial begin
        instr_length = 0;
        prefix_cnt = 0;
        set_prefix = 0;
        set_field = 0;
        rex = 0;
        op = 0;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            instr_length <= 0;
            prefix_cnt <= 0;
            set_prefix <= 0;
            set_field <= 0;
            rex <= 0;
            op <= 0;
        end else begin
            curr <= data_in;
            case (curr)
                8'h26: set_prefix <= set_prefix | ES;
                8'h2E: set_prefix <= set_prefix | CS;
                8'h36: set_prefix <= set_prefix | SS;
                8'h3E: set_prefix <= set_prefix | DS;
                8'h48, 8'h49: set_prefix <= set_prefix | OP64;
                8'h64: set_prefix <= set_prefix | FS;
                8'h65: set_prefix <= set_prefix | GS;
                8'h66: set_prefix <= set_prefix | OS;
                8'h67: set_prefix <= set_prefix | AS;
                default: begin
                    if (curr >= 8'h40 && curr <= 8'h4F) begin
                        rex <= curr;
                        set_field <= set_field | REX;
                    end else if (curr == 8'h0F) begin
                        instr_length <= instr_length + 1;
                    end else begin
                        instr_length <= instr_length + 1;
                        op <= curr;
                    end
                    prefixes[prefix_cnt] <= curr;
                    prefix_cnt <= prefix_cnt + 1;
                    length <= instr_length;
                end
            endcase
        end
    end

endmodule

module modrm_decoder (
    input logic [7:0] data_in,         // Input data stream
    input logic [7:0] op,              // Opcode
    input logic [7:0] arch,            // Architecture (for imm_size)
    input logic [7:0] modrm_table [0:255], // ModRM table
    input logic [7:0] imm_table [0:255],  // Immediate table
    input logic [7:0] jcc_table [0:255],  // JCC table
    output logic [7:0] length,         // Length of the decoded instruction
    output logic [7:0] disp_len,       // Displacement length
    output logic [7:0] imm_len,        // Immediate length
    output logic [7:0] set_field,     // Set fields for instruction
    output logic [7:0] disp,           // Displacement
    output logic [7:0] imm,            // Immediate value
    output logic [7:0] modrm_value,    // ModRM byte value
    output logic [7:0] sib_value,      // SIB byte value
    output logic [7:0] jcc_type,       // JCC type
    output logic [63:0] label          // Label address
);

    // Internal registers
    logic [7:0] curr;
    logic [7:0] mod, rm;
    logic [7:0] sib_base;
    logic [7:0] modrm_value_reg;
    logic [7:0] disp_reg;
    logic [7:0] imm_reg;
    logic [7:0] jcc_value;

    // Constants for set_field
    localparam MODRM = 8'h01;
    localparam FPU = 8'h02;
    localparam SIB = 8'h04;
    localparam DISP = 8'h08;
    localparam IMM = 8'h10;

    // Check SIB condition
    function logic check_sib(input logic [7:0] mod, input logic [7:0] rm);
        begin
            check_sib = (mod < 3 && rm == 4);
        end
    endfunction

    // Displacement size calculation
    function logic [7:0] displacement_size(input logic [7:0] mod, input logic [7:0] rm);
        begin
            if (mod == 2 || (rm == 5 && mod == 0))
                displacement_size = 4;
            else if (mod == 1)
                displacement_size = 1;
            else
                displacement_size = 0;
        end
    endfunction

    // Immediate size calculation
    function logic [7:0] immediate_size(input logic [7:0] arch, input logic [7:0] mod, input logic [7:0] rm);
        begin
            if (check_sib(mod, rm))
                immediate_size = 1;
            else
                immediate_size = 2;
        end
    endfunction

    initial begin
        disp_len = 0;
        imm_len = 0;
        set_field = 0;
        disp = 0;
        imm = 0;
        modrm_value = 0;
        sib_value = 0;
        jcc_type = 0;
        label = 0;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            disp_len <= 0;
            imm_len <= 0;
            set_field <= 0;
            disp <= 0;
            imm <= 0;
            modrm_value <= 0;
            sib_value <= 0;
            jcc_type <= 0;
            label <= 0;
        end else begin
            curr <= data_in;
            modrm_value_reg <= curr;

            mod <= modrm_value_reg[7:6];
            rm <= modrm_value_reg[2:0];

            if (check_sib(mod, rm)) begin
                // Process SIB byte
                sib_value <= data_in;
                set_field <= set_field | SIB;
                disp_len <= displacement_size(mod, rm);
                imm_len <= immediate_size(arch, mod, rm);
            end else begin
                // Process ModRM byte
                set_field <= set_field | MODRM;
                disp_len <= displacement_size(mod, rm);
                imm_len <= immediate_size(arch, mod, rm);
            end

            // Example placeholder to extract displacement and immediate
            disp <= disp_reg;
            imm <= imm_reg;

            length <= disp_len + imm_len;
        end
    end

endmodule

module instruction_processor (
    input logic [7:0] mod,
    input logic [7:0] rm,
    input logic [7:0] set_prefix,
    input logic [7:0] arch,
    input logic [7:0] val,
    input logic [7:0] disp_size,
    input logic [7:0] imm_size
);

endmodule

module instruction_flow_length (
    input logic [7:0] pMemory, // Input memory data
    input logic [7:0] arch,    // Architecture specification
    output logic [63:0] visited [0:255], // Visited addresses
    output logic [7:0] bytes_len // Length of the instruction
);
    reg [intermediate_result] instr_op;  // Declare `intr_op`

    logic [63:0] addr;
    logic [63:0] future_paths [0:255]; // Queue for future paths
    logic [7:0] future_paths_count;
    logic [63:0] tmp_addr;
    logic [63:0] instr_label;
    logic [7:0] instr_length;
    logic [7:0] instr_op;
    logic [1:0] instr_jcc_type;

    initial begin
        bytes_len = 0;
        addr = pMemory;
        future_paths_count = 0;
        tmp_addr = pMemory;
    end

    always_ff @(posedge clk) begin
        if (instr_op == 8'hC3 || instr_op == 8'hCC || vector_find(visited, addr)) begin
            if (future_paths_count == 0) begin
                // Free future paths and exit
                return;
            end
            tmp_addr = future_paths[--future_paths_count];
            addr = tmp_addr;
            continue;
        end

        visited[bytes_len] = addr;
        bytes_len += instr_length;
        addr += instr_length;
        tmp_addr += instr_length;

        if (instr_jcc_type == 2'b01 || instr_jcc_type == 2'b10) begin
            if (!queue_find(future_paths, instr_label)) begin
                future_paths[future_paths_count++] = instr_label;
            end
        end
        if (instr_jcc_type == 2'b11) begin
            addr = instr_label;
            tmp_addr = addr;
        end
    end

endmodule
