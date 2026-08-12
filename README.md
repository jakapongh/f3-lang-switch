# F3 Lang Switch

Menu bar app that remaps the **Mission Control key** (keyboard F3, no Fn) to toggle **ABC ↔ Thai**.

## Features

- Settings window on launch that explains the app
- Menu bar **F3** icon
- **Enabled** toggle (on by default) — in window and menu bar
- **Open at Login** — in window and menu bar
- **Hide Tray Icon** (window only)
- **Open Settings…** in the menu bar menu
- Prompts for Accessibility when needed
- Dock icon visible only while the settings window is open

## Build & install

```bash
./build.sh
open "$HOME/Applications/F3 Lang Switch.app"
```

## First run

1. Open the app
2. If prompted, allow **Accessibility**
3. Leave **Enabled** checked
4. Optionally enable **Open at Login**

Press F3 (Mission Control key) to switch languages.
