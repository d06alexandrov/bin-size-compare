from argparse import ArgumentParser
import glob
import subprocess


def run_size(filename):
    if filename is None:
        return None

    bin_paths = glob.glob(filename, recursive=True)

    if len(bin_paths) == 0:
        print("Can not find %" % filename)
        return None

    if len(bin_paths) > 1:
        print("There are more than 1 file that matches the pattern %" % filename)
        return None

    bin_path = bin_paths[0]

    sp = subprocess.run(["size", "-A", bin_path], capture_output=True)

    result = {}

    for line in sp.stdout.splitlines()[2:]:
        if not line.strip():
            continue

        name, val, *addr = line.split()
        name = name.decode('ascii')

        result[name] = {'val': int(val.decode('ascii'))}

        if addr:
            result[name]['addr'] = int(addr[0].decode('ascii'))

    return result


def compare(newer, prev, out):
    n_size = run_size(newer)
    p_size = run_size(prev) or {}

    with open(out, "a") as markdown:
        markdown.write("|Section|Size|Address|\n|-|-|-|\n")

        for key, val in n_size.items():
            val_to_print = val.get("val")
            addr_to_print = val.get("addr", "")

            if key in p_size:
                if val.get("val") != p_size[key].get("val"):
                    val_to_print = "%d (%+d)" % (val.get("val"),
                                                 val.get("val") - p_size[key].get("val"))

                del p_size[key]
            elif prev:
                val_to_print = "%d (%+d)" % (val.get("val"), val.get("val"))

            markdown.write("|%s|%s|%s|\n" % (key, val_to_print, addr_to_print))

        markdown.write("\n")

        if len(p_size) > 0:
            markdown.write("Removed sections: %s\n\n" %
                           ",".join(list(p_size.keys())))


def main():
    parser = ArgumentParser()
    parser.add_argument("-n", "--newer", dest="newer_filename",
                        help="path (glob) to the newest binary file")
    parser.add_argument("-p", "--prev", dest="prev_filename",
                        help="path (glob) to previous binary file")
    parser.add_argument("-o", "--out", dest="out_filename",
                        help="path to output file")

    args = parser.parse_args()

    compare(args.newer_filename, args.prev_filename, args.out_filename)


if __name__ == "__main__":
    main()
