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

max_vc_num = 2  # check noc pkg

num_pe = max_x_dim * max_y_dim * max_z_dim

flit_size = 32  # const
flit_pkt_width = 5  # check noc pkg
pe_addr_width = bit_width(num_pe)
flit_id_bit_width = flit_size - flit_pkt_width - 2*pe_addr_width

max_pkt_len = 2**flit_pkt_width - 1
# ----------------------------------------------


def bin_to_info(binaries):
    assert (len(binaries) == flit_size), len(binaries)
    offset = 0
    pkt_id = int(binaries[:flit_id_bit_width], 2)
    offset = offset + flit_id_bit_width
    src = int(binaries[offset:offset+pe_addr_width], 2)
    offset = offset + pe_addr_width
    dst = int(binaries[offset:offset+pe_addr_width], 2)
    offset = offset+pe_addr_width
    dlen = int(binaries[offset:], 2)

    return {"id": pkt_id, "src": src, "dst": dst, "len": dlen}


if __name__ == "__main__":

    noc_time = [x for x in read_file(
        "out/noc_time.txt").split("\n") if x != ""]

    inj_pkts = [x for x in read_file(
        "in/flit_data.txt").split("\n") if x != ""]

    ej_flits = []
    wrong_dsts = []
    for i in range(num_pe):
        for j in range(max_vc_num):
            path = "out/{}/recv_data_noc{}.txt".format(i, j)
            flits = [x for x in read_file(path).split(
                "\n") if x != ""]
            ej_flits.extend(flits)

            wrong_dst = [x for x in flits if bin_to_info(x)["dst"] != i]
            wrong_dsts.extend(wrong_dst)

    print(len(set(ej_flits)))

    flits_cnt = {}
    for key in set(ej_flits):
        flits_cnt[key] = 0

    for flit in ej_flits:
        flits_cnt[flit] += 1

    lost_flits = []
    for itr, (key, item) in enumerate(flits_cnt.items()):
        info = bin_to_info(key)
        print(itr, key, info, item)
        if info["len"] != item:
            lost_flits.append(key)

    lost_packets = set(inj_pkts) - set(ej_flits) - set(noc_time)

    print("Correct receive pkt count:", len(
        set(inj_pkts) - lost_packets - set(noc_time) - set(lost_flits)))

    print("wrong dst num:", len(wrong_dsts))

    print("lost packets:")
    for itr, pkt in enumerate(lost_packets):
        info = bin_to_info(pkt)
        print(itr, pkt, info)

    print("lost packet count:", len(lost_packets))

    print("lost flits:")
    for itr, pkt in enumerate(lost_flits):
        info = bin_to_info(pkt)
        print(itr, pkt, info, "recv num:", flits_cnt[pkt])
    print("lost flit of pkt count:", len(lost_flits))
