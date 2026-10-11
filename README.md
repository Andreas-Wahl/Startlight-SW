# 🚦 Slotcar Startlight "Bären(n)keller"

## 🏎️ Project Overview

Custom embedded firmware for a self-developed slotcar start light system for the CARRERA® Digital 124/132 platform.

The project includes:

- ⚙️ AVR Assembly firmware
- 📡 Manchester protocol decoder
- 🔄 Finite State Machine (FSM)
- 🚥 Race control and status indication
- 🐞 Debugging via ISP and debugWIRE
- 📖 Comprehensive technical documentation

---

## ✨ Features

- 🚦 Start sequence indication
- 🟢 Race operation indication
- 🟡 Pace Car / Safety Car indication
- ⚠️ False start detection
- 🚧 Chaos / Track Stop indication
- 🏁 Race winner indication

---

## 🧠 Technical Highlights

### 🔧 Hardware Platform

- Microchip ATtiny2313
- ⏱️ Internal 8 MHz oscillator
- 📥 External interrupt driven signal acquisition
- 🐞 debugWIRE support

### 💻 Software Architecture

```text
Carrera Data Signal
        │
        ▼
Manchester Decoder
        │
        ▼
 Packet Analysis
        │
        ▼
 Event Processing
        │
        ▼
 Finite State Machine
        │
        ▼
    LED Control
```

### 📦 Software Components

- MAIN
- DECODER
- FSM (Finite State Machine)

---

## 📖 Project Background

The project originated from a private CARRERA® Digital 132 racing track.

The original CARRERA® Startlight could not span a track configuration with more than two racing lanes and did not provide all desired visual indications.

Therefore, a complete custom solution was developed including:

- 🔌 Hardware design
- 📐 PCB layout
- ⚙️ Embedded firmware
- 🖨️ 3D CAD design
- 📚 Technical documentation

The system has been operating reliably for several years.

---

## 📂 Repository Contents

- 💾 AVR Assembly source code
- ⚙️ Include files and configuration headers
- 📑 Software documentation
- 🏗️ Architecture documentation

---

## 🔗 Related Projects

- 🔌 Hardware: [Startlight-HW](https://github.com/Andreas-Wahl/Startlight-HW)
- 🖨️ CAD Models: [Startlight-3D](https://github.com/Andreas-Wahl/Startlight-3D)

---

## 📜 Licensing

### 🔌 Electronics & Housing Design

CC BY-NC-SA 4.0

### 💾 Software

GNU AGPL v3.0

---

## 🚀 Getting Started

```bash
git clone https://github.com/Andreas-Wahl/Startlight-SW.git
```

Refer to the documentation for architecture, implementation details and build instructions.
