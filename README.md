🔐 ISA-Integrated AES: Custom RISC-V Instructions for Direct Cryptographic Acceleration

Author: Karthik Rohan R
GitHub: nahor-kihtrak
Project Type: Mini Project

📌 Project Overview

This project implements AES-128 encryption integrated directly into a RISC-V Instruction Set Architecture (ISA) using custom cryptographic instructions.
By embedding AES operations at the instruction level, the design enables cryptographic acceleration compared to software-only implementations.

The project is developed using Verilog and SystemVerilog, simulated with Icarus Verilog, verified using GTKWave, and prepared for synthesis using Xilinx Vivado.

🛠️ Tools & Technologies

Verilog / SystemVerilog

Icarus Verilog (iverilog)

GTKWave

Xilinx Vivado

Windows environment

🧠 Technical Highlights

Custom RISC-V ISA extensions for AES

Modular RTL design (CPU, Control, ALU, AES Core)

Register-level visibility via terminal output

Waveform-based functional verification

RTL suitable for FPGA synthesis

🏗️ Project Architecture
RISC-V CPU
 ├── Control Unit
 ├── ALU (Extended for AES)
 ├── AES Core
 │    ├── SubBytes
 │    ├── ShiftRows
 │    ├── MixColumns
 │    └── AddRoundKey
 ├── Register File
 ├── Instruction Memory
 └── Data Memory


📂 Repository Structure
aes_core.v        - AES-128 encryption core
alu.v             - ALU with AES instruction support
control.v         - Instruction decode and control logic
cpu.v             - Top-level RISC-V CPU module
dmem.v            - Data memory
imem.v            - Instruction memory
immgen.v          - Immediate generator
regfile.v         - RISC-V register file
sbox_tables.vh    - AES S-Box lookup tables
tb.v              - Testbench
dump.vcd          - Waveform dump file
README.md

▶️ How to Run (Simulation)
Compile
iverilog -g2012 -o aes_riscv cpu.v aes_core.v alu.v control.v regfile.v imem.v dmem.v immgen.v tb.v

Run
vvp aes_riscv


Register dumps are printed in the Windows terminal

View Waveforms
gtkwave dump.vcd

✅ Results & Verification

Correct AES-128 ciphertext match verified

Register dump confirms proper instruction execution

GTKWave waveforms validate timing and control behavior

Design is Vivado synthesis ready

Screenshots of ciphertext output and waveform verification are included in the repository.

🚀 Applications

Cryptographic hardware acceleration

Secure embedded systems

RISC-V ISA extension development

VLSI design and verification

FPGA-based security systems
