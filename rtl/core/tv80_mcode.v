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

module tv80_mcode 
  (/*AUTOARG*/
  // Outputs
  MCycles, TStates, Prefix, Inc_PC, Inc_WZ, IncDec_16, Read_To_Reg, 
  Read_To_Acc, Set_BusA_To, Set_BusB_To, ALU_Op, Save_ALU, PreserveC, 
  Arith16, Set_Addr_To, IORQ, Jump, JumpE, JumpXY, Call, RstP, LDZ, 
  LDW, LDSPHL, Special_LD, ExchangeDH, ExchangeRp, ExchangeAF, 
  ExchangeRS, I_DJNZ, I_CPL, I_CCF, I_SCF, I_RETN, I_BT, I_BC, I_BTR, 
  I_RLD, I_RRD, I_INRC, SetDI, SetEI, IMode, Halt, NoRead, Write, 
  // Inputs
  IR, ISet, MCycle, F, tstate, NMICycle, IntCycle
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

  input [7:0]           IR;
  input [1:0]           ISet                    ;
  input [6:0]           MCycle                  ;
  input [7:0]           F                       ;
  input [6:0]           tstate;
  input                 NMICycle                ;
  input                 IntCycle                ;
  output [2:0]          MCycles                 ;
  output [2:0]          TStates                 ;
  output [1:0]          Prefix                  ; // None,BC,ED,DD/FD
  output                Inc_PC                  ;
  output                Inc_WZ                  ;
  output [3:0]          IncDec_16               ; // BC,DE,HL,SP   0 is inc
  output                Read_To_Reg             ;
  output                Read_To_Acc             ;
  output [3:0]          Set_BusA_To     ; // B,C,D,E,H,L,DI/DB,A,SP(L),SP(M),0,F
  output [3:0]          Set_BusB_To     ; // B,C,D,E,H,L,DI,A,SP(L),SP(M),1,F,PC(L),PC(M),0
  output [3:0]          ALU_Op                  ;
  output                Save_ALU                ;
  output                PreserveC               ;
  output                Arith16                 ;
  output [2:0]          Set_Addr_To             ; // aNone,aXY,aIOA,aSP,aBC,aDE,aZI
  output                IORQ                    ;
  output                Jump                    ;
  output                JumpE                   ;
  output                JumpXY                  ;
  output                Call                    ;
  output                RstP                    ;
  output                LDZ                     ;
  output                LDW                     ;
  output                LDSPHL                  ;
  output [2:0]          Special_LD              ; // A,I;A,R;I,A;R,A;None
  output                ExchangeDH              ;
  output                ExchangeRp              ;
  output                ExchangeAF              ;
  output                ExchangeRS              ;
  output                I_DJNZ                  ;
  output                I_CPL                   ;
  output                I_CCF                   ;
  output                I_SCF                   ;
  output                I_RETN                  ;
  output                I_BT                    ;
  output                I_BC                    ;
  output                I_BTR                   ;
  output                I_RLD                   ;
  output                I_RRD                   ;
  output                I_INRC                  ;
  output                SetDI                   ;
  output                SetEI                   ;
  output [1:0]          IMode                   ;
  output                Halt                    ;
  output                NoRead                  ;
  output                Write   ;                

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

  wire [67:0] vec_base, vec_cb, vec_ed;
  reg [67:0]  vec_final;
  
  // instruction decoders
  tv80_mcode_base #(Mode) dec_base
    (
     // Outputs
     .output_vector                     (vec_base),
     // Inputs
     .IR                                (IR),
     .MCycle                            (MCycle),
     .tstate                            (tstate),
     .F                                 (F),
     .NMICycle                          (NMICycle),
     .IntCycle                          (IntCycle));

  tv80_mcode_cb #(Mode) dec_cb
    (
     // Outputs
     .output_vector                     (vec_cb),
     // Inputs
     .IR                                (IR),
     .MCycle                            (MCycle));

  tv80_mcode_ed #(Mode) dec_ed
    (
     // Outputs
     .output_vector                     (vec_ed),
     // Inputs
     .IR                                (IR),
     .MCycle                            (MCycle));
  
  always @ (/*AUTOSENSE*/IR or ISet or MCycle or SSS or vec_base
            or vec_cb or vec_ed)
    begin
      case (ISet)
        2'b00  : vec_final = vec_base;
        2'b01  : vec_final = vec_cb;
        default : vec_final = vec_ed;
      endcase // case(ISet)
      
      { MCycles,
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
        Write } = vec_final;
      
      if (Mode == 1 ) 
        begin
          if (MCycle[0] ) 
            begin
              //TStates = 3'b100;
            end 
          else 
            begin
              TStates = 3'b011;
            end
        end

      if (Mode == 3 ) 
        begin
          if (MCycle[0] ) 
            begin
              //TStates = 3'b100;
            end 
          else 
            begin
              TStates = 3'b100;
            end
        end

      if (Mode < 2 ) 
        begin
          if (MCycle[5] ) 
            begin
              Inc_PC = 1'b1;
              if (Mode == 1 ) 
                begin
                  Set_Addr_To = aXY;
                  TStates = 3'b100;
                  Set_BusB_To[2:0] = SSS;
                  Set_BusB_To[3] = 1'b0;
                end
              if (IR == 8'b00110110 || IR == 8'b11001011 ) 
                begin
                  Set_Addr_To = aNone;
                end
            end
          if (MCycle[6] ) 
            begin
              if (Mode == 0 ) 
                begin
                  TStates = 3'b101;
                end
              if (ISet != 2'b01 ) 
                begin
                  Set_Addr_To = aXY;
                end
              Set_BusB_To[2:0] = SSS;
              Set_BusB_To[3] = 1'b0;
              if (IR == 8'b00110110 || ISet == 2'b01 ) 
                begin
                  // LD (HL),n
                  Inc_PC = 1'b1;
                end 
              else 
                begin
                  NoRead = 1'b1;
                end
            end
        end // if (Mode < 2 )      
      
    end // always @ (IR, ISet, MCycle, F, NMICycle, IntCycle)
  
  // synopsys dc_script_begin
  // set_attribute current_design "revision" "$Id: tv80_mcode.v,v 1.5.4.2 2004-12-16 00:46:29 ghutchis Exp $" -type string -quiet
  // synopsys dc_script_end
endmodule // T80_MCode
