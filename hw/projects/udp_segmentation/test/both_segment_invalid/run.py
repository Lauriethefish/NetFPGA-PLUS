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
import sys
import os
import random
from scapy.layers.all import Ether, IP, TCP, UDP, Raw

nftest_init(sim_loop = [], hw_config = [])

# NB: ONLY simulator is supported here. The segmentor can't be used
# on its own on hardware, only integrated into the larger QUIC pipeline.

nftest_start()

# set parameters
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"
NUM_PKTS = 1454
num_ports = 2

pkts_expected = []
pkts_sent = []

print("Sending now: ")
totalPktLengths = [0,0]
# Send NUM_PKTS: expect back the exact packets we send.
DA = "00:ca:fe:00:00:00"

# The role of this test is to check that the segmentor can recover when
# passed a packet with an invalid segment length: i.e. the segment length
# is longer than the amount of data actually available in the packet.

def make_UDP_using_params_and_payload(payload):
    pkt = make_UDP_pkt_with_payload(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                src_IP=SRC_IP, TTL=TTL, src_port=8080, dst_port = 4040,
                payload=Raw(bytearray(payload)))
    pkt.time = ((1*(1e-8)) + (1e-6))
    return pkt

random.seed(1)
num_pkts = 1000

mtu = 1500
jumbo_mtu = 65535
udp_headers_len = 42
max_payload_len = 1500 - udp_headers_len

# Generates a random packet to segment, optionally cutting off the last segment.
def generate_rand_packet(cut_off_last_segment, pkts_expect, pkts_send):
    print("Generating random packet")
    current_size = 0
    max_allowed_payload = random.randint(0, jumbo_mtu - udp_headers_len)
    segment_num = 0
    send_payload = []
    last_payload_len = -1
    while True:
        segment_num += 1
        segment_len = random.randint(0, mtu)
        # Check if can't fit this segment
        if(current_size + segment_len + 2 > max_allowed_payload):
            break 

        # Write segment length
        send_payload.append(segment_len % 256)
        send_payload.append(segment_len >> 8)
        last_payload_len = segment_len
        print(f"Segment length: {segment_len}")

        payload = [min(segment_num, 255)] * segment_len
        pkt_expect = make_UDP_using_params_and_payload(payload)
        pkt_expect.getlayer(2)[scapy.UDP].chksum = 0
        pkts_expect.append(pkt_expect)

        send_payload.extend(payload)
        current_size += segment_len + 2

    if cut_off_last_segment and last_payload_len > 0:
        cut_off_amt = random.randint(1, last_payload_len)
        print(f"CUTTING OFF last segment by {cut_off_amt}")
        # Cut off a certain amount from the last packet, and remove the expected result.
        send_payload = send_payload[:len(send_payload) - cut_off_amt]
        pkts_expect = pkts_expected[:len(pkts_expect)-1]
        

    pkts_send.append(make_UDP_using_params_and_payload(send_payload))

# Generate a whole load of random packets interspersed with invalid ones

pkts_sent = []
pkts_expected = []

generate_rand_packet(False, pkts_expected, pkts_sent)
generate_rand_packet(True, pkts_expected, pkts_sent)
generate_rand_packet(False, pkts_expected, pkts_sent)

"""


# Not enough data to output
segment_payload = [0x2, 0x0, 0x1, 0x1, 0x5, 0x0, 0x2, 0x2]
segment_1 = [0x1, 0x1]
# Second segment shouldn't be sent at all, because there isn't enough data.

pkt_send_invalid = make_UDP_using_params_and_payload(segment_payload)
pkt_recv_seg1 = make_UDP_using_params_and_payload(segment_1)
pkt_recv_seg1.getlayer(2)[scapy.UDP].chksum = 0

# Then send a correctly formatted packet, and make sure it still works
segment_payload = [0x0, 0x0, 0x5, 0x0, 0x4e, 0x5e, 0x6f, 0x7e, 0x11]
segment_2 = []
segment_3 = [0x4e, 0x5e, 0x6f, 0x7e, 0x11]
pkt_send_valid = make_UDP_using_params_and_payload(segment_payload)
pkt_recv_seg2 = make_UDP_using_params_and_payload(segment_2)
pkt_recv_seg3 = make_UDP_using_params_and_payload(segment_3)
pkt_recv_seg2.getlayer(2)[scapy.UDP].chksum = 0
pkt_recv_seg3.getlayer(2)[scapy.UDP].chksum = 0

pkts_sent = [pkt_send_invalid, pkt_send_valid]
pkts_expected = [pkt_recv_seg1, pkt_recv_seg2, pkt_recv_seg3]
"""

nftest_send_single(pkts_sent)
nftest_expect_single(pkts_expected)

nftest_barrier()
nftest_finish([])
