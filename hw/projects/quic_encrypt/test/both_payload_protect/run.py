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

pkts_expected = []
pkts_sent = []

# Generate prescribed test cases
generate_testcases(pkts_sent, pkts_expected, checksum=False)

nftest_send_single(pkts_sent)
nftest_expect_single(pkts_expected)

nftest_barrier()
nftest_finish([])
