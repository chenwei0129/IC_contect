module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
  input clk;
  input reset;
  input [7:0] chardata;
  input isstring;
  input ispattern;
  output match;
  output [4:0] match_index;
  output valid;
  
  reg match;
  reg [4:0] match_index;
  reg valid;
  
  parameter RST        = 4'd0,
            GET_STR    = 4'd1,
            GET_PAT    = 4'd2,
            DECIDE_EX  = 4'd3,
            NOTHING    = 4'd4,
            NOTHING_EQ = 4'd5,
            HEAD       = 4'd6,
            HEAD_EQ    = 4'd7,
            REPEAT     = 4'd8,
            REPEAT_HEAD= 4'd9,
            OUTPUT     = 4'd10;
  
  reg [7:0] str [0:31];
  reg [7:0] pat [0:7];
  
  reg [3:0] state, state_next;
  reg [5:0] counter, counter_str, counter_pat;
  reg [1:0] op;
  reg star;
  reg [5:0] jump;
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      state <= RST;
    end else begin
      state <= state_next;
    end
  end
  
  always@(posedge clk)begin
    if(state==GET_PAT)begin
      jump <= 6'd31;
    end else if(state==REPEAT || state==REPEAT_HEAD)begin
      jump <= jump - 6'd1;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      counter <= 6'd0;
    end else if(state!=state_next && (state<=4'd3 || state>=REPEAT))begin
      counter <= 6'd0;
    end else if(state==NOTHING_EQ && state_next==NOTHING || state==HEAD_EQ && state_next==HEAD)begin
      counter <= match_index + 5'd1;
    end else begin
      counter <= ((state==NOTHING_EQ&&pat[counter_pat]==8'h2A || state==HEAD_EQ&&pat[counter_pat+6'd1]==8'h2A)&&star)?counter + jump:counter + 6'd1;
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      counter_pat <= 6'd0;
    end else if(state_next==NOTHING || state_next==HEAD)begin
      counter_pat <= 6'd0;
    end else begin
      counter_pat <= counter_pat + 6'd1;
    end
  end
  
  always@(posedge clk)begin
    if(state_next==GET_PAT && state!=GET_PAT)begin
      star <= 1'b0;
    end else if(state_next==GET_PAT)begin
      if(chardata==8'h2A)begin
        star <= 1'b1;
      end
    end
  end
  
  integer i;
  always@(posedge clk)begin
    if(state_next==GET_STR)begin
      if(state!=GET_STR)begin
        str[0] <= chardata;
        for(i=1;i<=31;i=i+1)begin
          str[i] <= 8'd0;
        end
      end else begin
        str[counter+6'd1] <= chardata;
      end
    end
  end
  
  always@(posedge clk)begin
    if(state_next==GET_PAT || state_next==DECIDE_EX)begin
      case(chardata)
        8'h5E:op <= (op==2'd2)?2'd0:op;
        8'h2A:op <= (op==2'd2)?2'd1:op;
        default:op <= (op==2'd2)?2'd2:op;
      endcase
    end else begin
      op <= 2'd2;
    end
  end
  
  always@(posedge clk)begin
    if(state_next==GET_PAT)begin
      if(state!=GET_PAT)begin
        pat[0] <= chardata;
        for(i=1;i<=7;i=i+1)begin
          pat[i] <= 8'd0;
        end
      end else begin
        pat[counter+6'd1] <= chardata;
      end
    end
  end
  
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      match_index <= 5'd0;
    end else if(state==NOTHING && state_next==NOTHING_EQ || state==HEAD && state_next==HEAD_EQ)begin
      match_index <= counter;
    end
  end
  
  always@(posedge clk)begin
    if(state_next==OUTPUT)begin
      valid <= 1'b1;
    end else begin
      valid <= 1'b0;
    end
  end
  
  always@(posedge clk)begin
    if(state_next==OUTPUT && (state==NOTHING_EQ || state==HEAD_EQ))begin
      match <= 1'b1;
    end else begin
      match <= 1'b0;
    end
  end
  
  always@(*)begin
    case(state)
      RST:begin
        state_next = (isstring)?GET_STR:RST;
      end
      GET_STR:begin
        state_next = (~isstring && ispattern)?GET_PAT:GET_STR;
      end
      GET_PAT:begin
        state_next = (~ispattern)?DECIDE_EX:GET_PAT;
      end
      DECIDE_EX:begin
        state_next = (op==2'd0)?HEAD:
                     //(op==2'd1)?MANY:
                     NOTHING;
      end
      NOTHING:begin
        state_next = ((str[counter]==8'd0 || counter>=6'd32)&&jump>6'd0&&star)?REPEAT:
                     ((str[counter]==8'd0 || counter>=6'd32))?OUTPUT:
                     (str[counter]==pat[counter_pat] || pat[counter_pat]==8'h2E)?NOTHING_EQ:
                     NOTHING;
      end
      NOTHING_EQ:begin
        state_next = (pat[counter_pat]==8'd0 || counter_pat==6'd8 || (pat[counter_pat]==8'h24&&(counter==6'd32||str[counter]==8'h20||str[counter]==8'd0)))?OUTPUT:
                     (counter>=6'd32)?REPEAT:
                     (str[counter]==pat[counter_pat] || pat[counter_pat]==8'h2E || pat[counter_pat]==8'h2A || (str[counter]==8'h20 || str[counter]==8'd0)&&pat[counter_pat]==8'h24)?NOTHING_EQ:
                     NOTHING;
      end
      HEAD:begin
        state_next = ((str[counter]==8'd0 || counter>=6'd32)&&jump>6'd0&&star)?REPEAT_HEAD:
                     ((str[counter]==8'd0 || counter>=6'd32))?OUTPUT:
                     (counter==8'd0 || (str[counter-6'd1]==8'h20 && (str[counter]==pat[counter_pat+6'd1] || pat[counter_pat+6'd1]==8'h2E)))?HEAD_EQ:
                     HEAD;
      end
      HEAD_EQ:begin
        state_next = (pat[counter_pat+6'd1]==8'd0 || counter_pat==6'd7 || (pat[counter_pat+6'd1]==8'h24&&(counter==6'd32||str[counter]==8'h20||str[counter]==8'd0)))?OUTPUT:
                     (counter>=6'd32)?REPEAT_HEAD:
                     (str[counter]==pat[counter_pat+6'd1] || pat[counter_pat+6'd1]==8'h2E || pat[counter_pat+6'd1]==8'h2A || (str[counter]==8'h20 || str[counter]==8'd0)&&pat[counter_pat+6'd1]==8'h24)?HEAD_EQ:
                     HEAD;
      end
      REPEAT:begin
        state_next = NOTHING;
      end
      REPEAT_HEAD:begin
        state_next = HEAD;
      end
      OUTPUT:begin
        state_next = (isstring)?GET_STR:GET_PAT;
      end
      default:begin
        state_next = RST;
      end
    endcase
  end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
endmodule
