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

import string, math, re

def log2 (num):
    return math.ceil (math.log (num) / math.log (2))

# function that tries to interpret a number in Verilog notation
def number (str):
    try:
        robj = re.compile ("(\d+)'([dhb])([\da-fA-F]+)")
        mobj = robj.match (str)
        if (mobj):
            if mobj.group(2) == 'h': radix = 16
            elif mobj.group(2) == 'b': radix = 2
            else: radix = 10
    
            return int (mobj.group(3), radix)
        else:
            return int(str)
    except ValueError:
        print "ERROR: number conversion of %s failed" % str
        return 0

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
        self.interrupts = 0
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
        self.nets.append (net('reg','rd_data',self.data_size))
        self.nets.append (net('reg','block_select'))
        self.nets.append (net('reg','doe'))

    # create a hook for post-processing to be done after all data has been
    # added to the object.
    def post (self):
        if (self.interrupts):
            self.int_ports()
        
    # create port for interrupt pin, as well as port for data output enable
    # when interrupt is asserted.
    # This block should be called after all register data has been read.
    def int_ports (self):
        self.ports.append (port ('output','int_n'))
        self.nets.append (net ('reg','int_n'))
        self.nets.append (net ('reg','int_vec',self.data_size))

    def int_logic (self):
        statements = []
        int_nets = []
        for r in self.registers:
            if r.interrupt: int_nets.append (r.name + "_int")
        statements.append ("int_n = ~(" + string.join (int_nets, ' | ') + ");")
        return comb_block (statements)

    def global_logic (self):
        # create select pin for this block
        statements = ["block_select = (addr[%d:%d] == %d) & !%s;" % (self.addr_size-1,self.local_width,self.base_addr >> self.local_width, self.req_pin)]

        # create read and write selects for each register
        for r in self.registers:
            slogic =  "block_select & (addr[%d:%d] == %d) & !rd_n" % (self.local_width-1,0,r.offset)
            #if r.interrupt:
            #    slogic = "%s_int | (%s)" % (r.name, slogic)
            s = "%s_rd_sel = %s;" % (r.name,slogic)
            statements.append (s)
            if r.write_cap():
                s = "%s_wr_sel = block_select & (addr[%d:%d] == %d) & !wr_n;" % (r.name,self.local_width-1,0,r.offset)
                statements.append (s)

        return comb_block (statements)

    def read_mux (self):
        s = ''
        sments = []
        rd_sel_list = []
        # Old code for simple tri-state interface
        #for r in self.registers:
        #    s += "assign rd_data = (%s_rd_sel) ? %s : %d'bz;\n" % (r.name, r.name, self.data_size)

        # create interrupt address mux
        if (self.interrupts):
            sments.append ("case (1'b1)")
            for r in self.registers:
                if r.interrupt:
                    sments.append ("  %s_int : int_vec = %d;" % (r.name, r.int_value))
            sments.append ("  default : int_vec = %d'bx;" % self.data_size)
            sments.append ("endcase")

        # create data-output mux
        sments.append ("case (1'b1)")
        for r in self.registers:
            sments.append ("  %s_rd_sel : rd_data = %s;" % (r.name, r.name))
            rd_sel_list.append (r.name + "_rd_sel")
        if (self.interrupts):
            sments.append ("  default : rd_data = int_vec;")
        else: sments.append ("  default : rd_data = %d'bx;" % self.data_size)
        sments.append ("endcase")

        sments.append ("doe = %s;" % string.join (rd_sel_list, ' | '))

        return comb_block (sments)
                
        
    def verilog (self):
        self.post()
        
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
        if (self.interrupts > 0): result += self.int_logic()
        
        # print function blocks
        for r in self.registers:
            result += r.verilog_body()
            
        result += 'endmodule\n'
        return result

    def add_register (self, type, params):
    #def add_register (self, name, type, width):
        if (type == 'status'):
            self.add (status_reg (params['name'],params['width']))
        elif (type == 'config'):
            self.add (config_reg (params['name'],params['width'],params['default']))
        elif (type == 'int_fixed'):
            r2 = config_reg (params['name'] + "_msk",params['width'],params['default'])
            r1 = int_fixed_reg (params['name'],r2,number(params['int_value']),params['width'])
            self.add (r1)
            self.add (r2)
            self.interrupts += 1
        elif (type == 'soft_set'):
            self.add (soft_set_reg(params['name'],params['width'],params['default']))
        elif (type == 'read_stb'):
            self.add (read_stb_reg (params['name'],params['width']))
        elif (type == 'write_stb'):
            self.add (write_stb_reg (params['name'],params['width'],params['default']))
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
        self.interrupt = 0

    def verilog_body (self):
        pass

    def io (self):
        return []

    def nets (self):
        return []

    def write_cap (self):
        return 0

    def id_comment (self):
        return "// register: %s\n" % self.name

class status_reg (basic_register):
    def __init__ (self, name='', width=0):
        basic_register.__init__(self, name, width)
        
    def verilog_body (self):
        return ''

    def io (self):
        return [port('input', self.name, self.width)]

    def nets (self):
        return [ net('reg', self.name + '_rd_sel')]

class config_reg (basic_register):
    def __init__ (self, name='', width=0, default=0):
        basic_register.__init__(self, name, width)
        self.default = default
        
    def verilog_body (self):
        statements = ["if (reset) %s <= %d;" % (self.name, self.default),
                      "else if (%s_wr_sel) %s <= %s;" % (self.name, self.name, 'wr_data')
                      ]
        return self.id_comment() + seq_block ('clk', statements)

    def io (self):
        return [ port('output',self.name, self.width) ]

    def nets (self):
        return [ net('reg', self.name, self.width),
                 net('reg', self.name + '_rd_sel'),
                 net('reg', self.name + '_wr_sel')]

    def write_cap (self):
        return 1

class int_fixed_reg (basic_register):
    def __init__ (self, name, mask_reg, int_value, width=0):
        basic_register.__init__(self, name, width)
        self.mask_reg = mask_reg
        self.interrupt = 1
        self.int_value = int_value
        
    def verilog_body (self):
        statements = ["if (reset) %s <= %d;" % (self.name, 0),
                      "else %s <= (%s_set | %s) & ~( {%d{%s}} & %s);" %
                      (self.name, self.name, self.name, self.width, self.name + '_wr_sel', 'wr_data'),
                      "if (reset) %s_int <= 0;" % self.name,
                      "else %s_int <= |(%s & ~%s);" % (self.name, self.name, self.mask_reg.name)
                      ]
        return self.id_comment() + seq_block ('clk', statements)

    def io (self):
        return [ port('input',self.name+"_set", self.width) ]

    def nets (self):
        return [ net('reg', self.name + '_rd_sel'),
                 net('reg', self.name, self.width),
                 net('reg', self.name + '_wr_sel'),
                 net('reg', self.name + '_int')]

    def write_cap (self):
        return 1

class soft_set_reg (basic_register):
    def __init__ (self, name='', width=0, default=0):
        basic_register.__init__(self, name, width)
        self.default = default
        
    def verilog_body (self):
        statements = ["if (reset) %s <= %d;" % (self.name, self.default),
                      "else %s <= ( ({%d{%s}} & %s) | %s) & ~(%s);" %
                            (self.name, self.width, self.name+'_wr_sel', 'wr_data',
                             self.name, self.name + '_clr')
                      ]
        return self.id_comment() + seq_block ('clk', statements)

    def io (self):
        return [ port('output',self.name, self.width),
                 port ('input',self.name+"_clr", self.width)]

    def nets (self):
        return [ net('reg', self.name, self.width),
                 net('reg', self.name + '_rd_sel'),
                 net('reg', self.name + '_wr_sel')]

    def write_cap (self):
        return 1

class write_stb_reg (config_reg):
    def __init__ (self, name='', width=0, default=0):
        config_reg.__init__(self, name, width, default)
        
    def verilog_body (self):
        statements = ["if (reset) %s <= %d;" % (self.name, self.default),
                      "else if (%s_wr_sel) %s <= %s;" % (self.name, self.name, 'wr_data'),
                      "if (reset) %s_stb <= 0;" % (self.name),
                      "else if (%s_wr_sel) %s_stb <= 1;" % (self.name, self.name),
                      "else %s_stb <= 0;" % (self.name)
                      ]
        return seq_block ('clk', statements)

    def io (self):
        io_list = config_reg.io (self)
        io_list.append ( port('output',self.name+"_stb") )
        return io_list

    def nets (self):
        net_list = config_reg.nets (self)
        net_list.append ( net('reg', self.name + "_stb") )
        return net_list

class read_stb_reg (status_reg):
    def __init__ (self, name='', width=0):
        status_reg.__init__(self, name, width)
        
    def verilog_body (self):
        statements = [
                      "if (reset) %s_stb <= 0;" % (self.name),
                      "else if (%s_rd_sel) %s_stb <= 1;" % (self.name, self.name),
                      "else %s_stb <= 0;" % (self.name)
                      ]
        return self.id_comment() + seq_block ('clk', statements)

    def io (self):
        io_list = status_reg.io (self)
        io_list.append (port('output',self.name+"_stb"))
        return io_list

    def nets (self):
        net_list = status_reg.nets(self)
        net_list.append (net('reg',self.name + '_stb'))
        return net_list
