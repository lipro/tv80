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

//----------------------------------------------------------------------
//  Simple network interface
//
//  Implements a GMII-like byte-wide interface on one side, and
//  an IO-mapped interface to the tv80.

//  IO-interface:
//    R0  --  Status register
//    R1  --  Control register
//    R2  --  RX Length (low)
//    R3  --  RX Length (high)
//    R4  --  RX Data
//    R5  --  TX Data
//    R6  --  Configuration

//  Status bits:
//    [0]     RX Packet Ready
//    [1]     TX Transmit Complete

//  Control bits:
//    [0]     Send TX Packet
//----------------------------------------------------------------------

module simple_gmii
  (
   input      clk,
   input      reset,

   // GMII Interface
   input [7:0] rx_data,
   input       rx_clk,
   input       rx_dv,
   input       rx_er,

   output reg [7:0] tx_data,
   output           tx_clk,
   output reg       tx_dv,
   output reg       tx_er,

   // TV80 Interface
   input       io_select,
   input       rd_n,
   input       wr_n,
   input [2:0] io_addr,
   input [7:0] io_data_in,
   output reg [7:0] io_data_out
  );
  
  //parameter   io_base_addr = 8'hA0;
  parameter txbuf_sz = 512, rxbuf_sz = 512;
  parameter wr_ptr_sz = 10;
  
  parameter st_tx_idle = 0, st_tx_xmit = 1;
  parameter st_rxo_idle = 2'b00,
            st_rxo_ready = 2'b01,
            st_rxo_ack   = 2'b11;
  
  parameter st_rxin_idle = 2'b00,
            st_rxin_receive = 2'b01,
            st_rxin_hold    = 2'b11;
  
  reg [wr_ptr_sz-1:0] tx_wr_ptr, tx_xm_ptr;
  reg [wr_ptr_sz-1:0] rx_wr_ptr, rx_rd_ptr, rx_count;
  reg [1:0]   tx_state;
  reg         wr_sel_tx_data;
  reg         wr_sel_tx_control;
  reg         start_transmit;
  wire [7:0] txbuf_data;

  reg         stat_tx_complete;

  reg         stat_rx_avail;

  reg [1:0]   rxin_state;
  reg         rxin_complete;
  reg         rd_sel_rx_data;
  reg [1:0]   rxo_state;
  wire        rxo_complete;
  reg         rxo_ack;
  wire        rxin_ack;
  wire [7:0]  rxbuf_data;
  reg         rxbuf_we;
 
  //assign      io_select = ((io_base_addr >> 3) == addr[7:3]);

  //------------------------------
  // IO Read Mux
  //------------------------------

  always @*
    begin
      case (io_addr)
        0 : io_data_out = { 6'h0, stat_tx_complete, stat_rx_avail };
        2 : io_data_out = rx_count[7:0];
        3 : io_data_out = { {16-wr_ptr_sz{1'b0}}, rx_count[wr_ptr_sz-1:8] };
        4 : io_data_out = rxbuf_data;
        default : io_data_out = 8'h0;
      endcase
    end
  
  //------------------------------
  // Receive Logic
  //------------------------------

  always @*
    begin
      rd_sel_rx_data = (io_select & !rd_n & (io_addr == 3'd4));
      rxbuf_we = ((rxin_state == st_rxin_idle) | (rxin_state == st_rxin_receive)) & rx_dv;
    end
  
  ram_1r_1w #(8, rxbuf_sz, wr_ptr_sz) rxbuf
    (.clk     (rx_clk),
     .wr_en   (rxbuf_we),
     .wr_addr (rx_wr_ptr),
     .wr_data (rx_data),

     .rd_addr (rx_rd_ptr),
     .rd_data (rxbuf_data));

  always @(posedge rx_clk)
    begin
      if (reset)
        begin
          rxin_state    <= #1 st_rxin_idle;
          rxin_complete <= #1 0;
          rx_wr_ptr     <= #1 0;
        end
      else
        begin
          case (rxin_state)
            st_rxin_idle :
              begin
                if (rx_dv)
                  begin
                    rx_wr_ptr <= #1 rx_wr_ptr + 1;
                    rxin_state <= #1 st_rxin_receive;
                    rxin_complete <= #1 0;
                  end
                else
                  begin
                    rx_wr_ptr <= #1 0;
                  end
              end // case: st_rxin_idle

            st_rxin_receive :
              begin
                if (rx_dv)
                  rx_wr_ptr <= #1 rx_wr_ptr + 1;
                else
                  begin
                    rxin_state <= #1 st_rxin_hold;
                    rxin_complete <= #1 1;
                  end
              end

            st_rxin_hold :
              begin
                if (rxin_ack & !rx_dv)
                  begin
                    rxin_state <= #1 st_rxin_idle;
                    rxin_complete <= #1 0;
                  end
              end

            default :
              rxin_state <= #1 st_rxin_idle;
          endcase // case(rxin_state)
        end // else: !if(reset)
    end // always @ (posedge rx_clk)

  sync2 comp_sync (clk, rxin_complete, rxo_complete);
  sync2 ack_sync  (rx_clk, rxo_ack, rxin_ack);

  always @(posedge clk)
    begin
      if (reset)
        begin
          rx_count <= #1 0;
          rxo_state <= #1 st_rxo_idle;
          stat_rx_avail <= #1 0;
          rxo_ack       <= #1 0;
        end
      else
        begin
          case (rxo_state)
            st_rxo_idle :
              begin
                rx_rd_ptr     <= #1 0;
                if (rxin_complete)
                  begin
                    rxo_state <= #1 st_rxo_ready;
                    stat_rx_avail <= #1 1;
                    rx_count <= #1 rx_wr_ptr;
                  end
              end

            st_rxo_ready :
              begin
                if (rd_sel_rx_data)
                  rx_rd_ptr <= #1 rx_rd_ptr + 1;

                if (rx_rd_ptr == rx_count)
                  begin
                    rxo_ack <= #1 1;
                    rxo_state <= #1 st_rxo_ack;
                    stat_rx_avail <= #1 0;
                  end
              end // case: st_rxo_ready

            st_rxo_ack :
              begin
                if (!rxo_complete)
                  rxo_state <= st_rxo_idle;
              end

            default :
              rxo_state <= #1 st_rxo_idle;
          endcase // case(rxo_state)
        end // else: !if(reset)
    end // always @ (posedge clk)
  
  //------------------------------
  // Transmit Logic
  //------------------------------

  assign      tx_clk = clk;
  
  always @*
    begin
      wr_sel_tx_data = (io_select & !wr_n & (io_addr == 3'd5));
      wr_sel_tx_control = (io_select & !wr_n & (io_addr == 3'd1));
      start_transmit    = wr_sel_tx_control & io_data_in[0];
    end

  ram_1r_1w #(8, txbuf_sz, wr_ptr_sz) txbuf
    (.clk     (clk),
     .wr_en   (wr_sel_tx_data),
     .wr_addr (tx_wr_ptr),
     .wr_data (io_data_in),

     .rd_addr (tx_xm_ptr),
     .rd_data (txbuf_data));  

  always @(posedge clk)
    begin
      if (reset)
        begin
          tx_state <= #1 st_tx_idle;
          tx_wr_ptr <= #1 0;
          tx_xm_ptr <= #1 0;
          tx_data   <= #1 0;
          tx_dv     <= #1 0;
          tx_er     <= #1 0;
          stat_tx_complete <= #1 0;
        end
      else
        begin
          case (tx_state)
            st_tx_idle :
              begin
                tx_xm_ptr <= #1 0;
                tx_dv     <= #1 0;
                tx_er     <= #1 0;
                
                if (start_transmit)
                  begin
                    tx_state <= #1 st_tx_xmit;
                    stat_tx_complete <= #1 0;
                  end
                else if (wr_sel_tx_data)
                  tx_wr_ptr <= #1 tx_wr_ptr + 1;
              end

            st_tx_xmit :
              begin
                if (tx_xm_ptr == tx_wr_ptr)
                  begin
                    tx_dv     <= #1 0;
                    tx_er     <= #1 0;
                    tx_state  <= #1 st_tx_idle;
                    tx_wr_ptr <= #1 0;
                    stat_tx_complete <= #1 1;
                  end
                else
                  begin
                    tx_data   <= #1 txbuf_data;
                    tx_dv     <= #1 1;
                    tx_er     <= #1 0;
                    tx_xm_ptr <= #1 tx_xm_ptr + 1;
                  end
              end

            default :
              begin
                tx_state <= #1 st_tx_idle;
              end
          endcase // case(tx_state)
        end // else: !if(reset)
    end // always @ (posedge clk)
            
  
endmodule

