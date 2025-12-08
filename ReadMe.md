<p align="center">
  <img src=".github/assets/atoll-logo.png" alt="Atoll logo" width="120">
</p>

<p align="center">
  <a href="https://github.com/Ebullioscopic/Atoll/stargazers">
    <img src="https://img.shields.io/github/stars/Ebullioscopic/Atoll?style=social" alt="GitHub stars"/>
  </a>
  <a href="https://github.com/Ebullioscopic/Atoll/network/members">
    <img src="https://img.shields.io/github/forks/Ebullioscopic/Atoll?style=social" alt="GitHub forks"/>
  </a>
  <a href="https://github.com/Ebullioscopic/Atoll/releases">
    <img src="https://img.shields.io/github/downloads/Ebullioscopic/Atoll/total?label=Downloads" alt="GitHub downloads"/>
  </a>
  <a href="https://discord.gg/PaqFkRTDF8">
    <img src="https://img.shields.io/discord/1429481472942669896?label=Discord&logo=discord&color=7289da" alt="Discord server"/>
  </a>
</p>

<p align="center">
  <a href="https://github.com/sponsors/Ebullioscopic">
    <img src="https://img.shields.io/badge/Sponsor-Ebullioscopic-ff69b4?style=for-the-badge&logo=github" alt="Sponsor Ebullioscopic"/>
  </a>
  <a href="https://github.com/Ebullioscopic/Atoll/releases/download/v1.0.2-beta/Atoll.dmg">
    <img src="https://img.shields.io/badge/Download-Atoll%20for%20macOS-0A84FF?style=for-the-badge&logo=apple" alt="Download Atoll for macOS"/>
  </a>
  <a href="https://www.buymeacoffee.com/kryoscopic">
    <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-kryoscopic-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=000000" alt="Buy Me a Coffee for kryoscopic"/>
  </a>
</p>

<p align="center">
  <a href="https://discord.gg/PaqFkRTDF8">Join our Discord community</a>
</p>

**Project rename:** DynamicIsland is now called **Atoll**. Visit the new repository at [github.com/Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll).

# Atoll

Atoll turns the MacBook notch into a focused command surface for media, system insight, and quick utilities. It stays out of the way until needed, then expands with responsive, native SwiftUI animations.

## UI Modes

### Minimalistic Mode
- Compact layout focused on core actions and quick glance info.
- Ideal when you want media and essentials without wider panels.

<p align="center">
  <img src=".github/assets/Minimalistic-v1.2.gif" alt="Minimalistic UI" width="520">
</p>

### Standard Mode
- Full-width experience with richer layouts, panels, and context.
- Best for deep control of media, stats, and productivity tools.

<p align="center">
  <img src=".github/assets/Non-minimalistic-v1.2.gif" alt="Standard UI" width="520">
</p>

## Calendar & Reminders
- Clean calendar panel with upcoming events and reminders.
- Efficient EventKit usage to minimise refreshes and background churn.
- Clear timeline of upcoming items; grants only when you approve Calendar access.

<p align="center">
  <img src=".github/assets/Calendar-v1.2.gif" alt="Calendar and reminders" width="520">
</p>

## Timers
- Named timers with live activity state, clear progress, and alerts.
- Choose circular ring or linear bar; pick tints that match your setup.
- Controls live both in the notch and via menu bar for quick access.

<p align="center">
  <img src=".github/assets/Timer-v1.2.gif" alt="Timers" width="520">
</p>

## Do Not Disturb
- One-tap Focus toggle with immediate visual feedback near the notch.
- See current status at a glance without digging through menus.

<p align="center">
  <img src=".github/assets/DND-v1.2.gif" alt="Do Not Disturb" width="520">
</p>

## Lock Screen Widgets
- Media playback controls with artwork and transport.
- Active timer progress with visual feedback.
- Device charging status and battery levels.
- Connected Bluetooth devices and their battery states.
- Current weather conditions and forecast.

<p align="center">
  <img src=".github/assets/lockscreen-v1.2.gif" alt="Do Not Disturb" width="520">
</p>

## Live Activities

- Media Playback
- Focus Mode
- Screen Recording
- Microphone, Camera Privacy Indicators
- Download progress `beta`
- Low Battery status, Charging

## Overview
- Media controls for Apple Music, Spotify, and more with inline previews.
- Live system insight (CPU, GPU, memory, network, disk) with lightweight graphs.
- Productivity tools: clipboard history, colour picker, timers, calendar.
- Optional minimalistic layout for a compact 420px notch footprint.

## Features
- Media: artwork and transport controls, inline sneak-peek, adaptive lighting that subtly echoes album colours.
- System: lightweight CPU/GPU/memory/network/disk graphs; drill into quick popovers when you need details.
- Productivity: rich timers with live activity, precise colour picker with formats, and a searchable clipboard history.
- Calendar: streamlined agenda with snapshot-driven updates to keep EventKit usage lean.
- Lock Screen: weather, media, charging, and Bluetooth battery widgets that respect system accessory styles.
- Customisation: minimalistic/standard layouts, animation styles, hover behaviour, and full shortcut remapping.

## Requirements
- macOS 14.0 or later (optimised for macOS 15+).
- MacBook with a notch (14/16‑inch MBP across Apple silicon generations).
- Xcode 15+ to build from source.
- Permissions as needed: Accessibility, Camera, Calendar, Screen Recording, Music.

## Installation
1) Clone and open the project
```bash
git clone https://github.com/Ebullioscopic/Atoll.git
cd Atoll
open DynamicIsland.xcodeproj
```
2) Select your Mac as the run destination, then build and run (⌘R).
3) Grant prompted permissions. The menu bar icon appears and the notch activates on hover.

## Quick Start
- Hover near the notch to expand; click to enter controls.
- Use tabs for Media, Stats, Timers, Clipboard, and more.
- Toggle Minimalistic Mode from Settings for a smaller layout.

## Settings
- Choose appearance, animation style, and per‑feature toggles.
- Remap global shortcuts and adjust hover behaviour.
- Enable lock screen widgets and select data sources.

## Troubleshooting (Basics)
- After granting Accessibility or Screen Recording, quit and relaunch the app.
- If metrics are empty, enable categories in Settings → Stats.
- Media not responding: verify player is active and Music permission is granted.

## License
Atoll is released under the GPL v3 License. Refer to [LICENSE](LICENSE) for the full terms.

## Acknowledgments

Atoll builds upon the work of several open-source projects and draws inspiration from innovative macOS applications:

- [**Boring.Notch**](https://github.com/TheBoredTeam/boring.notch) - foundational codebase that provided the initial media player integration, AirDrop surface implementation, file dock functionality, and calendar event display. Major architectural patterns and notch interaction models were adapted from this project.

- [**Alcove**](https://tryalcove.com) - primary inspiration for the Minimalistic Mode interface design and the conceptual framework for lock screen widget integration that informed Atoll's compact layout strategy.

- [**Stats**](https://github.com/exelban/stats) - source implementation for CPU temperature monitoring via SMC (System Management Controller) access, frequency sampling through IOReport bindings, and per-core CPU utilisation tracking. The system metrics collection architecture derives from Stats project readers.

- [**Open Meteo**](https://open-meteo.com) - weather apis for the lock screen widgets

## Contributors

<a href="https://github.com/Ebullioscopic/Atoll/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Ebullioscopic/Atoll" />
</a>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Ebullioscopic/Atoll&type=timeline&legend=top-left)](https://www.star-history.com/#Ebullioscopic/Atoll&type=timeline&legend=top-left)

## Updating Existing Clones
If you previously cloned DynamicIsland, update the remote to track the Atoll repository:

```bash
git remote set-url origin https://github.com/Ebullioscopic/Atoll.git
```

A heartfelt thanks to [TheBoredTeam](https://github.com/TheBoredTeam) for being supportive and being totally awesome, Atoll would not have been possible without Boring.Notch

---

<p align="center">
  <img src=".github/assets/iosdevcentre.jpeg" alt="iOS Development Centre exterior" width="420">
  <br>
  <sub>Backed by</sub>
  <br>
  <strong>iOS Development Centre</strong>
  <br>
  Powered by Apple and Infosys
  <br>
  SRM Institute of Science and Technology, Chennai, India
</p>