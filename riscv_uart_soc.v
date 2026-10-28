module riscv_uart_soc (
    input wire clk,
    input wire resetn,
    output wire tx_out,
    output wire tx_done
);

    // PicoRV32 memory bus signals
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire [31:0] mem_rdata;

    // UART Control Registers mapped in memory
    reg       uart_start;
    reg [7:0] uart_data_reg;

    // Address decoding for UART peripheral (base address 0x02000000)
    wire uart_select = (mem_addr == 32'h02000000);
    assign mem_ready = mem_valid; // Simple zero-wait state memory interface

    always @(posedge clk) begin
        if (!resetn) begin
            uart_start <= 1'b0;
            uart_data_reg <= 8'h00;
        end else begin
            uart_start <= 1'b0; 
            if (mem_valid && mem_ready && mem_wstrb[0] && uart_select) begin
                uart_data_reg <= mem_wdata[7:0];
                uart_start <= 1'b1; 
            end
        end
    end

    // Assign read data back to CPU
    assign mem_rdata = uart_select ? {24'd0, uart_data_reg} : 32'h00000000;

    // Instantiate PicoRV32 RISC-V Core (omitting unused optional ports for clean linting)
    picorv32 #(
        .BARREL_SHIFTER(0),
        .ENABLE_FAST_MUL(0),
        .COMPRESSED_ISA(0)
    ) cpu (
        .clk        (clk        ),
        .resetn     (resetn     ),
        .mem_valid  (mem_valid  ),
        .mem_instr  (mem_instr  ),
        .mem_ready  (mem_ready  ),
        .mem_addr   (mem_addr   ),
        .mem_wdata  (mem_wdata  ),
        .mem_wstrb  (mem_wstrb  ),
        .mem_rdata  (mem_rdata  ),
        .irq        (32'd0      )
    );

    // Instantiate Custom UART Transmitter
    uart_tx #(
        .CLKS_PER_BIT(87)
    ) my_uart (
        .clk      (clk           ),
        .rst      (!resetn       ),
        .tx_start (uart_start    ),
        .tx_data  (uart_data_reg ),
        .tx_out   (tx_out        ),
        .tx_done  (tx_done       )
    );

endmodule
