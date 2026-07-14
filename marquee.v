// ============================================================
// 八位七段数码管动态显示 + 跑马灯
// 开发板：Nexys A7-100T
// 端口与 icf.xdc 一致
//
// 功能：
//   1) 100MHz 分频，动态扫描 8 位共阳极数码管
//   2) 数码管跑马灯：十六进制字符在 8 位上滚动
//   3) LED 跑马灯：16 个 LED 依次点亮形成追逐效果
//
// 拨码开关：
//   sw_i[0] = 0 : 数码管向左滚动
//   sw_i[0] = 1 : 数码管向右滚动
//   sw_i[1] = 0 : LED 向左跑
//   sw_i[1] = 1 : LED 向右跑
//   sw_i[2] = 1 : 暂停滚动（保持当前画面）
// ============================================================

module marquee (
    input  wire        clk,         // 100MHz
    input  wire        rstn,        // 低有效复位
    input  wire [15:0] sw_i,        // 拨码开关
    output reg  [15:0] led_o,       // LED 跑马灯
    output reg  [7:0]  disp_seg_o,  // 段选 {DP,CG,CF,CE,CD,CC,CB,CA}
    output reg  [7:0]  disp_an_o    // 位选 AN[7:0]，低有效
);

    // ------------------------------------------------------------
    // 系统分频计数器（复用高位得到多种慢时钟）
    // 100MHz / 2^n
    //   [14] ~ 3.05 kHz  : 数码管扫描
    //   [24] ~ 3.0  Hz   : 跑马灯步进（约 0.33s 一格）
    // ------------------------------------------------------------
    reg [26:0] clkdiv;

    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            clkdiv <= 27'd0;
        else
            clkdiv <= clkdiv + 27'd1;
    end

    wire clk_scan = clkdiv[14];   // 扫描时钟
    wire clk_move = clkdiv[24];   // 滚动时钟

    // ============================================================
    // 一、数码管跑马灯数据
    // 用 16 个十六进制字符构成循环序列，窗口取 8 位显示
    // 序列：0 1 2 3 4 5 6 7 8 9 A B C D E F
    // ============================================================
    reg [3:0] pattern [0:15];
    reg [3:0] offset;             // 滚动起点

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1)
            pattern[i] = i[3:0];
    end

    // 滚动：每个 move 时钟移动一格
    always @(posedge clk_move or negedge rstn) begin
        if (!rstn)
            offset <= 4'd0;
        else if (!sw_i[2]) begin
            if (sw_i[0])
                offset <= offset + 4'd1;   // 右滚：起点递增
            else
                offset <= offset - 4'd1;   // 左滚：起点递减
        end
    end

    // 当前 8 位显示内容（每 4bit 一个字符）
    wire [3:0] dig0 = pattern[(offset + 4'd0) & 4'hF];
    wire [3:0] dig1 = pattern[(offset + 4'd1) & 4'hF];
    wire [3:0] dig2 = pattern[(offset + 4'd2) & 4'hF];
    wire [3:0] dig3 = pattern[(offset + 4'd3) & 4'hF];
    wire [3:0] dig4 = pattern[(offset + 4'd4) & 4'hF];
    wire [3:0] dig5 = pattern[(offset + 4'd5) & 4'hF];
    wire [3:0] dig6 = pattern[(offset + 4'd6) & 4'hF];
    wire [3:0] dig7 = pattern[(offset + 4'd7) & 4'hF];

    // ============================================================
    // 二、8 位动态扫描
    // ============================================================
    reg [2:0] scan;

    always @(posedge clk_scan or negedge rstn) begin
        if (!rstn)
            scan <= 3'd0;
        else
            scan <= scan + 3'd1;
    end

    // 取当前位数字
    reg [3:0] digit;
    always @(*) begin
        case (scan)
            3'd0:    digit = dig0;  // 最右
            3'd1:    digit = dig1;
            3'd2:    digit = dig2;
            3'd3:    digit = dig3;
            3'd4:    digit = dig4;
            3'd5:    digit = dig5;
            3'd6:    digit = dig6;
            3'd7:    digit = dig7;  // 最左
            default: digit = 4'h0;
        endcase
    end

    // 共阳极段码：{DP,CG,CF,CE,CD,CC,CB,CA}
    reg [7:0] seg_data;
    always @(*) begin
        case (digit)
            4'h0:    seg_data = 8'hC0;
            4'h1:    seg_data = 8'hF9;
            4'h2:    seg_data = 8'hA4;
            4'h3:    seg_data = 8'hB0;
            4'h4:    seg_data = 8'h99;
            4'h5:    seg_data = 8'h92;
            4'h6:    seg_data = 8'h82;
            4'h7:    seg_data = 8'hF8;
            4'h8:    seg_data = 8'h80;
            4'h9:    seg_data = 8'h90;
            4'hA:    seg_data = 8'h88;
            4'hB:    seg_data = 8'h83;
            4'hC:    seg_data = 8'hC6;
            4'hD:    seg_data = 8'hA1;
            4'hE:    seg_data = 8'h86;
            4'hF:    seg_data = 8'h84;
            default: seg_data = 8'hFF;
        endcase
    end

    // 输出位选 + 段码
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
            disp_seg_o <= seg_data;
        end
    end

    // ============================================================
    // 三、LED 跑马灯：16 位单点追逐
    // ============================================================
    reg [3:0] led_pos;

    always @(posedge clk_move or negedge rstn) begin
        if (!rstn)
            led_pos <= 4'd0;
        else if (!sw_i[2]) begin
            if (sw_i[1])
                led_pos <= led_pos + 4'd1;
            else
                led_pos <= led_pos - 4'd1;
        end
    end

    always @(*) begin
        led_o = 16'h0000;
        led_o[led_pos] = 1'b1;
    end

endmodule
