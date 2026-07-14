`timescale 1ns / 1ps

module led_runner(
    input  wire       clk,
    input  wire       rstn,
    output reg  [7:0] disp_an_o,
    output reg  [7:0] disp_seg_o
);

    /*
     * Nexys A7 系统时钟为 100 MHz。
     *
     * MOVE_TICKS = 10_000_000：
     * 蛇每隔约 0.1 秒向前移动一步。
     *
     * 数值越小，移动越快；
     * 数值越大，移动越慢。
     */
    localparam integer MOVE_TICKS = 10_000_000;

    /*
     * 蛇形路径总共包含 26 个位置，编号为 0～25。
     *
     * 0～7：
     * 顶部 A 段，从最左侧向最右侧移动。
     *
     * 8：
     * 最右侧数码管的 B 段，向下转弯。
     *
     * 9～16：
     * 中间 G 段，从最右侧向最左侧移动。
     *
     * 17：
     * 最左侧数码管的 E 段，向下转弯。
     *
     * 18～25：
     * 底部 D 段，从最左侧向最右侧移动。
     */
    localparam [4:0] PATH_END = 5'd25;

    // 八位数码管动态扫描计数器
    reg [15:0] scan_counter;

    // 控制蛇移动速度的计数器
    reg [23:0] move_counter;

    // 蛇头和三节蛇身的位置
    reg [4:0] snake_head;
    reg [4:0] snake_body1;
    reg [4:0] snake_body2;
    reg [4:0] snake_body3;

    /*
     * 移动方向：
     * 0：沿路径编号增大的方向移动；
     * 1：沿路径编号减小的方向移动。
     */
    reg direction;

    /*
     * 用于控制蛇身亮度的 PWM 计数器。
     * 蛇头最亮，尾巴逐渐变暗。
     */
    reg [1:0] pwm_counter;

    // 当前正在扫描的数码管编号，范围为 0～7
    wire [2:0] scan_sel;

    assign scan_sel = scan_counter[15:13];

    /*
     * 当前被扫描数码管中：
     *
     * A 段在蛇形路径中的编号；
     * G 段在蛇形路径中的编号；
     * D 段在蛇形路径中的编号。
     *
     * scan_sel = 0 对应最右侧数码管；
     * scan_sel = 7 对应最左侧数码管。
     */
    wire [4:0] top_path;
    wire [4:0] middle_path;
    wire [4:0] bottom_path;

    /*
     * 顶部路径：
     * 最左侧编号为 0，最右侧编号为 7。
     */
    assign top_path = 5'd7 - scan_sel;

    /*
     * 中间路径：
     * 最右侧编号为 9，最左侧编号为 16。
     */
    assign middle_path = 5'd9 + scan_sel;

    /*
     * 底部路径：
     * 最左侧编号为 18，最右侧编号为 25。
     */
    assign bottom_path = 5'd25 - scan_sel;


    /*
     * 数码管扫描计数器和 PWM 计数器。
     */
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            scan_counter <= 16'd0;
            pwm_counter  <= 2'd0;
        end
        else begin
            scan_counter <= scan_counter + 1'b1;
            pwm_counter  <= pwm_counter + 1'b1;
        end
    end


    /*
     * 蛇形移动逻辑。
     *
     * 正向移动：
     * 0 → 1 → 2 → ... → 25
     *
     * 到达 25 后：
     * 25 → 24 → 23 → ... → 0
     *
     * 到达 0 后再次折返，形成无缝循环。
     */
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            move_counter <= 24'd0;

            // 初始时形成长度为 4 的蛇
            snake_head  <= 5'd3;
            snake_body1 <= 5'd2;
            snake_body2 <= 5'd1;
            snake_body3 <= 5'd0;

            direction <= 1'b0;
        end
        else begin
            if (move_counter == MOVE_TICKS - 1) begin
                move_counter <= 24'd0;

                /*
                 * 蛇身跟随：
                 * 第三节跟随第二节；
                 * 第二节跟随第一节；
                 * 第一节跟随蛇头原来的位置。
                 */
                snake_body3 <= snake_body2;
                snake_body2 <= snake_body1;
                snake_body1 <= snake_head;

                if (direction == 1'b0) begin
                    // 正向移动
                    if (snake_head == PATH_END) begin
                        // 到达末端后立即折返
                        snake_head <= PATH_END - 1'b1;
                        direction  <= 1'b1;
                    end
                    else begin
                        snake_head <= snake_head + 1'b1;
                    end
                end
                else begin
                    // 反向移动
                    if (snake_head == 5'd0) begin
                        // 回到起点后立即再次折返
                        snake_head <= 5'd1;
                        direction  <= 1'b0;
                    end
                    else begin
                        snake_head <= snake_head - 1'b1;
                    end
                end
            end
            else begin
                move_counter <= move_counter + 1'b1;
            end
        end
    end


    /*
     * 判断指定路径位置当前是否应该点亮。
     *
     * 蛇头：100% 亮度；
     * 第一节蛇身：约 75% 亮度；
     * 第二节蛇身：约 50% 亮度；
     * 第三节蛇身：约 25% 亮度。
     */
    function segment_visible;
        input [4:0] path_index;

        begin
            if (path_index == snake_head)
                segment_visible = 1'b1;

            else if (path_index == snake_body1)
                segment_visible = (pwm_counter != 2'b00);

            else if (path_index == snake_body2)
                segment_visible = pwm_counter[1];

            else if (path_index == snake_body3)
                segment_visible = (pwm_counter == 2'b11);

            else
                segment_visible = 1'b0;
        end
    endfunction


    /*
     * 数码管动态扫描和蛇形路径显示。
     *
     * disp_seg_o[7:0] 对应：
     *
     * {DP, G, F, E, D, C, B, A}
     *
     * Nexys A7 数码管低电平有效：
     *
     * 0：点亮；
     * 1：熄灭。
     */
    always @(*) begin

        // 默认关闭全部数码管和全部笔画
        disp_an_o  = 8'b1111_1111;
        disp_seg_o = 8'b1111_1111;

        /*
         * 选择当前扫描的数码管。
         * 每一时刻只选中八位中的一位。
         */
        case (scan_sel)
            3'd0: disp_an_o = 8'b1111_1110;
            3'd1: disp_an_o = 8'b1111_1101;
            3'd2: disp_an_o = 8'b1111_1011;
            3'd3: disp_an_o = 8'b1111_0111;
            3'd4: disp_an_o = 8'b1110_1111;
            3'd5: disp_an_o = 8'b1101_1111;
            3'd6: disp_an_o = 8'b1011_1111;
            3'd7: disp_an_o = 8'b0111_1111;

            default:
                disp_an_o = 8'b1111_1111;
        endcase


        /*
         * 顶部横向路径：A 段。
         *
         * disp_seg_o[0] 对应 A 段。
         */
        if (segment_visible(top_path))
            disp_seg_o[0] = 1'b0;


        /*
         * 第一次转弯：
         * 使用最右侧数码管的 B 段连接顶部和中部。
         *
         * 路径编号为 8。
         */
        if ((scan_sel == 3'd0) &&
            segment_visible(5'd8))
            disp_seg_o[1] = 1'b0;


        /*
         * 中部横向路径：G 段。
         *
         * disp_seg_o[6] 对应 G 段。
         */
        if (segment_visible(middle_path))
            disp_seg_o[6] = 1'b0;


        /*
         * 第二次转弯：
         * 使用最左侧数码管的 E 段连接中部和底部。
         *
         * 路径编号为 17。
         */
        if ((scan_sel == 3'd7) &&
            segment_visible(5'd17))
            disp_seg_o[4] = 1'b0;


        /*
         * 底部横向路径：D 段。
         *
         * disp_seg_o[3] 对应 D 段。
         */
        if (segment_visible(bottom_path))
            disp_seg_o[3] = 1'b0;


        /*
         * 小数点始终关闭。
         *
         * 蛇头由路径中最前方、亮度最高的线段表示，
         * 不再使用位于右下角的小数点作为蛇头。
         */
        disp_seg_o[7] = 1'b1;
    end

endmodule
