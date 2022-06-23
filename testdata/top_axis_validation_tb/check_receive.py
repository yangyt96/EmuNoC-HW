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

from os import terminal_size
import os
import math
import pandas as pd

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


def read_file(fname):
    with open(fname, "r") as handle:
        ret = handle.read()
        return ret


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


def bin_to_info(binaries):
    assert (len(binaries) == flit_size), len(binaries)
    offset = 0
    pkt_id = int(binaries[:flit_id_bit_width], 2)
    offset = offset + flit_id_bit_width
    src = int(binaries[offset:offset+pe_bit_width], 2)
    offset = offset + pe_bit_width
    dst = int(binaries[offset:offset+pe_bit_width], 2)
    offset = offset+pe_bit_width
    dlen = int(binaries[offset:], 2)

    return {"id": pkt_id, "src": src, "dst": dst, "len": dlen}


if __name__ == "__main__":

    inj_pkts = [x for x in read_file(
        "in/flit_data.txt").split()]
    ej_time_data = [x for x in read_file(
        "out/recv_flit.txt").split()]

    inj_pkts = set(inj_pkts) - set(["1"*flit_size, "0"*flit_size])

    ej_pkts = set()
    ej_time_pkts = {}
    time = 0
    prev = "0"*flit_size
    for elem in ej_time_data:
        if prev == "0"*flit_size:
            time = int(elem, 2)
            ej_time_pkts[time] = []
        elif elem != "0"*flit_size:
            ej_pkts.add(elem)
            ej_time_pkts[time].append(elem)

        prev = elem

    for time, pkts in ej_time_pkts.items():
        for pkt in pkts:
            print("cyc:", time, pkt, bin_to_info(pkt))

    # lost packets
    lost_pkts = inj_pkts - ej_pkts
    # print("lost packets:")
    # for itr, pkt in enumerate(lost_pkts):
    #     print(itr, pkt, bin_to_info(pkt))
    print("lost packet len:", len(lost_pkts))

    lost_pkts = [bin_to_info(x) for x in lost_pkts]

    df = pd.DataFrame(lost_pkts)

    # print(df[df["src"] == df["src"].min()])
