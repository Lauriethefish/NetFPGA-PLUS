#!/usr/bin/env python3

#
# Copyright (c) 2015 University of Cambridge
# Copyright (c) 2015 Neelakandan Manihatty Bojan, Georgina Kalogeridou
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
# as part of the DARPA MRC research programme,
# and by the University of Cambridge Computer Laboratory under EPSRC EARL Project
# EP/P025374/1 alongside support from Xilinx Inc.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#
# Author:
#        Modified by Neelakandan Manihatty Bojan, Georgina Kalogeridou

import logging
logging.getLogger("scapy.runtime").setLevel(logging.ERROR)

from NFTest import *
from scapy.layers.all import Ether, IP, UDP, Raw
from scapy.layers.quic import *
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

import random

# Only simulation is supported here. This standalone IP must be integrated
# into the QUIC pipeline before it can be tested on hardware.
if isHW():
    raise SystemExit("quic_encrypt is a standalone simulation/IP project")

nftest_init(sim_loop = [], hw_config = [])

nftest_start()

# set parameters
SA = "aa:bb:cc:dd:ee:ff"
DA = "00:ca:fe:00:00:00"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"

pkts_expected = []
pkts_sent = []

# Constant key currently used by encryption module
key_size = 16 # in bytes
nonce_size = 12 # in bytes
key = 4
nonce = 5

key_bytes = key.to_bytes(key_size, 'big')

def format_16_byte_chunks(b):
    num_chunks = (len(b)+1)//16
    result = ""
    for i in range(num_chunks):
        upper_limit = min((i+1)*16, len(b))
        chunk = b[i*16:upper_limit]
        result += f"BLOCK {i}: {chunk.hex()}\n"
    return result


# Protects the payload of the QUIC packet `packet`
# (may have other layers on top, which are ignored)
# Returns the packet with protected payload
def protect_quic_payload(packet, packet_no):
    gcm = AESGCM(key_bytes)
    quic_packet = packet[QUIC]
    parent_layers = packet.copy()
    parent_layers[QUIC].underlayer.remove_payload()

    quic_headers = quic_packet.copy()
    quic_headers.remove_payload()
    raw_headers = bytes(quic_headers)
    raw_payload = bytes(quic_packet.payload)
    
    packet_nonce = nonce ^ packet_no
    packet_nonce_bytes = packet_nonce.to_bytes(12, 'big')
    aead_payload = gcm.encrypt(packet_nonce_bytes, raw_payload, raw_headers)

    print(f"Associated data:\n{format_64_byte_chunks(raw_headers)}")
    print(f"Nonce bytes: {packet_nonce_bytes.hex()}")
    print(f"Key bytes: {key_bytes.hex()}")
    print(f"Parent layers: {parent_layers}")
    print(f"QUIC headers: {quic_headers}")

    print(f"Original payload:\n{format_64_byte_chunks(raw_payload)}")
    print(f"AEAD payload:\n{format_64_byte_chunks(aead_payload)}, length: {len(aead_payload)}")
    return parent_layers / quic_headers / Raw(aead_payload)
    
print("Sending now: ")

mtu = 1500
for i in range(0, 1):
    random.seed(i)
    packet_no = random.randint(0, 2**32-1)
    pkt = Ether(src=SA, dst=DA)/IP(src=SRC_IP, dst=DST_IP, ttl=TTL, id=1)/UDP(sport=8080, dport=4040)
    pkt = pkt/QUIC_1RTT(DstConnID="ABCDEFGH", PacketNumber=packet_no)
    headers_len = len(bytes(pkt))
    max_payload_len = mtu - headers_len
    payload_len = random.randint(1, max_payload_len)
    payload = random.randbytes(payload_len)
    pkt = pkt/Raw(payload)

    print(f"Pre protection: {pkt}")

    pkt_protected = protect_quic_payload(pkt, packet_no)
    pkt_protected[UDP].chksum = 0
    pkt_protected[IP].chksum = 0
    print(f"Post protection: {pkt_protected}")

    pkt.time = 1 * 0.00001
    pkts_sent.append(pkt)
    # Until encryption is implemented, expect the same packet back.
    pkts_expected.append(pkt_protected)



nftest_send_single(pkts_sent)
nftest_expect_single(pkts_expected)

nftest_barrier()
nftest_finish([])
