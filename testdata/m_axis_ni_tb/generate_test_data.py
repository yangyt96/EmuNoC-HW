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


def bit_width(x: int):
    if x > 1:
        return math.ceil(math.log2(x))
    elif x == 1:
        return 1
    else:
        return 0


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


def conv_id_to_coord(router_id):
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


if __name__ == "__main__":
    # ----------------------------------------------

    # port 1
    port_val = 1
    time = 5
    flit_data = []
    inj_time = []
    pkt_len = []

    for itr, j in enumerate(range(30, 32)):
        flit = create_flit_hdr(pad=0, id=itr, src=port_val, dst=0, pkt_len=j)

        flit_data.extend([flit for itr in range(j)])
        inj_time.append(time)
        pkt_len.append(j)
        time += 30

    print(flit_data)
    print(inj_time)
    print(pkt_len)

    assert len(flit_data) == sum(pkt_len)

    path_inj_time = os.path.join("in", fname_inj_time)
    path_pkt_len = os.path.join("in", fname_pkt_len)
    path_flit_data = os.path.join("in", fname_flit_data)

    print(path_inj_time)
    print(path_pkt_len)
    print(path_flit_data)

    to_file(path_inj_time, "\n".join(map(str, inj_time)))
    to_file(path_pkt_len, "\n".join(map(str, pkt_len)))
    to_file(path_flit_data, "\n".join(flit_data))
