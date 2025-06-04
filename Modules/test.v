`timescale 1ns/1ps
module tb_spi_master;
    reg clk, cs_n, mosi;
    wire miso;
    spi_slave_param dut(
        .sclk(clk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso)
    );

    // 10 MHz SPI 时钟：时隙=100ns
    initial clk = 0;
    always #50 clk = ~clk;

    // SPI 读/写一个字节：MSB first
    // 行为：每个时钟下降沿把 mosi 设好，紧接着上升沿采 miso
    task spi_byte(input  [7:0] din, output [7:0] dout);
        integer i;
        begin
            dout = 8'h00;
            for (i = 7; i >= 0; i = i - 1) begin
                mosi <= din[i];
                @(negedge clk);        // 先把 mosi 推到 slave
                @(posedge clk); dout[i] <= miso;  // 上升沿采样 miso
            end
        end
    endtask

    // 发送一次 “同步头(0x7E,0x7E) + TAG + DATA”
    task spi_cmd(input [7:0] tag, input [7:0] data);
        reg [7:0] dummy;
        begin
            cs_n <= 1'b0;               // 拉低片选
            spi_byte(8'h7E, dummy);
            spi_byte(8'h7E, dummy);
            spi_byte(tag , dummy);
            spi_byte(data, dummy);
            cs_n <= 1'b1;               // 结束该命令
            repeat (20) @(posedge clk); // 空闲一段时间
        end
    endtask

    integer i;
    reg [7:0] rcv;
    initial begin
        // 先把寄存器清 0（避免 X）
        for (i = 0; i < 8; i = i + 1)
            dut.regs[i] = 8'h00;

        // 等待形稳
        cs_n = 1'b1; mosi = 1'b0;
        repeat (10) @(posedge clk);

        // 依次写 regs[0]~regs[7]
        for (i = 0; i < 8; i = i + 1) begin
            spi_cmd(i[7:0], (8'h11 << i));  
            // 比如写 regs[0]=0x11, regs[1]=0x22, 0x11 0x22 0x44 0x88 0x10 0x20 0x40 0x80
        end

        // 发起反馈命令（TAG=0x88, DATA 随意填）
        cs_n <= 1'b0;
        spi_byte(8'h7E, rcv);
        spi_byte(8'h7E, rcv);
        spi_byte(8'h88, rcv);
        spi_byte(8'h00, rcv);
        // 然后连续 8 字节读出 regs[0]~regs[7]
        for (i = 0; i < 8; i = i + 1)
            spi_byte(8'h00, rcv);

        cs_n <= 1'b1;
        #1000 $stop;   // 使用 $stop 使 ModelSim 不会自动退出
    end
endmodule

