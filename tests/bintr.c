#include "tv80_env.h"

/*
 * This test covers interrupt handling routines.  The actual interrupt code
 * is in assembly, in bintr_crt0.asm.
 *
 * The test generates five interrupts, and clears the interrupt after
 * each one.
 *
 * The isr routine uses the two writes to intr_cntdwn to first clear
 * assertion of the current interrupt and then disable the countdown
 * timer.
 */

unsigned char foo;
volatile unsigned char test_pass;
static unsigned char triggers;

void isr (void)
{
  triggers++;

  if (triggers > 5) {
    test_pass = 1;
    intr_cntdwn = 255;
    intr_cntdwn = 0;
  } else
    intr_cntdwn = 32;
}

int main ()
{
  int i;
  unsigned char check;

  test_pass = 0;
  triggers = 0;

  // start interrupt countdown
  intr_cntdwn = 64;

  for (i=0; i<200; i++)
    check = sim_ctl_port;

  if (test_pass)
    sim_ctl (SC_TEST_PASSED);
  else
    sim_ctl (SC_TEST_FAILED);

  return 0;
}

