
module Immgen(
    input [31:0]instruction,
    output reg [63:0]instruction64

);
   always @(*) begin
      case(instruction[6:0])
         7'b0000011:instruction64 = {{52{instruction[31]}},instruction[31:20]};
         7'b0100011:instruction64 = {{52{instruction[31]}},instruction[31:25],instruction[11:7]};
         7'b1100011:instruction64 = {{52{instruction[31]}},instruction[31], instruction[7], instruction[30:25], instruction[11:8]};
         7'b0010011:instruction64 = {{52{instruction[31]}},instruction[31:20]};
         7'b0011011:instruction64 = {{52{instruction[31]}},instruction[31:20]};
         7'b0110111:instruction64 = {{32{instruction[31]}}, instruction[31:12], 12'b0};
         7'b0010111:instruction64 = {{32{instruction[31]}}, instruction[31:12], 12'b0};
         7'b1101111:instruction64 = {{44{instruction[31]}},instruction[31],instruction[19:12],instruction[20],instruction[30:21]};
         7'b1100111:instruction64 = {{52{instruction[31]}},instruction[31:20]};
         default:instruction64 = 64'b0;
      endcase




   end






endmodule
