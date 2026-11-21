# Functions for generating test cases for QUIC packet encryption
# Including payload protection (currently) and header protection (later).

from scapy.layers.all import Ether, IP, UDP, Raw
from scapy.layers.quic import *
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import random

# Constant key currently used by encryption module
key_size = 16 # in bytes
nonce_size = 12 # in bytes
key = 4
nonce = 5

# set parameters
SA = "aa:bb:cc:dd:ee:ff"
DA = "00:ca:fe:00:00:00"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"

key_bytes = key.to_bytes(key_size, 'big')

def format_16_byte_chunks(b):
    num_chunks = (len(b)+15)//16
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

    print(f"Associated data:\n{format_16_byte_chunks(raw_headers)}")
    print(f"Nonce bytes: {packet_nonce_bytes.hex()}")
    print(f"Key bytes: {key_bytes.hex()}")
    print(f"Parent layers: {parent_layers}")
    print(f"QUIC headers: {quic_headers}")

    print(f"Original payload:\n{format_16_byte_chunks(raw_payload)}")
    print(f"AEAD payload:\n{format_16_byte_chunks(aead_payload)}, length: {len(aead_payload)}")
    return parent_layers / quic_headers / Raw(aead_payload)
    
mtu = 1500
# Some other edge-case payload lengths to try
# NB -1 is interpreted as maximum payload length according to MTU
# ETC for -2 which is (max payload length - 1)
extra_lengths = [0, 1, 2, 3, 4, 5, -1, -2, -3, -4, -5]
num_random_lengths = 800

# Generates the testcases for QUIC packet encryption
# Expected packets will have a checksum of 0 unless checksum is set.
def generate_testcases(pkts_sent, pkts_expected, checksum=False):
    for i in range(0, num_random_lengths+len(extra_lengths)):
        random.seed(i)
        packet_no = random.randint(0, 2**32-1)
        pkt = Ether(src=SA, dst=DA)/IP(src=SRC_IP, dst=DST_IP, ttl=TTL, id=1)/UDP(sport=8080, dport=4040)
        pkt = pkt/QUIC_1RTT(DstConnID="ABCDEFGH", PacketNumber=packet_no)
        headers_len = len(bytes(pkt))
        max_payload_len = mtu - headers_len

        if i >= num_random_lengths:
            j = i - num_random_lengths
            if extra_lengths[j] >= 0:
                payload_len = extra_lengths[j]
            else:
                payload_len = max_payload_len + extra_lengths[j] + 1
        else:
            payload_len = random.randint(1, max_payload_len)
        payload = random.randbytes(payload_len)
        pkt = pkt/Raw(payload)

        print(f"Pre protection: {pkt}")

        pkt_protected = protect_quic_payload(pkt, packet_no)
        if not checksum:
            pkt_protected[UDP].chksum = 0
            pkt_protected[IP].chksum = 0
        print(f"Post protection: {pkt_protected}")

        pkt.time = 1 * 0.00001
        pkts_sent.append(pkt)
        # Until encryption is implemented, expect the same packet back.
        pkts_expected.append(pkt_protected)
