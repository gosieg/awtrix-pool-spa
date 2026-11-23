# Awtrix NG Native App: Pool & Spa Monitor

A native on-device Berry script for [AWTRIX NG](https://github.com/Blueforcer/awtrix-ng) (Ulanzi TC001 / TC002 pixel clocks) that displays live Pool and Spa temperatures, target setpoints, and pump/heating statuses with Home Assistant integration via MQTT.

## Features

- **Native Berry Script:** Runs locally on the clock hardware with zero network lag and smooth rendering (~40 FPS).
- **Static Multi-Line Layout (No Scrolling):**
  - **Tall Displays (TC002, 52×16):** Renders Header on Line 1 (`Pool:` / `Spa:`) and Temperatures on Line 2 (`[cur]° -> [target]°`).
  - **Standard Displays (TC001, 32×8):** Uses an embedded 3×5 micro-font to render header on the top row and `[cur]°->[target]°` cleanly on the bottom row, completely eliminating text scrolling.
- **Smart Color Cues:**
  - Target temperature in **Orange**.
  - Current temperature in **Cyan Blue** while heating up.
  - Current temperature turns **Orange** once target is achieved.
  - Inactive/standby temperature in **Cyan Blue**.
  - `"PUMP OFF"` in dim gray when pumps are not running.
- **Dynamic Rotation Duration:** Extends screen time from 7s to 12s when actively heating.

---

## Installation

### 1. Clock Script Setup
1. Open your Awtrix clock web interface at `http://<your-clock-ip>/#/`.
2. Go to the **Scripts** tab and click **`+`** (New Script).
3. Name it `pool_spa`.
4. Copy and paste the contents of [`pool_spa.be`](pool_spa.be) into the editor.
5. Save (`Ctrl + S`) and toggle it active.

### 2. Home Assistant Automation Setup
This application listens on the MQTT topic `awtrix/pool_spa`.

Import or paste [`homeassistant_automation.yaml`](homeassistant_automation.yaml) into your Home Assistant automations:
- **Entities monitored:**
  - `water_heater.pool`
  - `water_heater.spa`
  - `switch.pool_pump`
  - `switch.spa_pump`
- **MQTT Topic:** `awtrix/pool_spa` (retained)
- **JSON Payload schema:**
  ```json
  {
    "pool": 62,
    "pool_target": 86,
    "pool_pump": true,
    "pool_heat": false,
    "spa": 98,
    "spa_target": 100,
    "spa_pump": false,
    "spa_heat": false
  }
  ```

---

## License
MIT
