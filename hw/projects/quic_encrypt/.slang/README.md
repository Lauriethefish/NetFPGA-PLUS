# quic_encrypt editor support

Open `quic_encrypt.code-workspace` from the repository root in VS Code. It opens
only this project and selects its local slang-server binary. The configuration
indexes `hw/hdl` and the editor-only external-module declarations, with
`SIMULATION=1` and `top_tb` as the simulation top. Formatting is not configured.
Opening the full repository also works: its `.slang/server.json` explicitly
limits indexing to this same project and these stubs.

The official `Hudson-River-Trading.vscode-slang` extension is installed locally.
The Linux x64 server v0.3.1 is under `.slang/local/bin/slang-server`, ignored by
Git. Its release archive SHA-256 is
`5162701e675e5b2cc8b43eab1b98a2af8bc2081667fc80d07aa971866bc9b867`.
After moving the checkout or using another machine, install the server there and
update `slang.path` in the workspace file and repository `.vscode/settings.json`.
Use **slang: Restart Language Server**
after changing that path, and **slang: Show Output** to inspect server messages.

Slang analyzes SystemVerilog, so `stubs/external_modules.sv` supplies only the
interfaces of the VHDL AES-GCM core and the two generated simulation IPs. This
enables port-name and width checking, but does not analyze their implementations.
Keep the declarations in sync if those interfaces change. They are referenced
only by the editor configuration; never add them to Vivado source lists.

The workspace does not hide diagnostics in unfinished RTL. Installation does not
require changing `quic_encrypt.sv`, the Vivado scripts, or any other project's
configuration.
