# quic_encrypt

Standalone AXI-stream IP and simulation scaffold based on `udp_segmentation`.
The `quic_encrypt` module currently passes packets through unchanged; encryption,
key handling and QUIC header protection are not implemented.

The interface uses 512-bit data, 64-bit keep and 128-bit user metadata, with
ready/valid backpressure and an active-low reset. Add the encryption datapath in
`hw/hdl/quic_encrypt.sv`.

On a machine with the repository's Vivado 2023.2 environment and shared NetFPGA
IP prepared, load Vivado's installed settings, then from the repository root:

```bash
source tools/settings.sh
export NF_PROJECT_NAME=quic_encrypt
export NF_DESIGN_DIR="$NFPLUS_FOLDER/hw/projects/$NF_PROJECT_NAME"
make -C "$NF_DESIGN_DIR/hw" sim TESTNAME=both_passthrough
```

The project Makefile also sets its own project name and paths, so it does not
require changing the defaults in `tools/settings.sh`. `DEVICE` and `BOARD` come
from that settings script. Ensure `PYTHON_BNRY` points to the checkout's Python
virtual environment on the machine running Vivado.

Use `make -C "$NF_DESIGN_DIR/hw"` to package the IP, or `simgui` for the GUI.
Simulation generates `single_stim.axi`, `single_expected.axi` and `single_log.axi`
in `test/`; the Makefile checks the output log exists and reconciles packets.
`both_passthrough` covers packet sizes around 64-byte boundaries and multi-beat
packets. It tests the scaffold, not encryption. Simulation clears prior generated
simulation logs. There is no board-level bitstream or hardware deployment target.
