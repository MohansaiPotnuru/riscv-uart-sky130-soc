# RISC-V UART SoC on SkyWater 130 nm (LibreLane)

[![CI](https://github.com/MohansaiPotnuru/riscv-uart-sky130-soc/actions/workflows/ci.yml/badge.svg)](https://github.com/MohansaiPotnuru/riscv-uart-sky130-soc/actions/workflows/ci.yml)
[![LibreLane](https://github.com/MohansaiPotnuru/riscv-uart-sky130-soc/actions/workflows/openlane.yml/badge.svg)](https://github.com/MohansaiPotnuru/riscv-uart-sky130-soc/actions/workflows/openlane.yml)
[![Release](https://img.shields.io/github/v/release/MohansaiPotnuru/riscv-uart-sky130-soc)](https://github.com/MohansaiPotnuru/riscv-uart-sky130-soc/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A small 32-bit RISC-V system-on-chip, taken from RTL to GDSII with **[LibreLane](https://github.com/librelane/librelane)** (the maintained successor to OpenLane 2) on the open-source **SkyWater SKY130A** PDK. It has:

- a **PicoRV32** RV32I CPU core,
- a **256-byte boot ROM** holding firmware that prints a message,
- a custom **memory-mapped 8N1 UART transmitter** with a busy/status register.

After reset the CPU runs from the ROM and sends `Hello from RISC-V on SKY130!` over `tx_out` at 115200 baud, over and over.

## Architecture

```mermaid
flowchart LR
    CPU["PicoRV32<br/>RV32I core"] -- "native mem bus<br/>(zero wait state)" --> DEC{"Address<br/>decode"}
    DEC -- "0x0000_0000-0x0000_00FF" --> ROM["Boot ROM<br/>64 x 32-bit"]
    DEC -- "0x0200_0000 / 0x0200_0004" --> REGS["UART regs<br/>TXDATA / STATUS"]
    REGS --> UART["uart_tx<br/>8N1, 115200 baud"]
    UART --> TX(["tx_out"])
    UART --> DONE(["tx_done"])
```

### Memory map

| Address | Name | Access | Description |
|---|---|---|---|
| `0x0000_0000` to `0x0000_00FF` | Boot ROM | R | Firmware. The reset vector is `0x0000_0000`. |
| `0x0200_0000` | `UART_TXDATA` | W / R | Writing `[7:0]` starts a transmission. A read returns the last byte written. |
| `0x0200_0004` | `UART_STATUS` | R | `bit0 = TX_BUSY`. Wait for it to clear before writing the next byte. |
| anything else | – | – | Reads return 0. Writes are ignored. |

### Top-level ports

| Port | Dir | Description |
|---|---|---|
| `clk` | in | System clock, 40 MHz (25 ns) |
| `resetn` | in | Active-low synchronous reset |
| `tx_out` | out | UART TX line (idle high) |
| `tx_done` | out | One-cycle pulse after each stop bit |

### Boot firmware

The firmware is ten RV32I instructions plus the message string. `firmware/gen_rom.py` encodes them straight into `src/boot_rom.v`, so you don't need a RISC-V toolchain. To change the message:

```sh
python3 firmware/gen_rom.py "Custom text\r\n"
```

```asm
        lui   s0, 0x02000        # UART base
restart:addi  s1, zero, MSG
next:   lbu   a0, 0(s1)
        beq   a0, zero, restart
wait:   lw    t0, 4(s0)          # STATUS
        andi  t0, t0, 1
        bne   t0, zero, wait     # spin while TX busy
        sw    a0, 0(s0)          # TXDATA
        addi  s1, s1, 1
        jal   zero, next
```

## Repository layout

```text
riscv-uart-sky130-soc/
├── src/
│   ├── riscv_uart_soc.v     # Top level: address decode, UART registers, CPU + ROM + UART
│   ├── uart_tx.v            # 8N1 UART transmitter (start/data/stop FSM, busy + done flags)
│   ├── boot_rom.v           # Generated boot ROM (do not edit by hand)
│   └── picorv32.v           # PicoRV32 core by Claire Wolf / YosysHQ (ISC licence, unmodified)
├── tb/
│   └── tb_riscv_uart_soc.v  # Self-checking testbench with a UART receiver model
├── firmware/
│   └── gen_rom.py           # RV32I encoder + ROM generator
├── constraints/
│   ├── pnr.sdc              # Place-and-route SDC (tighter fanout/transition targets)
│   └── signoff.sdc          # Signoff SDC (LibreLane defaults)
├── config.json              # LibreLane design configuration
├── LICENSE                  # MIT (src/picorv32.v stays ISC)
├── Makefile                 # sim / wave / lint / synth helpers
└── .github/workflows/
    ├── ci.yml               # Simulation and Yosys synthesis on every push
    └── openlane.yml         # Full LibreLane RTL-to-GDSII flow when hardware or config changes
```

## Design parameters (LibreLane)

| Parameter | Value |
|---|---|
| PDK / standard cells | `sky130A` / `sky130_fd_sc_hd` |
| Clock | 25 ns (40 MHz) on `clk` |
| Die area | 500 µm × 500 µm (absolute sizing) |
| Placement density | 50 % |
| Design repair | 200 µm max wire length, 50 % slew margin, `buf_1` / `clkbuf_1` / `clkbuf_2` excluded |
| Clock tree | Sinks clustered 8 per leaf buffer, trunk buffered every 60 µm |
| PDN | Core ring enabled, design hardened as a core |
| UART | 115200 baud, `CLKS_PER_BIT = 40 MHz / 115200 = 347` |
| CPU options | No counters, no barrel shifter, no MUL/DIV, no compressed ISA (to save area) |

If you change `CLOCK_PERIOD` in `config.json`, change the `CLK_FREQ_HZ` parameter in `riscv_uart_soc.v` to match, or the baud rate will be off.

## Simulation

You need [Icarus Verilog](https://steveicarus.github.io/iverilog/) 11 or newer. [Yosys](https://github.com/YosysHQ/yosys) is optional and only used for `make synth`.

```sh
make sim      # build and run the self-checking testbench
make wave     # same, plus a VCD dump for GTKWave
make synth    # generic Yosys synthesis + cell statistics
make lint     # Verilator lint (optional)
```

The testbench uses a smaller clock-to-baud ratio (10 clocks per bit) so it runs fast. It decodes the UART output and passes only if the full message arrives correctly twice:

```text
UART: Hello from RISC-V on SKY130!<0d><0a>Hello from RISC-V on SKY130!<0d><0a>
PASS: received 60 bytes correctly
```

## Running the LibreLane flow

You need Python 3.10+ and Docker. LibreLane downloads the sky130A PDK automatically through Ciel on the first run.

```sh
pip install librelane==3.0.17
librelane --dockerized config.json
```

The results go to `runs/<tag>/`. The final GDS is in `final/gds/`, all signoff metrics are in `final/metrics.json`, and each step (STA per corner, DRC, LVS, antenna check) has its own numbered directory. The [LibreLane workflow](.github/workflows/openlane.yml) runs the same command in GitHub Actions and uploads the outputs as an artifact.

## Physical design results

The current revision (v2, with the boot ROM) was hardened end to end in GitHub Actions ([run 42943552409](https://github.com/MohansaiPotnuru/riscv-uart-sky130-soc/actions/runs/42943552409), LibreLane 3.0.17, sky130A, about 20 minutes). The final GDS, `metrics.json` and signoff reports (per-corner STA, DRC, LVS and antenna) are attached to the [v2.1 release](https://github.com/MohansaiPotnuru/riscv-uart-sky130-soc/releases/tag/v2.1). Every signoff check passed with no warnings:

```text
Check for Routing DRC errors clear.
Check for Magic DRC errors clear.
Check for KLayout DRC errors clear.
Check for LVS errors clear.
No setup violations found
No hold violations found
No max slew violations found
No max cap violations found
```

Timing was checked at all nine sky130 corners: tt/ss/ff process, each with min/nom/max interconnect RC, from ff at -40 °C/1.95 V to ss at 100 °C/1.60 V.

| Metric | Value |
|---|---|
| Die / core area | 500 µm × 500 µm / 232,536 µm² |
| Placement utilisation | 52.7 % |
| Standard cells (excl. fill and tap) | 10,207 (1,509 flip-flops) |
| Clock | 25 ns (40 MHz) |
| Worst setup slack | 7.26 ns (ss, 100 °C, 1.60 V, max RC) |
| Worst hold slack | 0.034 ns (ff, -40 °C, 1.95 V, min RC) |
| Max slew / max cap / max fanout violations | 0 / 0 / 0 |
| Antenna violations | 0 (26 diodes inserted) |
| DRC (router / Magic / KLayout) | 0 / 0 / 0 |
| LVS errors | 0 |
| Routed wire length | 394,577 µm |
| Total power (typical corner) | 6.98 mW |

### How the signoff warnings were cleared

The first hardening of v2 used OpenLane v1. It met timing and was DRC/LVS clean, but signoff reported 21 antenna violations, 102 max-fanout violations and 81 slow-corner slew violations. Fixing them took several flow runs:

- **Antenna.** OpenLane v1 repairs antennas only at global routing, and its estimate was up to 2.6× lower than the antenna ratio measured after detailed routing. LibreLane repairs antennas again after detailed routing, which brought violations to 0 with only 26 diodes. OpenLane v1's heuristic diode insertion also fixed them, but it added 5,520 diodes, and each one counts as a fanout load.
- **Fanout.** Most violations were clock leaf buffers driving 11–15 flops, fixed by clustering 8 sinks per leaf. The clock root also drove all 16 level-4 buffers directly (0.29 pF against a 0.20 pF limit), fixed by buffering the trunk every 60 µm. The last few were nets with 10 logic loads plus one antenna diode, so the PnR SDC targets fanout 9.
- **Slew.** Mid-flow STA uses estimated wires with nominal RC, so it showed no violations. Signoff at ss/100 °C/1.60 V with max RC still found hundreds. They came from the resizer choosing the weakest buffers (`buf_1`, then `clkbuf_1`, then `clkbuf_2`) and from long wires. Excluding those cells, a 200 µm wire limit, a 50 % slew margin and a 0.70 ns PnR transition target (signoff checks 0.75 ns) cleared all of them.

> Note: this is a hardened layout (GDSII) produced by an open-source flow. It has not been fabricated.

## Changelog

- **v2.1** – Moved physical design from OpenLane v1 to LibreLane 3.0.17 and tuned it until signoff was free of warnings (antenna, fanout, slew and cap all 0 across nine corners). Added separate PnR and signoff SDC files.
- **v2** – Added a boot ROM so the CPU has code to run. In v1 every fetch returned `0x00000000`, an illegal instruction. Also added the `UART_STATUS` busy register, fixed the baud divisor (it was 87, which gives about 460 kbaud at 40 MHz; it is now derived from `CLK_FREQ_HZ / BAUD_RATE`), made `tx_done` a single-cycle pulse, made the UART reset synchronous to match the rest of the design, moved sources into `src/` to match `config.json`, and added the testbench and CI.
- **v1** – Initial PicoRV32 + UART integration, hardened with OpenLane.

## Acknowledgements and licences

This project is released under the [MIT licence](LICENSE), except `src/picorv32.v`, which keeps its original ISC licence.

- **PicoRV32** © Claire Xenia Wolf, ISC licence (see the header of `src/picorv32.v`).
- **SkyWater SKY130 PDK** – open-source PDK by Google and SkyWater Technology.
- **LibreLane / OpenROAD** – open-source RTL-to-GDSII flow (LibreLane, successor to Efabless OpenLane 2) and the OpenROAD project.
