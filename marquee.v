// ============================================================
// 七段数码管“流动跑马灯”
// 开发板：Nexys A7-100T
// 端口与 icf.xdc 一致
//
// 说明：
//   动态扫描 = 驱动手段（同一时刻只点亮一位，靠视觉暂留看成多位同时亮）
//   流动跑马灯 = 显示效果（亮点/图案在 8 位上从左到右或从右到左流动）
//
// 本设计：
//   1) 数码管：单点（或短拖尾）在 8 位上循环流动
//   2) LED：16 位单点追逐，同步流动
//
// 拨码开关：
//   sw_i[0] = 0 : 向左流动
//   sw_i[0] = 1 : 向右流动
//   sw_i[1] = 0 : 数码管单点流动
//   sw_i[1] = 1 : 数码管 3 位点拖尾流动（更像流水）
//   sw_i[2] = 1 : 暂停
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
    // 分频
    //   clkdiv[14] ~ 3 kHz  : 数码管动态扫描（必须快，防闪烁）
    //   clkdiv[24] ~ 3 Hz   : 跑马灯流动步进（必须慢，才能看清移动）
    // ------------------------------------------------------------
    reg [26:0] clkdiv;

    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            clkdiv <= 27'd0;
        else
            clkdiv <= clkdiv + 27'd1;
    end

    wire clk_scan = clkdiv[14];
    wire clk_move = clkdiv[24];

    // ============================================================
    // 流动位置：0~7 对应 8 个数码管
    // ============================================================
    reg [2:0] head;   // 流动“龙头”所在位

    always @(posedge clk_move or negedge rstn) begin
        if (!rstn)
            head <= 3'd0;
        else if (!sw_i[2]) begin
            if (sw_i[0])
                head <= head + 3'd1;   // 向右流
            else
                head <= head - 3'd1;   // 向左流
        end
    end

    // 每一位是否点亮（流动图案）
    // sw_i[1]=0 : 仅 head 一位亮（经典单点跑马）
    // sw_i[1]=1 : head 及后两位点亮，形成拖尾流水
    wire [2:0] t1 = head - 3'd1;
    wire [2:0] t2 = head - 3'd2;

    reg [7:0] lit;   // lit[i]=1 表示第 i 位要显示图案
    integer k;
    always @(*) begin
        lit = 8'h00;
        lit[head] = 1'b1;
        if (sw_i[1]) begin
            lit[t1] = 1'b1;
            lit[t2] = 1'b1;
        end
    end

    // 流动亮位显示字符 "8"（全段最醒目）；也可改成 "0"/"-"
    // 灭位输出全灭
    localparam [3:0] ON_DIGIT = 4'h8;

    // ============================================================
    // 动态扫描：高速轮流点亮 8 位
    // 同一时刻只选中一位，并输出该位段码
    // ============================================================
    reg [2:0] scan;

    always @(posedge clk_scan or negedge rstn) begin
        if (!rstn)
            scan <= 3'd0;
        else
            scan <= scan + 3'd1;
    end

    // 当前扫描位：亮则显示 8，灭则空白
    wire [3:0] digit = lit[scan] ? ON_DIGIT : 4'hF; // F 仅作占位，下面用 blank 区分
    wire       blank = ~lit[scan];

    // 共阳极段码
    reg [7:0] seg_data;
    always @(*) begin
        if (blank)
            seg_data = 8'hFF;          // 全灭
        else begin
            case (ON_DIGIT)
                4'h0:    seg_data = 8'hC0;
                4'h1:    seg_data = 8'hF9;
                4'h8:    seg_data = 8'h80;  // “8” 全段亮，流动最明显
                4'hA:    seg_data = 8'h88;
                default: seg_data = 8'h80;
            endcase
        end
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
    // LED 同步流动跑马灯（16 位单点）
    // ============================================================
    reg [3:0] led_pos;

    always @(posedge clk_move or negedge rstn) begin
        if (!rstn)
            led_pos <= 4'd0;
        else if (!sw_i[2]) begin
            if (sw_i[0])
                led_pos <= led_pos + 4'd1;
            else
                led_pos <= led_pos - 4'd1;
        end
    end

    always @(*) begin
        led_o = 16'h0000;
        led_o[led_pos] = 1'b1;
        // 拖尾模式时 LED 也带 2 点尾巴
        if (sw_i[1]) begin
            led_o[led_pos - 4'd1] = 1'b1;
            led_o[led_pos - 4'd2] = 1'b1;
        end
    end

endmodule
