module SET(clk, rst, en, central, radius, mode, busy, valid, candidate);

  parameter RST    = 2'b00,//reset state
            READY  = 2'b01,//ready state
            COMP   = 2'b10,//compute state
            DONE   = 2'b11;//done state

  input clk;
  input rst;
  input en;
  input [23:0] central;
  input [11:0] radius;
  input [1:0] mode;
  
  output reg busy;
  output reg valid;
  output reg [7:0] candidate;
  
  reg [1:0] state;//current state
  reg [1:0] n_state;//next state
  reg [3:0] x;//從1~8，一點一點慢慢檢查
  reg [3:0] y;//從1~8，一點一點慢慢檢查
  reg [3:0] x_A;//圓A圓心之x座標
  reg [3:0] y_A;//圓A圓心之y座標
  reg [3:0] x_B;//圓B圓心之x座標
  reg [3:0] y_B;//圓B圓心之y座標
  reg [3:0] x_C;//圓C圓心之x座標
  reg [3:0] y_C;//圓C圓心之y座標
  wire [3:0] x_dis_A;//x到圓A圓心之x座標
  wire [3:0] y_dis_A;//y到圓A圓心之y座標
  wire [3:0] x_dis_B;//x到圓B圓心之x座標
  wire [3:0] y_dis_B;//y到圓B圓心之y座標
  wire [3:0] x_dis_C;//x到圓C圓心之x座標
  wire [3:0] y_dis_C;//y到圓C圓心之y座標
  reg [7:0] r_sq_A;//圓A半徑平方
  reg [7:0] r_sq_B;//圓B半徑平方
  reg [7:0] r_sq_C;//圓C半徑平方
  reg [1:0] mode_reg;//儲存mode
  
  wire is_in_A;//是否在A集合
  wire is_in_B;//是否在B集合
  wire is_in_C;//是否在C集合
  reg match;//是否符合條件
  
  //計算目前座標距離各圓心的x,y距離
  assign x_dis_A = (x>x_A)?x-x_A:x_A-x;
  assign y_dis_A = (y>y_A)?y-y_A:y_A-y;
  assign x_dis_B = (x>x_B)?x-x_B:x_B-x;
  assign y_dis_B = (y>y_B)?y-y_B:y_B-y;
  assign x_dis_C = (x>x_C)?x-x_C:x_C-x;
  assign y_dis_C = (y>y_C)?y-y_C:y_C-y;
  
  //判斷是否在各集合中
  assign is_in_A = ((x_dis_A*x_dis_A + y_dis_A*y_dis_A)<=r_sq_A)?1'b1:1'b0;
  assign is_in_B = ((x_dis_B*x_dis_B + y_dis_B*y_dis_B)<=r_sq_B)?1'b1:1'b0;
  assign is_in_C = ((x_dis_C*x_dis_C + y_dis_C*y_dis_C)<=r_sq_C)?1'b1:1'b0;
  
  always@(posedge clk or posedge rst)begin
    if(rst)begin
      state <= RST;
    end else begin
      state <= n_state;
    end
  end
  
  //移動座標，從1~8，一點一點慢慢移動
  always@(posedge clk)begin
    if(state==READY && n_state==COMP)begin
      x <= 4'd1;
      y <= 4'd1;
    end else begin
      if(x==4'd8)begin
        x <= 4'd1;
        y <= y + 4'd1;
      end else begin
        x <= x + 4'd1;
        y <= y;
      end
    end
  end
  
  //在en時，讀取資料(三圓之圓心，半徑之平方)
  always@(posedge clk)begin
    if(en)begin
      x_A <= central[23:20];
      y_A <= central[19:16];
      x_B <= central[15:12];
      y_B <= central[11:8];
      x_C <= central[7:4];
      y_C <= central[3:0];
      r_sq_A <= radius[11:8] * radius[11:8];
      r_sq_B <= radius[7:4] * radius[7:4];
      r_sq_C <= radius[3:0] * radius[3:0];
    end else begin
      x_A <= x_A;
      y_A <= y_A;
      x_B <= x_B;
      y_B <= y_B;
      x_C <= x_C;
      y_C <= y_C;
      r_sq_A <= r_sq_A;
      r_sq_B <= r_sq_B;
      r_sq_C <= r_sq_C;
    end
  end
  
  always@(posedge clk)begin
    if(en)begin
      mode_reg <= mode;
    end
  end
  
  always@(posedge clk)begin
    if(state==READY)begin
      candidate <= 8'd0;
    end else if(match)begin
      candidate <= candidate + 8'd1;
    end
  end
  
  always@(*)begin
    case(mode_reg)
      2'b00:begin
        match = is_in_A;
      end
      2'b01:begin
        match = is_in_A & is_in_B;
      end
      2'b10:begin
        match = is_in_A ^ is_in_B;
      end
      2'b11:begin
        match = (is_in_A&is_in_B&(!is_in_C)) || (is_in_B&is_in_C&(!is_in_A)) || (is_in_C&is_in_A&(!is_in_B));
      end
      default:begin
        match = 1'b0;
      end
    endcase
  end
  
  always@(*)begin
    case(state)
      RST:begin
        busy = 1'b0;
        valid = 1'b0;
        n_state = (en)?READY:RST;
      end
      READY:begin
        busy = 1'b1;
        valid = 1'b0;
        n_state = COMP;
      end
      COMP:begin
        busy = 1'b1;
        valid = 1'b0;
        n_state = (x==4'd8 && y==4'd8)?DONE:COMP;
      end
      DONE:begin
        busy = 1'b0;
        valid = 1'b1;
        n_state = RST;
      end
    endcase
  end
  
endmodule