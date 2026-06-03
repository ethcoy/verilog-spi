/*

In the future: 

- Add inputs that allow the user to adjust the number of clock cycles before the first and last edges of o_spi_dclk

- Add an input that allows the user to adjust the minimum number of clock cycles between SPI transactions

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

    input wire [15:0] i_prescale
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

reg [c_COUNT_WIDTH - 1:0] r_shift_count = {c_COUNT_WIDTH{1'b0}};
reg [c_COUNT_WIDTH - 1:0] r_sample_count = {c_COUNT_WIDTH{1'b0}};

reg [16:0] r_shift_edge_count = 17'b0;
reg [16:0] r_sample_edge_count = 17'b0;

wire w_spi_dclk_shift_edge;
wire w_spi_dclk_sample_edge;

assign w_spi_dclk_shift_edge = r_prescale == (r_shift_edge_count - 1'b1) ? 1'b1 : 1'b0;
assign w_spi_dclk_sample_edge = r_prescale == (r_sample_edge_count - 1'b1) ? 1'b1 : 1'b0;

localparam s_SPI_IDLE = 2'd0;
localparam s_SPI_START = 2'd1;
localparam s_SPI_ACTIVE = 2'd2;
localparam s_SPI_WAIT = 2'd3;

reg [1:0] r_state = s_SPI_IDLE;

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
                r_shift_count <= c_DATA_WIDTH - 1'b1;
                r_sample_count <= c_DATA_WIDTH;
                r_state <= s_SPI_START;
            end
        end

        s_SPI_START: begin
            r_spi_en <= 1'b0;
            r_state <= s_SPI_ACTIVE;
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
                    if (w_spi_dclk_sample_edge) begin
                        r_spi_en <= 1'b1;
                        r_state <= s_SPI_WAIT;
                        m_axis_tvalid_reg <= 1'b1;
                    end
                end
                
                if (r_clk_phase) begin
                    if (w_spi_dclk_shift_edge) begin
                        r_spi_en <= 1'b1;
                        r_state <= s_SPI_WAIT;
                        m_axis_tvalid_reg <= 1'b1;
                    end
                end
            end
        end

        s_SPI_WAIT: begin
            if (m_axis_tvalid & m_axis_tready) begin
                s_axis_tready_reg <= 1'b1;
                m_axis_tvalid_reg <= 1'b0;
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
