// ============================================================
// 最自然的跑马灯（板子自带那种：单点往返）+ PWM 亮度可调
// 开发板：Nexys A7-100T，端口与 icf.xdc 一致
//
// 效果：
//   - 8 个数码管 + 16 个 LED 上只有一个亮点往返（到头折返）
//   - 亮点平滑，无残影，就是板子自带那种朴素跑马灯
//   - LED 与数码管同步走动
//
// 开关：
//   sw_i[1:0] : 速度  00最快 ~ 11最慢
//   sw_i[2]   = 1 : 暂停
//   sw_i[5:3] : 亮度  000最暗(灭) ~ 111最亮（共 8 级，PWM 调光）
// ============================================================

module marquee (
    input  wire        clk,         // 100MHz
    input  wire        rstn,        // 低有效复位
    input  wire [15:0] sw_i,
    output reg  [15:0] led_o,
    output reg  [7:0]  disp_seg_o,  // {DP,CG,CF,CE,CD,CC,CB,CA}
    output reg  [7:0]  disp_an_o    // AN 低有效
);

    // ------------------------------------------------------------
    // 亮度 PWM：100MHz / 2^14 ≈ 6.1kHz，远高于闪烁临界值
    //   pwm_cnt 周期 0..16383，高比 = duty/8
    // ------------------------------------------------------------
    reg [13:0] pwm_cnt;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) pwm_cnt <= 14'd0;
        else       pwm_cnt <= pwm_cnt + 14'd1;
    end
    wire [2:0] duty  = sw_i[5:3];
    wire       pwm_on = (pwm_cnt[13:11] < duty);   // 8 级占空比

    // ------------------------------------------------------------
    // 扫描分频：100MHz / 2^15 ≈ 3kHz，8 位扫描无闪烁
    // ------------------------------------------------------------
    reg [14:0] scan_div;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) scan_div <= 15'd0;
        else       scan_div <= scan_div + 15'd1;
    end
    wire clk_scan = scan_div[14];

    // ------------------------------------------------------------
    // 流动步进：约 12.5 ~ 50 步/秒
    // sw[1:0] = 00 最快 ... 11 最慢
    // ------------------------------------------------------------
    reg [22:0] move_div;
    reg [22:0] move_max;
    reg        move_tick;

    always @(*) begin
        case (sw_i[1:0])
            2'b00:   move_max = 23'd2_000_000;  // ~50 Hz
            2'b01:   move_max = 23'd3_000_000;  // ~33 Hz
            2'b10:   move_max = 23'd5_000_000;  // ~20 Hz
            default: move_max = 23'd8_000_000;  // ~12.5 Hz
        endcase
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            move_div  <= 23'd0;
            move_tick <= 1'b0;
        end
        else if (sw_i[2]) begin
            move_tick <= 1'b0;
        end
        else if (move_div >= move_max) begin
            move_div  <= 23'd0;
            move_tick <= 1'b1;
        end
        else begin
            move_div  <= move_div + 23'd1;
            move_tick <= 1'b0;
        end
    end

    // ============================================================
    // 数码管往返：head 在 0..7 之间来回折返（单点亮）
    // ============================================================
    reg [2:0] seg_head;
    reg       seg_dir;   // 0:+  1:-

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            seg_head <= 3'd0;
            seg_dir  <= 1'b0;
        end
        else if (move_tick) begin
            if (!seg_dir) begin
                if (seg_head == 3'd7) begin
                    seg_head <= 3'd6;
                    seg_dir  <= 1'b1;
                end
                else
                    seg_head <= seg_head + 3'd1;
            end
            else begin
                if (seg_head == 3'd0) begin
                    seg_head <= 3'd1;
                    seg_dir  <= 1'b0;
                end
                else
                    seg_head <= seg_head - 3'd1;
            end
        end
    end

    // ============================================================
    // LED 往返：led_head 在 0..15 之间来回折返
    // ============================================================
    reg [3:0] led_head;
    reg       led_dir;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            led_head <= 4'd0;
            led_dir  <= 1'b0;
        end
        else if (move_tick) begin
            if (!led_dir) begin
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
    // 数码管动态扫描：只点亮当前 head 所在的位
    //   共阳极：段为低亮，位为低选通；不点亮位置段输出全高（灭）
    //   PWM 期间通过把段拉成全高实现调光
    // ============================================================
    reg [2:0] scan;
    always @(posedge clk_scan or negedge rstn) begin
        if (!rstn) scan <= 3'd0;
        else       scan <= scan + 3'd1;
    end

    // 单位点亮时显示 "8"（0x80），否则灭（0xFF）
    wire [7:0] seg_glyph = (scan == seg_head) ? 8'h80 : 8'hFF;
    wire       seg_dim   = (scan == seg_head) & pwm_on;   // 该位才参与调光
    wire [7:0] seg_final = seg_dim ? 8'h80 : 8'hFF;       // PWM off 时切到全灭

    always @(posedge clk_scan or negedge rstn) begin
        if (!rstn) begin
            disp_an_o  <= 8'hFF;
            disp_seg_o <= 8'hFF;
        end
        else begin
            case (scan)
                3'd0:    disp_an_o <= 8'b1111_1110;
                3'd1:    disp_an_o <= 8'b1111_1101;
                3'd2:    disp_an_o <= 8'b1111_1011;
                3'd3:    disp_an_o <= 8'b1111_0111;
                3'd4:    disp_an_o <= 8'b1110_1111;
                3'd5:    disp_an_o <= 8'b1101_1111;
                3'd6:    disp_an_o <= 8'b1011_1111;
                3'd7:    disp_an_o <= 8'b0111_1111;
                default: disp_an_o <= 8'hFF;
            endcase
            disp_seg_o <= seg_final;
        end
    end

    // ============================================================
    // LED 输出：仅点亮 led_head 一位，PWM 调光
    // ============================================================
    always @(*) begin
        if (pwm_on) begin
            led_o = 16'h0000;
            led_o[led_head] = 1'b1;
        end
        else begin
            led_o = 16'h0000;
        end
    end

endmodule