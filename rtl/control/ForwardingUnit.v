
module ForwardingUnit(
    input [4:0]rs1_ex,
    input [4:0]rd_mem,
    input [4:0]rd_wb,
    input [4:0]rs2_ex,
    input Regwrite_mem,
    input Regwrite_wb,
    output reg [1:0]forwardA,
    output reg [1:0]forwardB



);
always @(*) begin
  if(Regwrite_mem && rd_mem != 5'd0 && rd_mem == rs1_ex)
    forwardA = 2'b10;
  else if (Regwrite_wb && rd_wb != 5'd0 && rd_wb == rs1_ex) begin
      forwardA = 2'b01;
    end
  else
      forwardA = 2'b00;

  if(Regwrite_mem && rd_mem != 5'd0 && rd_mem == rs2_ex)
    forwardB = 2'b10;
  else if (Regwrite_wb && rd_wb != 5'd0 && rd_wb == rs2_ex) begin
      forwardB = 2'b01;
    end
  else
      forwardB = 2'b00;    
  



        
  end





endmodule
