//
// TV80 8-Bit Microprocessor Core
// Based on the VHDL T80 core by Daniel Wallner (jesus@opencores.org)
//
// Copyright (c) 2004 Guy Hutchison (ghutchis@opencores.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation 
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module tv80_mcode_cb
  (/*AUTOARG*/
  // Outputs
  output_vector, 
  // Inputs
  IR, MCycle
  );
  
  parameter             Mode   = 0;
  parameter             Flag_C = 0;
  parameter             Flag_N = 1;
  parameter             Flag_P = 2;
  parameter             Flag_X = 3;
  parameter             Flag_H = 4;
  parameter             Flag_Y = 5;
  parameter             Flag_Z = 6;
  parameter             Flag_S = 7;

  output [67:0]         output_vector;
  
  input [7:0]           IR;
  input [6:0]           MCycle                  ;

  // regs
  reg [2:0]             MCycles                 ;
  reg [2:0]             TStates                 ;
  reg [1:0]             Prefix                  ; // None,BC,ED,DD/FD
  reg                   Inc_PC                  ;
  reg                   Inc_WZ                  ;
  reg [3:0]             IncDec_16               ; // BC,DE,HL,SP   0 is inc
  reg                   Read_To_Reg             ;
  reg                   Read_To_Acc             ;
  reg [3:0]             Set_BusA_To     ; // B,C,D,E,H,L,DI/DB,A,SP(L),SP(M),0,F
  reg [3:0]             Set_BusB_To     ; // B,C,D,E,H,L,DI,A,SP(L),SP(M),1,F,PC(L),PC(M),0
  reg [3:0]             ALU_Op                  ;
  reg                   Save_ALU                ;
  reg                   PreserveC               ;
  reg                   Arith16                 ;
  reg [2:0]             Set_Addr_To             ; // aNone,aXY,aIOA,aSP,aBC,aDE,aZI
  reg                   IORQ                    ;
  reg                   Jump                    ;
  reg                   JumpE                   ;
  reg                   JumpXY                  ;
  reg                   Call                    ;
  reg                   RstP                    ;
  reg                   LDZ                     ;
  reg                   LDW                     ;
  reg                   LDSPHL                  ;
  reg [2:0]             Special_LD              ; // A,I;A,R;I,A;R,A;None
  reg                   ExchangeDH              ;
  reg                   ExchangeRp              ;
  reg                   ExchangeAF              ;
  reg                   ExchangeRS              ;
  reg                   I_DJNZ                  ;
  reg                   I_CPL                   ;
  reg                   I_CCF                   ;
  reg                   I_SCF                   ;
  reg                   I_RETN                  ;
  reg                   I_BT                    ;
  reg                   I_BC                    ;
  reg                   I_BTR                   ;
  reg                   I_RLD                   ;
  reg                   I_RRD                   ;
  reg                   I_INRC                  ;
  reg                   SetDI                   ;
  reg                   SetEI                   ;
  reg [1:0]             IMode                   ;
  reg                   Halt                    ;
  reg                   NoRead                  ;
  reg                   Write   ;                

  parameter             aNone   = 3'b111;
  parameter             aBC     = 3'b000;
  parameter             aDE     = 3'b001;
  parameter             aXY     = 3'b010;
  parameter             aIOA    = 3'b100;
  parameter             aSP     = 3'b101;
  parameter             aZI     = 3'b110;
  //    constant aNone  : std_logic_vector[2:0] = 3'b000;
  //    constant aXY    : std_logic_vector[2:0] = 3'b001;
  //    constant aIOA   : std_logic_vector[2:0] = 3'b010;
  //    constant aSP    : std_logic_vector[2:0] = 3'b011;
  //    constant aBC    : std_logic_vector[2:0] = 3'b100;
  //    constant aDE    : std_logic_vector[2:0] = 3'b101;
  //    constant aZI    : std_logic_vector[2:0] = 3'b110;

  function is_cc_true;
    input [7:0] F;
    input [2:0] cc;
    begin
      if (Mode == 3 ) 
        begin
          case (cc)
            3'b000  : is_cc_true = F[7] == 1'b0; // NZ
            3'b001  : is_cc_true = F[7] == 1'b1; // Z
            3'b010  : is_cc_true = F[4] == 1'b0; // NC
            3'b011  : is_cc_true = F[4] == 1'b1; // C
            3'b100  : is_cc_true = 0;
            3'b101  : is_cc_true = 0;
            3'b110  : is_cc_true = 0;
            3'b111  : is_cc_true = 0;
          endcase
        end 
      else 
        begin
          case (cc)
            3'b000  : is_cc_true = F[6] == 1'b0; // NZ
            3'b001  : is_cc_true = F[6] == 1'b1; // Z
            3'b010  : is_cc_true = F[0] == 1'b0; // NC
            3'b011  : is_cc_true = F[0] == 1'b1; // C
            3'b100  : is_cc_true = F[2] == 1'b0; // PO
            3'b101  : is_cc_true = F[2] == 1'b1; // PE
            3'b110  : is_cc_true = F[7] == 1'b0; // P
            3'b111  : is_cc_true = F[7] == 1'b1; // M
          endcase
        end
    end
  endfunction // is_cc_true
  

  reg [2:0] DDD;
  reg [2:0] SSS;
  reg [1:0] DPAIR;
  reg [7:0] IRB;
  
  always @ (/*AUTOSENSE*/IR or MCycle)
    begin
      DDD = IR[5:3];
      SSS = IR[2:0];
      DPAIR = IR[5:4];
      IRB = IR;

      MCycles = 3'b001;
      if (MCycle[0] ) 
        begin
          TStates = 3'b100;
        end 
      else 
        begin
          TStates = 3'b011;
        end
      Prefix = 2'b00;
      Inc_PC = 1'b0;
      Inc_WZ = 1'b0;
      IncDec_16 = 4'b0000;
      Read_To_Acc = 1'b0;
      Read_To_Reg = 1'b0;
      Set_BusB_To = 4'b0000;
      Set_BusA_To = 4'b0000;
      ALU_Op = { 1'b0, IR[5:3] };
      Save_ALU = 1'b0;
      PreserveC = 1'b0;
      Arith16 = 1'b0;
      IORQ = 1'b0;
      Set_Addr_To = aNone;
      Jump = 1'b0;
      JumpE = 1'b0;
      JumpXY = 1'b0;
      Call = 1'b0;
      RstP = 1'b0;
      LDZ = 1'b0;
      LDW = 1'b0;
      LDSPHL = 1'b0;
      Special_LD = 3'b000;
      ExchangeDH = 1'b0;
      ExchangeRp = 1'b0;
      ExchangeAF = 1'b0;
      ExchangeRS = 1'b0;
      I_DJNZ = 1'b0;
      I_CPL = 1'b0;
      I_CCF = 1'b0;
      I_SCF = 1'b0;
      I_RETN = 1'b0;
      I_BT = 1'b0;
      I_BC = 1'b0;
      I_BTR = 1'b0;
      I_RLD = 1'b0;
      I_RRD = 1'b0;
      I_INRC = 1'b0;
      SetDI = 1'b0;
      SetEI = 1'b0;
      IMode = 2'b11;
      Halt = 1'b0;
      NoRead = 1'b0;
      Write = 1'b0;
      

      //----------------------------------------------------------------------------
      //
      //  CB prefixed instructions
      //
      //----------------------------------------------------------------------------
      
      Set_BusA_To[2:0] = IR[2:0];
      Set_BusB_To[2:0] = IR[2:0];
      
      case (IRB)
        8'b00000000,8'b00000001,8'b00000010,8'b00000011,8'b00000100,8'b00000101,8'b00000111,
        8'b00010000,8'b00010001,8'b00010010,8'b00010011,8'b00010100,8'b00010101,8'b00010111,
        8'b00001000,8'b00001001,8'b00001010,8'b00001011,8'b00001100,8'b00001101,8'b00001111,
        8'b00011000,8'b00011001,8'b00011010,8'b00011011,8'b00011100,8'b00011101,8'b00011111,
        8'b00100000,8'b00100001,8'b00100010,8'b00100011,8'b00100100,8'b00100101,8'b00100111,
        8'b00101000,8'b00101001,8'b00101010,8'b00101011,8'b00101100,8'b00101101,8'b00101111,
        8'b00110000,8'b00110001,8'b00110010,8'b00110011,8'b00110100,8'b00110101,8'b00110111,
        8'b00111000,8'b00111001,8'b00111010,8'b00111011,8'b00111100,8'b00111101,8'b00111111 :
          begin
            // RLC r
            // RL r
            // RRC r
            // RR r
            // SLA r
            // SRA r
            // SRL r
            // SLL r (Undocumented) / SWAP r
            if (MCycle[0] ) begin
              ALU_Op = 4'b1000;
              Read_To_Reg = 1'b1;
              Save_ALU = 1'b1;
            end
          end // case: 8'b00000000,8'b00000001,8'b00000010,8'b00000011,8'b00000100,8'b00000101,8'b00000111,...
        
        8'b00000110,8'b00010110,8'b00001110,8'b00011110,8'b00101110,8'b00111110,8'b00100110,8'b00110110  :
          begin
            // RLC (HL)
            // RL (HL)
            // RRC (HL)
            // RR (HL)
            // SRA (HL)
            // SRL (HL)
            // SLA (HL)
            // SLL (HL) (Undocumented) / SWAP (HL)
            MCycles = 3'b011;
            case (1'b1) // MCycle
              MCycle[0], MCycle[6] :
                Set_Addr_To = aXY;
              MCycle[1] :
                begin
                  ALU_Op = 4'b1000;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  Set_Addr_To = aXY;
                  TStates = 3'b100;
                end
              
              MCycle[2] :
                Write = 1'b1;
              default :;
            endcase // case(MCycle)
          end // case: 8'b00000110,8'b00010110,8'b00001110,8'b00011110,8'b00101110,8'b00111110,8'b00100110,8'b00110110
        
        8'b01000000,8'b01000001,8'b01000010,8'b01000011,8'b01000100,8'b01000101,8'b01000111,
            8'b01001000,8'b01001001,8'b01001010,8'b01001011,8'b01001100,8'b01001101,8'b01001111,
            8'b01010000,8'b01010001,8'b01010010,8'b01010011,8'b01010100,8'b01010101,8'b01010111,
            8'b01011000,8'b01011001,8'b01011010,8'b01011011,8'b01011100,8'b01011101,8'b01011111,
            8'b01100000,8'b01100001,8'b01100010,8'b01100011,8'b01100100,8'b01100101,8'b01100111,
            8'b01101000,8'b01101001,8'b01101010,8'b01101011,8'b01101100,8'b01101101,8'b01101111,
            8'b01110000,8'b01110001,8'b01110010,8'b01110011,8'b01110100,8'b01110101,8'b01110111,
            8'b01111000,8'b01111001,8'b01111010,8'b01111011,8'b01111100,8'b01111101,8'b01111111 :
              begin
                // BIT b,r
                if (MCycle[0] )
                  begin
                    Set_BusB_To[2:0] = IR[2:0];
                    ALU_Op = 4'b1001;
                  end
              end // case: 8'b01000000,8'b01000001,8'b01000010,8'b01000011,8'b01000100,8'b01000101,8'b01000111,...
        
        8'b01000110,8'b01001110,8'b01010110,8'b01011110,8'b01100110,8'b01101110,8'b01110110,8'b01111110  :
          begin
            // BIT b,(HL)
            MCycles = 3'b010;
            case (1'b1) // MCycle
              MCycle[0], MCycle[6] :
                Set_Addr_To = aXY;
              MCycle[1] :
                begin
                  ALU_Op = 4'b1001;
                  TStates = 3'b100;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01000110,8'b01001110,8'b01010110,8'b01011110,8'b01100110,8'b01101110,8'b01110110,8'b01111110
        
        8'b11000000,8'b11000001,8'b11000010,8'b11000011,8'b11000100,8'b11000101,8'b11000111,
            8'b11001000,8'b11001001,8'b11001010,8'b11001011,8'b11001100,8'b11001101,8'b11001111,
            8'b11010000,8'b11010001,8'b11010010,8'b11010011,8'b11010100,8'b11010101,8'b11010111,
            8'b11011000,8'b11011001,8'b11011010,8'b11011011,8'b11011100,8'b11011101,8'b11011111,
            8'b11100000,8'b11100001,8'b11100010,8'b11100011,8'b11100100,8'b11100101,8'b11100111,
            8'b11101000,8'b11101001,8'b11101010,8'b11101011,8'b11101100,8'b11101101,8'b11101111,
            8'b11110000,8'b11110001,8'b11110010,8'b11110011,8'b11110100,8'b11110101,8'b11110111,
            8'b11111000,8'b11111001,8'b11111010,8'b11111011,8'b11111100,8'b11111101,8'b11111111 :
              begin
                // SET b,r
                if (MCycle[0] ) 
                  begin
                    ALU_Op = 4'b1010;
                    Read_To_Reg = 1'b1;
                    Save_ALU = 1'b1;
                  end
              end // case: 8'b11000000,8'b11000001,8'b11000010,8'b11000011,8'b11000100,8'b11000101,8'b11000111,...
        
        8'b11000110,8'b11001110,8'b11010110,8'b11011110,8'b11100110,8'b11101110,8'b11110110,8'b11111110  :
          begin
            // SET b,(HL)
            MCycles = 3'b011;
            case (1'b1) // MCycle
              MCycle[0], MCycle[6] :
                Set_Addr_To = aXY;
              MCycle[1] :
                begin
                  ALU_Op = 4'b1010;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  Set_Addr_To = aXY;
                  TStates = 3'b100;
                end
              MCycle[2] :
                Write = 1'b1;
              default :;
            endcase // case(MCycle)
          end // case: 8'b11000110,8'b11001110,8'b11010110,8'b11011110,8'b11100110,8'b11101110,8'b11110110,8'b11111110
        
        8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000111,
            8'b10001000,8'b10001001,8'b10001010,8'b10001011,8'b10001100,8'b10001101,8'b10001111,
            8'b10010000,8'b10010001,8'b10010010,8'b10010011,8'b10010100,8'b10010101,8'b10010111,
            8'b10011000,8'b10011001,8'b10011010,8'b10011011,8'b10011100,8'b10011101,8'b10011111,
            8'b10100000,8'b10100001,8'b10100010,8'b10100011,8'b10100100,8'b10100101,8'b10100111,
            8'b10101000,8'b10101001,8'b10101010,8'b10101011,8'b10101100,8'b10101101,8'b10101111,
            8'b10110000,8'b10110001,8'b10110010,8'b10110011,8'b10110100,8'b10110101,8'b10110111,
            8'b10111000,8'b10111001,8'b10111010,8'b10111011,8'b10111100,8'b10111101,8'b10111111 :
              begin
                // RES b,r
                if (MCycle[0] ) 
                  begin
                    ALU_Op = 4'b1011;
                    Read_To_Reg = 1'b1;
                    Save_ALU = 1'b1;
                  end
              end // case: 8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000111,...
        
        8'b10000110,8'b10001110,8'b10010110,8'b10011110,8'b10100110,8'b10101110,8'b10110110,8'b10111110  :
          begin
            // RES b,(HL)
            MCycles = 3'b011;
            case (1'b1) // MCycle
              MCycle[0], MCycle[6] :
                Set_Addr_To = aXY;
              MCycle[1] :
                begin
                  ALU_Op = 4'b1011;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  Set_Addr_To = aXY;
                  TStates = 3'b100;
                end
              
              MCycle[2] :
                Write = 1'b1;
              default :;
            endcase // case(MCycle)
          end // case: 8'b10000110,8'b10001110,8'b10010110,8'b10011110,8'b10100110,8'b10101110,8'b10110110,8'b10111110
        
      endcase // case(IRB)
      
    end // always @ (IR, ISet, MCycle, F, NMICycle, IntCycle)

  assign output_vector = { MCycles,
                           TStates,   
                           Prefix,   
                           Inc_PC,    
                           Inc_WZ,    
                           IncDec_16,
                           Read_To_Reg,
                           Read_To_Acc,
                           Set_BusA_To,
                           Set_BusB_To,
                           ALU_Op,     
                           Save_ALU,   
                           PreserveC,  
                           Arith16,    
                           Set_Addr_To,
                           IORQ,       
                           Jump,       
                           JumpE,      
                           JumpXY,     
                           Call,       
                           RstP,       
                           LDZ,        
                           LDW,        
                           LDSPHL,     
                           Special_LD, 
                           ExchangeDH, 
                           ExchangeRp, 
                           ExchangeAF, 
                           ExchangeRS, 
                           I_DJNZ,     
                           I_CPL,      
                           I_CCF,      
                           I_SCF,      
                           I_RETN,     
                           I_BT,       
                           I_BC,       
                           I_BTR,      
                           I_RLD,      
                           I_RRD,      
                           I_INRC,     
                           SetDI,      
                           SetEI,      
                           IMode,      
                           Halt,       
                           NoRead,     
                           Write }; 
  
  // synopsys dc_script_begin
  // set_attribute current_design "revision" "$Id: tv80_mcode_cb.v,v 1.1.2.1 2004-11-30 21:58:10 ghutchis Exp $" -type string -quiet
  // synopsys dc_script_end
endmodule // T80_MCode
