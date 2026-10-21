#Gen AI

import socket
import struct

def checksum(data):
    if len(data) % 2:
        data += b"\x00"
    words = struct.unpack(f"!{len(data) // 2}H", data)
    total = sum(words)
    total = (total >> 16) + (total & 0xFFFF)
    total += total >> 16
    return (~total) & 0xFFFF


def send_echo(destination, packet_type, identifier, payload):
    header = struct.pack("!BBHHH", packet_type, 0, 0, identifier, 1)
    header = struct.pack(
        "!BBHHH", packet_type, 0, checksum(header + payload), identifier, 1
    )
    with socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP) as sock:
        sock.sendto(header + payload, (destination, 0))


destination = socket.gethostbyname("snort-target")
send_echo(destination, 8, 678, b"1234")
send_echo(destination, 0, 0, b"AAAAAAAAAA")
print(f"Sent one ICMP test packet for each signature to {destination}.")
