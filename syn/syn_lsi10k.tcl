set file_list [list tv80s tv80_core tv80_alu tv80_mcode tv80_reg tv80_mcode_base tv80_mcode_cb tv80_mcode_ed ]
set module_name tv80s
set clock clk
set period 30

# create working directories, if not present
set dir_list [list db work report]
foreach dir $dir_list {
  if {[file isdirectory $dir] == 0} { file mkdir $dir }
}
define_design_lib WORK -path work

# read in design files
foreach file_name $file_list {
  analyze -format verilog ../rtl/core/$file_name.v
}
elaborate $module_name

current_design $module_name

# set up basic constraints and library info
create_clock $clock -period $period
set_clock_skew -uncertainty [expr $period / 10.0] $clock

set target_library [list lsi_10k.db]
set synthetic_library [list dw_foundation.sldb standard.sldb ]

set link_library [concat \
      * \
      $target_library \
      $synthetic_library \
      ]

# compile
compile

# save reports and resulting database
report_timing > report/$module_name.timing
report_area   > report/$module_name.area
report_reference > report/$module_name.reference
write -format db -hier -output db/$module_name.db

# now adjust clock speed and compile again
set period [expr $period / 3.0]
create_clock $clock -period $period
set_clock_skew -uncertainty [expr $period / 10.0] $clock

compile -effort high
report_timing > report/fast_$module_name.timing
report_area   > report/fast_$module_name.area
write -format db -hier -output db/fast_$module_name.db

quit

