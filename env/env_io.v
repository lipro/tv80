
module env_io (/*AUTOARG*/
  // Outputs
  DI, 
  // Inputs
  clk, iorq_n, rd_n, wr_n, addr, DO
  );

  parameter str_buf_sz = 256;
  
  input clk;
  input iorq_n;
  input rd_n;
  input wr_n;
  input [7:0] addr;
  input [7:0] DO;
  inout [7:0] DI;

  reg [7:0]    io_data;

  reg [7:0]    str_buf [0:str_buf_sz-1];
  reg 	       io_cs;
  integer      buf_ptr, i;

  reg [7:0]    timeout_ctl;
  reg [15:0]   cur_timeout;
  reg [15:0]   max_timeout;

  reg [7:0]    int_countdown;
  
  assign       DI = (!iorq_n & !rd_n & io_cs) ? io_data : {8{1'bz}};

  initial
    begin
      io_cs = 0;
      buf_ptr = 0;
      cur_timeout = 0;
      max_timeout = 10000;
      timeout_ctl = 1;
      int_countdown = 0;
    end
  
  always @(posedge clk)
    begin
      if (!iorq_n & !wr_n)
	case (addr)
	  8'h80 :
	    begin
	      case (DO)
		1 : tb_top.test_pass;

		2 : tb_top.test_fail;

		3 : tb_top.dumpon;

		4 : tb_top.dumpoff;

		default :
		  begin
		    $display ("%t: ERROR   : Unknown I/O command %x", $time, DO);
		  end
	      endcase // case(DO)
	    end // case: :...

	  8'h81 :
	    begin
	      str_buf[buf_ptr] = DO;
	      buf_ptr = buf_ptr + 1;

	      if (buf_ptr == str_buf_sz)
		begin
		  $display ("%t: WARNING : String buffer reached maximum size without detecting EOL", $time);
		  $write ("%t: WARNING : Contents: ", $time);
		  for (i=0; i<buf_ptr; i=i+1)
		    $write ("%s", str_buf[i]);
		  $write ("\n");
		  buf_ptr = 0;
		end

	      //$display ("%t: DEBUG   : Detected write of character %x", $time, DO);
	      if (DO == 8'h0A)
		begin
		  $write ("%t: PROGRAM : ", $time);

		  for (i=0; i<buf_ptr; i=i+1)
		    $write ("%s", str_buf[i]);
		      
		  buf_ptr = 0;
		end
	    end // case: 8'h81

	  8'h82 :
	    begin
	      timeout_ctl = DO;
  	    end

	  8'h83 : max_timeout[7:0] = DO;
	  8'h84 : max_timeout[15:8] = DO;

	  8'h90 : int_countdown = DO;
	endcase // case(addr)
    end // always @ (posedge clk)

  always @(posedge clk)
    begin
      if (timeout_ctl[1])
	cur_timeout = 0;
      else if (timeout_ctl[0])
	cur_timeout = cur_timeout + 1;

      if (cur_timeout >= max_timeout)
	begin
	  $display ("%t: ERROR   : Reached timeout %d cycles", $time, max_timeout);
	  tb_top.test_fail;
	end
    end // always @ (posedge clk)

  always @(posedge clk)
    begin
      if (int_countdown == 1)
	begin
	  tb_top.int_n  <= #1 1'b0;
	  int_countdown = 0;
	end
      else if (int_countdown > 1)
	int_countdown = int_countdown - 1;
    end
  
endmodule // env_io
