/*
 * Copyright (c) 2003-2004 by Cisco Systems Inc.
 * $Id: t80_top.v,v 1.1 2004-05-16 17:39:57 ghutchis Exp $
 * All rights reserved.
 *
 * Author: Guy Hutchison
 * 
 */

module t80_top (/*AUTOARG*/
  // Outputs
  t80_cpu_req, t80_cpu_read, t80_cpu_addr, t80_cpu_wdata, 
  t80_cpu_mem_rdata, t80_cpu_mem_ack, 
  // Inputs
  clk250, reset, cpu_reset, cpu_t80_ack, cpu_t80_rdata, cpu_t80_addr, 
  cpu_t80_mem_read, cpu_t80_mem_wdata, cpu_t80_mem_req
  );

  input         clk250;
  input         reset;
  input         cpu_reset;
  
  // interface from T80 to Alkindi registers
  output        t80_cpu_req;
  input         cpu_t80_ack;
  output        t80_cpu_read;
  output [10:0] t80_cpu_addr;
  output [15:0] t80_cpu_wdata;
  input [15:0]  cpu_t80_rdata;

  // interface from external CPU to T80
  input [15:0]  cpu_t80_addr;
  input         cpu_t80_mem_read;
  input [7:0]   cpu_t80_mem_wdata;
  output [7:0]  t80_cpu_mem_rdata;
  input         cpu_t80_mem_req;
  output        t80_cpu_mem_ack;

  wire [15:0]   addr;

`ifdef T80_4K_RAM
  parameter     asz = 12,
                depth = 4096;
`else
  parameter     asz = 11,
                depth = 2048;
`endif
  
  reg           lcl_reset, lcl_cpu_reset_n;
  wire [7:0] 	ram_wdata;
  wire [7:0] 	ram_rdata;
  wire [7:0] 	din, dout;
  
  assign     ram_wdata = dout;
  
  always @(posedge clk250)
    begin
      lcl_reset <= #1 reset;
      lcl_cpu_reset_n <= #1 ~cpu_reset;
    end
  
  ak_clk_sync req_sync (.clk(clk250), .din (cpu_t80_mem_req), .dout(cpu_sync_req));

  wire wait_n = 1'b1;
  wire int_n = 1'b1;
  wire nmi_n = 1'b1;
  wire busrq_n = 1'b1;
  
  t80_wrap t80_inst
    (
     // Outputs
     .mem_req				(mem_req),
     .mem_rd				(mem_rd),
     .io_req				(io_req),
     .io_rd				(io_rd),
     .addr				(addr[15:0]),
     .dout				(dout[7:0]),
     // Inputs
     .clk250				(clk250),
     .reset_n				(lcl_cpu_reset_n),
     .wait_n				(wait_n),
     .int_n				(int_n),
     .nmi_n				(nmi_n),
     .busrq_n				(busrq_n),
     .mem_ack				(mem_ack),
     .io_ack				(io_ack),
     .din				(din[7:0]));
    
  ak_t80_io t80_io0
    (/*AUTOINST*/
     // Outputs
     .io_ack				(io_ack),
     .int_n				(int_n),
     .nmi_n				(nmi_n),
     .din				(din[7:0]),
     .t80_cpu_req			(t80_cpu_req),
     .t80_cpu_read			(t80_cpu_read),
     .t80_cpu_addr			(t80_cpu_addr[10:0]),
     .t80_cpu_wdata			(t80_cpu_wdata[15:0]),
     // Inputs
     .clk250				(clk250),
     .reset				(reset),
     .io_req				(io_req),
     .io_rd				(io_rd),
     .addr				(addr[15:0]),
     .mreq_n				(mreq_n),
     .dout				(dout[7:0]),
     .ram_rdata				(ram_rdata[7:0]),
     .cpu_t80_ack			(cpu_t80_ack),
     .cpu_t80_rdata			(cpu_t80_rdata[15:0]));

  t80_memctl t80_memctl0
    (
     // Outputs
     .mem_ack				(mem_ack),
     .ram_rdata				(ram_rdata[7:0]),
     .t80_cpu_mem_rdata			(t80_cpu_mem_rdata[7:0]),
     .t80_cpu_mem_ack			(t80_cpu_mem_ack),
     // Inputs
     .clk250				(clk250),
     .reset				(reset),
     .mem_req				(mem_req),
     .mem_rd				(mem_rd),
     .addr				(addr[asz-1:0]),
     .ram_wdata				(ram_wdata[7:0]),
     .cpu_t80_addr			(cpu_t80_addr[asz-1:0]),
     .cpu_t80_mem_read			(cpu_t80_mem_read),
     .cpu_t80_mem_wdata			(cpu_t80_mem_wdata[7:0]),
     .cpu_t80_mem_req			(cpu_sync_req));
  

// synopsys dc_script_begin
// set_attribute current_design "revision" "$Id: t80_top.v,v 1.1 2004-05-16 17:39:57 ghutchis Exp $" -type string -quiet
// synopsys dc_script_end
endmodule // t80_top
