// Self-checking testbench: boots the SoC, decodes the UART line and checks the
// boot ROM message arrives intact (twice, to prove the restart loop works).
//
//   iverilog -g2012 -o sim.vvp tb/tb_riscv_uart_soc.v src/*.v && vvp sim.vvp
`timescale 1ns / 1ps
`default_nettype none

module tb_riscv_uart_soc;

    // Scaled-down clock/baud ratio keeps the simulation fast (10 clocks per bit).
    localparam integer CLK_FREQ_HZ  = 1_152_000;
    localparam integer BAUD_RATE    = 115_200;
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer CLK_PERIOD   = 25;            // ns (time base only)

    localparam [8*30-1:0] EXPECTED = "Hello from RISC-V on SKY130!\015\n"; // \015 = CR
    localparam integer    MSG_LEN  = 30;
    localparam integer    REPEATS  = 2;

    reg  clk    = 1'b0;
    reg  resetn = 1'b0;
    wire tx_out;
    wire tx_done;

    always #(CLK_PERIOD / 2) clk = ~clk;

    riscv_uart_soc #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE)
    ) dut (
        .clk     (clk),
        .resetn  (resetn),
        .tx_out  (tx_out),
        .tx_done (tx_done)
    );

    // ---------------- UART receiver model ----------------
    task automatic uart_rx(output [7:0] b);
        integer i;
        begin
            @(negedge tx_out);                                  // start bit edge
            repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge clk); // middle of bit 0
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = tx_out;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            if (tx_out !== 1'b1) begin
                $display("FAIL: framing error (stop bit low)");
                $fatal(1);
            end
        end
    endtask

    integer n, errors;
    reg [7:0] got, want;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_riscv_uart_soc.vcd");
            $dumpvars(0, tb_riscv_uart_soc);
        end

        errors = 0;
        repeat (5) @(posedge clk);
        resetn = 1'b1;

        $write("UART: ");
        for (n = 0; n < MSG_LEN * REPEATS; n = n + 1) begin
            uart_rx(got);
            want = EXPECTED[8 * (MSG_LEN - 1 - (n % MSG_LEN)) +: 8];
            if (got >= 8'h20) $write("%c", got); else $write("<%02h>", got);
            if (got !== want) begin
                $display("\nFAIL: byte %0d = 0x%02h, expected 0x%02h", n, got, want);
                errors = errors + 1;
            end
        end
        $display("");

        if (errors == 0) $display("PASS: received %0d bytes correctly", MSG_LEN * REPEATS);
        else begin
            $display("FAIL: %0d byte errors", errors);
            $fatal(1);
        end
        $finish;
    end

    // Watchdog: a byte takes ~10 bit times plus CPU overhead.
    initial begin
        #(CLK_PERIOD * CLKS_PER_BIT * 20 * MSG_LEN * (REPEATS + 1));
        $display("FAIL: timeout - SoC stopped transmitting");
        $fatal(1);
    end

endmodule

`default_nettype wire
