# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimLoad Manager (SLM) is an X-Plane 12 flight simulator plugin written in Lua for the **FlyWithLua** scripting framework. It simulates realistic passenger boarding, cargo loading, and fuel ground operations, integrating with SimBrief for flight plan data.

No build step is required — Lua scripts are interpreted directly by FlyWithLua at X-Plane runtime.

Your Onlyplace tu work is : C:\Users\Etien\Documents\SITES&PLUGINS\plugins\Simloadmanager\WIP\GITHUB

## Running & Testing

**To run:** Place `.lua` files and the `SimLoad-Manager-Sounds/` folder in your FlyWithLua scripts directory, then start X-Plane 12. FlyWithLua loads and executes scripts automatically.

**To test changes:** Reload scripts in X-Plane via the FlyWithLua menu (Plugins → FlyWithLua → Reload all Lua scripts). There is no automated test suite.

**Settings file** (auto-created at runtime):
```
Resources/plugins/FlyWithLua/Modules/simload_settings.txt
```

## Code Architecture

### Files

- **`SimLoadManager.lua`** — Main plugin (~2,876 lines). Contains all core logic organized top-to-bottom: initialization, state variables, sound system, settings I/O, SimBrief HTTP integration, embarkation/disembarkation/fuel state machines, ImGui UI, and FlyWithLua event loop registration.
- **`SimLoadManager_loadsheet.lua`** — Secondary floating window module (~436 lines). Renders a detailed loadsheet (planned vs. actual weights, passenger tables, fuel) as a separate ImGui window. It reads from `SLM_Loadsheet_Data`, a global table populated by the main file.

### State Machine

Operations run as a time-based state machine. The current operation phase is tracked by a global state string. The main `do_every_frame` callbacks (`manage_embark`, `manage_disembark`, `manage_fuel_loading`) advance state based on elapsed time.

Key states: `idle` → `embark_started` → `embark_done` / `disembark_started` → `disembark_done` / `fuel_loading` → `fuel_done`

### SimBrief Integration

`fetch_simbrief_data(id)` performs an HTTP GET to the SimBrief XML API, parses the response, and populates `SLM_Loadsheet_Data`. All subsequent operations (timing calculations, UI display) derive from this table.

### Custom DataRefs

The plugin exposes its internal state to other X-Plane plugins via custom FlyWithLua datarefs (e.g., `FlyWithLua/SimLoadManager/state`, `pax_done`, `cargo_done`, `fuel_done`, progress fractions, ETAs). These are updated every frame in `update_slm_datarefs()`.

### X-Plane Commands

Registered commands (usable in X-Plane key bindings):
- `FlyWithLua/SimloadManager/Toggle` — Main window
- `FlyWithLua/SimloadManager/StartEmbark` / `StopEmbark`
- `FlyWithLua/SimloadManager/StartDisembark` / `StopDisembark`
- `FlyWithLua/SimloadManager/StartFuel` / `StopFuel`
- `FlyWithLua/SimloadManager/Reset`
- `FlyWithLua/SimloadManager/ImportSimbrief`

### Timing Presets

Four presets (Realistic, Fast, VeryFast, Custom) set per-passenger and per-kg timing parameters. Applied via `apply_realistic_timings()` etc. Custom values are user-configurable in the UI and persisted to the settings file.

### SGES Integration

The plugin optionally detects the Simple Ground Equipment Services (SGES) plugin and calls SGES commands to animate service vehicles when loading begins/ends.

### Sound System

16 WAV files in `SimLoad-Manager-Sounds/`. Loaded via FlyWithLua's `load_WAV_file()`. Volume adjusts dynamically based on whether the camera is internal or external. All sounds are managed through wrapper functions; do not call FlyWithLua sound functions directly in logic code.

## FlyWithLua API Patterns

- `do_every_frame("function_name()")` — Registers a per-frame callback (string-based, not a function reference).
- `float_wnd_create(...)` / `float_wnd_set_imgui_builder(...)` — ImGui floating window creation.
- `dataref(name, path, "writable")` — Declares a dataref variable.
- `create_dataref(path, type, callback)` — Exposes a custom dataref.
- `XPLMSpeakString(text)` — Text-to-speech via X-Plane.
