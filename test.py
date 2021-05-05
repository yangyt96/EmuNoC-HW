import os
import sys
print(sys.argv)


cwd = os.getcwd()
print(cwd)

combination = ["{} {} {}".format(z, x, y) for x in range(4)
               for y in range(4) for z in range(1)]

combination = ["0 0 0", "0 3 3"]

sim_num = 1

count = 0
for i in combination:
    for j in combination:
        if i == j:
            continue

        edit_src_pos = "(" + i.replace(" ", ",") + ")"
        edit_dst_pos = "(" + j.replace(" ", ",") + ")"
        print(edit_src_pos, "->", edit_dst_pos)
        with open("bkp/TESTBENCH_PACKAGE.vhd", "r") as file:
            data = file.read().replace("$src_pos", edit_src_pos).replace(
                "$dst_pos", edit_dst_pos)
            with open("testbench/utils/TESTBENCH_PACKAGE.vhd", "w") as out:
                out.write(data)

        os.chdir(os.path.join(cwd, "./data/pic"))
        cmd = "python3 file2data.py {} {}".format(i, j)
        # print(cmd)
        os.system(cmd)
        os.chdir(cwd)

        os.system("make")

        # print("\n\n\n")
        count += 1

        if count == sim_num:
            break

    if count == sim_num:
        break
