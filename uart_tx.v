module uart_tx #(
    parameter CLKS_PER_BIT = 87 // Set based on clock frequency / baud rate
)(
    input wire clk,
    input wire rst,
    input wire tx_start,
    input wire [7:0] tx_data,
    output reg tx_out,
    output reg tx_done
);

    // State machine states
    localparam IDLE       = 3'b000;
    localparam TX_START   = 3'b001;
    localparam TX_DATA    = 3'b010;
    localparam TX_STOP    = 3'b011;
    localparam CLEANUP    = 3'b100;

    reg [2:0] state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] tx_data_reg = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_out <= 1'b1;
            tx_done <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out <= 1'b1;
                    tx_done <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_start) begin
                        tx_data_reg <= tx_data;
                        state <= TX_START;
                    end
                end

                TX_START: begin
                    tx_out <= 1'b0; // Send Start Bit (Low)
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= TX_DATA;
                    end
                end

                TX_DATA: begin
                    tx_out <= tx_data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= TX_STOP;
                        end
                    end
                end

                TX_STOP: begin
                    tx_out <= 1'b1; // Send Stop Bit (High)
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        tx_done <= 1'b1;
                        state <= CLEANUP;
                    end
                end

                CLEANUP: begin
                    tx_done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
