module TPA(clk, reset_n, 
	   SCL, SDA, 
	   cfg_req, cfg_rdy, cfg_cmd, cfg_addr, cfg_wdata, cfg_rdata);
input 		clk; 
input 		reset_n;
// Two-Wire Protocol slave interface 
input 		SCL;  
inout		SDA;

// Register Protocal Master interface 
input		cfg_req;
output		cfg_rdy;
input		cfg_cmd;
input	[7:0]	cfg_addr;
input	[15:0]	cfg_wdata;
output	[15:0]  cfg_rdata;

reg	[15:0] Register_Spaces	[0:255];

// ===== Coding your RTL below here ================================= 
  parameter  RST             = 4'b0000,
             RIM_READY       = 4'b0001,
			 RIM_EX          = 4'b0010,
			 TWP_READY       = 4'b0011,
			 TWP_ADDR        = 4'b0100,
			 TWP_DATA        = 4'b0101,
			 TWP_EX          = 4'b0110,
			 TWP_WAIT        = 4'b0111,
			 TWP_READY_READ  = 4'b1000,
			 TWP_EX_READ     = 4'b1001;
  
  reg cfg_rdy;
  reg [15:0] cfg_rdata;
  
  reg RIM_cmd_reg;
  reg [3:0] RIM_state;
  reg [3:0] RIM_n_state;
  reg [3:0] TWP_state;
  reg [3:0] TWP_n_state;
  reg [3:0] counter;
  reg TWP_cmd_reg;
  reg [7:0] TWP_addr;
  reg [15:0] TWP_data;
  reg [7:0] TWP_can_write;
  reg [7:0] addr;
  
  always@(posedge clk)begin
    if(TWP_state==RST)begin
      TWP_can_write <= 8'd0;
    end else if(TWP_state<=TWP_EX)begin
      TWP_can_write <= TWP_can_write + (cfg_req==1'b1&&cfg_cmd==1'b1);
      addr <= (cfg_req==1'b1&&cfg_cmd==1'b1)?cfg_addr:8'bz;
    end
  end
  
  always@(posedge clk or negedge reset_n)begin
    if(~reset_n)begin
	  RIM_state <= RST;
	  TWP_state <= RST;
	end
	else begin
	  RIM_state <= RIM_n_state;
	  TWP_state <= TWP_n_state;
	end
  end
  
  always@(posedge clk)begin
    if(RIM_state==RST && cfg_req==1'b1)
	  RIM_cmd_reg <= cfg_cmd;
  end
  
  always@(posedge SCL or negedge reset_n)begin
    if(~reset_n)
	  counter <= 4'd0;
	else if(TWP_state!=TWP_n_state)
	  counter <= 4'd0;
	else
	  counter <= counter + 4'd1;
  end
  
  always@(posedge SCL)begin
    if(TWP_state==TWP_READY)
	  TWP_cmd_reg <= SDA;
  end
  
  always@(posedge SCL)begin
    if(TWP_state==TWP_ADDR)
      TWP_addr[counter] <= SDA;
  end
  
  always@(posedge SCL)begin
    if(TWP_state==TWP_DATA)
	  TWP_data[counter] <= SDA;
  end
  
  always@(posedge clk)begin
	if(RIM_n_state==RIM_EX && RIM_cmd_reg==1'b1)
	  Register_Spaces[cfg_addr] <= cfg_wdata;
	if(TWP_state==TWP_EX && (TWP_can_write==8'd0 || (addr!=TWP_addr)))
	  Register_Spaces[TWP_addr] <= TWP_data;
  end
  
  assign SDA = (TWP_state==TWP_READY_READ)?1'b0:
               (TWP_state==TWP_EX_READ)?Register_Spaces[TWP_addr][counter]:
			   1'bz;
    
  always@(*)begin
    case(RIM_state)
      RST:begin
	    cfg_rdy = 1'b0;
	    cfg_rdata = 16'd0;
	    RIM_n_state = (cfg_req)?RIM_READY:RST;
	  end
      RIM_READY:begin
	    cfg_rdy = 1'b1;
	    cfg_rdata = 16'd0;
	    RIM_n_state = RIM_EX;
	  end
      RIM_EX:begin
	    cfg_rdy = 1'b1;
	    cfg_rdata = (RIM_cmd_reg==1'b0)?Register_Spaces[cfg_addr]:16'd0;
	    RIM_n_state = RST;
	  end
	  default:begin
	    cfg_rdy = 1'b0;
	    cfg_rdata = 16'd0;
	    RIM_n_state = RST;
	  end
	endcase
  end
  
  always@(*)begin
    case(TWP_state)
	  RST:
	    TWP_n_state = (SDA==1'b0)?TWP_READY:RST;
	  TWP_READY:
	    TWP_n_state = TWP_ADDR;
	  TWP_ADDR:
	    TWP_n_state = (counter==4'd7 && TWP_cmd_reg==1'b1)?TWP_DATA:
		              (counter==4'd7 && TWP_cmd_reg==1'b0)?TWP_WAIT:
					  TWP_ADDR;
	  TWP_DATA:
	    TWP_n_state = (counter==4'd15)?TWP_EX:TWP_DATA;
	  TWP_EX:
	    TWP_n_state = RST;
	  TWP_WAIT:
	    TWP_n_state = (counter==4'd2)?TWP_READY_READ:TWP_WAIT;
	  TWP_READY_READ:
	    TWP_n_state = TWP_EX_READ;
      TWP_EX_READ:
	    TWP_n_state = (counter==4'd15)?RST:TWP_EX_READ;
      default:
	    TWP_n_state = RST;
	endcase
  end

endmodule