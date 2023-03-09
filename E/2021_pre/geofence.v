module geofence ( clk,reset,X,Y,valid,is_inside);
  
  input clk;
  input reset;
  input [9:0] X;
  input [9:0] Y;
  output reg valid;
  output reg is_inside;
  
  parameter RST    = 3'b000,
            GET    = 3'b001,
            SORT   = 3'b010,
            DETECT = 3'b011,
            VALID  = 3'b100;
  
  reg [9:0] DUT_X;
  reg [9:0] DUT_Y;
  
  reg [9:0] receiver_x [0:5];
  reg [9:0] receiver_y [0:5];
  
  reg [2:0] counter;
  
  reg [2:0] state;
  reg [2:0] n_state;
  
  reg [2:0] index1;
  reg [2:0] index2;
  
  wire signed [10:0] x0;
  wire signed [10:0] y0;
  wire signed [10:0] x1;
  wire signed [10:0] y1;
  wire signed [10:0] x2;
  wire signed [10:0] y2;
  
  wire signed [10:0] Ax;
  wire signed [10:0] Ay;
  wire signed [10:0] Bx;
  wire signed [10:0] By;
  
  wire signed [20:0] mul_Ax_By;
  wire signed [20:0] mul_Ay_Bx;
  
  assign x0 = (state==SORT)?{1'b0, receiver_x[0]}:{1'b0, DUT_X};
  assign y0 = (state==SORT)?{1'b0, receiver_y[0]}:{1'b0, DUT_Y};
  assign x1 = {1'b0, receiver_x[index1]};
  assign y1 = {1'b0, receiver_y[index1]};
  assign x2 = {1'b0, receiver_x[index2]};
  assign y2 = {1'b0, receiver_y[index2]};
  
  assign Ax = x1 - x0;
  assign Ay = y1 - y0;
  assign Bx = x2 - x0;
  assign By = y2 - y0;
  
  assign mul_Ax_By = Ax * By;
  assign mul_Ay_Bx = Ay * Bx;
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      state <= RST;
    end else begin
      state <= n_state;
    end
  end
  
  always@(posedge clk)begin
    if(state==RST)begin
      counter <= 3'd0;
    end else if(state!=n_state)begin
      counter <= 3'd0;
    end else begin
      counter <= counter + 3'd1;
    end
  end
  
  always@(posedge clk)begin
    if(state==RST)begin
      DUT_X <= X;
      DUT_Y <= Y;
    end
  end
  
  always@(posedge clk)begin
    if(state==GET)begin
      receiver_x[counter] <= X;
      receiver_y[counter] <= Y;
    end else if(state==SORT && mul_Ax_By>mul_Ay_Bx)begin
      receiver_x[index1] <= x2[9:0];
      receiver_y[index1] <= y2[9:0];
      receiver_x[index2] <= x1[9:0];
      receiver_y[index2] <= y1[9:0];
    end
  end
  /*
  always@(posedge clk)begin
    if(state==GET)begin
      index1 <= 3'd1;
      index2 <= 3'd2;
    end else if(state==SORT && n_state==DETECT)begin
      index1 <= 3'd0;
      index2 <= 3'd1;
    end else if(state==DETECT)begin
      index1 <= index1 + 3'd1;
      index2 <= (index2==3'd5)?3'd0:index2 + 3'd1;
    end else if(index2==3'd5)begin
      index1 <= index1 + 3'd1;
      index2 <= index1 + 3'd2;
    end else begin
      index1 <= index1;
      index2 <= index2 + 3'd1;
    end
  end
  */
  always@(posedge clk)begin
    if(state==GET)begin
      index1 <= 3'd1;
    end else if(state==SORT && n_state==DETECT)begin
      index1 <= 3'd0;
    end else if(state==DETECT || index2==3'd5)begin
      index1 <= index1 + 3'd1;
    end else begin
      index1 <= index1;
    end
  end
  
  always@(posedge clk)begin
    if(state==GET)begin
      index2 <= 3'd2;
    end else if(state==SORT && n_state==DETECT)begin
      index2 <= 3'd1;
    end else if(state==DETECT)begin
      index2 <= (index2==3'd5)?3'd0:index2 + 3'd1;
    end else if(index2==3'd5)begin
      index2 <= index1 + 3'd2;
    end else begin
      index2 <= index2 + 3'd1;
    end
  end
  
  always@(posedge clk)begin
    if(mul_Ax_By<mul_Ay_Bx && index1==3'd5)begin
      is_inside <= 1'b1;
    end else begin
      is_inside <= 1'b0;
    end
  end
  
  always@(*)begin
    case(state)
      RST:begin
        valid = 1'b0;
        n_state = GET;
      end
      GET:begin
        valid = 1'b0;
        n_state = (counter==3'd5)?SORT:GET;
      end
      SORT:begin
        valid = 1'b0;
        n_state = (index1==3'd4 && index2==3'd5)?DETECT:SORT;
      end
      DETECT:begin
        valid = 1'b0;
        n_state = (mul_Ax_By>mul_Ay_Bx || index1==3'd5)?VALID:DETECT;
      end
      VALID:begin
        valid = 1'b1;
        n_state = RST;
      end
      default:begin
        valid = 1'b0;
        n_state = RST;
      end
    endcase
  end
  
endmodule

