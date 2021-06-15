# Project    : Traffic generator for a NoC
# -----------------------------------------
# Description: Convert arbitrary data types to uint8 and make further processes
# for using the converted data (in the binary system) in a real digital system.
# The system supports multiple header structure
# -----------------------------------------
# File       : data2file.py
# Author     : Seyed Nima Omidsajedi  <nima@omidsajedi.com>
# Company    : University of Bremen
# -----------------------------------------
# Copyright (c) 2019
# -----------------------------------------
# Vesion     : 2.1.0
# -----------------------------------------
# Header structure:
# -----------------------------------------------------------------------------------------------
# |              |           |       |       |       |        |        |        |               |
# | Flit_padding | Packet_id | Z_src | Y_src | X_src | Z_dest | Y_dest | X_dest | Packet_length |
# |              |           |       |       |       |        |        |        |               |
# -----------------------------------------------------------------------------------------------


import os
import sys
import math
import random
import numpy as np
from PIL import Image

# *********************************** Define functions


# Define flit division

def data2flit(s, n):
    for start in range(0, len(s), n):
        yield s[start:start+n]


# Define bit conversion


def bit_length(n):
    if n == 1:
        return 1
    elif n > 1:
        return math.ceil(math.log(n) / math.log(2))


# Define bit conversion


def int2binary(w, z):
    return bin(w)[2:].zfill(z)


# *********************************** Generic variables

input_file = "lena.jpg"
# output_greyscale_file = "greyscale.png"  # Enable when Greyscale image is needed
output_file = "in/data_flits.txt"   # Output file will be in binary
output_packet_length_file = "in/packet_length.txt"
output_inj_time_file = "in/injection_time.txt"  # Injection time in C.C
output_data_header_file = "in/data_header.txt"
output_packet_header_length = "in/packet_header_length.txt"
header_included = True  # header_included in the packet structure
max_x_dim = 2  # starting from 1 //  Must be the same in both files + VHDL files
max_y_dim = 1  # starting from 1 //  Must be the same in both files + VHDL files
max_z_dim = 1  # starting from 1 //  Must be the same in both files + VHDL files
flit_width = 32  # Must be the same in both files + VHDL files
# (number of flits + header_included) in a packet //  Must be the same in both files + VHDL files
max_packet_len = 31
# src_address = (int(sys.argv[1]), int(sys.argv[2]), int(
#     sys.argv[3]))  # Z Y X  //   starting from 0
# dest_address = (int(sys.argv[4]), int(sys.argv[5]), int(
#     sys.argv[6]))  # Z Y X   //  starting from 0
src_address = (0, 0, 0)
dest_address = (0, 0, 1)
lower_range_packet_length = 1  # Lower range of packet_length for random function
upper_range_packet_length = 30  # Upper range of packet_length for random function
mu, sigma = 0, 0  # Mean and Standard deviation for the injection time


print(__file__, src_address, "->", dest_address)
print("dimension", max_x_dim, max_y_dim, max_z_dim)

# *********************************** Internal variables

data_flits = ""
data_save = ""
packet_num = 0  # Should not be changed
packet_line_counter = 0  # Should not be changed
final_inj_time = 0  # Should not be changed
data_packet_length = ""
data_inj_time = ""
flit_padding_width = flit_width / 16  # Should not be changed
packet_length_line_counter = 0  # Should not be changed
packet_header_length = 0  # Should not be changed
packet_id = 0  # Should not be changed
data_line_counter = 0  # Should not be changed
header = []
header_temp = ""
data2save = ""
packet_header2save = ""
flit_padding_bin = ""

# *******************************************************************************
# ********************************************************************* Main body

# Greyscale Conversion

# Enable when Greyscale image is needed
# img = Image.open(input_file).convert('L')  # convert image to grayscale
# img.save(output_greyscale_file)


#######################
# pre remove list
rmv_list = [
    output_file,
    output_packet_length_file,
    output_inj_time_file,
    output_data_header_file,
    output_packet_header_length,
]
[os.remove(x) for x in rmv_list if os.path.exists(x)]


# ******************************************************************
# ************************************************** Data Conversion
""" generate data_flits.txt, which convert the whole img into binaries flits """

# input_data = open(output_greyscale_file, 'rb')  # Enable when Greyscale image is needed
input_data = open(input_file, 'rb')  # Disable when Greyscale image is used
my_data = list(input_data.read())
final_Data = np.array(my_data).astype('uint8')
data_bin = [np.binary_repr(np.array(final_Data)[i], 8)
            for i in range(len(final_Data))]

print(len(my_data), my_data[:5])
print(len(final_Data), final_Data)
print(len(data_bin), data_bin[:5], len(data_bin[0]))

for i in range(len(data_bin)):
    data_flits += str(data_bin[i])

for j in data2flit(data_flits, flit_width):
    data_save += str(j) + "\n"


with open(output_file, "w") as handle:
    handle.write(data_save)
    handle.close()


# ******************************************************************
# ******************************************************** Data info

# Determine packet length
line_num = sum(1 for line in open(output_file))
print("line_num", line_num)


while packet_num <= line_num:
    packet_length_temp = random.randint(
        lower_range_packet_length, upper_range_packet_length)

    if packet_num + packet_length_temp < line_num:
        packet_num = packet_length_temp + packet_num
        packet_line_counter += 1
        data_packet_length += str(packet_length_temp) + "\n"
    else:
        packet_length_temp = line_num - packet_num
        data_packet_length += str(packet_length_temp)
        packet_line_counter += 1
        break


f = open(output_packet_length_file, 'w')
f.write(data_packet_length)
f.close()


################################################################
# Data injection time

for inj_time in range(packet_line_counter):
    random_inj_time = abs(round(np.random.normal(mu, sigma)))
    if random_inj_time < lower_range_packet_length:
        random_inj_time = random_inj_time + lower_range_packet_length + 1
    final_inj_time = final_inj_time + random_inj_time
    data_inj_time += str(final_inj_time) + "\n"


g = open(output_inj_time_file, 'w')
g.write(str(data_inj_time))
g.close()

# ******************************************************************
# ************************************************* Data_header_info

x_width = bit_length(max_x_dim)
y_width = bit_length(max_y_dim)
z_width = bit_length(max_z_dim)

print("x_width", x_width)
print("y_width", y_width)
print("z_width", z_width)


packet_id_width = math.ceil(math.log(packet_line_counter) / math.log(2))
packet_length_width = bit_length(max_packet_len)

print("packet_length_width", packet_length_width)

# multiply by 2 is cuz of src and dst
header_total = int(flit_padding_width + packet_id_width + (2 *
                   z_width) + (2 * y_width) + (2 * x_width) + packet_length_width)
header_num = math.ceil(header_total / flit_width)

print("header_total", header_total, "bits")
print("header_num", header_num)

######################

if (src_address[2] >= max_x_dim) | (dest_address[2] >= max_x_dim):
    sys.exit('Fatal error: the router address exceeded the maximum router number (z)!')
if (src_address[1] >= max_y_dim) | (dest_address[1] >= max_y_dim):
    sys.exit('Fatal error: the router address exceeded the maximum router number (y)!')
if (src_address[0] >= max_z_dim) | (dest_address[0] >= max_z_dim):
    sys.exit('Fatal error: the router address exceeded the maximum router number (x)!')
if upper_range_packet_length + header_num > max_packet_len:
    sys.exit(
        'Fatal error: the entered packet length exceeded the maximum "packet + header" number!')

#######################

with open(output_file) as f:
    input_data = f.readlines()

input_data_line_num = sum(1 for line in open(output_file))
last_line_data = input_data[input_data_line_num - 1]

with open(output_packet_length_file) as f:
    packet_length = f.readlines()

for x in range(0, len(packet_length)):

    if x < len(packet_length) - 1:
        flit_padding = 0
    elif x == len(packet_length) - 1:
        flit_padding_bit = flit_width - len(last_line_data) + 1
        flit_padding = flit_padding_bit / 8

    header_flit = int2binary(int(flit_padding), int(flit_padding_width)) + \
        int2binary(packet_id, packet_id_width) + \
        int2binary(src_address[0], z_width) + \
        int2binary(src_address[1], y_width) + \
        int2binary(src_address[2], x_width) + \
        int2binary(dest_address[0], z_width) + \
        int2binary(dest_address[1], y_width) + \
        int2binary(dest_address[2], x_width) + \
        int2binary(int(packet_length[packet_length_line_counter]) +
                   int(header_included) + header_num - 1, packet_length_width)

    packet_id = packet_id + 1
    packet_length_line_counter = packet_length_line_counter + 1
    packet_header_length = int(packet_length[x]) + header_num
    packet_header2save += str(packet_header_length) + "\n"

    if len(header_flit) > flit_width:
        header_flit = header_flit.rjust(flit_width*header_num, '1')
        header_temp = header_flit[(header_num - 1)
                                  * flit_width: len(header_flit)]
        data2save += header_temp + "\n"
        for i in range(header_num-1, 0, -1):
            header_temp = header_flit[flit_width * (i-1): flit_width * i]
            data2save += header_temp + "\n"
    else:
        header_flit = header_flit.rjust(flit_width, '1')
        data2save += header_flit + "\n"

    if int(packet_length[x]) > max_packet_len:
        sys.exit('Fatal error: the packet_length exceeded the maximum legal number!')

    for y in range(0, int(packet_length[x])):
        if y % int(packet_length[x]) == (int(packet_length[x]) - 1):
            data2save += str(input_data[data_line_counter].rjust(flit_width + 1, '1'))
        else:
            data2save += str(input_data[data_line_counter])
        data_line_counter = data_line_counter + 1

    # print(packet_id, packet_id_width)
    # print(src_address)
    # print(dest_address)
    # print(packet_length[packet_length_line_counter])
    # print(int2binary(int(packet_length[packet_length_line_counter]) +
    #                  int(header_included) + header_num - 1, packet_length_width))
    # print(header_flit)

    # if x == 4:
    #     exit(0)


f = open(output_data_header_file, 'w')
f.write(data2save)
f.close()


f = open(output_packet_header_length, 'w')
f.write(packet_header2save)
f.close()


# Reports

print("******************************")
print("Number of flits: %i" % line_num)
print("******************************")
print("Number of packets: %i" % packet_line_counter)
print("******************************")
print("Number of headers: %i" % header_num)
print("******************************")
print("Required bits for packet_id: %i" % packet_id_width)
print("******************************")
