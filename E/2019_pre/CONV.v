
`timescale 1ns/10ps

module  CONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output reg [11:0] iaddr,
	input	[19:0]	idata,	
	
	output reg cwr,
	output reg [11:0] 	caddr_wr,
	output reg [19:0] 	cdata_wr,
	
	output reg crd,
	output reg [11:0] 	caddr_rd,
	input	 [19:0]	cdata_rd,
	
	output reg [2:0] 	csel
	);
  
  parameter RST   = 4'd0,
            READY = 4'd1,
            CONV_R0= 4'd2,
            CONV0  = 4'd3,
            CONV_W0  = 4'd4,
            MAX_R = 4'd5,
            MAX   = 4'd6,
            MAX_W   = 4'd7,
            WAIT = 4'd8,
            FC_R = 4'd9,
            FC = 4'd10,
            FC_W = 4'd11,
            DONE  = 4'd12;
  
  reg [3:0] state, n_state;
  reg [3:0] counter;
  reg signed [6:0] row, col;
  reg signed [19:0] ifmap;
  reg signed [19:0] weight;
  reg signed [39:0] answer_temp;
  reg signed [19:0] answer;
  reg conv0_done;
  reg conv1_done;
  reg max0_done;
  reg max1_done;
  reg signed [19:0] max_value;
  reg toggle;
  
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
    end else if(state!=n_state || counter==4'd10)begin
      counter <= 4'd0;
    end else begin
      counter <= counter + 4'd1;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      row <= -7'd1;
      col <= 7'd63;
    end else if(state==CONV_R0)begin
      if(row==7'd63 && col==7'd63)begin
        row <= 7'd0;
        col <= 7'd0;
      end else if(col==7'd63)begin
        row <= row + 7'd1;
        col <= 7'd0;
      end else begin
        row <= row;
        col <= col + 7'd1;
      end
    end else if(state==WAIT)begin
      row <= 7'd0;
      col <= -7'd2;
    end else if(state==MAX_R)begin
      if(row==7'd62 && col==7'd62)begin
        row <= 7'd0;
        col <= 7'd0;
      end else if(col==7'd62)begin
        row <= row + 7'd2;
        col <= 7'd0;
      end else begin
        row <= row;
        col <= col + 7'd2;
      end
    end
  end
  
  always@(posedge clk)begin
    case(counter)
      4'd0:iaddr <= {row[5:0]-6'd1, col[5:0]-6'd1};
      4'd1:iaddr <= {row[5:0]-6'd1, col[5:0]     };
      4'd2:iaddr <= {row[5:0]-6'd1, col[5:0]+6'd1};
      4'd3:iaddr <= {row[5:0]     , col[5:0]-6'd1};
      4'd4:iaddr <= {row[5:0]     , col[5:0]     };
      4'd5:iaddr <= {row[5:0]     , col[5:0]+6'd1};
      4'd6:iaddr <= {row[5:0]+6'd1, col[5:0]-6'd1};
      4'd7:iaddr <= {row[5:0]+6'd1, col[5:0]     };
      4'd8:iaddr <= {row[5:0]+6'd1, col[5:0]+6'd1};
      default:iaddr <= 12'd0;
    endcase
  end
  
  always@(posedge clk)begin
    if(state==WAIT || state==FC_R)begin
      caddr_rd <= 12'd0;
    end else if(state==FC_W && ~toggle)begin
      caddr_rd <= caddr_rd + 12'd1;
    end else if(n_state>=FC)begin
      caddr_rd <= caddr_rd;
    end else begin
      case(counter)
        4'd0:caddr_rd <= {row[5:0]     , col[5:0]     };
        4'd1:caddr_rd <= {row[5:0]     , col[5:0]+6'd1};
        4'd2:caddr_rd <= {row[5:0]+6'd1, col[5:0]     };
        4'd3:caddr_rd <= {row[5:0]+6'd1, col[5:0]+6'd1};
        default:caddr_rd <= 12'd0;
      endcase
    end
  end
  
  always@(posedge clk)begin
    crd <= 1'b1;
  end
  
  always@(posedge clk)begin
    case(counter)
      4'd1:ifmap <= (row==7'd0  || col==7'd0 )?20'd0:idata;
      4'd2:ifmap <= (row==7'd0               )?20'd0:idata;
      4'd3:ifmap <= (row==7'd0  || col==7'd63)?20'd0:idata;
      4'd4:ifmap <= (              col==7'd0 )?20'd0:idata;
      4'd5:ifmap <=                                  idata;
      4'd6:ifmap <= (              col==7'd63)?20'd0:idata;
      4'd7:ifmap <= (row==7'd63 || col==7'd0 )?20'd0:idata;
      4'd8:ifmap <= (row==7'd63 || col==7'd0 )?20'd0:idata;
      4'd9:ifmap <= (row==7'd63 || col==7'd63)?20'd0:idata;
      default:ifmap <= idata;
    endcase
  end
  
  always@(posedge clk)begin
    if(counter==4'd1)begin
      max_value <= cdata_rd;
    end else begin
      max_value <= (cdata_rd>max_value)?cdata_rd:max_value;
    end
  end
  
  always@(*)begin
    answer <= (answer_temp[39] && answer_temp[15])?{answer_temp[39], answer_temp[34:16]}-20'd1:
              (~answer_temp[39] && answer_temp[15])?{answer_temp[39], answer_temp[34:16]}+20'd1:
              {answer_temp[39], answer_temp[34:16]};
  end
  
  always@(posedge clk)begin
    if(state==CONV_W0)begin
      cdata_wr <= (answer[19])?20'd0:answer;
    end else if(state==MAX_W)begin
      cdata_wr <= max_value;
    end else if(state==FC)begin
      cdata_wr <= cdata_rd;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      caddr_wr <= 12'b1111_1111_1111;
    end else if(state==CONV_W0)begin
      caddr_wr <= caddr_wr + 12'd1;
    end else if(state==MAX_W)begin
      if(caddr_wr==12'd1023)begin
        caddr_wr <= 12'd0;
      end else begin
        caddr_wr <= caddr_wr + 12'd1;
      end
    end else if(state==FC_R)begin
      caddr_wr <= 12'd0;
    end else if(state==FC_W)begin
      caddr_wr <= caddr_wr + 12'd1;
    end
  end
  
  always@(posedge clk)begin
    cwr <= (state==CONV_W0 || state==MAX_W || state==FC)?1'b1:1'b0;
  end
  
  always@(posedge clk)begin
    csel <= (~conv0_done)?3'b001:
            (~conv1_done)?3'b010:
            (n_state==MAX && ~max0_done)?3'b001:
            (n_state==MAX && max0_done)?3'b010:
            (~max0_done)?3'b011:
            (~max1_done)?3'b100:
            (n_state==FC && ~toggle)?3'b011:
            (n_state==FC &&  toggle)?3'b100:
            (n_state==FC_W)?3'b101:
            3'b000;
  end
  
  always@(posedge clk)begin
    if(~conv0_done)begin
      case(counter)
        4'd1:weight <= 20'h0A89E;
        4'd2:weight <= 20'h092D5;
        4'd3:weight <= 20'h06D43;
        4'd4:weight <= 20'h01004;
        4'd5:weight <= 20'hF8F71;
        4'd6:weight <= 20'hF6E54;
        4'd7:weight <= 20'hFA6D7;
        4'd8:weight <= 20'hFC834;
        4'd9:weight <= 20'hFAC19;
        default:weight <= 20'd0;
      endcase
    end else begin
      case(counter)
        4'd1:weight <= 20'hFDB55;
        4'd2:weight <= 20'h02992;
        4'd3:weight <= 20'hFC994;
        4'd4:weight <= 20'h050FD;
        4'd5:weight <= 20'h02F20;
        4'd6:weight <= 20'h0202D;
        4'd7:weight <= 20'h03BD7;
        4'd8:weight <= 20'hFD369;
        4'd9:weight <= 20'h05E68;
        default:weight <= 20'd0;
      endcase
    end
  end
  
  always@(posedge clk)begin
    if(counter==4'd0 && state==CONV0)begin
      answer_temp <= (~conv0_done)?$signed({20'h01310, 16'd0}):$signed({20'hF7295, 16'd0});
    end else begin
      answer_temp <= answer_temp + ifmap*weight;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      conv0_done <= 1'b0;
    end else if(n_state==CONV_R0 && row==7'd63 && col==7'd63)begin
      conv0_done <= 1'b1;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      conv1_done <= 1'b0;
    end else if(state==WAIT && row==7'd63 && col==7'd63)begin
      conv1_done <= 1'b1;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      max0_done <= 1'b0;
    end else if(state==MAX_R && row==7'd62 && col==7'd62)begin
      max0_done <= 1'b1;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      max1_done <= 1'b0;
    end else if(state==WAIT && row==7'd62 && col==7'd62)begin
      max1_done <= 1'b1;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      toggle <= 1'b0;
    end else if(state==FC_R)begin
      toggle <= 1'b1;
    end else if(state==FC_W)begin
      toggle <= ~toggle;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      busy <= 1'b0;
    end else if(n_state==CONV_R0)begin
      busy <= 1'b1;
    end else if(n_state==DONE)begin
      busy <= 1'b0;
    end else begin
      busy <= busy;
    end
  end
  
  always@(*)begin
    case(state)
      RST:begin
        n_state = (~reset)?READY:RST;
        //busy = 1'b0;
      end
      READY:begin
        n_state = (ready)?CONV_R0:READY;
        //busy = 1'b0;
      end
      CONV_R0:begin
        n_state = CONV0;
        //busy = 1'b1;
      end
      CONV0:begin
        n_state = (counter==4'd10)?CONV_W0:
                  CONV0;
        //busy = 1'b1;
      end
      CONV_W0:begin
        n_state = (row==7'd63 && col==7'd63 && conv0_done)?WAIT:
                  CONV_R0;
        //busy = 1'b1;
      end
      WAIT:begin
        n_state = (max0_done)?FC_R:
                  MAX_R;
        //busy = 1'b1;
      end
      MAX_R:begin
        n_state = MAX;
        //busy = 1'b1;
      end
      MAX:begin
        n_state = (counter==4'd4)?MAX_W:
                  MAX;
        //busy = 1'b1;
      end
      MAX_W:begin
        n_state = (row==7'd62 && col==7'd62 && max0_done)?WAIT:
                  MAX_R;
        //busy = 1'b1;
      end
      FC_R:begin
        n_state = FC;
        //busy = 1'b1;
      end
      FC:begin
        n_state = FC_W;
        //busy = 1'b1;
      end
      FC_W:begin
        n_state = (caddr_wr==12'd2047)?DONE:
                  FC;
        //busy = 1'b1;
      end
      DONE:begin
        n_state = DONE;
        //busy = 1'b0;
      end
      default:begin
      
      end
    endcase
  end
endmodule




