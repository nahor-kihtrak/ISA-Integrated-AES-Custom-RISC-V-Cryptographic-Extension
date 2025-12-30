# 🔐 ISA-Integrated AES: Custom RISC-V Cryptographic Extension

A hardware mini project implementing **AES cryptographic acceleration** using **custom RISC-V ISA extensions**, designed and verified using **Verilog/SystemVerilog**.

---

## 👤 Author Details

* **GitHub Username:** nahor-kihtrak
* **Real Name:** Karthik Rohan R

### 👥 Project Partner

* **GitHub Username:** aditya220406
* **Real Name:** Aditya M

---

## 📌 Project Overview

This project integrates an **AES encryption core** directly into a **RISC-V processor datapath** using custom instructions.
The design is simulated and verified using **Icarus Verilog** and **GTKWave**, ensuring correct ciphertext generation.

---

## 🧩 File Structure

```
├── README.md           # Project documentation
├── Schematic.pdf       # RTL / block-level schematic
├── aes_core.v          # AES encryption core
├── alu.v               # Arithmetic Logic Unit
├── control.v           # Control unit
├── cpu.v               # Top-level RISC-V CPU module
├── dmem.v              # Data memory
├── imem.v              # Instruction memory
├── immgen.v            # Immediate generator
├── regfile.v           # Register file
├── sbox_tables.vh      # AES S-Box lookup tables
└── tb.v                # Testbench
```

---

## ⚙️ Tools & Technologies Used

* **Languages:** Verilog, SystemVerilog
* **Simulation:** Icarus Verilog (iverilog)
* **Waveform Viewer:** GTKWave
* **Synthesis (optional):** Xilinx Vivado
* **Platform:** Windows

---

## ▶️ Simulation & Verification

### Steps to Run Simulation

```
iverilog -o aes_cpu tb.v cpu.v alu.v control.v aes_core.v regfile.v imem.v dmem.v immgen.v
vvp aes_cpu
gtkwave dump.vcd
```

### Verification Details

* Register dump observed in Windows terminal
* Correct AES ciphertext matched with reference output
* Functional timing verified using GTKWave

---

## 📊 Results

* ✅ Correct ciphertext generation
* ✅ Successful execution of AES custom instructions
* ✅ Verified datapath and control logic

Result screenshots and waveform images are included in the repository.

---

## 📚 Applications

* Hardware cryptography acceleration
* Secure embedded systems
* Custom RISC-V processor design
* Academic mini projects

---

## 📜 License

This project is developed strictly for **academic and educational purposes**.

---

⭐ If you find this project useful, feel free to star the repository!

---
