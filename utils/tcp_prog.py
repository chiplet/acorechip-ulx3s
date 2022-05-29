# Utility script for sending programming waveform JTAG sequence
# Over openocd tcl_port (TCP socket)

import socket
import numpy as np
from argparse import ArgumentParser
from elftools.elf.elffile import ELFFile
from progressbar import progressbar

# returns result bytes excluding the terminating byte 0x1a
# blocks until the result has been read
def send_command(sock, command):
    sock.sendall(command.encode('ascii')+b'\n\x1a')
    recv_buf = b''
    while True:
        recv_byte = sock.recv(1)
        if recv_byte == b'\x1a':
            break
        recv_buf += recv_byte
    return recv_buf

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

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('localhost', 6666))

    print("Writing program image over JTAG:")
    tapname = "acorechip.prog"

    # ftdi reset
    send_command(sock, "ftdi_set_signal nSRST 1")
    send_command(sock, "ftdi_set_signal nSRST 0")
    # jlink reset
    #send_command(sock, "jtag arp_init-reset")

    for (addr, data) in progressbar(program_image):
        # addr
        send_command(sock, "irscan {} 1".format(tapname))
        send_command(sock, "drscan {} 16 {}".format(tapname, addr))
        # data
        send_command(sock, "irscan {} 2".format(tapname))
        send_command(sock, "drscan {} 8 {}".format(tapname, data))
        # write_en
        send_command(sock, "irscan {} 3".format(tapname))
        send_command(sock, "drscan {} 1 1".format(tapname))
        send_command(sock, "drscan {} 1 0".format(tapname))
        
    # enable core
    send_command(sock, "irscan {} 4".format(tapname))
    send_command(sock, "drscan {} 1 1".format(tapname))
    
    sock.close()

if __name__=='__main__':
    main()
