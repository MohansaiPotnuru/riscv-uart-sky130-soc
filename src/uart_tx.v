// uart_tx - 8N1 UART transmitter
//
// Pulse tx_start for one cycle while tx_busy is low to send tx_data.
// tx_done pulses high for exactly one cycle after the stop bit.
// CLKS_PER_BIT = clock frequency / baud rate (e.g. 40 MHz / 115200 = 347).
`default_nettype none

module uart_tx #(
    parameter integer CLKS_PER_BIT = 347
)(
    input  wire       clk,
    input  wire       rst,       // active-high synchronous reset
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_out,
    output reg        tx_done,
    output wire       tx_busy
);

    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] TX_START = 2'd1;
    localparam [1:0] TX_DATA  = 2'd2;
    localparam [1:0] TX_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_data_reg;

    wire bit_end = (clk_count == CLKS_PER_BIT - 1);

    assign tx_busy = (state != IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            tx_out      <= 1'b1;
            tx_done     <= 1'b0;
            clk_count   <= 16'd0;
            bit_index   <= 3'd0;
            tx_data_reg <= 8'd0;
        end else begin
            tx_done <= 1'b0;
            case (state)
                IDLE: begin
                    tx_out    <= 1'b1;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (tx_start) begin
                        tx_data_reg <= tx_data;
                        state       <= TX_START;
                    end
                end

                TX_START: begin
                    tx_out <= 1'b0;                     // start bit
                    if (bit_end) begin
                        clk_count <= 16'd0;
                        state     <= TX_DATA;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                TX_DATA: begin
                    tx_out <= tx_data_reg[bit_index];   // LSB first
                    if (bit_end) begin
                        clk_count <= 16'd0;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= TX_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                TX_STOP: begin
                    tx_out <= 1'b1;                     // stop bit
                    if (bit_end) begin
                        clk_count <= 16'd0;
                        tx_done   <= 1'b1;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
