# Functions for generating tests for variable-length GSO

from .PacketLib import *
import random

# Maximum size of a frame *after* segmentation.
mtu = 1500
# Maximum possible size of a frame *before* segmentation.
jumbo_mtu = 65535
udp_headers_len = 42
max_payload_len = mtu - udp_headers_len
max_fittable_into_jumbo_frame = (jumbo_mtu - udp_headers_len) // (2 + max_payload_len)

# Standard, deterministic testcases
testcases = [
    [1024, 500, 4, 22, 1048, 3, 445, 0, 1, 2, 3],
    [92, 25, 48],
    *([[1500 - udp_headers_len] * max_fittable_into_jumbo_frame] * 5),
    [0, 0, 0, 0, 0, 0, 0, 1],
]

# Encodes the variable GSO packet length, which is stored little-endian.
def encode_length_le(length, into):
    into.extend([length % 256, length >> 8])

# Generates a packet to segment based upon an array of lengths
def generate_determ_segment_packet(lengths, pkts_expect, pkts_send, valid_udp_checksum, **kwargs):
    send_payload = []
    for i in range(len(lengths)):
        segment_len = lengths[i]
        payload = [min(i, 255)] * segment_len
        encode_length_le(segment_len, send_payload)
        send_payload.extend(payload)
        pkt_expect = make_UDP_pkt_with_payload(Raw(bytearray(payload)), **kwargs)
        pkts_expect.append(pkt_expect)

    pkts_send.append(make_UDP_pkt_with_payload(Raw(bytearray(send_payload)), **kwargs))


# Generates a packet to be segmented into randomly generated lengths.
# If cut_off_last_segment is true, then the data of the packet may be cut off
# so that there is not enough for the last segment.
# This is to test the ability of GSO to recover from such errors.
def generate_rand_segment_packet(cut_off_last_segment, pkts_expect, pkts_send, valid_udp_checksum, **kwargs):
    current_size = 0
    max_allowed_payload = random.randint(0, jumbo_mtu - udp_headers_len)
    segment_num = 0
    send_payload = []
    last_payload_len = -1
    while True:
        segment_num += 1
        segment_len = random.randint(0, mtu)
        # Check if can't fit this segment, and if so, stop.
        if(current_size + segment_len + 2 > max_allowed_payload):
            break 

        # Write segment length
        encode_length_le(segment_len, send_payload)
        last_payload_len = segment_len

        # Base payload upon segment number.
        # TODO: random payload would be a good idea.
        payload = [min(segment_num, 255)] * segment_len
        pkt_expect = make_UDP_pkt_with_payload(Raw(bytearray(payload)), **kwargs)
        pkts_expect.append(pkt_expect)

        send_payload.extend(payload)
        current_size += segment_len + 2

    if cut_off_last_segment and last_payload_len > 0:
        cut_off_amt = random.randint(1, last_payload_len)
        print(f"CUTTING OFF last segment by {cut_off_amt}")
        # Cut off a certain amount from the last packet, and remove the expected result.
        send_payload = send_payload[:-cut_off_amt]
        del pkts_expect[-1]
        

    pkts_send.append(make_UDP_pkt_with_payload(Raw(bytearray(send_payload)), **kwargs))

# Generates a set of random testcases for the packet segmentation.
# These may contain incorrectly formatted GSO packets if allow_invalid_packets is true.
# The packets to send and those to expect in receipt are added to pkts_expect and pkts_send.
# Around num_pkts packets will be sent, but this doesn't include invalid packets
# if present.
# By default, the expected packets have UDP checksum 0. If this should not be the case,
# pass valid_udp_checksum=True
def generate_testcases(seed, pkts_expect, pkts_send, allow_invalid_packets, num_pkts=500, valid_udp_checksum=False, **kwargs):
    random.seed(seed)

    for lengths in testcases:
        print(f"Generating deterministic testcase {lengths}")
        generate_determ_segment_packet(lengths, pkts_expect, pkts_send, valid_udp_checksum, **kwargs)
    
    for _ in range(num_pkts):
        print("Generating standard packet to segment")
        generate_rand_segment_packet(False, pkts_expect, pkts_send, valid_udp_checksum, **kwargs)

        if allow_invalid_packets and random.randint(1, 10) == 1:
            print("Generating invalid packets")
            for _ in range(random.randint(1, 3)):
                generate_rand_segment_packet(True, pkts_expect, pkts_send, valid_udp_checksum, **kwargs)

    for pkt in pkts_expect:
        if not valid_udp_checksum:
            pkt.getlayer(2)[scapy.UDP].chksum = 0
        pkt.time = ((1*(1e-8)) + (1e-6))

    for pkt in pkts_send:
        pkt.time = ((1*(1e-8)) + (1e-6))