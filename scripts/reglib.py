#!/usr/bin/env python
# Copyright (c) 2004 Guy Hutchison (ghutchis@opencores.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import string, math

def log2 (num):
    return math.ceil (math.log (num) / math.log (2))

def comb_block (statements):
    result = 'always @*\n'
    result += '  begin\n'
    for s in statements:
        result += '    ' + s + '\n'
    result += '  end\n'
    return result

def seq_block (clock, statements):
    result = 'always @(posedge ' + clock + ')\n'
    result += '  begin\n'
    for s in statements:
        result += '    ' + s + '\n'
    result += '  end\n'
    return result

class net:
    def __init__ (self, type, name, width=1):
        self.width = width
        self.name  = name
        self.type  = type

    def declaration (self):
        if (self.width == 1):
            return self.type + ' ' + self.name + ';'
        else:
            return "%s [%d:0] %s;" % (self.type, self.width-1, self.name)
        
class port:
    def __init__ (self, direction, name, width=1):
        self.direction = direction
        self.width = width
        self.name = name

    def declaration (self):
        if (self.width == 1):
            return self.direction + ' ' + self.name + ';'
        else:
            return "%s [%d:0] %s;" % (self.direction, self.width-1, self.name)
        
class register_group:
    def __init__ (self, mem_mapped=0):
        self.base_addr = 0
        self.addr_size = 16
        self.data_size = 8
        self.name = ''
        self.local_width = 1
        self.registers = []
        self.ports = [port ('input', 'clk'), port('input','reset')]
        self.nets  = []
        if (mem_mapped):
            self.req_pin = 'mreq_n'
        else:
            self.req_pin = 'iorq_n'
        self.tv80_intf()

    def tv80_intf (self):
        self.ports.append (port ('input', 'addr', self.addr_size))
        self.ports.append (port ('input', 'wr_data', self.data_size))
        self.ports.append (port ('output', 'rd_data', self.data_size))
        self.ports.append (port ('output', 'doe'))
        self.ports.append (port ('input','rd_n'))
        self.ports.append (port ('input', 'wr_n'))
        self.ports.append (port ('input', self.req_pin))

    def global_logic (self):
        # create select pin for this block
        self.nets.append (net('reg','block_select'))
        statements = ["block_select = (addr[%d:%d] == %d) & !%s;" % (self.addr_size-1,self.local_width,self.base_addr >> self.local_width, self.req_pin)]

        # create read and write selects for each register
        for r in self.registers:
            s = "%s_rd_sel = block_select & (addr[%d:%d] == %d) & !rd_n;" % (r.name,self.local_width-1,0,r.offset)
            statements.append (s)
            if r.write_cap():
                s = "%s_wr_sel = block_select & (addr[%d:%d] == %d) & !wr_n;" % (r.name,self.local_width-1,0,r.offset)
                statements.append (s)

        return comb_block (statements)

    def read_mux (self):
        s = ''
        for r in self.registers:
            s += "assign rd_data = (%s_rd_sel) ? %s : %d'bz;\n" % (r.name, r.name, self.data_size)

        return s
                
        
    def verilog (self):
        result = 'module ' + self.name + ' (\n'
        result += string.join (map (lambda x: x.name, self.ports), ',')
        result += ');\n'

        # print port list
        for p in self.ports:
            result += p.declaration() + '\n'

        # print net list
        for n in self.nets:
            result += n.declaration() + '\n'

        # create global logic
        result += self.global_logic()
        result += self.read_mux()
        
        # print function blocks
        for r in self.registers:
            result += r.verilog_body()
            
        result += 'endmodule;\n'
        return result

    def add_register (self, name, type, width):
        if (type == 'status'):
            self.add (status_reg (name,width))
        elif (type == 'config'):
            self.add (config_reg (name,width))
        else:
            print "Unknown register type",type
            
    def add (self, reg):
        self.registers.append (reg)
        self.ports.extend (reg.io())
        self.nets.extend (reg.nets())
        self.local_width = int(math.ceil (log2 (len (self.registers))))
        rnum = 0
        for r in self.registers:
            r.offset = rnum
            rnum += 1
        
class basic_register:
    def __init__ (self, name='', width=0):
        self.offset = 0
        self.width  = width
        self.name   = name

    def verilog_body (self):
        pass

    def io (self):
        return []

    def nets (self):
        return []

    def write_cap (self):
        return 0

class status_reg (basic_register):
    def __init__ (self, name='', width=0):
        basic_register.__init__(self, name, width)
        
    def verilog_body (self):
        pass

    def io (self):
        return [('input',self.width, self.name)]

    def nets (self):
        return [ net('reg', name + '_rd_sel')]

class config_reg (basic_register):
    def __init__ (self, name='', width=0):
        basic_register.__init__(self, name, width)
        self.default = 0
        
    def verilog_body (self):
        statements = ["if (reset) %s <= %d;" % (self.name, self.default),
                      "else if %s_wr_sel %s <= %s;" % (self.name, self.name, 'wr_data')
                      ]
        return seq_block ('clk', statements)

    def io (self):
        return [ port('output',self.name, self.width) ]

    def nets (self):
        return [ net('reg', self.name + '_rd_sel'), net('reg', self.name + '_wr_sel')]

    def write_cap (self):
        return 1
    
