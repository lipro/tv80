#!/usr/bin/env python

def ihex2mem (infile, outfile):
    ifh = open (infile, 'r')
    ofh = open (outfile, 'w')

    bcount = 0
    line = ifh.readline()
    while (line != ''):
        if (line[0] == ':'):
            rlen = int(line[1:3], 16)
            addr = int(line[3:7], 16)
            rtyp = int(line[7:9], 16)
            ptr = 9
            for i in range (0, rlen):
                val = int(line[9+i*2:9+i*2+2], 16)
                ofh.write ("@%02x %02x\n" % (addr+i, val))
                bcount += 1

        line = ifh.readline()
        
    ifh.close()
    ofh.close()

    return bcount

def cmdline ():
    import sys
    
    infile = sys.argv[1]
    outfile = sys.argv[2]

    bc = ihex2mem (infile, outfile)
    print "Converted %d bytes from %s to %s" % (bc, infile, outfile)
    
if __name__ == '__main__':
    cmdline()

