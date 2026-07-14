// 跑马灯简易仿真（观察扫描与滚动逻辑）
`timescale 1ns / 1ps

module marquee_tb;
    reg         clk;
    reg         rstn;
    reg  [15:0] sw_i;
    wire [15:0] led_o;
    wire [7:0]  disp_seg_o;
    wire [7:0]  disp_an_o;

    marquee uut (
        .clk(clk),
        .rstn(rstn),
        .sw_i(sw_i),
        .led_o(led_o),
        .disp_seg_o(disp_seg_o),
        .disp_an_o(disp_an_o)
    );

    initial clk = 0;
    always #5 clk = ~clk;   // 100MHz

    initial begin
        rstn = 0;
        sw_i = 16'h0000;    // 左滚，不暂停
        #100;
        rstn = 1;

        // 跑足够久，让 move 时钟翻转几次
        #50_000_000;
        sw_i[0] = 1'b1;     // 改右滚
        #50_000_000;
        sw_i[2] = 1'b1;     // 暂停
        #20_000_000;
        $finish;
    end

    always @(disp_an_o) begin
        if (rstn)
            $display("[%0t] AN=%b SEG=%h LED=%b", $time, disp_an_o, disp_seg_o, led_o);
    end
endmodule
