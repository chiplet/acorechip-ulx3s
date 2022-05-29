# Utility script for sending programming waveform JTAG sequence
# Over openocd tcl_port (TCP socket)

import telnetlib
import numpy as np
from argparse import ArgumentParser
from elftools.elf.elffile import ELFFile
from progressbar import progressbar

def write_command(tn, command):
    tn.write(command.encode('ascii')+b'\n')
    # FIXME: telnetlib drops messages when writing at full speed even when
    # reading back responses, using a hardcoded delay for now
    import time; time.sleep(0.0005)

def read_elf(filepath):
    """
    Load program data to memory from the ELF file located at ``filepath``.
    The loaded data is stored as an numpy array with adderss and data columns.

    Parameters
    ----------
    filepath : str
        Path to program ELF file to be loaded.

    """
    fd = open(filepath, 'rb')
    elffile = ELFFile(fd)

    # Get program instructions as a byte string
    sections = ['.text', '.data', '.sdata', '.rodata']
    rom_bytes = b''
    for sect_name in sections:
        section = elffile.get_section_by_name(sect_name)
        if section is not None:
            rom_bytes += section.data()
    indata=np.array([b for b in rom_bytes]).astype(int)
    
    program_size = len(indata)
    print("Program size: {} bytes".format(program_size))

    # Assign vales to programming interface: address, data
    write_addr = np.arange(program_size).astype(int)
    return np.r_['1', write_addr.reshape(-1,1), indata.reshape(-1,1) ].reshape(-1,2)


def main():
    parser = ArgumentParser()
    parser.add_argument("elf", help="ELF file path")
    args = parser.parse_args()

    program_image = read_elf(args.elf)
    tn = telnetlib.Telnet('localhost', 4444)

    print("Writing program image over JTAG:")
    tapname = "acorechip.prog"
    #write_command(tn, "ftdi_set_signal nSRST 1")
    #write_command(tn, "ftdi_set_signal nSRST 0")
    write_command(tn, "jtag arp_init-reset")
    for (addr, data) in progressbar(program_image):
        # addr
        write_command(tn, "irscan {} 1".format(tapname))
        write_command(tn, "drscan {} 16 {}".format(tapname, addr))
        # data
        write_command(tn, "irscan {} 2".format(tapname))
        write_command(tn, "drscan {} 8 {}".format(tapname, data))
        # write_en
        write_command(tn, "irscan {} 3".format(tapname))
        write_command(tn, "drscan {} 1 1".format(tapname))
        write_command(tn, "drscan {} 1 0".format(tapname))
    # core en
    write_command(tn, "irscan {} 4".format(tapname))
    write_command(tn, "drscan {} 1 1".format(tapname))
    
    tn.close()

if __name__=='__main__':
    main()
