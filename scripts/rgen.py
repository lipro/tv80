#!/usr/bin/python
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

# This script generates I/O mapped control and status registers based
# on an XML configuration file.

import reglib
import xml.dom.minidom
import sys, os, re

def node_info (node):
    print "Methods:",dir(node)
    print "Child Nodes:",node.childNodes

def create_reg_group (node):
    rg = reglib.register_group()

    rg.name = node.getAttribute ("name")
    rg.addr_size = reglib.number(node.getAttribute ("addr_sz"))
    rg.base_addr = reglib.number(node.getAttribute ("base_addr"))

    return rg

def create_register (rg, node):
    params = {}
    params['name'] = node.getAttribute ("name")
    type = node.getAttribute ("type")
    params['width'] = int(node.getAttribute ("width"))
    params['default'] = node.getAttribute ("default")
    params['int_value'] = node.getAttribute ("int_value")

    # May switch to this code later for a more general implementation
    #for anode in node.childNodes:
    #    if anode.nodeType = anode.ATTRIBUTE_NODE:
    #        params[anode.nodeName] = anode.nodeValue

    if type == '': type = 'config'
    if params['default'] == '': params['default'] = 0
    else: params['default'] = reglib.number (params['default'])

    rg.add_register (type, params)

def create_verilog (top_node):
    rg = create_reg_group (top_node)

    # get list of register nodes
    reg_nodes = top_node.getElementsByTagName ("register")

    for r in reg_nodes:
        create_register (rg, r)

    fname = rg.name + ".v"
    fh = open (fname, 'w')
    fh.write (rg.verilog())
    fh.close()

def parse_file (filename):
    rdoc = xml.dom.minidom.parse (filename)
    blk_list = rdoc.getElementsByTagName ("tv_registers")

    for blk in blk_list:
        create_verilog (blk)
    
    rdoc.unlink()

if (len (sys.argv) > 1):
    parse_file (sys.argv[1])
else:
    print "Usage: %s <filename>" % os.path.basename (sys.argv[0])

