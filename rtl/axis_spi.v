/*

Copyright (c) 2026 Ethan Coyle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

module axis_spi #(
    parameter c_DATA_WIDTH = 8
) (
    input wire i_rst,

    input wire i_clk,

    /*
     * AXI-stream input
     */
    input wire [c_DATA_WIDTH - 1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,

    /*
     * AXI-stream output
     */
    output wire [c_DATA_WIDTH - 1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    output wire m_axis_tready,

    /*
     * SPI pins
     */
    output wire o_spi_dclk,
    output wire o_spi_copi,
    input wire i_spi_cipo,
    output wire o_spi_en,

    /*
     * SPI configuration
     */
    input wire i_clk_polarity,
    input wire i_clk_phase,

    /*
     * Timing configuration
     */
    input wire [15:0] i_prescale,
    input wire [15:0] i_en_setup_time,
    input wire [15:0] i_en_hold_time,
    input wire [15:0] i_en_high_time
);

localparam c_COUNT_WIDTH = $clog2(c_DATA_WIDTH) + 1'b1;

reg [c_DATA_WIDTH - 1:0] s_axis_tdata_reg = {c_DATA_WIDTH{1'b0}};
reg s_axis_tready_reg = 1'b1;

assign s_axis_tready = s_axis_tready_reg;

reg [c_DATA_WIDTH - 1:0] m_axis_tdata_reg = {c_DATA_WIDTH{1'b0}};
reg m_axis_tvalid_reg = 1'b0;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;

reg r_spi_dclk = 1'b0;
reg r_spi_copi = 1'b0;
reg r_spi_en = 1'b1;

assign o_spi_dclk = r_spi_dclk;
assign o_spi_copi = r_spi_copi;
assign o_spi_en = r_spi_en;

reg r_clk_polarity = 1'b0;
reg r_clk_phase = 1'b0;

reg [15:0] r_prescale_hold = 16'b0;
reg [16:0] r_prescale = 17'b0;

reg [15:0] r_en_setup_time = 16'b0;
reg [15:0] r_en_hold_time = 16'b0;
reg [15:0] r_en_high_time = 16'b0;

reg [c_COUNT_WIDTH - 1:0] r_shift_count = {c_COUNT_WIDTH{1'b0}};
reg [c_COUNT_WIDTH - 1:0] r_sample_count = {c_COUNT_WIDTH{1'b0}};

reg [16:0] r_shift_edge_count = 17'b0;
reg [16:0] r_sample_edge_count = 17'b0;

wire w_spi_dclk_shift_edge;
wire w_spi_dclk_sample_edge;

assign w_spi_dclk_shift_edge = r_prescale == (r_shift_edge_count - 1'b1) ? 1'b1 : 1'b0;
assign w_spi_dclk_sample_edge = r_prescale == (r_sample_edge_count - 1'b1) ? 1'b1 : 1'b0;

localparam s_SPI_IDLE = 3'd0;
localparam s_SPI_START = 3'd1;
localparam s_SPI_EN_SETUP = 3'd2;
localparam s_SPI_ACTIVE = 3'd3;
localparam s_SPI_EN_HOLD = 3'd4;
localparam s_SPI_WAIT = 3'd5;

reg [2:0] r_state = s_SPI_IDLE;

always @(posedge i_clk) begin
    case (r_state)
        s_SPI_IDLE: begin
            if (s_axis_tvalid & s_axis_tready) begin
                s_axis_tdata_reg <= s_axis_tdata;
                s_axis_tready_reg <= 1'b0;
                r_clk_polarity <= i_clk_polarity;
                r_spi_dclk <= i_clk_polarity;
                r_clk_phase <= i_clk_phase;
                r_prescale_hold <= i_prescale;
                r_prescale <= 17'b0;
                r_en_setup_time <= i_en_setup_time;
                r_en_hold_time <= i_en_hold_time;
                r_en_high_time <= i_en_high_time;
                r_shift_count <= c_DATA_WIDTH - 1'b1;
                r_sample_count <= c_DATA_WIDTH;
                r_state <= s_SPI_START;
            end
        end

        s_SPI_START: begin
            r_spi_en <= 1'b0;
            r_state <= s_SPI_EN_SETUP;
            case ({r_clk_polarity, r_clk_phase})
                2'b00: begin
                    r_shift_count <= r_shift_count - 1'b1;
                    r_spi_copi <= s_axis_tdata_reg[r_shift_count];
                    r_sample_edge_count <= r_prescale_hold;
                    r_shift_edge_count <= r_prescale_hold << 1'b1;
                end

                2'b01: begin
                    r_sample_edge_count <= r_prescale_hold << 1'b1;
                    r_shift_edge_count <= r_prescale_hold;
                end

                2'b10: begin
                    r_shift_count <= r_shift_count - 1'b1;
                    r_spi_copi <= s_axis_tdata_reg[r_shift_count];
                    r_sample_edge_count <= r_prescale_hold;
                    r_shift_edge_count <= r_prescale_hold << 1'b1;
                end

                2'b11: begin
                    r_sample_edge_count <= r_prescale_hold << 1'b1;
                    r_shift_edge_count <= r_prescale_hold;
                end
            endcase

            if (r_en_setup_time == 16'b0) begin
                r_prescale <= r_prescale_hold - 1'b1;
                r_state <= s_SPI_ACTIVE;
            end
        end

        s_SPI_EN_SETUP: begin
            r_en_setup_time <= r_en_setup_time - 1'b1;
            if (r_en_setup_time == 16'd1) begin
                r_prescale <= r_prescale_hold - 1'b1;
                r_state <= s_SPI_ACTIVE;
            end
        end

        s_SPI_ACTIVE: begin
            r_prescale <= r_prescale + 1'b1;
            if (w_spi_dclk_sample_edge) begin
                m_axis_tdata_reg <= (m_axis_tdata_reg << 1'b1) | i_spi_cipo;
                if (r_sample_count > {c_COUNT_WIDTH{1'b0}}) begin
                    r_sample_count <= r_sample_count - 1'b1;
                end
            end

            if (w_spi_dclk_shift_edge) begin
                r_spi_copi <= s_axis_tdata_reg[r_shift_count];
                if (r_shift_count > {c_COUNT_WIDTH{1'b0}}) begin
                    r_shift_count <= r_shift_count - 1'b1;
                end
            end
            
            if (r_shift_count == {c_COUNT_WIDTH{1'b0}} & r_sample_count == {c_COUNT_WIDTH{1'b0}}) begin
                if (~r_clk_phase) begin
                    if (w_spi_dclk_shift_edge) begin
                        r_state <= s_SPI_EN_HOLD; 
                        if (r_en_hold_time == 16'b0) begin
                            r_spi_en <= 1'b1;
                            m_axis_tvalid_reg <= 1'b1;
                            r_state <= s_SPI_WAIT;
                        end
                    end
                end
            end

            if (r_shift_count == {c_COUNT_WIDTH{1'b0}} & r_sample_count == 1'b1) begin
                if (r_clk_phase) begin
                    if (w_spi_dclk_sample_edge) begin
                        r_state <= s_SPI_EN_HOLD; 
                        if (r_en_hold_time == 16'b0) begin
                            r_spi_en <= 1'b1;
                            m_axis_tvalid_reg <= 1'b1;
                            r_state <= s_SPI_WAIT;
                        end
                    end
                end
            end
        end

        s_SPI_EN_HOLD: begin
            r_en_hold_time <= r_en_hold_time - 1'b1;
            if (r_en_hold_time == 16'd1) begin
                r_spi_en <= 1'b1;
                m_axis_tvalid_reg <= 1'b1;
                r_state <= s_SPI_WAIT;
            end
        end

        s_SPI_WAIT: begin
            if (m_axis_tvalid & m_axis_tready) begin
                m_axis_tvalid_reg <= 1'b0;
                if (r_en_high_time == 16'b0) begin
                    s_axis_tready_reg <= 1'b1;
                    r_state <= s_SPI_IDLE;
                end
            end

            if (r_en_high_time > 16'b0) begin
                r_en_high_time <= r_en_high_time - 1'b1;
            end

            if (r_en_high_time == 16'b0 & ~m_axis_tvalid) begin
                s_axis_tready_reg <= 1'b1;
                r_state <= s_SPI_IDLE;
            end
        end
    endcase 

    if (w_spi_dclk_sample_edge | w_spi_dclk_shift_edge) begin
        r_spi_dclk <= ~r_spi_dclk;
        if (r_sample_count == {c_COUNT_WIDTH{1'b0}}) begin
            r_spi_dclk <= r_clk_polarity;
        end
    end

    if (r_prescale == (r_prescale_hold << 1'b1) - 1'b1) begin
        r_prescale <= 17'b0;
    end
end

endmodule
