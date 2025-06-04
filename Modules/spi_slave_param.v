`timescale 1ns/1ps
module spi_slave_param
(
    input  wire sclk,    // SPI 时钟，CPOL=0, CPHA=0
    input  wire cs_n,    // 片选，低有效
    input  wire mosi,    // 主机发 从机收
    output reg  miso     // 从机发 主机收，高阻或有效
);

    // ------------------------------------------------------
    // 状态机定义（5 个状态）
    //   0 = WAIT1   ：等待第一个 0x7E
    //   1 = WAIT2   ：已经收到一个 0x7E，等待第二个 0x7E
    //   2 = READ_TAG：收到两个 0x7E 后，这里接收 TAG 字节
    //   3 = READ_DAT：接收 DATA 字节（或进入反馈模式）
    //   4 = FEEDBACK：TAG=0x88 时进入，从 regs[0] … regs[7] 回送
    // ------------------------------------------------------
    localparam WAIT1    = 3'd0;
    localparam WAIT2    = 3'd1;
    localparam READ_TAG = 3'd2;
    localparam READ_DAT = 3'd3;
    localparam FEEDBACK = 3'd4;

    reg [2:0]  state;       // 当前状态
    reg [2:0]  bit_cnt;     // 接收位计数 0~7
    reg [7:0]  shift_reg;   // 接收移位寄存器（7:0 用来拼 byte）
    reg [7:0]  byte_rcv;    // 一字节接收完成后锁存：{shift_reg[6:0], mosi}
    reg [7:0]  tag_byte;    // 存 TAG 字节
    reg [7:0]  data_byte;   // 存 DATA 字节（若 TAG!=0x88，则写入 regs）
    reg [7:0]  regs [7:0];  // 8 个参数寄存器
    reg [2:0]  fb_ptr;      // 反馈指针 0~7

    // ------------------------------------------------------
    // 下降沿推出下一位到 miso
    //   - cs_n = 1 时：高阻
    //   - state=FEEDBACK 时：逐位输出 regs[fb_ptr]
    // ------------------------------------------------------
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            miso   <= 1'bz;
            fb_ptr <= 3'd0;
        end else if (state == FEEDBACK) begin
            // 每个时钟周期 bit_cnt=0..7，按 MSB first 从 regs[fb_ptr] 推出
            miso <= regs[fb_ptr][7 - bit_cnt];
        end
    end

    // ------------------------------------------------------
    // 上升沿采样 MOSI，累积到 shift_reg；bit_cnt 0~7 循环
    // 收满 1 字节 (bit_cnt==7) 时：
    //   - 拼 byte_rcv
    //   - 根据当前 state 做状态转换
    //   - 收完后 清 bit_cnt
    // ------------------------------------------------------
    always @(posedge sclk or posedge cs_n) begin
        if (cs_n) begin
            state    <= WAIT1;
            bit_cnt  <= 3'd0;
            shift_reg<= 8'd0;
            byte_rcv <= 8'd0;
            tag_byte <= 8'd0;
            data_byte<= 8'd0;
            // regs 永远保持之前写入的值（上电后会有 X，可以在 testbench 里先清零或依次写入）
        end
        else begin
            // 先把新 bit 推到 shift_reg
            shift_reg <= { shift_reg[6:0], mosi };

            if (bit_cnt == 3'd7) begin
                // 拼接出一个完整字节
                byte_rcv <= { shift_reg[6:0], mosi };

                // 一字节到来，基于原 state 做转移
                case (state)
                    WAIT1: begin
                        if ({ shift_reg[6:0], mosi } == 8'h7E)
                            state <= WAIT2;
                        else
                            state <= WAIT1;
                    end

                    WAIT2: begin
                        if ({ shift_reg[6:0], mosi } == 8'h7E)
                            state <= READ_TAG;
                        else begin
                            // 如果不是第二个 0x7E，但自身又是 0x7E，可以保持 WAIT2
                            if ({ shift_reg[6:0], mosi } == 8'h7E)
                                state <= WAIT2;
                            else
                                state <= WAIT1;
                        end
                    end

                    READ_TAG: begin
                        tag_byte <= { shift_reg[6:0], mosi };
                        state    <= READ_DAT;
                    end

                    READ_DAT: begin
                        data_byte <= { shift_reg[6:0], mosi };
                        if (tag_byte == 8'h88) begin
                            // 进入反馈模式
                            fb_ptr <= 3'd0;
                            state  <= FEEDBACK;
                        end else begin
                            // 写回寄存器（仅当 tag_byte 在 0x00~0x07 范围内）
                            if (tag_byte < 8'h08) begin
                                regs[tag_byte[2:0]] <= { shift_reg[6:0], mosi };
                            end
                            state <= WAIT1;  // 写完一个包，回去重新找同步头
                        end
                    end

                    FEEDBACK: begin
                        if (fb_ptr == 3'd7) begin
                            state <= WAIT1;   // 8 字节都发完了，回到最初等待下一个同步头
                        end
                        fb_ptr <= fb_ptr + 1'b1;
                    end

                    default: state <= WAIT1;
                endcase

                bit_cnt <= 3'd0;  // 收满一字节后清 0
            end
            else begin
                bit_cnt <= bit_cnt + 1'b1;
            end
        end
    end
endmodule

