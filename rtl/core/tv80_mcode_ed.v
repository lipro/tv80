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

module tv80_mcode_ed
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
  
  input [7:0]            IR;
  input [6:0]            MCycle                  ;

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
      //  ED prefixed instructions
      //
      //----------------------------------------------------------------------------

      casex (IRB)
        // 8 BIT LOAD GROUP
        8'b01010111  :
          begin
            // LD A,I
            Special_LD = 3'b100;
            TStates = 3'b101;
          end
        
        8'b01011111  :
          begin
            // LD A,R
            Special_LD = 3'b101;
            TStates = 3'b101;
          end
        
        8'b01000111  :
          begin
            // LD I,A
            Special_LD = 3'b110;
            TStates = 3'b101;
          end
        
        8'b01001111  :
          begin
            // LD R,A
            Special_LD = 3'b111;
            TStates = 3'b101;
          end
        
        // 16 BIT LOAD GROUP
        8'b01xx1011 :
          begin
            // LD dd,(nn)
            MCycles = 3'b101;
            case (1'b1) // MCycle
              MCycle[1] :
                begin
                  Inc_PC = 1'b1;
                  LDZ = 1'b1;
                end
              
              MCycle[2] :
                begin
                  Set_Addr_To = aZI;
                  Inc_PC = 1'b1;
                  LDW = 1'b1;
                end
              
              MCycle[3] :
                begin
                  Read_To_Reg = 1'b1;
                  if (IR[5:4] == 2'b11 ) 
                    begin
                      Set_BusA_To = 4'b1000;
                    end 
                  else 
                    begin
                      Set_BusA_To[2:1] = IR[5:4];
                      Set_BusA_To[0] = 1'b1;
                    end
                  Inc_WZ = 1'b1;
                  Set_Addr_To = aZI;
                end // case: 4
              
              MCycle[4] :
                begin
                  Read_To_Reg = 1'b1;
                  if (IR[5:4] == 2'b11 ) 
                    begin
                      Set_BusA_To = 4'b1001;
                    end 
                  else 
                    begin
                      Set_BusA_To[2:1] = IR[5:4];
                      Set_BusA_To[0] = 1'b0;
                    end
                end // case: 5
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01001011,8'b01011011,8'b01101011,8'b01111011
        
        
        8'b01xx0011  :
          begin
            // LD (nn),dd
            MCycles = 3'b101;
            case (1'b1) // MCycle
              MCycle[1] :
                begin
                  Inc_PC = 1'b1;
                  LDZ = 1'b1;
                end
              
              MCycle[2] :
                begin
                  Set_Addr_To = aZI;
                  Inc_PC = 1'b1;
                  LDW = 1'b1;
                  if (IR[5:4] == 2'b11 ) 
                    begin
                      Set_BusB_To = 4'b1000;
                    end 
                  else 
                    begin
                      Set_BusB_To[2:1] = IR[5:4];
                      Set_BusB_To[0] = 1'b1;
                      Set_BusB_To[3] = 1'b0;
                    end
                end // case: 3
              
              MCycle[3] :
                begin
                  Inc_WZ = 1'b1;
                  Set_Addr_To = aZI;
                  Write = 1'b1;
                  if (IR[5:4] == 2'b11 ) 
                    begin
                      Set_BusB_To = 4'b1001;
                    end 
                  else 
                    begin
                      Set_BusB_To[2:1] = IR[5:4];
                      Set_BusB_To[0] = 1'b0;
                      Set_BusB_To[3] = 1'b0;
                    end
                end // case: 4
              
              MCycle[4] :
                begin
                  Write = 1'b1;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01000011,8'b01010011,8'b01100011,8'b01110011
        
        8'b101xx000 :
          begin
            // LDI, LDD, LDIR, LDDR
            MCycles = 3'b100;
            case (1'b1) // MCycle
              MCycle[0] :
                begin
                  Set_Addr_To = aXY;
                  IncDec_16 = 4'b1100; // BC
                end
              
              MCycle[1] :
                begin
                  Set_BusB_To = 4'b0110;
                  Set_BusA_To[2:0] = 3'b111;
                  ALU_Op = 4'b0000;
                  Set_Addr_To = aDE;
                  if (IR[3] == 1'b0 ) 
                    begin
                      IncDec_16 = 4'b0110; // IX
                    end 
                  else 
                    begin
                      IncDec_16 = 4'b1110;
                    end
                end // case: 2
              
              MCycle[2] :
                begin
                  I_BT = 1'b1;
                  TStates = 3'b101;
                  Write = 1'b1;
                  if (IR[3] == 1'b0 ) 
                    begin
                      IncDec_16 = 4'b0101; // DE
                    end 
                  else 
                    begin
                      IncDec_16 = 4'b1101;
                    end
                end // case: 3
              
              MCycle[3] :
                begin
                  NoRead = 1'b1;
                  TStates = 3'b101;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b10100000 , 8'b10101000 , 8'b10110000 , 8'b10111000
        
        8'b101xx001 :
          begin
            // CPI, CPD, CPIR, CPDR
            MCycles = 3'b100;
            case (1'b1) // MCycle
              MCycle[0] :
                begin
                  Set_Addr_To = aXY;
                  IncDec_16 = 4'b1100; // BC
                end
              
              MCycle[1] :
                begin
                  Set_BusB_To = 4'b0110;
                  Set_BusA_To[2:0] = 3'b111;
                  ALU_Op = 4'b0111;
                  Save_ALU = 1'b1;
                  PreserveC = 1'b1;
                  if (IR[3] == 1'b0 ) 
                    begin
                      IncDec_16 = 4'b0110;
                    end 
                  else 
                    begin
                      IncDec_16 = 4'b1110;
                    end
                end // case: 2
              
              MCycle[2] :
                begin
                  NoRead = 1'b1;
                  I_BC = 1'b1;
                  TStates = 3'b101;
                end
              
              MCycle[3] :
                begin
                  NoRead = 1'b1;
                  TStates = 3'b101;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b10100001 , 8'b10101001 , 8'b10110001 , 8'b10111001
        
        8'b01xxx100 :
          begin
            // NEG
            ALU_Op = 4'b0010;
            Set_BusB_To = 4'b0111;
            Set_BusA_To = 4'b1010;
            Read_To_Acc = 1'b1;
            Save_ALU = 1'b1;
          end
        
        8'b01000110,8'b01001110,8'b01100110,8'b01101110  :
          begin
            // IM 0
            IMode = 2'b00;
          end
        
        8'b01010110,8'b01110110  :
          // IM 1
          IMode = 2'b01;
        
        8'b01011110,8'b01110111  :
          // IM 2
          IMode = 2'b10;
        
        // 16 bit arithmetic
        8'b01001010,8'b01011010,8'b01101010,8'b01111010  :
          begin
            // ADC HL,ss
            MCycles = 3'b011;
            case (1'b1) // MCycle
              MCycle[1] :
                begin
                  NoRead = 1'b1;
                  ALU_Op = 4'b0001;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  Set_BusA_To[2:0] = 3'b101;
                  case (IR[5:4])
                    0,1,2  :
                      begin
                        Set_BusB_To[2:1] = IR[5:4];
                        Set_BusB_To[0] = 1'b1;
                      end
                    default :
                      Set_BusB_To = 4'b1000;
                  endcase
                  TStates = 3'b100;
                end // case: 2
              
              MCycle[2] :
                begin
                  NoRead = 1'b1;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  ALU_Op = 4'b0001;
                  Set_BusA_To[2:0] = 3'b100;
                  case (IR[5:4])
                    0,1,2  :
                      begin
                        Set_BusB_To[2:1] = IR[5:4];
                        Set_BusB_To[0] = 1'b0;
                      end
                    default :
                      Set_BusB_To = 4'b1001;
                  endcase // case(IR[5:4])
                end // case: 3
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01001010,8'b01011010,8'b01101010,8'b01111010
        
        8'b01000010,8'b01010010,8'b01100010,8'b01110010  :
          begin
            // SBC HL,ss
            MCycles = 3'b011;
            case (1'b1) // MCycle
              MCycle[1] :
                begin
                  NoRead = 1'b1;
                  ALU_Op = 4'b0011;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  Set_BusA_To[2:0] = 3'b101;
                  case (IR[5:4])
                    0,1,2  :
                      begin
                        Set_BusB_To[2:1] = IR[5:4];
                        Set_BusB_To[0] = 1'b1;
                      end
                    default :
                      Set_BusB_To = 4'b1000;
                  endcase
                  TStates = 3'b100;
                end // case: 2
              
              MCycle[2] :
                begin
                  NoRead = 1'b1;
                  ALU_Op = 4'b0011;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  Set_BusA_To[2:0] = 3'b100;
                  case (IR[5:4])
                    0,1,2  :
                      Set_BusB_To[2:1] = IR[5:4];
                    default :
                      Set_BusB_To = 4'b1001;
                  endcase
                end // case: 3
              
              default :;
              
            endcase // case(MCycle)
          end // case: 8'b01000010,8'b01010010,8'b01100010,8'b01110010
        
        8'b01101111  :
          begin
            // RLD
            MCycles = 3'b100;
            case (1'b1) // MCycle
              MCycle[1] :
                begin
                  NoRead = 1'b1;
                  Set_Addr_To = aXY;
                end
              
              MCycle[2] :
                begin
                  Read_To_Reg = 1'b1;
                  Set_BusB_To[2:0] = 3'b110;
                  Set_BusA_To[2:0] = 3'b111;
                  ALU_Op = 4'b1101;
                  TStates = 3'b100;
                  Set_Addr_To = aXY;
                  Save_ALU = 1'b1;
                end
              
              MCycle[3] :
                begin
                  I_RLD = 1'b1;
                  Write = 1'b1;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01101111
        
        8'b01100111  :
          begin
            // RRD
            MCycles = 3'b100;
            case (1'b1) // MCycle
              MCycle[1] :
                Set_Addr_To = aXY;
              MCycle[2] :
                begin
                  Read_To_Reg = 1'b1;
                  Set_BusB_To[2:0] = 3'b110;
                  Set_BusA_To[2:0] = 3'b111;
                  ALU_Op = 4'b1110;
                  TStates = 3'b100;
                  Set_Addr_To = aXY;
                  Save_ALU = 1'b1;
                end
              
              MCycle[3] :
                begin
                  I_RRD = 1'b1;
                  Write = 1'b1;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01100111
        
        8'b01xxx101 :
          begin
            // RETI, RETN
            MCycles = 3'b011;
            case (1'b1) // MCycle
              MCycle[0] :
                Set_Addr_To = aSP;
              
              MCycle[1] :
                begin
                  IncDec_16 = 4'b0111;
                  Set_Addr_To = aSP;
                  LDZ = 1'b1;
                end
              
              MCycle[2] :
                begin
                  Jump = 1'b1;
                  IncDec_16 = 4'b0111;
                  I_RETN = 1'b1;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01000101,8'b01001101,8'b01010101,8'b01011101,8'b01100101,8'b01101101,8'b01110101,8'b01111101
        
        8'b01xxx000 :
          begin
            // IN r,(C)
            MCycles = 3'b010;
            case (1'b1) // MCycle
              MCycle[0] :
                Set_Addr_To = aBC;
              
              MCycle[1] :
                begin
                  IORQ = 1'b1;
                  if (IR[5:3] != 3'b110 ) 
                    begin
                      Read_To_Reg = 1'b1;
                      Set_BusA_To[2:0] = IR[5:3];
                    end
                  I_INRC = 1'b1;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01000000,8'b01001000,8'b01010000,8'b01011000,8'b01100000,8'b01101000,8'b01110000,8'b01111000
        
        8'b01xxx001 :
          begin
            // OUT (C),r
            // OUT (C),0
            MCycles = 3'b010;
            case (1'b1) // MCycle
              MCycle[0] :
                begin
                  Set_Addr_To = aBC;
                  Set_BusB_To[2:0]        = IR[5:3];
                  if (IR[5:3] == 3'b110 ) 
                    begin
                      Set_BusB_To[3] = 1'b1;
                    end
                end
              
              MCycle[1] :
                begin
                  Write = 1'b1;
                  IORQ = 1'b1;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b01000001,8'b01001001,8'b01010001,8'b01011001,8'b01100001,8'b01101001,8'b01110001,8'b01111001
        
        8'b10100010 , 8'b10101010 , 8'b10110010 , 8'b10111010  :
          begin
            // INI, IND, INIR, INDR
            MCycles = 3'b100;
            case (1'b1) // MCycle
              MCycle[0] :
                begin
                  Set_Addr_To = aBC;
                  Set_BusB_To = 4'b1010;
                  Set_BusA_To = 4'b0000;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  ALU_Op = 4'b0010;
                end
              
              MCycle[1] :
                begin
                  IORQ = 1'b1;
                  Set_BusB_To = 4'b0110;
                  Set_Addr_To = aXY;
                end
              
              MCycle[2] :
                begin
                  if (IR[3] == 1'b0 ) 
                    begin
		      IncDec_16 = 4'b0110;
                    end 
                  else 
                    begin
		      IncDec_16 = 4'b1110;
                    end
                  TStates = 3'b100;
                  Write = 1'b1;
                  I_BTR = 1'b1;
                end // case: 3
              
              MCycle[3] :
                begin
                  NoRead = 1'b1;
                  TStates = 3'b101;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b10100010 , 8'b10101010 , 8'b10110010 , 8'b10111010
        
        8'b10100011 , 8'b10101011 , 8'b10110011 , 8'b10111011  :
          begin
            // OUTI, OUTD, OTIR, OTDR
            MCycles = 3'b100;
            case (1'b1) // MCycle
              MCycle[0] :
                begin
                  TStates = 3'b101;
                  Set_Addr_To = aXY;
                  Set_BusB_To = 4'b1010;
                  Set_BusA_To = 4'b0000;
                  Read_To_Reg = 1'b1;
                  Save_ALU = 1'b1;
                  ALU_Op = 4'b0010;
                end
              
              MCycle[1] :
                begin
                  Set_BusB_To = 4'b0110;
                  Set_Addr_To = aBC;
                  if (IR[3] == 1'b0 ) 
                    begin
                      IncDec_16 = 4'b0110;
                    end 
                  else 
                    begin
                      IncDec_16 = 4'b1110;
                    end
                end
              
              MCycle[2] :
                begin
                  if (IR[3] == 1'b0 ) 
                    begin
                      IncDec_16 = 4'b0010;
                    end 
                  else 
                    begin
                      IncDec_16 = 4'b1010;
                    end
                  IORQ = 1'b1;
                  Write = 1'b1;
                  I_BTR = 1'b1;
                end // case: 3
              
              MCycle[3] :
                begin
                  NoRead = 1'b1;
                  TStates = 3'b101;
                end
              
              default :;
            endcase // case(MCycle)
          end // case: 8'b10100011 , 8'b10101011 , 8'b10110011 , 8'b10111011

        default : ;
        
      endcase // case(IRB)                  
      
    end // always @ (IR, ISet, MCycle, F, NMICycle, IntCycle)

  assign                output_vector = { MCycles,
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
  // set_attribute current_design "revision" "$Id: tv80_mcode_ed.v,v 1.1.2.1 2004-11-30 21:58:10 ghutchis Exp $" -type string -quiet
  // synopsys dc_script_end
endmodule // T80_MCode
