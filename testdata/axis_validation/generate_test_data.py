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

# ----------------------------------------------
# Functions


def create_packet(id, src, dst, pkt_len):
    pkt_data = ""
    pkt_data += int_to_bin(id, flit_id_bit_width)
    pkt_data += int_to_bin(src, pe_bit_width)
    pkt_data += int_to_bin(dst, pe_bit_width)
    pkt_data += int_to_bin(pkt_len, flit_pkt_width)

    assert len(pkt_data) == flit_size, "len(pkt_data)={}, pkt_len:{}".format(
        len(pkt_data), pkt_len)
    return pkt_data


def create_random_sim_data(start_time: int, axis_len):

    global pkt_id

    ret = {}
    ret["flit_data"] = []
    for itr in range(axis_len):

        src = randint(0, num_pe-1)
        dst = randint(0, num_pe-1)
        while src == dst:
            dst = randint(0, num_pe-1)
        pkt_len = randint(1, max_pkt_len)

        ret["flit_data"].append(create_packet(
            pkt_id, src=src, dst=dst, pkt_len=pkt_len))

        print("id:", pkt_id, "src:", src, "dst:", dst,
              "len:", pkt_len, ret["flit_data"][-1])

        pkt_id += 1

    ret["inj_time"] = [start_time]
    ret["pkt_len"] = [axis_len]

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

    """ Pressure test """
    td = TestData()

    # data injection to all pe
    data = {}
    data["flit_data"] = []
    data["inj_time"] = [0]

    pkt_id = 0
    for i in range(num_pe):
        for j in range(num_pe):
            if i == j:
                continue

            tmp = create_packet(pkt_id, i, j, 31)
            data["flit_data"].append(tmp)

            pkt_id += 1

    shuffle(data["flit_data"])
    data["flit_data"].insert(0, int_to_bin(0, flit_size))
    data["pkt_len"] = [len(data["flit_data"])]

    for i in data["flit_data"]:
        print(i, bin_to_info(i))

    td.add(data)

    print(len(data["flit_data"]))

    # run to inf
    data = {}
    data["flit_data"] = ["1"*flit_size]
    data["inj_time"] = [0]
    data["pkt_len"] = [1]
    td.add(data)

    td.to_txt("in")
