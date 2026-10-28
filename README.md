# 32-Bit RISC-V SoC (`riscv_uart_soc`) — OpenLane SkyWater 130nm ASIC Design

An industry-standard, fully verified digital ASIC implementation of a custom **32-bit RISC-V System-on-Chip (SoC)** targeting the **SkyWater 130nm (sky130A) PDK**. The project executes an automated RTL-to-GDSII physical design flow using containerized **OpenLane v1.0.2**, achieving complete timing closure with zero DRC/LVS violations.

---

**## 📌 Architecture Overview**

The design integrates an open-source 32-bit RISC-V processor core with a custom memory-mapped UART peripheral:
* **Processor Core:** `PicoRV32` RV32I soft-core executing standard RISC-V machine instructions.
* **Peripheral:** Custom Verilog `uart_tx` module mapped to memory address `0x02000000`.
* **Handshake Protocol:** Zero-wait state memory interface mapping core write operations directly to peripheral transmit control registers.

---

**## 🛠️ Project Structure**

```text
riscv-uart-sky130-soc/
├── src/
│   ├── riscv_uart_soc.v   # Top-level SoC integration & memory-mapped I/O logic
│   ├── uart_tx.v          # Custom UART transmitter module
│   └── picorv32.v         # PicoRV32 RISC-V core
├── config.json            # OpenLane flow configuration parameters
└── README.md              # Project documentation & verification reports

**⚙️ Design Specifications & Constraints**  

**Parameter                                     Value**

Process PDK                                SkyWater 130nm (sky130A)
Standard Cell Library                      sky130_fd_sc_hd
Die Area                                   350.0 µm × 350.0 µm
Target Clock Period                        25.0 ns (40 MHz)
Core Design Type                           DESIGN_IS_CORE: true
Power Distribution                         Core Rings enabled (FP_PDN_CORE_RING: true)



**🚀 How to Run the OpenLane Flow**

**Prerequisites**

Docker installed and configured on Linux/Ubuntu.

OpenLane v1.0.2 container image pulled.

**Execution Command**

Run the containerized flow from your OpenLane directory:

docker run --rm \
  -v $(pwd):/openlane \
  -v $(pwd)/designs:/openlane/install \
  -v ~:/home/$USER \
  -v ~/.ciel:/home/$USER/.ciel \
  -e PDK_ROOT=/home/$USER/.ciel \
  -e PDK=sky130A \
  --user 1000:1000 \
  --network host \
  ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69-amd64 \
  sh -c "./flow.tcl -design riscv_uart_soc"


**📊 Physical Design & Signoff Results**

The physical design pipeline successfully executed all 42 flow stages:

1.Synthesis (Yosys): Mapped behavioral Verilog logic to standard cell netlist.

2.Floorplanning & PDN (OpenROAD): Formed power grid (VPWR/VGND) and tap/decap cell insertions.

3.Placement & Routing (FastRoute): Successfully placed standard cells and routed global/detailed interconnections with zero shorts.

4.Clock Tree Synthesis (CTS): Balanced clock distribution tree across the core.

5.Signoff Verification (Magic & KLayout):

    Setup/Hold Timing: 0 Violations across all process corners.

    DRC (Design Rule Checking): 0 Violations in detailed routing and GDS streaming out.

    LVS (Layout vs. Schematic): Fully verified equivalence

**Signoff Log Verification**

[INFO]: Running Magic DRC ...
[INFO]: No DRC violations after detailed routing.
[INFO]: No DRC violations after GDS streaming out.
[INFO]: There are no setup violations in the design at the typical corner.
[INFO]: There are no hold violations in the design at the typical corner.
[SUCCESS]: Flow complete.

**📜 License & Acknowledgments**

PicoRV32 Core: Designed by Clifford Wolf (YosysHQ) under ISC License.

SkyWater 130nm PDK: Open-source PDK released by Google & SkyWater.

Flow Infrastructure: Built using OpenLane by Efabless & OpenROAD project.
