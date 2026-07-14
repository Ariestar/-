// ============================================================
// 板子自带那种"蛇形"跑马灯（带渐暗拖尾）+ 全局亮度可调
// 开发板：Nexys A7-100T，端口与 icf.xdc 一致
// 参考：led_runner.v（板载 demo）
//
// 效果（与板载 led_runner 一致）：
//   - 数码管上亮点沿 上沿 A -> 中段 G -> 下沿 D 三段路径往返爬行
//   - 龙头 100% 亮，往后 3 节身体 75% / 50% / 25% 渐暗（2-bit PWM 拖尾）
//   - 16 个 LED 同步蛇形往返，同样 4 级渐暗拖尾
//
// 开关：
//   sw_i[1:0] : 速度  00最快 ~ 11最慢
//   sw_i[2]   = 1 : 暂停
//   sw_i[5:3] : 全局亮度  000灭 ~ 111最亮（8 级，与拖尾 PWM 相乘）
// ============================================================

module marquee (
    input  wire        clk,         // 100MHz
    input  wire        rstn,        // 低有效复位
    input  wire [15:0] sw_i,
    output reg  [15:0] led_o,
    output reg  [7:0]  disp_seg_o,  // {DP,CG,CF,CE,CD,CC,CB,CA}
    output reg  [7:0]  disp_an_o    // AN 低有效
);

    // ============================================================
    // 路径长度：0..25，覆盖 上沿(0..7) + 中段(9..16) + 下沿(18..25)
    // ============================================================
    localparam [4:0] PATH_END = 5'd25;

    // ------------------------------------------------------------
    // 扫描 + 拖尾 PWM 计数器（与 led_runner 一致）
    //   scan_counter[15:13] 选当前扫描的数码管
    //   pwm_counter[1:0]     4 相位，制造龙头/身体 4 级渐暗
    // ------------------------------------------------------------
    reg [15:0] scan_counter;
    reg [1:0]  pwm_counter;

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

    wire [2:0] scan_sel = scan_counter[15:13];

    // ------------------------------------------------------------
    // 全局亮度 PWM：8 级，频率 100MHz/8 = 12.5MHz，远高于扫描
    //   duty=0 灭，duty=7 全亮（恒亮），其余按 duty/8 占空比
    //   与拖尾 PWM 相乘：全亮时即板载 led_runner 原始效果
    // ------------------------------------------------------------
    reg [2:0] pwm_global;
    always @(posedge clk or negedge rstn) begin
        if (!rstn)    pwm_global <= 3'd0;
        else          pwm_global <= pwm_global + 3'd1;
    end

    wire [2:0] duty      = sw_i[5:3];
    wire       global_on = (duty == 3'd7) || (pwm_global < duty);

    // ------------------------------------------------------------
    // 流动步进：sw[1:0] 选速度，sw[2] 暂停
    // ------------------------------------------------------------
    reg [23:0] move_counter;
    reg [23:0] move_max;
    reg        move_tick;

    always @(*) begin
        case (sw_i[1:0])
            2'b00:   move_max = 24'd4_000_000;   // ~25 Hz
            2'b01:   move_max = 24'd7_000_000;   // ~14 Hz
            2'b10:   move_max = 24'd10_000_000;  // ~10 Hz（板载默认）
            default: move_max = 24'd16_000_000;   // ~6 Hz
        endcase
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            move_counter <= 24'd0;
            move_tick    <= 1'b0;
        end
        else if (sw_i[2]) begin
            move_tick <= 1'b0;
        end
        else if (move_counter == move_max - 1'b1) begin
            move_counter <= 24'd0;
            move_tick    <= 1'b1;
        end
        else begin
            move_counter <= move_counter + 1'b1;
            move_tick    <= 1'b0;
        end
    end

    // ============================================================
    // 蛇身（数码管路径）：龙头 + 3 节身体，路径 0..25 往返
    // ============================================================
    reg [4:0] snake_head;
    reg [4:0] snake_body1;
    reg [4:0] snake_body2;
    reg [4:0] snake_body3;
    reg       direction;   // 0:+  1:-

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            snake_head   <= 5'd3;
            snake_body1  <= 5'd2;
            snake_body2  <= 5'd1;
            snake_body3  <= 5'd0;
            direction    <= 1'b0;
        end
        else if (move_tick) begin
            snake_body3 <= snake_body2;
            snake_body2 <= snake_body1;
            snake_body1 <= snake_head;

            if (direction == 1'b0) begin
                if (snake_head == PATH_END) begin
                    snake_head <= PATH_END - 1'b1;
                    direction  <= 1'b1;
                end
                else
                    snake_head <= snake_head + 1'b1;
            end
            else begin
                if (snake_head == 5'd0) begin
                    snake_head <= 5'd1;
                    direction  <= 1'b0;
                end
                else
                    snake_head <= snake_head - 1'b1;
            end
        end
    end

    // ============================================================
    // 蛇身（LED）：龙头 + 3 节身体，16 个 LED 上 0..15 往返
    // ============================================================
    reg [3:0] led_head;
    reg [3:0] led_body1;
    reg [3:0] led_body2;
    reg [3:0] led_body3;
    reg       led_dir;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            led_head  <= 4'd3;
            led_body1 <= 4'd2;
            led_body2 <= 4'd1;
            led_body3 <= 4'd0;
            led_dir   <= 1'b0;
        end
        else if (move_tick) begin
            led_body3 <= led_body2;
            led_body2 <= led_body1;
            led_body1 <= led_head;

            if (led_dir == 1'b0) begin
                if (led_head == 4'd15) begin
                    led_head <= 4'd14;
                    led_dir  <= 1'b1;
                end
                else
                    led_head <= led_head + 4'd1;
            end
            else begin
                if (led_head == 4'd0) begin
                    led_head <= 4'd1;
                    led_dir  <= 1'b0;
                end
                else
                    led_head <= led_head - 4'd1;
            end
        end
    end

    // ============================================================
    // 路径映射：scan_sel(0..7) -> 当前扫描管在三条路径上的编号
    //   top_path    = 7 - scan_sel   (上沿 A，右到左)
    //   middle_path = 9 + scan_sel   (中段 G，左到右)
    //   bottom_path = 25 - scan_sel  (下沿 D，右到左)
    // ============================================================
    wire [4:0] top_path    = 5'd7  - scan_sel;
    wire [4:0] middle_path = 5'd9  + scan_sel;
    wire [4:0] bottom_path = 5'd25 - scan_sel;

    // ============================================================
    // 拖尾可见性（与 led_runner 一致）
    //   龙头 100%、身体1 75%、身体2 50%、身体3 25%
    //   再与全局亮度 PWM 相乘
    // ============================================================
    function segment_visible;
        input [4:0] path_index;
        begin
            if (path_index == snake_head)
                segment_visible = global_on;
            else if (path_index == snake_body1)
                segment_visible = global_on && (pwm_counter != 2'b00);
            else if (path_index == snake_body2)
                segment_visible = global_on && (pwm_counter[1]);
            else if (path_index == snake_body3)
                segment_visible = global_on && (pwm_counter == 2'b11);
            else
                segment_visible = 1'b0;
        end
    endfunction

    // ============================================================
    // 数码管动态扫描 + 段码输出
    //   disp_seg_o: {DP,G,F,E,D,C,B,A}，低有效
    // ============================================================
    always @(*) begin
        disp_an_o  = 8'b1111_1111;
        disp_seg_o = 8'b1111_1111;

        case (scan_sel)
            3'd0: disp_an_o = 8'b1111_1110;
            3'd1: disp_an_o = 8'b1111_1101;
            3'd2: disp_an_o = 8'b1111_1011;
            3'd3: disp_an_o = 8'b1111_0111;
            3'd4: disp_an_o = 8'b1110_1111;
            3'd5: disp_an_o = 8'b1101_1111;
            3'd6: disp_an_o = 8'b1011_1111;
            3'd7: disp_an_o = 8'b0111_1111;
            default: disp_an_o = 8'b1111_1111;
        endcase

        // 上沿 A 段
        if (segment_visible(top_path))
            disp_seg_o[0] = 1'b0;

        // 第一转角：右上管 B 段连接上沿到中段（路径编号 8）
        if ((scan_sel == 3'd0) && segment_visible(5'd8))
            disp_seg_o[1] = 1'b0;

        // 中段 G 段
        if (segment_visible(middle_path))
            disp_seg_o[6] = 1'b0;

        // 第二转角：左下管 E 段连接中段到底沿（路径编号 17）
        if ((scan_sel == 3'd7) && segment_visible(5'd17))
            disp_seg_o[4] = 1'b0;

        // 下沿 D 段
        if (segment_visible(bottom_path))
            disp_seg_o[3] = 1'b0;

        // 小数点关闭
        disp_seg_o[7] = 1'b1;
    end

    // ============================================================
    // LED 输出：龙头 + 3 节身体，4 级渐暗，再叠加全局亮度
    // ============================================================
    always @(*) begin
        led_o = 16'h0000;
        if (global_on) begin
            led_o[led_head] = 1'b1;
            if (pwm_counter != 2'b00) led_o[led_body1] = 1'b1;
            if (pwm_counter[1])        led_o[led_body2] = 1'b1;
            if (pwm_counter == 2'b11)  led_o[led_body3] = 1'b1;
        end
    end

endmodule