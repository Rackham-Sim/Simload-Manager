# SimLoad Manager

**SimLoad Manager** – Realistic Pax, Cargo & Fuel Ground Operations for X-Plane 12

SimLoad Manager (SLM) adds realistic passenger, cargo, and fuel loading operations to X-Plane 12.  
It integrates seamlessly with **SimBrief**, **FlyWithLua**, and **SGES** to provide immersive and automated ground operations without modifying aircraft files.

---

## ✨ Features

- Realistic **passenger, cargo, and fuel loading / unloading**
- **SimBrief integration**
  - Automatic import of PAX, cargo, and fuel
  - Automatic unit detection (kg / lbs)
- Manual load entry available
- Real-time **progress bars and time estimation**
- Multiple loading speeds:
  - Realistic
  - Fast
  - Very Fast
  - Custom
- Fuel loading:
  - Before boarding
  - During boarding
- **Ambient sounds and AI-generated voice announcements**
  - Adaptive volume based on internal/external view
- Persistent settings (SimBrief ID, units, timing)
- **SGES integration**
  - Stairs
  - Belt loaders
  - Fuel truck
  - Passenger flow
  - Cones (fully managed by SGES)
- Automatic jetway logic with **AutoDGS compatibility**
- Built-in stairs support (“Do Not Call Stairs” option)
- **FlyWithLua commands** for external control
- **Exposed datarefs (SLM API)** for third-party integration
- Integrated **Loadsheet system (SLMLS)**
- Works with **any aircraft** (no aircraft data modification)

---

## 📄 Loadsheet (SLMLS)

SimLoad Manager includes **SLMLS (SimLoad Manager Loadsheet)**:

- Generates a realistic loadsheet at the end of loading
- Displays:
  - ZFW
  - Payload distribution
  - Fuel values
  - Mass in kg / lbs
- Loadsheet window automatically positions next to the SLM window

---

## Requirements
- X-Plane 12
- FlyWithLua
- Simple Ground Equipment & Services (SGES)

---

## 🛠 Installation

1. Extract the downloaded archive
2. Copy the following files into: ``X-Plane 12/Resources/plugins/FlyWithLua/Scripts/``

- `SimLoadManager.lua`
- `SimLoadManager_loadsheet.lua`

3. Copy the folder: ``SimLoad-Manager-Sounds`` into the same directory
   
⚠️ **Do not rename the folder**

---

## ⚠️ Update Note

If updating from a version **prior to v1.9.0**, delete: ``Resources/plugins/FlyWithLua/Modules/simload_settings.txt``


The file will be recreated automatically on next launch.

---

## 🔧 Requirements

- **X-Plane 12**
- **FlyWithLua** (latest recommended)
- **Simple Ground Equipment & Services (SGES)**  
  *(required for automatic ground handling)*

---

## 💡 Optional

- **SimBrief account** (recommended for full automation)

---

## ▶️ Usage

1. Launch X-Plane
2. Open **SimLoad Manager** via FlyWithLua menu or assigned command
3. Load a SimBrief flight or enter values manually
4. Start the loading process
5. Open the **Loadsheet (SLMLS)** once loading is complete

---

## 🧩 Compatibility

- Compatible with all aircraft
- Compatible with AutoDGS
- No aircraft files are modified
- Safe for online flying

---

## ❤️ Support

If you enjoy SimLoad Manager:
- Leave feedback on X-Plane.org
- Consider supporting development via Ko-Fi

---

## 📜 License

Specify your license here (MIT / GPL / Custom).

---






