"""
COPYRIGHT(c) 2022
INSTITUTE FOR COMMUNICATION TECHNOLOGIES AND EMBEDDED SYSTEMS
RWTH AACHEN
GERMANY

This confidential and proprietary software may be used, copied,
modified, merged, published or distributed according to the
permissions and/or limitations granted by an authorizing license
agreement.

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

Author: 1. Tan Yee Yang (tan@ice.rwth-aachen.de)
        2. Jan Moritz Joseph (joseph@ice.rwth-aachen.de)
"""

import os
import math
from random import randint, shuffle

# ----------------------------------------------
# General function


def bit_width(val: int):
    if val > 1:
        return math.ceil(math.log2(val))
    elif val == 1:
        return 1
    else:
        return 0
    return len(bin(val))-2


def int_to_bin(val, length):
    ret = bin(val)[2:].zfill(length)
    assert length == len(ret), "length={} len(ret)={}".format(length, len(ret))
    return ret


def to_file(path, str_obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        handle.write(str_obj)
        handle.close()


# ----------------------------------------------
# NoC configuration
max_x_dim = 4  # check noc pkg
max_y_dim = 4  # check noc pkg
max_z_dim = 1  # check noc pkg

num_pe = max_x_dim * max_y_dim * max_z_dim

flit_size = 32  # const
flit_pkt_width = 5  # check noc pkg
pe_bit_width = bit_width(num_pe)
flit_id_bit_width = flit_size - flit_pkt_width - 2*pe_bit_width

max_pkt_len = 2**flit_pkt_width - 1

# ----------------------------------------------
# Generated files: same in vhdl
fname_inj_time = "inj_time.txt"
fname_pkt_len = "pkt_len.txt"
fname_flit_data = "flit_data.txt"

# ----------------------------------------------
# Global variables
pkt_id = 0

node_to_coord = {}
coord_to_node = {}
node = 0
for z in range(max_z_dim):
    for y in range(max_y_dim):
        for x in range(max_x_dim):
            xyz = (x, y, z)
            node_to_coord[node] = xyz
            coord_to_node[xyz] = node
            print(node, xyz)
            node += 1

# ----------------------------------------------
# Functions


def create_packet(src, dst, pkt_len):
    global pkt_id
    pkt_data = ""
    pkt_data += int_to_bin(pkt_id, flit_id_bit_width)
    pkt_data += int_to_bin(src, pe_bit_width)
    pkt_data += int_to_bin(dst, pe_bit_width)
    pkt_data += int_to_bin(pkt_len, flit_pkt_width)

    assert len(pkt_data) == flit_size, "len(pkt_data)={}, pkt_len:{}".format(
        len(pkt_data), pkt_len)

    pkt_id += 1
    return pkt_data


class TestData(dict):
    def __init__(self):
        self["flit_data"] = []
        self["inj_time"] = []
        self["pkt_len"] = []

    def add(self, data: dict):
        self["flit_data"].extend(data["flit_data"])
        self["inj_time"].extend(data["inj_time"])
        self["pkt_len"].extend(data["pkt_len"])

    def to_txt(self, path="."):
        path_flit_data = os.path.join(path, "flit_data.txt")
        path_inj_time = os.path.join(path, "inj_time.txt")
        path_pkt_len = os.path.join(path, "pkt_len.txt")

        with open(path_flit_data, "w") as handle:
            handle.write("\n".join(self["flit_data"]))
            handle.close()
        with open(path_inj_time, "w") as handle:
            handle.write("\n".join(map(str, self["inj_time"])))
            handle.close()
        with open(path_pkt_len, "w") as handle:
            handle.write("\n".join(map(str, self["pkt_len"])))
            handle.close()


def bin_to_info(binaries):
    assert (len(binaries) == flit_size), len(binaries)
    offset = 0
    tmp_id = int(binaries[:flit_id_bit_width], 2)
    offset = offset + flit_id_bit_width
    tmp_src = int(binaries[offset:offset+pe_bit_width], 2)
    offset = offset + pe_bit_width
    tmp_dst = int(binaries[offset:offset+pe_bit_width], 2)
    offset = offset+pe_bit_width
    tmp_len = int(binaries[offset:], 2)

    return {"id": tmp_id, "src": tmp_src, "dst": tmp_dst, "len": tmp_len}


if __name__ == "__main__":

    """ Pressure test """
    td = TestData()

    ########################################################################
    # data injection all to all
    data = {}
    time = 0
    data["flit_data"] = [int_to_bin(time, flit_size)]
    data["inj_time"] = [time]

    for i in range(num_pe):
        tmp = []
        for j in range(num_pe):
            if i == j:
                continue

            tmp.append(create_packet(i, j, 31))

        # shuffle(tmp)
        data["flit_data"].extend(tmp)

    data["pkt_len"] = [len(data["flit_data"])]
    td.add(data)

    # ##########################################################################
    # # test: custom
    # time = 0
    # data = {}
    # data["flit_data"] = [int_to_bin(time, flit_size)]
    # data["inj_time"] = [time]
    # data["flit_data"].append(create_packet(0, 1, 31))
    # data["flit_data"].append(create_packet(0, 2, 31))
    # data["flit_data"].append(create_packet(0, 3, 31))
    # data["pkt_len"] = [len(data["flit_data"])]
    # td.add(data)

    # time = 21
    # data = {}
    # data["flit_data"] = [int_to_bin(time, flit_size)]
    # data["inj_time"] = [time]
    # data["flit_data"].append(create_packet(2, 1, 27))
    # data["pkt_len"] = [len(data["flit_data"])]
    # td.add(data)

    # time = 91
    # data = {}
    # data["flit_data"] = [int_to_bin(time, flit_size)]
    # data["inj_time"] = [time]
    # data["flit_data"].append(create_packet(1, 3, 4))
    # data["pkt_len"] = [len(data["flit_data"])]
    # td.add(data)

    # ##########################################################################
    # # run to 500
    # data = {}
    # data["flit_data"] = [int_to_bin(500, flit_size)]
    # data["inj_time"] = [0]
    # data["pkt_len"] = [1]
    # td.add(data)

    # td.to_txt("in")

    ##########################################################################
    # run to inf
    data = {}
    data["flit_data"] = ["1"*flit_size]
    data["inj_time"] = [0]
    data["pkt_len"] = [1]
    td.add(data)

    td.to_txt("in")
