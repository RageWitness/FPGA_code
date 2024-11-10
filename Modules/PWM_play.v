/*///////////////////////////////////////////////////////////////////////
 pwm_clk = sampling rate * accuracy(LOD) * carrier frequency  (USE PLL)

in this project:  sampling rate = 16KHz  , accuracy(LOD) = 4095 (12bit) , carrier frequency = 32KHz

!!!! pwm_data should be sent in at sampling frequency 
*/
module PWM_play#(parameter LOD = 4095 )(
        input pwm_clk,
        input [15:0] pwm_data,  //16bit depth sampling data
        output reg audio_out 
);
    
    wire [31:0] temp_data; 
    wire [11:0] mapped_data;
    wire [11:0] pwm_door; 


    assign temp_data = pwm_data * LOD;  //16 Mapping 12 bit (1)
    assign mapped_data = (temp_data + 32768) >> 16; //16 Mapping 12 bit (2)
    assign pwm_door = LOD - mapped_data;   //calualte door of pwm

    reg[11:0] pwm_counter = 1;

    //pwm control 
    always @(posedge pwm_clk) begin
       if (pwm_counter < LOD) begin
            if (pwm_counter >= pwm_door ) begin
                audio_out <=1;
            end else begin
                audio_out <=0;
            end
            pwm_counter <= pwm_counter + 1;
       end else begin
        pwm_counter <=1;
        audio_out<=0;
       end
    end
    

endmodule
