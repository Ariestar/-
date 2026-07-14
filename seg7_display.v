// ============================================================
// 八位共阳极七段数码管动态显示
// 开发板：Nexys A7-100T
//
// 功能：在 8 位数码管上动态刷新显示 0~F 十六进制数字串
//
// 编程要点（对应实验文档第 6 节）：
//   1) 100MHz 分频，分频系数 2^15
//   2) 分频时钟下轮流选中 8 个数码管之一（AN 低有效）
//   3) 分频时钟下更新 8 个 0~F 数字字符（8*4=32 位）
//   4) 组合电路：根据当前选中位，取出对应 4 位数字
//   5) 分频时钟下将数字译码为 7 段码（含 DP）
//   6) 输出数码管使能信号 disp_an_o 与段码 disp_seg_o
//
// 段选排列顺序：{DP, CG, CF, CE, CD, CC, CB, CA}
// 共阳极：AN 与段码均为低电平有效
// 端口名与 icf.xdc 约束文件一致
// ============================================================

module seg7_display (
    input  wire        clk,         // 100MHz 系统时钟
    input  wire        rstn,        // 低有效复位（CPU_RESETN）
    input  wire [15:0] sw_i,        // 拨码开关
    output wire [15:0] led_o,       // LED 指示
    output reg  [7:0]  disp_seg_o,  // 段选 {DP,CG,CF,CE,CD,CC,CB,CA}
    output reg  [7:0]  disp_an_o    // 位选 AN[7:0]，低有效
);

    // LED 回显拨码开关
    assign led_o = sw_i;

    // ============================================================
    // 1) 100MHz 分频，分频系数 2^15
    //    100MHz / 2^15 ≈ 3.05 kHz
    //    8 位轮扫 → 每位约 381 Hz，人眼无闪烁
    // ============================================================
    reg [14:0] clkdiv;

    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            clkdiv <= 15'd0;
        else
            clkdiv <= clkdiv + 15'd1;
    end

    wire clk_scan = clkdiv[14];   // 扫描时钟 ≈ 3 kHz

    // ============================================================
    // 2) 分频时钟下，每个时钟选中 8 个数码管中的一个
    //    scan 循环 0~7，对应 AN0~AN7
    // ============================================================
    reg [2:0] scan;

    always @(posedge clk_scan or negedge rstn) begin
        if (!rstn)
            scan <= 3'd0;
        else
            scan <= scan + 3'd1;
    end

    // ============================================================
    // 3) 要显示的 8 个十六进制数字（共 32 位）
    //
    // 方案 A（默认）：固定显示 01234567，上板即可验证
    // 方案 B：高 16 位固定 89AB，低 16 位由拨码开关控制
    //         （注释掉方案 A，打开方案 B 即可切换）
    // ============================================================
    wire [31:0] display_data = 32'h0123_4567;                 // 方案 A
    // wire [31:0] display_data = {16'h89AB, sw_i};           // 方案 B

    // ============================================================
    // 4) 组合电路：根据当前选中的数码管，取出对应 4 位数字
    //    scan=0 → 最低 4 位（最右侧数码管 AN0）
    //    scan=7 → 最高 4 位（最左侧数码管 AN7）
    // ============================================================
    reg [3:0] digit;

    always @(*) begin
        case (scan)
            3'd0:    digit = display_data[ 3: 0];
            3'd1:    digit = display_data[ 7: 4];
            3'd2:    digit = display_data[11: 8];
            3'd3:    digit = display_data[15:12];
            3'd4:    digit = display_data[19:16];
            3'd5:    digit = display_data[23:20];
            3'd6:    digit = display_data[27:24];
            3'd7:    digit = display_data[31:28];
            default: digit = 4'h0;
        endcase
    end

    // ============================================================
    // 5) 数字 → 共阳极 7 段码译码（组合电路）
    //    格式：{DP, CG, CF, CE, CD, CC, CB, CA}
    //    编码与讲义一致：
    //      0:C0 1:F9 2:A4 3:B0 4:99 5:92 6:82 7:F8
    //      8:80 9:90 A:88 B:83 C:C6 D:A1 E:86 F:84
    // ============================================================
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
            default: seg_data = 8'hFF;   // 全灭
        endcase
    end

    // ============================================================
    // 6) 输出：位选使能 + 段码
    //    在扫描时钟下锁存，避免毛刺
    // ============================================================
    always @(posedge clk_scan or negedge rstn) begin
        if (!rstn) begin
            disp_an_o  <= 8'hFF;     // 全部关闭
            disp_seg_o <= 8'hFF;     // 段全灭
        end
        else begin
            // 位选：仅当前 scan 对应位为 0，其余为 1
            case (scan)
                3'd0:    disp_an_o <= 8'b1111_1110;  // AN0
                3'd1:    disp_an_o <= 8'b1111_1101;  // AN1
                3'd2:    disp_an_o <= 8'b1111_1011;  // AN2
                3'd3:    disp_an_o <= 8'b1111_0111;  // AN3
                3'd4:    disp_an_o <= 8'b1110_1111;  // AN4
                3'd5:    disp_an_o <= 8'b1101_1111;  // AN5
                3'd6:    disp_an_o <= 8'b1011_1111;  // AN6
                3'd7:    disp_an_o <= 8'b0111_1111;  // AN7
                default: disp_an_o <= 8'hFF;
            endcase

            // 段码
            disp_seg_o <= seg_data;
        end
    end

endmodule
