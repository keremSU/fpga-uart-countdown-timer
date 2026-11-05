module serial_template (
    input sys_clk,
    input sys_rst_n,
    output [5:0] bled,
    input [3:0] sw,
    input [3:0] btn,
    output [7:0] led,
    output reg [7:0] seven,
    output reg [3:0] segment,
    input uart_rx
);

parameter CLK_FRE  = 27;
parameter UART_FRE = 115200;

// 27 MHz clock, so 1 Hz tick fires every 27_000_000 cycles
localparam TICK_MAX = CLK_FRE * 1000000 - 1;

wire rx_data_valid;
wire rx_data_ready;
wire [7:0] rx_data_w;

assign rx_data_ready = 1'b1;
assign bled = 6'b111111;
assign led  = rx_data_w;   // show last received byte on LEDs (debug)

uart_rx #(
    .CLK_FRE(CLK_FRE),
    .BAUD_RATE(UART_FRE)
) uart_rx_inst (
    .clk           (sys_clk),
    .rst_n         (sys_rst_n),
    .rx_data       (rx_data_w),
    .rx_data_valid (rx_data_valid),
    .rx_data_ready (rx_data_ready),
    .rx_pin        (uart_rx)
);

// BCD digit registers for MM:SS display
reg [3:0] min_tens, min_ones, sec_tens, sec_ones;
reg running;

// 1 Hz tick
reg [24:0] tick_cnt;
reg tick;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        tick_cnt <= 0;
        tick     <= 0;
    end else if (tick_cnt == TICK_MAX) begin
        tick_cnt <= 0;
        tick     <= 1;
    end else begin
        tick_cnt <= tick_cnt + 1;
        tick     <= 0;
    end
end

// btn[0] = BUTTON0, active-low (PULL_MODE=UP in .cst)
// Two-stage synchronizer + edge detector
reg btn_s0, btn_s1, btn_s2;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        btn_s0 <= 1; btn_s1 <= 1; btn_s2 <= 1;
    end else begin
        btn_s0 <= btn[0];
        btn_s1 <= btn_s0;
        btn_s2 <= btn_s1;
    end
end

// falling edge = button pressed
wire btn0_press = btn_s2 && !btn_s1;

wire time_zero  = (min_tens == 0 && min_ones == 0 && sec_tens == 0 && sec_ones == 0);
wire secs_ok    = (sec_tens <= 5);
wire can_start  = !time_zero && secs_ok;

// Main state machine
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        min_tens <= 0; min_ones <= 0;
        sec_tens <= 0; sec_ones <= 0;
        running  <= 0;
    end else begin

        // Start button
        if (btn0_press && !running && can_start)
            running <= 1;

        // UART input - when not running
        if (!running && rx_data_valid) begin
            if (rx_data_w >= 8'h30 && rx_data_w <= 8'h39) begin
                min_tens <= min_ones;
                min_ones <= sec_tens;
                sec_tens <= sec_ones;
                sec_ones <= rx_data_w - 8'h30;
            end
        end

        // Countdown
        if (running && tick) begin
            if (time_zero) begin
                running <= 0;
            end else if (sec_ones > 0) begin
                sec_ones <= sec_ones - 1;
            end else begin
                sec_ones <= 9;
                if (sec_tens > 0) begin
                    sec_tens <= sec_tens - 1;
                end else begin
                    sec_tens <= 5;
                    if (min_ones > 0) begin
                        min_ones <= min_ones - 1;
                    end else begin
                        min_ones <= 9;
                        if (min_tens > 0)
                            min_tens <= min_tens - 1;
                        else begin
                            min_tens <= 0;
                            running  <= 0;
                        end
                    end
                end
            end
        end

    end
end

// Display mux - same as original template
reg [15:0] dispCounter;
reg [1:0]  segCounter;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        dispCounter <= 0;
        segCounter  <= 0;
    end else begin
        dispCounter <= dispCounter + 1;
        if (dispCounter == 0)
            segCounter <= segCounter + 1;
    end
end

// BCD to 7-segment (same code as original template's hex2seven table)
function [6:0] bcd2seg;
    input [3:0] d;
    begin
        case (d)
            4'd0: bcd2seg = 7'b0111111;
            4'd1: bcd2seg = 7'b0000110;
            4'd2: bcd2seg = 7'b1011011;
            4'd3: bcd2seg = 7'b1001111;
            4'd4: bcd2seg = 7'b1100110;
            4'd5: bcd2seg = 7'b1101101;
            4'd6: bcd2seg = 7'b1111101;
            4'd7: bcd2seg = 7'b0000111;
            4'd8: bcd2seg = 7'b1111111;
            4'd9: bcd2seg = 7'b1101111;
            default: bcd2seg = 7'b0000000;
        endcase
    end
endfunction

// Digit 2 (min_ones) gets dot bit set as a colon separator
always @(*) begin
    case (segCounter)
        2'b00: begin seven = {1'b0, bcd2seg(sec_ones)}; segment = 4'b0001; end
        2'b01: begin seven = {1'b0, bcd2seg(sec_tens)}; segment = 4'b0010; end
        2'b10: begin seven = {1'b1, bcd2seg(min_ones)}; segment = 4'b0100; end
        2'b11: begin seven = {1'b0, bcd2seg(min_tens)}; segment = 4'b1000; end
        default: begin seven = 8'b0; segment = 4'b0001; end
    endcase
end

endmodule