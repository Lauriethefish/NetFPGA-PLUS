package inter_structs;
  typedef struct packed {
    logic [6*8-1:0] dst_addr;
    logic [6*8-1:0] src_addr;
    logic [15:0] ethertype;
  } ether_header;

  typedef struct packed {
    logic [3:0] version;
    logic [3:0] ihl;
    logic [5:0] dscp;
    logic [1:0] ecn;
    logic [15:0] total_length;
    logic [15:0] identification;
    logic [2:0] flags;
    logic [12:0] frag_offset;
    logic [7:0] ttl;
    logic [7:0] protocol;
    logic [15:0] header_checksum;
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
  } ipv4_header;

  // Full size: 42 bytes
  typedef struct packed {
    ether_header ether;
    ipv4_header ipv4;
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] length;
    logic [15:0] checksum;
  } udp_header;

  // Used for checksum calculation
  // Full size: 20 bytes.
  typedef struct packed {
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [7:0] zeroes;
    logic [7:0] protocol;
    logic [15:0] udp_length;
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] length;
    logic [15:0] checksum;
  } udp_pseudo_header;
endpackage