task test_pass;
    begin
      $display ("%t: --- TEST PASSED ---", $time);
      #100;
      $finish;
    end
endtask // test_pass

task test_fail;
    begin
      $display ("%t: !!! TEST FAILED !!!", $time);
      #100;
      $finish;
    end
endtask // test_fail

task dumpon;
    begin
      $dumpfile (`DUMPFILE_NAME);
      $dumpvars;
    end
endtask // dumpon

task dumpoff;
    begin
      // ???
    end
endtask // dumpoff

