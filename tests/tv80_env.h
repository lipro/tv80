// Environment library
// Creates definitions of the special I/O ports used by the
// environment, as well as some utility functions to allow
// programs to print out strings in the test log.

#ifndef TV80_ENV_H
#define TV80_ENV_H

sfr at 0x80 sim_ctl_port;
sfr at 0x81 msg_port;
sfr at 0x82 timeout_port;
sfr at 0x83 max_timeout_low;
sfr at 0x84 max_timeout_high;

#define SC_TEST_PASSED 0x01
#define SC_TEST_FAILED 0x02
#define SC_DUMPON      0x03
#define SC_DUMPOFF     0x04

void print (char *string)
{
  char *iter;

  timeout_port = 0x02;
  timeout_port = 0x01;

  iter = string;
  while (*iter != 0) {
    msg_port = *iter++;
  }
}

void print_num (int num)
{
  int cd = 0;
  int i;
  char digits[8];

  timeout_port = 0x02;
  timeout_port = 0x01;

  while (num > 0) {
    digits[cd++] = (num % 10) + '0';
    num /= 10;
  }
  for (i=cd; i>0; i--)
    msg_port = digits[i-1];
}

void sim_ctl (unsigned char code)
{
  sim_ctl_port = code;
}

void set_timeout (unsigned int max_timeout)
{
  timeout_port = 0x02;

  max_timeout_low = (max_timeout & 0xFF);
  max_timeout_high = (max_timeout >> 8);

  timeout_port = 0x01;
}

#endif
