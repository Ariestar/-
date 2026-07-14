// ============================================================
// 八位七段动态显示 —— 简易仿真测试文件
// 用法：在 Vivado 中 Add Sources → Simulation Sources 加入本文件
//       然后 Run Simulation
// 说明：为加快仿真，可在综合前临时把分频计数器位宽改小；
//       本测试平台仅检查复位与扫描切换行为
// ============================================================

`timescale 1ns / 1ps

module seg7_display_tb;

    reg         clk;
    reg         rstn;
    reg  [15:0] sw_i;
    wire [15:0] led_o;
    wire [7:0]  disp_seg_o;
    wire [7:0]  disp_an_o;

    // 例化被测模块
    seg7_display uut (
        .clk        (clk),
        .rstn       (rstn),
        .sw_i       (sw_i),
        .led_o      (led_o),
        .disp_seg_o (disp_seg_o),
        .disp_an_o  (disp_an_o)
    );

    // 100MHz 时钟：周期 10ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // 激励
    initial begin
        rstn = 1'b0;
        sw_i = 16'h0000;
        #100;
        rstn = 1'b1;

        // 运行足够长时间，让 2^15 分频后的扫描时钟翻转若干次
        // 2^15 * 10ns ≈ 327.68 us，跑 3 ms 约可扫 9 轮
        #3_000_000;

        $display("Simulation finished.");
        $display("led_o      = %h", led_o);
        $display("disp_an_o  = %b", disp_an_o);
        $display("disp_seg_o = %h", disp_seg_o);
        $finish;
    end

    // 监视位选变化
    always @(disp_an_o) begin
        if (rstn)
            $display("[%0t] AN=%b  SEG=%h", $time, disp_an_o, disp_seg_o);
    end

endmodule
