
`timescale 1ns/10ps

module  CONV(
	input		clk,
	input		reset,
	output reg busy,	
	input		ready,	
			
	output	[11:0] iaddr,
	input signed [19:0] idata,	
	
	output reg  cwr,
	output reg [11:0] caddr_wr,
	output signed [19:0] cdata_wr,
	
	output reg  crd,
	output reg [11:0] caddr_rd,
	input signed [19:0] cdata_rd,
	
	output reg [2:0] csel
	);

  parameter     RST         = 3'b000,
                READY_CONV  = 3'b001,
				CONV        = 3'b010,
				WRITE_CONV  = 3'b011,
				READY_MAX   = 3'b100,
				MAX         = 3'b101,
				WRITE_MAX   = 3'b110,
				DONE        = 3'b111;
  
  reg signed [39:0] cdata_wr_temp;
  reg [3:0] counter;
  reg [2:0] state;
  reg [2:0] n_state;
  reg signed [7:0] row_temp;
  reg signed [7:0] col_temp;
  reg signed [19:0] max_temp;
  
  reg signed [19:0] WEIGHT [0:9];
  reg signed [19:0] BIAS;
  
  wire [5:0] row;
  wire [5:0] col;
  wire boundary;
  wire signed [19:0] pixel_in;
  wire signed [19:0] weight;
  wire [19:0] relu_round_result;
  wire signed [39:0] conv_temp1;
  wire signed [39:0] conv_temp2;
  
  assign boundary = (&row_temp || row_temp[6] || &col_temp || col_temp[6])?1'b1:1'b0;//等於-1或64
  assign pixel_in = (boundary)?20'd0:idata;
  assign weight = WEIGHT[counter];
  
  //經過relu以及四捨五入後的結果
  assign relu_round_result = (cdata_wr_temp[39])?20'd0:
                             (cdata_wr_temp[15])?cdata_wr_temp[35:16] + 20'd1:
                                                 cdata_wr_temp[35:16];
  //決定寫入記憶體的資料為conv或是max pooling的結果
  assign cdata_wr = (state==WRITE_MAX)?max_temp:
                                       relu_round_result;
                    
  //zero padding 所需，計算讀取的記憶體位置
  assign row = row_temp[5:0];
  assign col = col_temp[5:0];
  assign iaddr = {row, col};
  
  //初始化權重以及bias
  always@(posedge clk or posedge reset)begin
    if(reset)begin
	  WEIGHT[0] <= 20'h0A89E;
	  WEIGHT[1] <= 20'h092D5;
	  WEIGHT[2] <= 20'h06D43;
	  WEIGHT[3] <= 20'h01004;
	  WEIGHT[4] <= 20'hF8F71;
	  WEIGHT[5] <= 20'hF6E54;
	  WEIGHT[6] <= 20'hFA6D7;
	  WEIGHT[7] <= 20'hFC834;
	  WEIGHT[8] <= 20'hFAC19;
	  WEIGHT[9] <= 20'h00000;
	  BIAS <= 20'h01310;
	end
	else begin
	  WEIGHT[0] <= WEIGHT[0];
	  WEIGHT[1] <= WEIGHT[1];
	  WEIGHT[2] <= WEIGHT[2];
	  WEIGHT[3] <= WEIGHT[3];
	  WEIGHT[4] <= WEIGHT[4];
	  WEIGHT[5] <= WEIGHT[5];
	  WEIGHT[6] <= WEIGHT[6];
	  WEIGHT[7] <= WEIGHT[7];
	  WEIGHT[8] <= WEIGHT[8];
	  WEIGHT[9] <= WEIGHT[9];
	  BIAS <= BIAS;
	end
  end

  
  always@(posedge clk or posedge reset)begin
    if(reset)
	  state <= RST;
	else
	  state <= n_state;
  end
  
  always@(posedge clk)begin
    if(n_state==READY_CONV || n_state==READY_MAX)
	  counter <= 4'd0;
	else
	  counter <= counter + 4'd1;
  end
  //開始進行conv以及max pooling時，將寫入的記憶體位置歸零
  always@(posedge clk)begin
    if(state==RST || (state==WRITE_CONV&&n_state==READY_MAX))
	  caddr_wr <= 12'd0;
	else if(state==WRITE_CONV || state==WRITE_MAX)
	  caddr_wr <= caddr_wr + 12'd1;
  end
  
  always@(posedge clk)begin
    if(state==RST && n_state==READY_CONV)begin
	  row_temp <= 8'b1111_1111;
	  col_temp <= 8'b1111_1111;
	end
	else if(counter==4'd8 && caddr_wr[5:0]==6'b111111)begin
	  row_temp <= row_temp - 8'd1;
	  col_temp <= 8'b1111_1111;
	end
	else if(counter==4'd8)begin
	  row_temp <= row_temp - 8'd2;
	  col_temp <= col_temp - 8'd1;
	end
	else if (counter==4'd2 || counter==4'd5)begin
	  row_temp <= row_temp + 8'd1;
	  col_temp <= col_temp - 8'd2;
	end
	else if(counter<4'd9)begin
	  row_temp <= row_temp;
	  col_temp <= col_temp + 8'd1;
	end
  end
  /////////////////////////////////////////////////////////////////////////////////////////////
  assign conv_temp1 = (state==READY_CONV || state==CONV)?(pixel_in*weight):
                                                         cdata_wr_temp;
  assign conv_temp2 = (state==READY_CONV)?{4'b0000, BIAS, 16'b0000_0000_0000_0000}:
                      (state==CONV)?cdata_wr_temp:
					  40'd0;
  always@(posedge clk)begin
	cdata_wr_temp <= conv_temp1 + conv_temp2;
  end
  /*
  always@(posedge clk)begin
    if(state==READY_CONV)
	  cdata_wr_temp <= (pixel_in*weight) + {4'b0000, BIAS, 16'b0000_0000_0000_0000};
	else if(state==CONV)
	  cdata_wr_temp <= cdata_wr_temp + (pixel_in*weight);
  end
  */
  always@(posedge clk)begin
    if(state==WRITE_CONV)
	  caddr_rd <= 12'd0;
	else if(counter<4'd4) begin
	  if(&caddr_rd[6:0] || ~counter[0])
	    caddr_rd <= caddr_rd + 12'd1;
	  else if(~counter[1])
	    caddr_rd <= caddr_rd + 12'd63;
	  else if(counter[1])
	    caddr_rd <= caddr_rd - 12'd63;
	end
  end
  
  always@(posedge clk)begin
    if(counter==4'd0)
	  max_temp <= cdata_rd;
	else begin
	  if(cdata_rd>max_temp)
	    max_temp <= cdata_rd;
	end
  end
  //防止合成後，busy訊號震盪，將其從下下方的always block獨立出來
  always@(*)begin
    busy = (state==RST || state==DONE)?1'b0:1'b1;
  end
  
  always@(*)begin
    case(state)
	  RST:begin
	    //busy = 1'b0;
		cwr = 1'b0;
		crd = 1'b0;
		csel = 3'b000;
		n_state = (ready)?READY_CONV:RST;
	  end
	  READY_CONV:begin
	    //busy = 1'b1;
		cwr = 1'b0;
		crd = 1'b0;
		csel = 3'b000;
		n_state = CONV;
	  end
	  CONV:begin
	    //busy = 1'b1;
		cwr = 1'b0;
		crd = 1'b0;
		csel = 3'b000;
		n_state = (counter==4'd8)?WRITE_CONV:CONV;
	  end
	  WRITE_CONV:begin
	    //busy = 1'b1;
		cwr = 1'b1;
		crd = 1'b0;
		csel = 3'b001;
		n_state = (caddr_wr==12'd4095)?READY_MAX:READY_CONV;
	  end
	  READY_MAX:begin
	    //busy = 1'b1;
		cwr = 1'b0;
		crd = 1'b1;
		csel = 3'b001;
		n_state = MAX;
	  end
	  MAX:begin
	    //busy = 1'b1;
		cwr = 1'b0;
		crd = 1'b1;
		csel = 3'b001;
		n_state = (counter==4'd3)?WRITE_MAX:MAX;
	  end
	  WRITE_MAX:begin
	    //busy = 1'b1;
		cwr = 1'b1;
		crd = 1'b0;
		csel = 3'b011;
		n_state = (caddr_wr==12'd1023)?DONE:READY_MAX;
	  end
	  DONE:begin
	    //busy = 1'b0;
		cwr = 1'b0;
		crd = 1'b0;
		csel = 3'b000;
		n_state = DONE;
	  end
	endcase
  end
  
endmodule