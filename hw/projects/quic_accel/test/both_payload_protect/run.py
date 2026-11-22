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
from NFTest.QuicCryptoLib import *
import sys
import os
from scapy.layers.all import Ether, IP, TCP, UDP
from scapy.all import *
import reg_defines_quic_accel
from reg_defines_quic_accel import *

conn = ('../connections/conn', [])
nftest_init(sim_loop = ['nf0', 'nf1'], hw_config = [conn])

if isHW():
   # reset_counters (triggered by Write only event) for all the modules 
   #nftest_regwrite(NFPLUS_INPUT_ARBITER_0_RESET(), 0x1)
   #nftest_regwrite(NFPLUS_OUTPUT_PORT_LOOKUP_0_RESET(), 0x1)
   #nftest_regwrite(NFPLUS_OUTPUT_QUEUES_0_RESET(), 0x1)
   pass
   # TODO: implement counter reset

pkts_send = []
pkts_expected = []

generate_testcases(pkts_send, pkts_expected, checksum=True, num_random_lengths=800)

nftest_start()

for (pkt, expected) in zip(pkts_send, pkts_expected):
   nftest_send_dma('nf0', pkt)

   # NB this practically never fires because the minimum length QUIC header
   # already brings the frame to 60 bytes.
   # TODO: If we fix up the bypass datapath, actually check the padding IP
   # works by replacing this with some UDP datagram that's too short,
   # for example.
   len_expected = len(bytes(expected))
   if len_expected < 60:
      print("Padding out expected packet")
      pad = Padding()
      pad.load = '\x00' * (60 - len_expected)
      expected = expected / pad

   nftest_expect_phy('nf0', expected)

nftest_barrier()


# TODO: for now not testing registers.
#rres1 = nftest_regread_expect(NFPLUS_QUIC_ACCEL_0_NUM_TX(), NUM_PKTS)
#rres2 = nftest_regread_expect(NFPLUS_QUIC_ACCEL_0_NUM_RX(), 0)
#rres3 = nftest_regread_expect(NFPLUS_QUIC_ACCEL_0_NUM_TX_RAW(), NUM_PKTS)
#rres4 = nftest_regread_expect(NFPLUS_QUIC_ACCEL_0_NUM_RX_RAW(), 0)
#rres5 = nftest_regread_expect(NFPLUS_QUIC_ACCEL_0_MAGIC(), 0xffdafafa)
#mres=[rres1, rres2, rres3, rres4, rres5]

nftest_finish([])
