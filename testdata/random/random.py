# Project    : Traffic generator for  NoC
# -----------------------------------------
# Description: Generate different length of packets that will be injected to NoC
# -----------------------------------------
# File       : random.py
# Author     : Tan Yee Yang <yee.yang.tan@rwth-aachen.de>
# Company    : RWTH Aachen University
# -----------------------------------------
# Copyright (c) 2021
# -----------------------------------------
# Vesion     : 2021.5
# -----------------------------------------
# Header structure:
# -----------------------------------------------------------------------------------------------
# |              |           |       |       |       |        |        |        |               |
# | Flit_padding | Packet_id | Z_src | Y_src | X_src | Z_dest | Y_dest | X_dest | Packet_length |
# |              |           |       |       |       |        |        |        |               |
# -----------------------------------------------------------------------------------------------

import os

NOC_Z = 1
NOC_Y = [2]
NOC_X = [2]

src_addr = (0,0,)