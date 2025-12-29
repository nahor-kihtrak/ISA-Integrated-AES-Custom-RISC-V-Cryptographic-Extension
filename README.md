```md
# 🔐 ISA-Integrated AES: Custom RISC-V Instructions for Direct Cryptographic Acceleration

**Author:** Karthik Rohan R  
**GitHub:** [nahor-kihtrak](https://github.com/nahor-kihtrak)  
**Project Type:** Mini Project  

---

## 📌 Project Overview

This project implements **AES-128 encryption integrated directly into a RISC-V Instruction Set Architecture (ISA)** using **custom cryptographic instructions**.  
By embedding AES operations at the **instruction level**, the design achieves efficient cryptographic acceleration compared to software-only implementations.

The project is developed using **Verilog and SystemVerilog**, simulated with **Icarus Verilog**, verified using **GTKWave**, and prepared for synthesis using **Xilinx Vivado**.

---

## 🎯 Objectives

- Design and integrate **custom RISC-V instructions** for AES encryption  
- Implement **hardware-accelerated AES-128** within the CPU datapath  
- Verify correctness using **register dump analysis** and **waveform inspection**  
- Ensure ciphertext correctness using standard AES test vectors  

---

## 🛠️ Tools & Technologies

- **HDL:** Verilog, SystemVerilog  
- **Simulation:** Icarus Verilog (`iverilog`)  
- **Waveform Viewer:** GTKWave  
- **Synthesis:** Xilinx Vivado  
- **Platform:** Windows  

---

## 🧠 Technical Highlights

- Custom **RISC-V ISA extensions** for cryptographic acceleration  
- Modular RTL design with clear separation of datapath and control  
- Register-level visibility through terminal-based dumps  
- Functional verification using GTKWave waveforms  
- Synthesis-ready RTL suitable for FPGA implementation  

---

## 🏗️ Project Architecture

```

RISC-V CPU
│
├── Control Unit (Instruction Decode & Control Signals)
│
├── ALU (Extended with AES Operations)
│
├── AES Core
│     ├── SubBytes (S-Box)
│     ├── ShiftRows
│     ├── MixColumns
│     └── AddRoundKey
│
├── Register File
└── Instruction & Data Memory

```

---

## 📂 Repository Structure

```

├── aes_core.v        # AES-128 encryption core
├── alu.v             # ALU with custom AES instruction support
├── control.v         # Control unit and instruction decoding
├── cpu.v             # Top-level RISC-V CPU integration
├── dmem.v            # Data memory
├── imem.v            # Instruction memory
├── immgen.v          # Immediate generator
├── regfile.v         # RISC-V register file
├── sbox_tables.vh    # AES S-Box lookup tables
├── tb.v              # Testbench for verification
├── dump.vcd          # Generated waveform file
├── README.md

````

---

## ▶️ How to Run (Simulation)

### Compile
```bash
iverilog -g2012 -o aes_riscv \
cpu.v aes_core.v alu.v control.v regfile.v \
imem.v dmem.v immgen.v tb.v
````

### Run

```bash
vvp aes_riscv
```

* Register values and intermediate outputs are displayed in the **Windows terminal**

### View Waveforms

```bash
gtkwave dump.vcd
```

---

## ✅ Results & Verification

* ✔ Correct **AES-128 ciphertext match** verified using standard test vectors
* ✔ Register dump confirms correct instruction execution
* ✔ GTKWave waveforms validate timing and control behavior
* ✔ RTL is compatible with **Vivado synthesis**

Screenshots of ciphertext output and waveform analysis are included in the repository.

---

## 🚀 Applications

* Cryptographic hardware acceleration
* Secure embedded systems
* RISC-V ISA extension research
* VLSI design and verification projects
* FPGA-based security implementations

---

## 📌 Notes

* Implemented as a **mini project** focusing on CPU-level cryptographic integration
* Designed for clarity, modularity, and verification
* Can be extended to support AES decryption or additional cryptographic primitives

```
```
