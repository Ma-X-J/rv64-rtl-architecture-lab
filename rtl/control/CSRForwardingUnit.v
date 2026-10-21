
module CSRForwardingUnit(
    input [11:0]CSR_addr_id,
    input [11:0]CSR_addr_ex,
    input [11:0]CSR_addr_mem,
    input valid_ex,
    input CSRWrite_ex,
    input valid_mem,
    input CSRWrite_mem,
    output reg [1:0]CSRForward_id


);
always @(*) begin
    if(valid_ex == 1'b1 && CSRWrite_ex == 1'b1 && CSR_addr_ex == CSR_addr_id)
      CSRForward_id = 2'b10;
    else if(valid_mem == 1'b1 && CSRWrite_mem == 1'b1 && CSR_addr_mem == CSR_addr_id)
        CSRForward_id = 2'b01;
    else
        CSRForward_id = 2'b00;
end








endmodule