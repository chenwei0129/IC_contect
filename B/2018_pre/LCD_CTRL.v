module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
  
  //FSM parameter
  parameter    RST    = 3'b000,
               READ   = 3'b001,
               READY  = 3'b010,//busy 0，receive command
			   BUSY   = 3'b011,//busy 1，execute command
			   DONE   = 3'b100;
  
  //command
  parameter    WRITE   = 4'b0000,
               S_UP    = 4'b0001,//shift up
			   S_DOWN  = 4'b0010,//shift down
			   S_LEFT  = 4'b0011,//shift left
			   S_RIGHT = 4'b0100,//shift right
			   MAX     = 4'b0101,//get maximum
			   MIN     = 4'b0110,//get minimum
			   AVE     = 4'b0111,//get average
			   C_ROT   = 4'b1000,//counterclockwise rotation
			   ROT     = 4'b1001,//clockwise rotation
			   M_X     = 4'b1010,//mirror X axis
			   M_Y     = 4'b1011;//mirror Y axis

  input clk;
  input reset;
  input [3:0] cmd;
  input cmd_valid;
  input [7:0] IROM_Q;

  output reg IROM_rd;
  output reg [5:0] IROM_A;
  output reg IRAM_valid;
  output reg [7:0] IRAM_D;
  output reg [5:0] IRAM_A;
  output reg busy;
  output reg done;
  
  reg [2:0] state;
  reg [2:0] n_state;
  reg [3:0] cmd_reg;
  reg [5:0] counter;
  reg [7:0] data [0:63];
  reg [2:0] row;
  reg [2:0] col;
  
  wire [7:0] max_temp1;
  wire [7:0] max_temp2;
  wire [7:0] max;
  wire [7:0] min_temp1;
  wire [7:0] min_temp2;
  wire [7:0] min;
  wire [9:0] ave;
  wire [7:0] p1;
  wire [7:0] p2;
  wire [7:0] p3;
  wire [7:0] p4;
  reg [7:0] p1_new;
  reg [7:0] p2_new;
  reg [7:0] p3_new;
  reg [7:0] p4_new;
  
  
  
  /*
  執行指令
  shift up/down/left/right
  若為其他指令則保持原值(不須加上default)
  */
  always@(posedge clk or posedge reset)begin
    if(reset)begin
	  row <= 3'd4;
	  col <= 3'd4;
	end
	else if(state==BUSY)begin
	  case(cmd_reg)
	    S_UP:begin
		  row <= (row==3'd1)?row:
		         row - 3'd1;
		  col <= col;
		end
		S_DOWN:begin
		  row <= (row==3'd7)?row:
		         row + 3'd1;
		  col <= col;
		end
		S_LEFT:begin
		  row <= row;
		  col <= (col==3'd1)?col:
		         col - 3'd1;
		end
		S_RIGHT:begin
		  row <= row;
		  col <= (col==3'd7)?col:
		         col + 3'd1;
		end
	  endcase
	end
  end
  
  //選出要執行指令的4個pixels
  assign p1 = data[{row-3'd1, col-3'd1}];
  assign p2 = data[{row-3'd1, col}];
  assign p3 = data[{row, col-3'd1}];
  assign p4 = data[{row, col}];
  
  /*
  執行指令
  max / min / average / counterclockwise rotation / clockwise rotation / mirror x / mirror y
  所有指令皆在一個cycle執行完畢
  並決定執行指令後的4個pixels
  若為其他指令則保持原值(不須加上default)
  */
  assign max_temp1 = (p1>p2)?p1:p2;
  assign max_temp2 = (p3>p4)?p3:p4;
  assign max = (max_temp1>max_temp2)?max_temp1:max_temp2;
  
  assign min_temp1 = (p1<p2)?p1:p2;
  assign min_temp2 = (p3<p4)?p3:p4;
  assign min = (min_temp1<min_temp2)?min_temp1:min_temp2;
  
  assign ave = (p1 + p2 + p3 + p4)>>2;
  
  always@(*)begin
    case(cmd_reg)
  	  MAX:begin
	    p1_new <= max;
	    p2_new <= max;
	    p3_new <= max;
	    p4_new <= max;
	  end
	  MIN:begin
	    p1_new <= min;
	    p2_new <= min;
	    p3_new <= min;
	    p4_new <= min;
	  end
	  AVE:begin
	    p1_new <= ave;
	    p2_new <= ave;
	    p3_new <= ave;
	    p4_new <= ave;
	  end
	  C_ROT:begin
	    p1_new <= p2;
	    p2_new <= p4;
	    p3_new <= p1;
	    p4_new <= p3;
	  end
	  ROT:begin
	    p1_new <= p3;
	    p2_new <= p1;
	    p3_new <= p4;
	    p4_new <= p2;
	  end
	  M_X:begin
	    p1_new <= p3;
	    p2_new <= p4;
	    p3_new <= p1;
	    p4_new <= p2;
	  end
	  M_Y:begin
	    p1_new <= p2;
	    p2_new <= p1;
	    p3_new <= p4;
	    p4_new <= p3;
	  end
	  default:begin
	    p1_new <= p1;
	    p2_new <= p2;
	    p3_new <= p3;
	    p4_new <= p4;
	  end
    endcase
  end
  //將執行指令後的新pixels存回data reg
  always@(posedge clk)begin
    if(state==READ)begin
	  data[counter] <= IROM_Q;
	end
    else if(state==BUSY)begin
	  data[{row-3'd1, col-3'd1}] <= p1_new;
	  data[{row-3'd1, col}]      <= p2_new;
	  data[{row, col-3'd1}]      <= p3_new;
	  data[{row, col}]           <= p4_new;
	end
  end
  
  //FSM
  always@(posedge clk or posedge reset)begin
    if(reset)
	  state <= RST;
	else
	  state <= n_state;
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)
	  counter <= 6'd0;
	else if((state==READY&&n_state==BUSY) || (state==RST&&n_state==READ))
	  counter <= 6'd0;
	else
	  counter <= counter + 6'd1;
  end
  
  always@(posedge clk)begin
    if(cmd_valid)
	  cmd_reg <= cmd;
  end
  
  /*
  busy的default為1，READY階段時為0以接收cmd，接收到有效指令時再變為1
  */
  always@(posedge clk or posedge reset)begin
    if(reset)
	  busy <= 1'b1;
	else if(cmd_valid)
	  busy <= 1'b1;
	else if(n_state==READY)
	  busy <= 1'b0;
	else
	  busy <= 1'b1;
  end
  
  always@(*)begin
    case(state)
	  RST:begin
	    IROM_rd = 1'b0;
        IROM_A = 6'd0;
        IRAM_valid = 1'b0;
        IRAM_D = 8'd0;
        IRAM_A = 6'd0;
        done = 1'b0;
		n_state = READ;
	  end
	  READ:begin
	    IROM_rd = 1'b1;
        IROM_A = counter;
        IRAM_valid = 1'b0;
        IRAM_D = 8'd0;
        IRAM_A = 6'd0;
        done = 1'b0;
		n_state = (counter==6'd63)?READY:READ;
	  end
	  READY:begin
	    IROM_rd = 1'b0;
        IROM_A = 6'd0;
        IRAM_valid = 1'b0;
        IRAM_D = 8'd0;
        IRAM_A = 6'd0;
        done = 1'b0;
		n_state = (cmd_valid)?BUSY:READY;
	  end
	  BUSY:begin
	    IROM_rd = 1'b0;
        IROM_A = 6'd0;
        IRAM_valid = (cmd_reg==WRITE)?1'b1:1'b0;
        IRAM_D = data[counter];
        IRAM_A = counter;
        done = 1'b0;
		n_state = (cmd_reg!=WRITE)?READY:
		          (counter==63)?DONE:
				  BUSY;
	  end
	  DONE:begin
	    IROM_rd = 1'b0;
        IROM_A = 6'd0;
        IRAM_valid = 1'b0;
        IRAM_D = 8'd0;
        IRAM_A = 6'd0;
        done = 1'b1;
		n_state = DONE;
	  end
	  default:begin
	    IROM_rd = 1'b0;
        IROM_A = 6'd0;
        IRAM_valid = 1'b0;
        IRAM_D = 8'd0;
        IRAM_A = 6'd0;
        done = 1'b0;
		n_state = RST;
	  end
	endcase
  end

endmodule
