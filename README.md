# 🔐 ISA-Integrated AES: Custom RISC-V Instructions for Direct Cryptographic Acceleration

**Author:** Karthik Rohan R
**GitHub:** [nahor-kihtrak](https://github.com/nahor-kihtrak)
**Project Type:** Mini Project

---

## 📌 Project Overview

This project implements **AES-128 encryption integrated directly into a RISC-V Instruction Set Architecture (ISA)** using **custom cryptographic instructions**.
Instead of treating AES as a software-only routine, cryptographic operations are accelerated at the **instruction level**, improving performance and architectural efficiency.

The design is developed using **Verilog and SystemVerilog**, simulated with **Icarus Verilog**, verified through **GTKWave waveform analysis**, and prepared for synthesis using **Xilinx Vivado**.

---

## 🎯 Objectives

* Integrate **AES encryption** directly into the RISC-V ISA
* Design **custom instructions** for cryptographic operations
* Verify correctness through **register dump and waveform analysis**
* Ensure **ciphertext correctness** matching AES-128 standards

---

## 🛠️ Tools & Technologies

| Category          | Tools                               |
| ----------------- | ----------------------------------- |
| HDL               | Verilog, SystemVerilog              |
| Simulation        | Icarus Verilog (`iverilog`)         |
| Waveform Analysis | GTKWave                             |
| Synthesis         | Xilinx Vivado                       |
| Platform          | Windows (Terminal-based simulation) |

---

## 🧠 Technical Highlights

* **Custom RISC-V ISA Extensions** for AES operations
* **Hardware-accelerated AES-128 encryption**
* Modular RTL design for easy verification and synthesis
* Register-level visibility via **terminal dump**
* Functional verification using **waveform inspection**

---

## 🏗️ Project Architecture

```
RISC-V Core
   │
   ├── Custom AES Instruction Decoder
   │
   ├── AES Encryption Engine
   │     ├── SubBytes
   │     ├── ShiftRows
   │     ├── MixColumns
   │     └── AddRoundKey
   │
   └── Register File & Control Logic
```

---

## ▶️ How to Run the Project (Simulation)

### 1️⃣ Compile the Design

```bash
iverilog -g2012 -o aes_riscv *.v *.sv
```

### 2️⃣ Run Simulation

```bash
vvp aes_riscv
```

* Register dumps will be displayed in the **Windows terminal**
* Ciphertext values can be cross-verified with standard AES test vectors

### 3️⃣ View Waveforms

```bash
gtkwave dump.vcd
```

* Inspect instruction execution
* Observe AES round transformations
* Verify timing and control signals

---

## ✅ Results & Verification

* ✔ **Correct AES-128 ciphertext match** verified using test vectors
* ✔ **Register dump validation** via terminal output
* ✔ **Waveform screenshots** confirm correct instruction sequencing
* ✔ Design is **synthesis-ready** in Vivado

> Screenshots of ciphertext match and GTKWave waveforms are included in the repository for reference.

---

## 📂 Repository Structure

```
├── rtl/                # Verilog & SystemVerilog source files
├── tb/                 # Testbench files
├── waveforms/          # GTKWave screenshots
├── outputs/            # Ciphertext & register dump results
├── README.md
```

---

## 🚀 Applications & Relevance

* Cryptographic hardware acceleration
* Secure embedded systems
* RISC-V ISA extension research
* VLSI design & verification projects
* FPGA-based security implementations
