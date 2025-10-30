
module lcd_controller#(
    parameter FREQ_HZ = 40000000,

    parameter HORIZONTAL_BACK_PORCH = 10, // px
    parameter HORIZONTAL_FRONT_PORCH = 40, // px
    
    parameter VERTICAL_BACK_PORCH = 10, // lines
    parameter VERTICAL_FRONT_PORCH = 10, // lines

    parameter HORIZONTAL_DATA_WIDTH = 800, // px
    parameter VERTICAL_DATA_WIDTH = 480 // lines
)(
    input wire clk,
    input wire aresetn,
    input wire i_start,

    output wire     o_clk,
    output wire     o_data_en,
    output wire[7:0] o_red,
    output wire[7:0] o_green,
    output wire[7:0] o_blue
);
    parameter IDLE = 0;

    assign o_clk = clk;

    parameter CTRL_VBP  = 2'b01;
    parameter CTRL_DATA = 2'b10;
    parameter CTRL_VFP  = 2'b11;
    reg[1:0] controller_state;

    parameter LINE_HBP  = 2'b01;
    parameter LINE_DATA = 2'b10;
    parameter LINE_HFP  = 2'b11;
    reg[1:0] line_state;
    reg[8:0] line_count;
    reg[9:0] px_count;

    assign o_data_en = (controller_state == CTRL_DATA) && (line_state == LINE_DATA);
    assign o_red = 8'h00;
    assign o_green = 8'h00;
    assign o_blue = o_data_en ? 8'hFF : 8'h00;

    // this module works at negedge
    // the lcd reads at posedge
    // allows us to meet hold and setup for lcd
    // easily
    always @(negedge clk) begin
        if (!aresetn) begin
            controller_state <= IDLE;
            line_state <= IDLE;
            px_count <= 0;
            line_count <= 0;
        end
        else if (controller_state == IDLE) begin
            // stay in idle until start
            if (i_start) begin
                controller_state <= CTRL_VBP;
                line_state <= LINE_HBP;
                px_count <= 0;
            end
        end
        else begin
            case (line_state)
                IDLE: begin
                    line_state <= LINE_HBP;
                    px_count <= 0;
                    line_count <= 0;
                end
                LINE_HBP: begin
                    if (px_count >= HORIZONTAL_BACK_PORCH - 1) begin
                        line_state <= LINE_DATA;
                        px_count <= 0;
                    end
                    else begin
                        px_count <= px_count + 1;
                    end
                end
                LINE_DATA: begin
                    if (px_count >= HORIZONTAL_DATA_WIDTH - 1) begin
                        line_state <= LINE_HFP;
                        px_count <= 0;
                    end
                    else begin
                        px_count <= px_count + 1;
                    end
                end
                LINE_HFP: begin
                    if (px_count >= HORIZONTAL_FRONT_PORCH - 1) begin
                        px_count <= 0;
                        case (controller_state)
                            CTRL_VBP: begin
                                line_state <= LINE_HBP;
                                if (line_count == VERTICAL_BACK_PORCH - 1) begin
                                    line_count <= 0;
                                    controller_state <= CTRL_DATA;
                                end
                                else begin
                                    line_count <= line_count + 1;
                                end
                            end
                            CTRL_DATA: begin
                                line_state <= LINE_HBP;
                                if (line_count == VERTICAL_DATA_WIDTH - 1) begin
                                    line_count <= 0;
                                    controller_state <= CTRL_VFP;
                                end
                                else begin
                                    line_count <= line_count + 1;
                                end
                            end
                            CTRL_VFP: begin
                                if (line_count == VERTICAL_FRONT_PORCH - 1) begin
                                    // frame done
                                    line_count <= 0;
                                    controller_state <= IDLE;
                                    line_state <= IDLE;
                                end
                                else begin
                                    line_count <= line_count + 1;
                                end
                            end
                        endcase
                    end
                    else begin
                        px_count <= px_count + 1;
                    end
                end
            endcase
        end
    end

endmodule


