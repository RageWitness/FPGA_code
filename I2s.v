module I2s (
    input clk;
    input [15:0] left;
    input [15:0] right;
    output reg din;
    output reg sck;
    output reg ws;
);
    reg [5:0] div_sck_counter =0;
    
    always @(posedge clk) begin      //44 div ->sck (44.117 actually)
        if (div_sck_counter > 43) begin
            div_sck_counter <= 0;
        end
        else if (div_sck_counter == 43) begin
            sck <= ~sck;   //toggle sck
            div_sck_counter <= 0;
        end else begin
        div_sck_counter <= div_sck_counter + 1;
        end
    end

    reg [4:0] div_ws =0;

    always @(negedge sck) begin  //17 div -> ws
        if (div_ws > 16) begin
            div_ws <= 0;
        end 
        else if (div_ws == 16) begin
            ws <= ~ws;      //toggle ws
            div_ws <= 0;
        end else begin
            div_ws <= div_ws +1;
        end
    end

    reg [15:0] l2c; reg [15:0] r2c; // output buff
    
    always @(negedge ws) begin
        l2c <= left;    //new data send in, waiting to be sent
        r2c <= right;
    end

    always @(negedge sck) begin
        
        if (div_ws > 16) begin
            din <= 0;
        end else if (div_ws == 16) begin
            din <= 0;
        end else begin
            din <= ws? r2c[15-div_ws]:l2c[15-div_ws];
        end

    end


endmodule
