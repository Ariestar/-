// ============================================================
// 七段数码管流动跑马灯（往返 + 残影）
// 开发板：Nexys A7-100T，端口与 icf.xdc 一致
//
// 效果：
//   - 亮点在 8 位上来回往返（到头折返，不是转圈）
//   - 速度快，带多级拖尾残影
//   - LED 同步往返 + 残影
//
// 开关：
//   sw_i[1:0] : 速度 00最快 ~ 11最慢
//   sw_i[2]   = 1 : 暂停
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
    // 扫描分频：100MHz / 2^15 ≈ 3kHz，8 位扫描无闪烁
    // ------------------------------------------------------------
    reg [14:0] scan_div;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) scan_div <= 15'd0;
        else       scan_div <= scan_div + 15'd1;
    end
    wire clk_scan = scan_div[14];

    // ------------------------------------------------------------
    // 流动步进：约 12.5 ~ 50 步/秒（默认最快，残影明显）
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
    // 往返：head 在 0..7 之间来回折返
    // ============================================================
    reg [2:0] head;
    reg       dir;   // 0:+  1:-

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            head <= 3'd0;
            dir  <= 1'b0;
        end
        else if (move_tick) begin
            if (!dir) begin
                if (head == 3'd7) begin
                    head <= 3'd6;
                    dir  <= 1'b1;
                end
                else
                    head <= head + 3'd1;
            end
            else begin
                if (head == 3'd0) begin
                    head <= 3'd1;
                    dir  <= 1'b0;
                end
                else
                    head <= head - 3'd1;
            end
        end
    end

    // ============================================================
    // 残影：保存最近 5 个位置，龙头最亮、尾巴渐暗
    // ============================================================
    reg [2:0] trail0, trail1, trail2, trail3, trail4;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            trail0 <= 3'd0;
            trail1 <= 3'd0;
            trail2 <= 3'd0;
            trail3 <= 3'd0;
            trail4 <= 3'd0;
        end
        else if (move_tick) begin
            trail4 <= trail3;
            trail3 <= trail2;
            trail2 <= trail1;
            trail1 <= trail0;
            trail0 <= head;
        end
    end

    // level[i]: 0灭 1最淡 ... 5最亮
    reg [2:0] level [0:7];
    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1)
            level[i] = 3'd0;
        level[trail4] = 3'd1;
        level[trail3] = 3'd2;
        level[trail2] = 3'd3;
        level[trail1] = 3'd4;
        level[trail0] = 3'd5;
    end

    // ============================================================
    // 动态扫描 + 按亮度输出不同段码（制造残影层次）
    // ============================================================
    reg [2:0] scan;
    always @(posedge clk_scan or negedge rstn) begin
        if (!rstn) scan <= 3'd0;
        else       scan <= scan + 3'd1;
    end

    // 共阳极：8 全亮 > 0 > 5 > - > 小数点 > 灭
    reg [7:0] seg_out;
    always @(*) begin
        case (level[scan])
            3'd5:    seg_out = 8'h80; // 8  龙头
            3'd4:    seg_out = 8'hC0; // 0
            3'd3:    seg_out = 8'h92; // 5
            3'd2:    seg_out = 8'hBF; // -
            3'd1:    seg_out = 8'h7F; // 仅 DP，最淡
            default: seg_out = 8'hFF; // 灭
        endcase
    end

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
            disp_seg_o <= seg_out;
        end
    end

    // ============================================================
    // LED 往返 + 残影
    // ============================================================
    reg [3:0] led_head;
    reg       led_dir;
    reg [3:0] lt0, lt1, lt2, lt3, lt4;

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

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            lt0 <= 4'd0; lt1 <= 4'd0; lt2 <= 4'd0;
            lt3 <= 4'd0; lt4 <= 4'd0;
        end
        else if (move_tick) begin
            lt4 <= lt3; lt3 <= lt2; lt2 <= lt1; lt1 <= lt0; lt0 <= led_head;
        end
    end

    always @(*) begin
        led_o = 16'h0000;
        led_o[lt4] = 1'b1;
        led_o[lt3] = 1'b1;
        led_o[lt2] = 1'b1;
        led_o[lt1] = 1'b1;
        led_o[lt0] = 1'b1;
    end

endmodule
