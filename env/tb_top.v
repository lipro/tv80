`define TV80_CORE_PATH tb_top.tv80s_inst.i_tv80_core

module tb_top;

  reg         clk;
  reg         reset_n; 
  reg         wait_n; 
  reg         int_n; 
  reg         nmi_n; 
  reg         busrq_n; 
  wire        m1_n; 
  wire        mreq_n; 
  wire        iorq_n; 
  wire        rd_n; 
  wire        wr_n; 
  wire        rfsh_n; 
  wire        halt_n; 
  wire        busak_n; 
  wire [15:0] A;
  wire [7:0]  di;
  wire [7:0]  do;
  wire 	      ram_rd_cs, ram_wr_cs, rom_rd_cs;
  reg         tx_clk;
  
  always
    begin
      clk = 1;
      #5;
      clk = 0;
      #5;
    end

  always
    begin
      tx_clk = 0;
      #8;
      tx_clk = 1;
      #8;
    end      

  assign rom_rd_cs = !mreq_n & !rd_n & !A[15];
  assign ram_rd_cs = !mreq_n & !rd_n & A[15];
  assign ram_wr_cs = !mreq_n & !wr_n & A[15];
  
  tv80s tv80s_inst
    (
     // Outputs
     .m1_n				(m1_n),
     .mreq_n				(mreq_n),
     .iorq_n				(iorq_n),
     .rd_n				(rd_n),
     .wr_n				(wr_n),
     .rfsh_n				(rfsh_n),
     .halt_n				(halt_n),
     .busak_n				(busak_n),
     .A					(A[15:0]),
     .do				(do[7:0]),
     // Inputs
     .reset_n				(reset_n),
     .clk				(clk),
     .wait_n				(wait_n),
     .int_n				(int_n),
     .nmi_n				(nmi_n),
     .busrq_n				(busrq_n),
     .di				(di[7:0]));

  async_mem ram
    (
     // Outputs
     .rd_data				(di),
     // Inputs
     .wr_clk				(clk),
     .wr_data				(do),
     .wr_cs				(ram_wr_cs),
     .addr				(A[14:0]),
     .rd_cs				(ram_rd_cs));

  async_mem rom
    (
     // Outputs
     .rd_data				(di),
     // Inputs
     .wr_clk				(),
     .wr_data				(),
     .wr_cs				(1'b0),
     .addr				(A[14:0]),
     .rd_cs				(rom_rd_cs));

  env_io env_io_inst
    (
     // Outputs
     .DI				(di[7:0]),
     // Inputs
     .clk				(clk),
     .iorq_n				(iorq_n),
     .rd_n				(rd_n),
     .wr_n				(wr_n),
     .addr				(A[7:0]),
     .DO				(do[7:0]));

  wire   nwintf_sel = !iorq_n & (A[7:3] == 5'b00001);
  wire [7:0] rx_data, tx_data;
  wire       rx_clk, rx_dv, rx_er;
  wire       tx_dv, tx_er;
  wire [7:0] nw_data_out;
  
  // loopback config
  assign     rx_data = tx_data;
  assign     rx_dv = tx_dv;
  assign     rx_er = tx_er;
  assign     rx_clk = tx_clk;

  assign     di = (nwintf_sel & !rd_n) ? nw_data_out : 8'bz;
  
  simple_gmii nwintf
    (
     // Outputs
     .tx_dv                             (tx_dv),
     .tx_er                             (tx_er),
     .tx_data                           (tx_data),
     .tx_clk                            (tx_clk),
     .io_data_out                       (nw_data_out),
     // Inputs
     .clk                               (clk),
     .reset                             (!reset_n),
     .rx_data                           (rx_data),
     .rx_clk                            (rx_clk),
     .rx_dv                             (rx_dv),
     .rx_er                             (rx_er),
     .io_select                         (nwintf_sel),
     .rd_n                              (rd_n),
     .wr_n                              (wr_n),
     .io_addr                           (A[2:0]),
     .io_data_in                        (do));

  initial
    begin
      clear_ram;
      reset_n = 0;
      wait_n = 1;
      int_n  = 1;
      nmi_n  = 1;
      busrq_n = 1;
      $readmemh (`PROGRAM_FILE,  tb_top.rom.mem);
      repeat (20) @(negedge clk);
      reset_n = 1;
    end // initial begin

`ifdef DUMP_START
  always
    begin
      if ($time > `DUMP_START)
	dumpon;
      #100;
    end
`endif
  
  
/*
  always
    begin
      while (mreq_n) @(posedge clk);
      wait_n <= #1 0;
      @(posedge clk);
      wait_n <= #1 1;
      while (!mreq_n) @(posedge clk);
    end
  */
      
`ifdef TV80_INSTRUCTION_DECODE
  reg [7:0] state;
  initial
    state = 0;
     
  always @(posedge clk)
    begin : inst_decode
      if ((`TV80_CORE_PATH.mcycle[6:0] == 1) && 
          (`TV80_CORE_PATH.tstate[6:0] == 8))
        begin
          op_decode.decode (`TV80_CORE_PATH.IR[7:0], state);
        end
      else if (`TV80_CORE_PATH.mcycle[6:0] != 1)
        state = 0;
    end
`endif
  
`include "env_tasks.v"
  
endmodule // tb_top
