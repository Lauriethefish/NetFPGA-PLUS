#!/usr/bin/env python3
"""Simulation smoke test for the initial pass-through encryption scaffold."""

from NFTest import (
    isHW, nftest_init, nftest_start, nftest_send_single,
    nftest_expect_single, nftest_finish,
)
from scapy.layers.all import Ether, IP, UDP, Raw

if isHW():
    raise SystemExit("quic_encrypt is a standalone simulation/IP project")

nftest_init(sim_loop=[], hw_config=[])
nftest_start()

# Exercise single beats, exact beat boundaries and multi-beat packets.
# Ethernet/IP/UDP headers occupy 42 bytes.
packets = []
for index, length in enumerate((18, 21, 22, 23, 86, 87, 512, 1458)):
    packet = (
        Ether(src="aa:bb:cc:dd:ee:ff", dst="00:ca:fe:00:00:00")
        / IP(src="192.168.0.1", dst="192.168.1.1", id=index)
        / UDP(sport=8080, dport=4040)
        / Raw(bytes((offset + index) % 256 for offset in range(length)))
    )
    packet.time = index * 0.00001
    packets.append(packet)

# Until encryption is implemented, every byte and packet boundary is preserved.
nftest_send_single(packets)
nftest_expect_single(packets)
nftest_finish([])
