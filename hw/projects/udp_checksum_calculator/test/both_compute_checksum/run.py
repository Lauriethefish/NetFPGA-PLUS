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
from scapy.layers.all import Ether, IP, TCP, UDP

nftest_init(sim_loop = [], hw_config = [])

# NB: ONLY simulator is supported here. The checksum calculator can't be used
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
# send NUM_PKTS from ports nf2c0...nf2c1
for i in range(NUM_PKTS):
    DA = "00:ca:fe:00:00:00"
    pkt_expect = make_UDP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                            src_IP=SRC_IP, TTL=TTL, src_port=8080, dst_port = 4040,
                            pkt_len=80)
    pkt = pkt_expect.copy()
    pkt.getlayer(2)[scapy.UDP].chksum = 0
    pkt.time = ((i*(1e-8)) + (1e-6)) 
    pkts_sent.append(pkt)
    pkts_expected.append(pkt_expect)

nftest_send_single(pkts_sent) 
nftest_expect_single(pkts_expected) 
mres = []

print("")

nftest_barrier()
nftest_finish(mres)
