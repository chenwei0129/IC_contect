`timescale 1ns/10ps
module GPSDC(clk, reset_n, DEN, LON_IN, LAT_IN, COS_ADDR, COS_DATA, ASIN_ADDR, ASIN_DATA, Valid, a, D);

  input              clk;
  input              reset_n;
  input              DEN;
  input      [23:0]  LON_IN;//8, 16
  input      [23:0]  LAT_IN;//8, 16
  input      [95:0]  COS_DATA;//x(16, 32), y(16, 32)
  output reg [6:0]   COS_ADDR;
  input      [127:0] ASIN_DATA;//x(0, 64), y(0, 64)
  output reg [5:0]   ASIN_ADDR;
  output reg         Valid;
  output     [39:0]  D;//8, 32
  output     [63:0]  a;//0, 64
  
  reg [3:0] state;
  reg [3:0] n_state;
  
  reg signed [24:0] LON_reg_past;//(1, 8, 16)
  reg signed [24:0] LAT_reg_past;//(1, 8, 16)
  reg signed [24:0] LON_reg_new;//(1, 8, 16)
  reg signed [24:0] LAT_reg_new;//(1, 8, 16)
  reg [47:0] cos_x0;//16, 32
  reg [47:0] cos_y0;//16, 32
  reg [47:0] cos_x1;//16, 32
  reg [47:0] cos_y1;//16, 32
  wire [95:0] cos_x0_ex;//16+16, 32+32
  wire [95:0] cos_y0_ex;//16+16, 32+32
  wire [95:0] cos_x1_ex;//16+16, 32+32
  wire [95:0] cos_y1_ex;//16+16, 32+32
  reg [191:0] cos_a;//(16+16)×2, (32+32)×2, 有效位數96(32, 64)
  reg [191:0] cos_b;//(16+16)×2, (32+32)×2, 有效位數96(32, 64)
  
  reg [63:0] asin_x0;//0, 64
  reg [63:0] asin_y0;//0, 64
  reg [63:0] asin_x1;//0, 64
  reg [63:0] asin_y1;//0, 64
  wire [127:0] asin_x0_ex;//0+0, 64+64
  wire [127:0] asin_y0_ex;//0+0, 64+64
  wire [127:0] asin_x1_ex;//0+0, 64+64
  wire [127:0] asin_y1_ex;//0+0, 64+64
  
  //計算sin^2的中介值
  //signed 1 +24 = 25
  //25+16 = 41
  //41*2 = 82
  wire signed [40:0] temp1;
  wire signed [40:0] temp2;
  wire signed [40:0] sin1;
  wire signed [40:0] sin2;
  wire signed [81:0] sin1_sq;
  wire signed [81:0] sin2_sq;//((8, 16)+(0, 16))*2 = 80
  reg  signed [15:0] rad;
  reg [207:0] a_temp;//64(cos_a)+64(cos_b)+80(sin2_sq)
  
  reg [23:0] R;
  reg [255:0] D_temp1;//(0+0)×2, (64+64)×2, 有效位數128(0, 128)
  wire [151:0] D_temp2;//(0+24), 128取(8, 32)
  
  parameter   RST       = 4'b0000,
              INIT1     = 4'b0001,
              SEARCH1   = 4'b0010,
              WAIT      = 4'b0011,
              SEARCH2   = 4'b0100,
              CAL1      = 4'b0101,
              CAL2      = 4'b0110,
              SEARCH3   = 4'b0111,
              CAL3      = 4'b1000,
              DONE      = 4'b1001;
  
  assign cos_x0_ex = {16'd0, cos_x0, 32'd0};
  assign cos_y0_ex = {16'd0, cos_y0, 32'd0};
  assign cos_x1_ex = {16'd0, cos_x1, 32'd0};
  assign cos_y1_ex = {16'd0, cos_y1, 32'd0};
  
  assign asin_x0_ex = {asin_x0, 64'd0};
  assign asin_y0_ex = {asin_y0, 64'd0};
  assign asin_x1_ex = {asin_x1, 64'd0};
  assign asin_y1_ex = {asin_y1, 64'd0};
  
  always@(posedge clk or negedge reset_n)begin
    if(~reset_n)begin
      state <= RST;
    end else begin
      state <= n_state;
    end
  end
  
  always@(posedge clk)begin
    if(state==INIT1 && DEN)begin
      LAT_reg_new <= {1'b0, LAT_IN};
      LON_reg_new <= {1'b0, LON_IN};
    end else if(state==WAIT && DEN)begin
      LAT_reg_past <= LAT_reg_new;
      LON_reg_past <= LON_reg_new;
      LAT_reg_new <= {1'b0, LAT_IN};
      LON_reg_new <= {1'b0, LON_IN};
    end
  end
  
  always@(posedge clk)begin
    if(state==INIT1 || state==WAIT)begin
      COS_ADDR <= 7'd0;
    end else if(n_state==SEARCH1 || n_state==SEARCH2)begin
      COS_ADDR <= COS_ADDR + 7'd1;
    end
  end
  
  //搜尋cos內插使用值
  always@(posedge clk)begin
    if(DEN)begin
      cos_x1 <= 48'd0;
    end else if(n_state==SEARCH1 || n_state==SEARCH2)begin
      cos_x1 <= COS_DATA[95:48];
      cos_y1 <= COS_DATA[47:0];
      cos_x0 <= cos_x1;
      cos_y0 <= cos_y1;
    end
  end
  
  ////////////////計算a/////////////////
  //計算a準確至小數點64位
  assign a = a_temp[191:128];
  //計算sin^2
  //assign rad = 16'h477;
  always@(posedge clk)begin
    if(~reset_n)begin
      rad = 16'h477;
    end
  end
  
  assign temp1 = (LAT_reg_new-LAT_reg_past)*rad;
  assign temp2 = (LON_reg_new-LON_reg_past)*rad;
  assign sin1 = (temp1[39])?(temp1+$signed(40'd1))>>>1:temp1>>>1;
  assign sin2 = (temp2[39])?(temp2+$signed(40'd1))>>>1:temp2>>>1;
  assign sin1_sq = sin1*sin1;
  assign sin2_sq = sin2*sin2;
  //計算兩個cos，其中一個cos為另一個cos舊的值，直接assign
  //cos_a為舊的值，cos_b為新的值
  always@(posedge clk)begin
    if(state==CAL1 || state==WAIT)begin
      cos_b <= (cos_y0_ex*(cos_x1_ex-cos_x0_ex)+({24'd0, LAT_reg_new, 48'd0}-cos_x0_ex)*(cos_y1_ex-cos_y0_ex))/(cos_x1_ex-cos_x0_ex);
    end
  end
  always@(posedge clk)begin
    if(state==CAL1)begin
      cos_a <= cos_b;
    end
  end
  //計算a精確值(a_temp)
  always@(posedge clk)begin
    if(state==CAL2)begin
      a_temp <= {sin1_sq[79:0], 128'd0} + cos_a[63:0]*cos_b[63:0]*sin2_sq[79:0];
    end
  end
  
  always@(posedge clk)begin
    if(state==CAL2)begin
      ASIN_ADDR <= 6'd0;
    end else begin
      ASIN_ADDR <= ASIN_ADDR + 6'd1;
    end
  end
  
  //搜尋asin內插使用值
  always@(posedge clk)begin
    if(state==CAL2)begin
      asin_x1 <= 64'd0;
    end else if(n_state==SEARCH3)begin
      asin_x1 <= ASIN_DATA[127:64];
      asin_y1 <= ASIN_DATA[63:0];
      asin_x0 <= asin_x1;
      asin_y0 <= asin_y1;
    end
  end
  
  assign D = D_temp2[135:96];
  assign D_temp2 = D_temp1 * R;
  //assign R = 24'd12756274;
  always@(posedge clk)begin
    if(~reset_n)begin
      R = 24'd12756274;
    end
  end
  
  always@(posedge clk)begin
    if(state==CAL3)begin
      D_temp1 <= ((asin_y0_ex*(asin_x1_ex-asin_x0_ex)+({a, 64'd0}-asin_x0_ex)*(asin_y1_ex-asin_y0_ex))/(asin_x1_ex-asin_x0_ex));
    end
  end
  
  //////FSM////////
  always@(*)begin
    case(state)
      RST:begin
        n_state = INIT1;
        Valid = 1'b0;
      end
      INIT1:begin
        n_state = (DEN)?SEARCH1:INIT1;
        Valid = 1'b0;
      end
      SEARCH1:begin
        n_state = (cos_x1>{LAT_reg_new, 16'd0})?WAIT:SEARCH1;
        Valid = 1'b0;
      end
      WAIT:begin
        n_state = (DEN)?SEARCH2:WAIT;
        Valid = 1'b0;
      end
      SEARCH2:begin
        n_state = (cos_x1>{LAT_reg_new, 16'd0})?CAL1:SEARCH2;
        Valid = 1'b0;
      end
      CAL1:begin
        n_state = CAL2;
        Valid = 1'b0;
      end
      CAL2:begin
        n_state = SEARCH3;
        Valid = 1'b0;
      end
      SEARCH3:begin
        n_state = (asin_x1>a)?CAL3:SEARCH3;
        Valid = 1'b0;
      end
      CAL3:begin
        n_state = DONE;
        Valid = 1'b0;
      end
      DONE:begin
        n_state = WAIT;
        Valid = 1'b1;
      end
      default:begin
        n_state = RST;
        Valid = 1'b0;
      end
    endcase
  end
  
endmodule
