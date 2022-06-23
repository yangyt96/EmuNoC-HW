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


def int_to_bin(val, len):
    return bin(val)[2:].zfill(len)


def to_file(path, str_obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        handle.write(str_obj)
        handle.close()


# ----------------------------------------------
# NoC configuration
max_x_dim = 2  # check noc pkg
max_y_dim = 2  # check noc pkg
max_z_dim = 1  # check noc pkg

flit_size = 32  # const
flit_pkt_width = 5  # check noc pkg
flit_addr_x_width = bit_width(max_x_dim)
flit_addr_y_width = bit_width(max_y_dim)
flit_addr_z_width = bit_width(max_z_dim)
flit_id_width = 8
flit_pad_width = flit_size - flit_id_width - flit_pkt_width \
    - 2 * (flit_addr_x_width + flit_addr_y_width + flit_addr_z_width)

# Router configuration
port_num = 5  # check noc pkg

port_exist = [x for x in range(1, port_num)]
max_pkt_len = 2**flit_pkt_width - 1

# ----------------------------------------------
# Generated files: same in vhdl
fname_inj_time = "inj_time.txt"
fname_pkt_len = "pkt_len.txt"
fname_flit_data = "flit_data.txt"

# ----------------------------------------------
# Functions


def conv_id_to_coord(router_id: int):
    z = router_id // (max_x_dim * max_y_dim)
    y = router_id % (max_x_dim * max_y_dim) // max_x_dim
    x = router_id % (max_x_dim * max_y_dim) % max_x_dim

    return {"x": x, "y": y, "z": z}


def create_flit_hdr(pad, id, src, dst, pkt_len):
    src_coord = conv_id_to_coord(src)
    dst_coord = conv_id_to_coord(dst)

    hdr = ""
    hdr += int_to_bin(pad, flit_pad_width)
    hdr += int_to_bin(id, flit_id_width)
    hdr += int_to_bin(src_coord["z"], flit_addr_z_width)
    hdr += int_to_bin(src_coord["y"], flit_addr_y_width)
    hdr += int_to_bin(src_coord["x"], flit_addr_x_width)
    hdr += int_to_bin(dst_coord["z"], flit_addr_z_width)
    hdr += int_to_bin(dst_coord["y"], flit_addr_y_width)
    hdr += int_to_bin(dst_coord["x"], flit_addr_x_width)
    hdr += int_to_bin(pkt_len, flit_pkt_width)

    assert len(hdr) == flit_size
    return hdr


def create_sim_data(start_time: int, pkt_len: int, src: int, dst: int, pad=0):
    ret = {}
    ret["flit_data"] = [create_flit_hdr(pad, id=itr,
                                        src=src, dst=dst,
                                        pkt_len=pkt_len) for itr in range(pkt_len)]
    ret["inj_time"] = [start_time]
    ret["pkt_len"] = [pkt_len]

    return ret


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


if __name__ == "__main__":

    td = TestData()

    # single test for long packet
    td.add(create_sim_data(start_time=0,
           pkt_len=max_pkt_len, src=0, dst=3))

    # single test for smaller packet
    td.add(create_sim_data(start_time=100,
           pkt_len=max_pkt_len//2, src=0, dst=2))

    # continuously multiple small packet injection
    for itr in range(4):
        td.add(create_sim_data(start_time=300,
                               pkt_len=2, src=0, dst=1))

    for itr in range(10):
        td.add(create_sim_data(start_time=400,
                               pkt_len=1, src=0, dst=1))

    td.to_txt("in")
