# AES-GCM port reference

This documents the `top_aes_gcm` entity currently generated in
[`aes-gcm/src/gen_rtl/top_aes_gcm.vhd`](../../../aes-gcm/src/gen_rtl/top_aes_gcm.vhd).
Descriptions follow the checked-out RTL, including the supporting modules, rather
than assuming an AXI Stream interface. Timing below is derived from source
inspection; it has not been verified with a new simulation.

## Current generated configuration

- AES-128, with ten round instances and internal key expansion.
- No optional registers inside each round (`pipe stages: 0`); the rounds still
  have registered outputs.
- One combinational GHASH multiplier (`aes_gcm_split_gfmul => 0`).
- 128-bit payload and AAD blocks, 96-bit IV, 128-bit authentication tag.

The wrapper fixes `aes_gcm_mode_g => AES_MODE_128_C`. Changing the runtime mode
port does not change this configuration. Regenerating the core can change these
properties, so recheck this reference after regeneration.

## Ports

All vector ranges are descending, `[width-1:0]`. Controls are active high unless
stated otherwise. Inputs are sampled on rising clock edges, except for the
asynchronous reset.

| Port | Direction | Width | Meaning and use |
| --- | --- | --- | --- |
| `clk_i` | Input | 1 | Clock for all sequential logic. Transfers and synchronous control actions occur on its rising edge. |
| `rst_i` | Input | 1 | Asynchronous reset for the core, including the stored key, IV/counter, AES pipeline, GHASH state, and output-valid registers. |
| `aes_gcm_mode_i` | Input | 2 | Runtime key-size selector in a core generated for all modes: `00` = 128, `01` = 192, `10` = 256. **Ignored by the current fixed AES-128 wrapper**; drive `00`. `11` is the package's all-modes configuration constant, not a fourth key size. |
| `aes_gcm_enc_dec_i` | Input | 1 | `0` = encrypt plaintext into ciphertext; `1` = decrypt ciphertext into plaintext. The counter-mode XOR datapath is the same in both cases; this selects whether GHASH authenticates output ciphertext or input ciphertext and changes GHASH control timing. Keep stable throughout a packet and its tag calculation. |
| `aes_gcm_pipe_reset_i` | Input | 1 | Synchronously clears AES round valid/counter state and final AES output validity, discarding prefetched counter blocks. Does not reset the stored original key, IV/counter generator, GHASH state, or payload output register. Use with the counter stopped when flushing between packets; it is not a whole-core reset. |
| `aes_gcm_key_word_val_i` | Input | 4 | Key-load enables, with an unusual grouped mapping described below. For this AES-128 core, pulse `0100` for one clock while the key is present. Any asserted bit also invalidates the cached GHASH hash subkey and IV-dependent tag mask. Drive zero otherwise. |
| `aes_gcm_key_word_i` | Input | 256 | Unexpanded key input. For AES-128, place the key in `[255:128]`, with the first key byte in `[255:248]`; drive `[127:0]` to zero. Captured according to the key-load enables. |
| `aes_gcm_iv_val_i` | Input | 1 | Loads the 96-bit IV on a rising edge **only while the counter generator is stopped** (`iv_val_q = 0`). Also invalidates the cached IV-dependent tag mask. Pulse for one clock after key loading and before starting the counter. An assertion while running still invalidates the tag mask even though the IV register does not load. |
| `aes_gcm_iv_i` | Input | 96 | Complete IV/nonce, captured when the IV-load condition holds. The first byte is `[95:88]`. The core appends its own 32-bit counter; do not include a counter in this port. |
| `aes_gcm_icb_start_cnt_i` | Input | 1 | Pulse for one clock to start counter-block generation and set the low 32-bit counter to `1`. If needed, also initiates encryption of the all-zero block to obtain the GHASH hash subkey. Load key and IV first; do not hold this signal high, because it repeatedly forces the counter to `1`. |
| `aes_gcm_icb_stop_cnt_i` | Input | 1 | Stops counter-block generation through the registered run flag. Stop takes priority over start for that flag. Does not flush counter blocks already in the AES pipeline, reset the counter value, or finish GHASH. |
| `aes_gcm_ghash_pkt_val_i` | Input | 1 | Packet envelope for authentication. Hold high across AAD, payload, and any gaps. Its sampled falling transition triggers length-block processing and tag production. It is independent of the counter start/stop controls. See packet timing below. |
| `aes_gcm_ghash_aad_bval_i` | Input | 16 | Valid-byte mask for the current AAD block; zero means no AAD beat. Must be contiguous ones from bit 15 downward. There is no separate AAD-valid or AAD-ready port. Each nonzero beat during the AAD phase is processed on a clock edge; holding it high repeats that block. |
| `aes_gcm_ghash_aad_i` | Input | 128 | Additional authenticated data: included in the tag but not encrypted or emitted on the payload output. Pack bytes from `[127:120]` downward. GHASH masks invalid bytes to zero. Send AAD before payload. |
| `aes_gcm_data_in_bval_i` | Input | 16 | Valid-byte mask for the payload, also acting as input-valid: nonzero together with `aes_gcm_ready_o = 1` accepts one beat. Use the same contiguous, most-significant-byte-first masks as AAD. Zero inserts a gap and leaves the next payload keystream block unconsumed once initialization is complete. |
| `aes_gcm_data_in_i` | Input | 128 | Plaintext in encryption mode, ciphertext in decryption mode. Pack the first byte in `[127:120]`. Present the data and mask together at an accepting rising edge. |
| `aes_gcm_ready_o` | Output | 1 | Payload readiness: an encrypted counter block is available and both the GHASH hash subkey and IV-dependent tag mask have been loaded. May change during operation; check it for every payload beat. It is not an output-ready input or a general AAD handshake. |
| `aes_gcm_data_out_val_o` | Output | 1 | Registered payload-output validity. An accepted input beat produces its XOR result immediately after that accepting edge, valid for the following clock interval. Consecutive accepted beats can keep this high on consecutive cycles. There is no output acknowledgement. |
| `aes_gcm_data_out_bval_o` | Output | 16 | Registered copy of the accepted input byte mask, aligned with output data and output-valid. Zero on cycles without an accepted payload beat. |
| `aes_gcm_data_out_o` | Output | 128 | Ciphertext in encryption mode, plaintext in decryption mode. Valid only with output-valid and only in byte lanes selected by the output mask. Invalid lanes are not guaranteed to be zero. The register retains its previous data between valid outputs. |
| `aes_gcm_ghash_tag_val_o` | Output | 1 | One-clock tag-valid pulse from the end-of-packet pipeline. Asserted with the tag after the third rising edge sampling a low packet envelope following a high one. No tag-ready handshake exists. |
| `aes_gcm_ghash_tag_o` | Output | 128 | Full computed authentication tag, valid with tag-valid and retained until the next tag/reset. In decryption mode this is a computed tag to compare externally against the received tag; the core has no received-tag input or authentication-success output. |
| `aes_gcm_icb_cnt_overflow_o` | Output | 1 | Registered indication that the 32-bit counter reached `FFFFFFFF`. Counter generation then stops automatically. This is a level reflecting counter state, not a per-packet completion pulse or a sticky error latch. Reset or a new start reinitializes the counter and subsequently clears the indication. |

## Key-load enables

These are groups of key bits, not four individual 32-bit word enables.
The mapping in generated `aes_ecb.vhd` is:

| Enable bit | Key input bits captured | Current AES-128 behavior |
| --- | --- | --- |
| `[2]` | `[255:128]` (four 32-bit words) | Loads the complete AES-128 key. |
| `[1]` | `[127:64]` (two 32-bit words) | These stored words are forced to zero in AES-128 mode. |
| `[0]` | `[63:0]` (two 32-bit words) | These stored words are forced to zero in AES-128 mode. |
| `[3]` | None | Does not load key bits, but still invalidates GHASH initialization through the reduction of all four enables. Keep zero. |

For example, load a 128-bit key `K` with `aes_gcm_key_word_i = {K, 128'b0}`
and `aes_gcm_key_word_val_i = 4'b0100` for one rising edge. Return the enables
to zero before starting the counter. There is no key-load acknowledgement.

## Byte ordering and masks

Mask bit 15 selects data `[127:120]`, bit 14 selects `[119:112]`, and so on,
down to bit 0 selecting `[7:0]`. These are the valid nonempty mask patterns:

```text
Bytes:    1    2    3    4    5    6    7    8
Mask:  8000 C000 E000 F000 F800 FC00 FE00 FF00
Bytes:    9   10   11   12   13   14   15   16
Mask:  FF80 FFC0 FFE0 FFF0 FFF8 FFFC FFFE FFFF
```

For example, three bytes `AA BB CC` use data
`128'hAABBCC00000000000000000000000000` and mask `16'hE000`.
Use full blocks followed by at most one partial final block in each of AAD and
payload. Each accepted partial block is independently zero-padded for GHASH;
the core does not combine short beats into a full block.

Sparse or low-aligned masks are not supported. GHASH's case statement rejects
them without an error port, while the payload XOR path can still accept a
nonzero mask. Supplying such masks can therefore produce data with an incorrect
authentication result.

## Packet sequence and timing

1. Reset the core initially. Keep packet-valid, byte masks, and load/start/stop
   controls low when idle.
2. With the counter stopped and old AES work flushed, load the key, then pulse
   IV-valid with the 96-bit IV. Allow the IV-load edge before pulsing start.
3. Pulse counter-start for one clock, then wait for payload-ready. Initialization
   produces `H = AES_K(0)` and the tag mask `AES_K(IV || 32'h00000001)`;
   payload keystream starts with counter `2`. Initial readiness takes multiple
   clocks; the one-register payload XOR latency is not the startup latency.
4. Raise packet-valid and supply AAD. AAD has no backpressure and is not gated
   by payload-ready internally; waiting for readiness before starting AAD is a
   straightforward integration sequence.
5. Clear the AAD mask before sending payload. This nonoverlapping sequence works
   for both directions. In encryption mode the implementation can overlap the
   last AAD beat and first plaintext beat because ciphertext reaches GHASH a
   cycle later. Do not assume that overlap works for decryption: input ciphertext
   goes directly to GHASH, where AAD has priority.
6. Supply each payload beat when ready is high. A conservative controller keeps
   the payload mask zero while not ready, then presents data and a nonzero mask
   for the accepting edge. The GHASH control logic observes the input mask
   without universally gating it with ready, so avoid treating this interface
   as an unrestricted AXI valid/ready channel.
7. After the final payload acceptance, return the payload mask to zero. Keep
   packet-valid high through the acceptance edge, then lower it for packet end.
   In encryption mode the registered final ciphertext can be hashed on the first
   edge that samples packet-valid low.
8. Capture the tag when tag-valid asserts. If edge `F` is the first edge sampling
   packet-valid low after a high level: `F` registers end-of-packet, `F+1` hashes
   the length block, and `F+2` registers the tag and asserts tag-valid. Leave the
   packet envelope low and wait for tag completion before beginning another
   packet.
9. Stop the counter and flush prefetched AES blocks before loading the next IV
   and restarting at counter `1`. Stop alone does not flush the AES pipeline;
   pipeline-reset alone does not stop the counter. The same key can be retained,
   and GHASH retains `H` until a new key-load enable invalidates it.

There is no payload output backpressure. An adapter must capture every valid
output; if downstream storage is full, pause input acceptance before producing
more output. Decryption emits plaintext before tag comparison, so the surrounding
design must manage its release according to the external comparison result.

For packets with both zero AAD and zero payload, verify behavior separately before
relying on it: the GHASH accumulator is initialized on the first valid data beat,
not solely on packet-valid rising. This inspection does not establish correct
empty-packet behavior across successive packets.

## RTL used for this reference

- [Generated wrapper](../../../aes-gcm/src/gen_rtl/top_aes_gcm.vhd): exact public ports and fixed generics.
- [AES/GHASH connection](../../../aes-gcm/src/aes_gcm.vhd): encrypt/decrypt selection and signal routing.
- [Counter-mode datapath](../../../aes-gcm/src/gcm_gctr.vhd): readiness, acceptance, XOR, output registers.
- [IV and counter](../../../aes-gcm/src/aes_icb.vhd): IV loading, start/stop, overflow.
- [Generated AES ECB](../../../aes-gcm/src/gen_rtl/aes_ecb.vhd): key-load mapping and pipeline-reset routing.
- [GHASH](../../../aes-gcm/src/gcm_ghash.vhd): byte masks, length accumulation, tag pipeline.
- [Authentication control](../../../aes-gcm/src/aes_enc_dec_ctrl.vhd): AAD/payload phase timing.
- [AES constants](../../../aes-gcm/src/aes_pkg.vhd) and [GCM constants](../../../aes-gcm/src/gcm_pkg.vhd): widths and mode encodings.
