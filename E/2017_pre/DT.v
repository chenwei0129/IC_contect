module DT(
	input 			clk, 
	input			reset,
	output	reg		done ,
	output	reg		sti_rd ,
	output	reg 	[9:0]	sti_addr ,
	input		[15:0]	sti_di,
	output	reg		res_wr ,
	output	reg		res_rd ,
	output	reg 	[13:0]	res_addr ,
	output	reg 	[7:0]	res_do,
	input		[7:0]	res_di
	);
  
  parameter RST             = 3'b000,
            WRITE_EDGE      = 3'b001,
            READ_STI        = 3'b010,
            WRITE_READ_BOTH = 3'b011,
            FORWRD_DONE     = 3'b100,
            WRITE_EDGE_BACK = 3'b101,
            READ_RES        = 3'b110,
            DONE            = 3'b111;
  
  reg [2:0] state;
  reg [2:0] n_state;
  
  reg [3:0] counter;
  
  reg [15:0] sti_di_reg;
  reg [7:0] compare_window [0:4];
  wire [7:0] t1;
  wire [7:0] t2;
  wire [7:0] t3;
  wire [7:0] answer_forward;
  wire [7:0] t4;
  wire [7:0] t5;
  wire [7:0] t6;
  wire [7:0] answer_back;
  wire [7:0] answer;
  
  reg [13:0] res_addr_write;
  reg [13:0] res_addr_read;
  
  assign t1 = (compare_window[0]<=compare_window[1])?compare_window[0]:compare_window[1];
  assign t2 = (compare_window[2]<=compare_window[3])?compare_window[2]:compare_window[3];
  assign t3 = (t1<=t2)?t1:t2;
  assign answer_forward = t3 + 8'd1;
  
  assign t4 = (compare_window[0]<=compare_window[1])?compare_window[0]:compare_window[1];
  assign t5 = (compare_window[2]<=compare_window[3])?compare_window[2]:compare_window[3];
  assign t6 = (t4<=t5)?t4:t5;
  assign answer_back = (compare_window[4]<=t6+8'd1)?compare_window[4]:t6+8'd1;
  
  assign answer = (state<=FORWRD_DONE)?answer_forward:answer_back;
  
  always@(posedge clk or negedge reset)begin
    if(~reset)begin
      state <= RST;
    end else begin
      state <= n_state;
    end
  end
  
  always@(posedge clk or negedge reset)begin
    if(~reset)begin
      counter <= 4'd0;
    end else if(state!=n_state)begin
      counter <= 4'd0;
    end else begin
      counter <= counter + 4'd1;
    end
  end
  
  always@(posedge clk)begin
    if(state==READ_STI && res_addr[6:0]==7'd0)begin
      compare_window[2] <= res_di;
      compare_window[4] <= sti_di[15];
      compare_window[1] <= 8'd0;
    end else if(state==WRITE_READ_BOTH)begin
      compare_window[3] <= res_do;
      compare_window[0] <= compare_window[1];
      compare_window[2] <= res_di;
      compare_window[4] <= sti_di_reg[4'd14-counter];
      compare_window[1] <= compare_window[2];
    end else if(state==WRITE_EDGE_BACK && res_addr[6:0]==7'd127)begin
      compare_window[1] <= 1'b0;
    end else if(state==READ_RES && counter[0]==1'b0)begin
      compare_window[3] <= res_do;
      compare_window[4] <= res_di;
    end else if(state==READ_RES && counter[0]==1'b1)begin
      compare_window[0] <= compare_window[1];
      compare_window[1] <= compare_window[2];
      compare_window[2] <= res_di;
    end
  end
  /*
  always@(posedge clk)begin
    if(state==RST)begin
      res_addr_write <= 14'd0;
    end else if(state==WRITE_EDGE || state==WRITE_READ_BOTH)begin
      res_addr_write <= res_addr_write + 14'd1;
    end else if(state==FORWRD_DONE)begin
      res_addr_write <= 14'd16383;
    end else if(state==WRITE_EDGE_BACK)begin
      res_addr_write <= res_addr_write - 14'd1;
    end else if(state==READ_RES && counter[0]==1'b0)begin
      res_addr_write <= res_addr_read;
    end
  end
  
  always@(posedge clk)begin
    if(state==WRITE_EDGE_BACK)begin
      res_addr_read <= 14'd16255;
    end else if(state==READ_RES && counter[0]==1'b0)begin
      res_addr_read <= res_addr_read + 14'd127;
    end else if(state==READ_RES && counter[0]==1'b1)begin
      res_addr_read <= res_addr_read - 14'd128;
    end
  end
  
  always@(posedge clk or negedge clk)begin
    if(clk)begin
      if(state==WRITE_READ_BOTH)begin
        res_addr <= res_addr_write - 14'd125;
      end else if(state<=FORWRD_DONE)begin
        res_addr <= res_addr_write - 14'd126;
      end else if(state==WRITE_EDGE_BACK)begin
        res_addr <= 14'd16255;
      end else if(state==READ_RES && counter[0]==1'b0)begin
        res_addr <= res_addr_read + 14'd127;
      end else if(state==READ_RES && counter[0]==1'b1)begin
        res_addr <= res_addr_read - 14'd128;
      end
    end else begin
      res_addr <= res_addr_write;
    end
  end
  */
  
  always@(posedge clk)begin
    if(state==RST)begin
      res_addr_write <= 14'd0;
    end else if(state==WRITE_EDGE || state==WRITE_READ_BOTH)begin
      res_addr_write <= res_addr_write + 14'd1;
    end else if(state==FORWRD_DONE)begin
      res_addr_write <= 14'd16383;
    end else if(state==WRITE_EDGE_BACK)begin
      res_addr_write <= res_addr_write - 14'd1;
    end else if(state==READ_RES && counter[0]==1'b0)begin
      res_addr_write <= res_addr_read - 14'd127;
    end
  end
  
  always@(negedge clk)begin
    if(state==WRITE_READ_BOTH && res_addr_write[6:0]!=7'd127)begin
      res_addr_read <= res_addr_write - 14'd125;
    end else if(state==WRITE_EDGE || state==READ_STI || state==WRITE_READ_BOTH&&res_addr_write[6:0]==7'd127)begin
      res_addr_read <= res_addr_write - 14'd126;
    end else if(state==WRITE_EDGE_BACK)begin
      res_addr_read <= 14'd16255;
    end else if(state==READ_RES && counter[0]==1'b0)begin
      res_addr_read <= res_addr_read + 14'd127;
    end else if(state==READ_RES && counter[0]==1'b1)begin
      res_addr_read <= res_addr_read - 14'd128;
    end
  end
  
  always@(*)begin
    if(~clk)begin/////////////////////////////confused//////////////////////
      res_addr = res_addr_read;
    end else begin
      res_addr = res_addr_write;
    end
  end
  
  always@(negedge clk)begin
    //if(state==WRITE_EDGE || state==WRITE_READ_BOTH || (state==READ_RES&&res_addr_read[6:0]<=7'd126))begin
    if(state==WRITE_EDGE || state==WRITE_READ_BOTH || (state==READ_RES&&res_addr[6:0]<=7'd126))begin
      res_wr <= 1'b1;
    end else begin
      res_wr <= 1'b0;
    end
  end
  
  always@(posedge clk)begin
    if(state==READ_STI)begin
      sti_di_reg <= sti_di;
    end
  end
  
  always@(negedge clk)begin
    //if(state==WRITE_EDGE || state<=FORWRD_DONE&&sti_di_reg[4'd15-counter]==1'b0 || state==WRITE_EDGE_BACK || (state==READ_RES&&compare_window[4]==4'd0))begin
    if(state==WRITE_EDGE || state<=FORWRD_DONE&&sti_di_reg[4'd15-counter]==1'b0 || state==WRITE_EDGE_BACK)begin
      res_do <= 8'd0;
    end else begin
      res_do <= answer;
    end
  end
  
  always@(posedge clk)begin
    if(state==RST)begin
      sti_addr <= 10'd8;
    end else if(state==READ_STI)begin
      sti_addr <= sti_addr + 10'd1;
    end
  end
  
  always@(*)begin
    case(state)
      RST:begin
        n_state = (reset)?WRITE_EDGE:RST;
        sti_rd = 1'b0;
        res_rd = 1'b0;
        done = 1'b0;
      end
      WRITE_EDGE:begin
        n_state = (res_addr_write==14'd16383)?FORWRD_DONE:
                  (res_addr_write==14'd127)?READ_STI:
                  WRITE_EDGE;
        sti_rd = 1'b0;
        res_rd = 1'b0;
        done = 1'b0;
      end
      READ_STI:begin
        n_state = WRITE_READ_BOTH;
        sti_rd = 1'b1;
        res_rd = 1'b1;
        done = 1'b0;
      end
      WRITE_READ_BOTH:begin
        n_state = (res_addr_write==14'd16255)?WRITE_EDGE:
                  (counter==4'd15)?READ_STI:
                  WRITE_READ_BOTH;
        sti_rd = 1'b0;
        res_rd = 1'b1;
        done = 1'b0;
      end
      FORWRD_DONE:begin
        n_state = WRITE_EDGE_BACK;
        sti_rd = 1'b0;
        res_rd = 1'b0;
        done = 1'b0;
      end
      ////////////////////////////////
      WRITE_EDGE_BACK:begin
        n_state = (res_addr_write==14'd0)?DONE:
                  (res_addr_write==14'd16256)?READ_RES:
                  WRITE_EDGE_BACK;
        sti_rd = 1'b0;
        res_rd = 1'b0;
        done = 1'b0;
      end
      READ_RES:begin
        n_state = (res_addr_write==14'd128)?WRITE_EDGE_BACK:
                  READ_RES;
        sti_rd = 1'b0;
        res_rd = 1'b1;
        done = 1'b0;
      end
      DONE:begin
        n_state = RST;
        sti_rd = 1'b0;
        res_rd = 1'b0;
        done = 1'b1;
      end
      default:begin
        n_state = RST;
        sti_rd = 1'b0;
        res_rd = 1'b0;
        done = 1'b0;
      end
    endcase
  end
  
endmodule
