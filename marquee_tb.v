// 跑马灯简易仿真（观察扫描与往返、PWM 调光）
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
        sw_i = 16'b000_000_0_00;  // 全开关下 = 最亮、不暂停、最快
        #100;
        rstn = 1;

        // 最亮档跑一段
        #50_000_000;

        // 调暗
        sw_i[5:3] = 3'b011;  // 中等亮度
        #50_000_000;

        // 改慢速
        sw_i[1:0] = 2'b11;
        #50_000_000;

        // 暂停
        sw_i[2] = 1'b1;
        #20_000_000;
        $finish;
    end

    always @(disp_an_o) begin
        if (rstn)
            $display("[%0t] AN=%b SEG=%h LED=%04x duty=%b", $time, disp_an_o, disp_seg_o, led_o, sw_i[5:3]);
    end
endmodule
