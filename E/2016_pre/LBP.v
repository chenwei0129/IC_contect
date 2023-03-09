`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);

  input   	clk;
  input   	reset;
  output reg [13:0] 	gray_addr;
  output  reg    	gray_req;
  input   	gray_ready;
  input   [7:0] 	gray_data;
  output  [13:0] 	lbp_addr;
  output reg 	lbp_valid;
  output  [7:0] 	lbp_data;
  output reg finish;
//====================================================================
  parameter   RST    = 2'b00,
              COMP   = 2'b01,
              WRITE  = 2'b10,
              DONE   = 2'b11;
  
  reg [1:0] state;
  reg [1:0] n_state;
  
  reg [6:0] row;
  reg [6:0] col;
  reg [7:0] threshold;
  reg g [1:8];
  
  reg [3:0] counter;
  
  assign lbp_data = {g[8], g[7], g[6], g[5], g[4], g[3], g[2], g[1]};
  assign lbp_addr = {row, col};
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      state <= RST;
    end else begin
      state <= n_state;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      counter <= 4'd0;
    end else if(state!=n_state)begin
      counter <= 4'd0;
    end else begin
      counter <= counter + 4'd1;
    end
  end
  
  always@(posedge clk)begin
    if(state==RST)begin
      row <= 7'd1;
      col <= 7'd1;
    end else if(state==WRITE)begin
      if(col==7'd126)begin
        row <= row + 7'd1;
        col <= 7'd1;
      end else begin
        row <= row;
        col <= col + 7'd1;
      end
    end
  end
  
  always@(posedge clk)begin
    if(counter==4'd0)begin
      threshold <= gray_data;
    end
  end
  
  always@(posedge clk)begin
    g[counter] <= (gray_data>=threshold)?1'b1:1'b0;
  end
  
  always@(*)begin
    case(counter)
      4'd0:gray_addr = {row, col};
      4'd1:gray_addr = {row-7'd1, col-7'd1};
      4'd2:gray_addr = {row-7'd1, col};
      4'd3:gray_addr = {row-7'd1, col+7'd1};
      4'd4:gray_addr = {row, col-7'd1};
      4'd5:gray_addr = {row, col+7'd1};
      4'd6:gray_addr = {row+7'd1, col-7'd1};
      4'd7:gray_addr = {row+7'd1, col};
      4'd8:gray_addr = {row+7'd1, col+7'd1};
      default:gray_addr = 14'd0;
    endcase
  end
  
  always@(*)begin
    case(state)
      RST:begin
        gray_req = 1'b0;
        lbp_valid = 1'b0;
        finish = 1'b0;
        n_state = (gray_ready)?COMP:RST;
      end
      COMP:begin
        gray_req = 1'b1;
        lbp_valid = 1'b0;
        finish = 1'b0;
        n_state = (counter==4'd8)?WRITE:COMP;
      end
      WRITE:begin
        gray_req = 1'b0;
        lbp_valid = 1'b1;
        finish = 1'b0;
        n_state = (row==7'd126 && col==7'd126)?DONE:COMP;
      end
      DONE:begin
        gray_req = 1'b0;
        lbp_valid = 1'b0;
        finish = 1'b1;
        n_state = RST;
      end
      default:begin
        gray_req = 1'b0;
        lbp_valid = 1'b0;
        finish = 1'b0;
        n_state = RST;
      end
    endcase
  end
  
//====================================================================
endmodule
