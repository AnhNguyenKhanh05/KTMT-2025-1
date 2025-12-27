// Mở rộng dấu từ 16-bit lên 32-bit
module SignExtend (
    input  [15:0] in, // 16 bit thấp của lệnh
    output [31:0] out
);
    // Lấy bit dấu (bit 15) đắp vào 16 bit cao
    assign out = {{16{in[15]}}, in};
endmodule


// Dịch trái 2 bit (thêm 00 vào cuối)
module ShiftLeft2 (
    input  [31:0] in,
    output [31:0] out
);
    assign out = {in[29:0], 2'b00};
endmodule


// Nối từ SignExtend sang ShiftLeft2
module OffsetProcessor (
    input  [15:0] instr_15_0,
    output [31:0] processed_offset
);
    wire [31:0] sign_ext_to_shift; // Dây nối

    SignExtend my_sign_ext (   // Gọi SignExtend
        .in(instr_15_0),
        .out(sign_ext_to_shift)
    );

    ShiftLeft2 my_shift_left (   // Gọi ShiftLeft2
        .in(sign_ext_to_shift),
        .out(processed_offset)
    );
endmodule


// Tính toán địa chỉ Branch (ID Stage)
module BranchAddrCalc (
    input  [31:0] PC_plus_4_ID,   // PC+4 truyền từ giai đoạn IF sang ID
    input  [15:0] instr_15_0,   // Nhận 16 bit thấp của lệnh
    output [31:0] Branch_Addr   // Địa chỉ đích để quay về Mux của PC
);
    wire [31:0] branch_offset_final;

    OffsetProcessor my_offset_proc (
        .instr_15_0(instr_15_0),
        .processed_offset(branch_offset_final)
    );

    // Bộ cộng địa chỉ Branch
    assign Branch_Addr = PC_plus_4_ID + branch_offset_final;

endmodule


// PC và Mux (IF Stage)
module PC_Stage (
    input wire clk,
    input wire reset,
    input wire PCWrite,   // Tín hiệu từ Hazard Detection Unit (1 chạy, 0 dừng)
    input wire [1:0] PCSrc,   // Tín hiệu điều khiển chọn địa chỉ (00 PC+4, 01 Branch, 10 Jump)
    input wire [31:0] Branch_Addr,   // Địa chỉ từ bộ cộng Branch
    input wire [31:0] Jump_Addr,   // Địa chỉ từ Jump logic
    
    output reg [31:0] Current_PC,  // Giá trị PC hiện tại đưa vào IM
    output wire [31:0] PC_plus_4   // Giá trị PC+4 đưa vào pipeline register
);

    reg [31:0] Next_pc;

    // Bộ cộng PC + 4 (Tuần tự mặc định)
    assign PC_plus_4 = Current_PC + 4;

    // Bộ Mux chọn Next_PC (Xử lý Jump và Branch): Dựa trên tín hiệu điều khiển PCSrc
    always @(*) begin
        case (PCSrc)
            2'b01:   Next_pc = Branch_Addr; // Chọn đường nhảy Branch
            2'b10:   Next_pc = Jump_Addr;   // Chọn đường nhảy Jump
            default: Next_pc = PC_plus_4;   // Mặc định đi thẳng (00 hoặc các TH khác)
        endcase
    end

    // Cập nhật thanh ghi PC
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            Current_PC <= 32'h0000_0000;
        end 
        else if (PCWrite) begin 
            // Nếu không có Hazard (PCWrite = 1), cập nhật PC mới
            Current_PC <= Next_pc;
        end
        // Nếu PCWrite = 0, Current_PC giữ nguyên giá trị (Stall)
    end

endmodule
