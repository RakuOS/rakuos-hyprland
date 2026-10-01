# Hyprland Configuration — Quick Guide

Every file lives under `~/.config/hypr/`. The format is Lua, not KDL.

Reload after editing: `SUPER + SHIFT + R`

> **Important for existing users.** This folder is *copied* into your home when
> the account is created. If you already have an account, edit the files in your
> own home directory. Edits to `/etc/skel` only reach newly created users.

---

## Changing monitors?

**`config/variables.lua`**

```lua
MONITOR1 = "eDP-1"
MONITOR2 = "DP-1"
```

List the outputs available on your machine:

```bash
hyprctl monitors
```

Use the value from the `NAME` column. Leave it empty (`""`) if there is no second
monitor.

These variables are read by:

- `config/monitors.lua` — the output that gets configured
- `config/workspaces.lua` — workspaces 1-5 go to `MONITOR1`, 6-9 to `MONITOR2`
- `PRIMARY_MONITOR` — where launcher, Discord and `.exe` windows are opened

---

## Changing or adding default apps?

**`config/variables.lua`**

```lua
TERMINAL     = "ghostty"
FILE_MANAGER = "nautilus"
BROWSER      = "firefox"
EDITOR       = "zeditor"
CALCULATOR   = "gnome-calculator"
```

`binds.lua` reads these variables, so this is the only file you need to touch —
no need to edit the binds themselves. Session-aware launching goes through the
`launchPrefix` (`uwsm app -- `) defined in `binds.lua`.

---

## Where are the keyboard binds?

**`config/binds.lua`** — every `SUPER + ...` binding is here. `M` stands for
`SUPER`.

Example:

```lua
hl.bind(M .. " + Return", hl.dsp.exec_cmd(launchPrefix .. TERMINAL), { description = "Terminal" })
```

Shortcuts worth knowing:

| Shortcut | Action |
|---|---|
| `SUPER + Return` | Terminal |
| `SUPER + E` / `B` / `N` | File manager / Browser / Editor |
| `SUPER + Space` | App launcher |
| `SUPER + 1..9` | Switch workspace |
| `SUPER + SHIFT + 1..9` | Send window to workspace |
| `SUPER + 0` | `gaming` workspace |
| `SUPER + S` | Scratchpad |
| `SUPER + F` / `SHIFT + F` | Fullscreen / maximize |
| `SUPER + SHIFT + S` | Send window to scratchpad |
| `Print` / `SHIFT + Print` / `CTRL + Print` | Screenshot region / fullscreen / window |
| `SUPER + ALT` + click-drag | Move window (mouse:272) |
| `SUPER + SHIFT + R` | Reload config |

The scripts called by these binds live in `scripts/`:

| Script | Action |
|---|---|
| `screenshot.sh` | Screenshot, saves to `~/Pictures/Screenshots`, opens Swash |
| `ocr.sh` | OCR a region → clipboard |
| `qr.sh` | Scan a QR code → clipboard |
| `lens.sh` | Google Lens (region) — **uploads to a public host, do not use it for sensitive data** |
| `focus-dir.sh` / `swap-dir.sh` | Directional focus/swap, adapting to the active layout |
| `gamemode.sh` | Toggle decorative effects (max FPS / restore) |
| `lock-and-suspend.sh` | Lock, then suspend |

---

## Gaps, borders, blur, opacity

**`config/decorations.lua`**

```lua
gaps_in  = 5     -- spacing between windows
gaps_out = 10    -- spacing from window to screen edge
border_size = 2 -- border thickness
rounding = 12    -- corner rounding
active_opacity   = 0.9
inactive_opacity = 0.7
```

The `blur` group (`size`, `passes`) and `shadow` are in the same file. **`scale`
is not here** — that lives in `monitors.lua`.

---

## Layouts and animations

- **Layout** — `config/misc.lua`. The active layout is forced to `scrolling` on
  the last line. The `dwindle` / `master` / `swapsplit` values can be changed
  there.
- **Layout presets** — `layouts/fair.lua` (automatic grid), `layouts/deck.lua`.
  Reachable via `SUPER + ALT + W` (the Noctalia panel).
- **Animations** — `config/animations.lua`. Switch preset by changing one line:

  ```lua
  ANIMATION_PRESET = "bounce"   -- air, minimal, rage, smooth, ...
  ```

  The full list is in `config/animations_presets/`.

---

## Optional plugins (Noctalia)

Some settings are easier through a Noctalia plugin than by editing Lua. All of
them are optional — nothing here is required for a working session.

Source: <https://github.com/tofan79/mindset-noctalia-plugins>

These two are the recommended ones: between them they cover the fiddly parts of
this config — switching tiling layouts (including your own `deck.lua` and
`fair.lua`) and picking an animation preset — without hand-editing Lua.

| Plugin | API | What it does |
|---|---|---|
| `mindset/hypr-layouts` | 13 | Per-workspace tiling layout picker. Auto-detects your custom `layouts/*.lua` on top of the built-ins |
| `mindset/hypr-animations` | 13 | Animation preset picker, reads `config/animations_presets/` |

### Install

```bash
# register the source (Noctalia fetches it at startup)
noctalia msg plugins source add mindset git https://github.com/tofan79/mindset-noctalia-plugins.git

# enable what you want
noctalia msg plugins enable mindset/hypr-layouts
noctalia msg plugins enable mindset/hypr-animations
```

Verify with `noctalia msg plugins list | grep mindset`.

Edits inside a `.luau` plugin file hot-reload. Changes to the manifest
(`plugin.toml`) need a full config reload.

`hypr-layouts` is already wired to `SUPER + ALT + W` in `config/binds.lua` via
`mindset/hypr-layouts:panel`, so enabling that plugin is all it takes for that
shortcut to work. `hypr-animations` has no bind — open it from the Noctalia
plugin list.

### GloView (Mission Control-style overview)

GloView is **not installed by default** and its binds are commented out. It
needs the COPR repo and the package first:

```bash
dnf copr enable mindset/Mindset-Apps
dnf install gloview-git
```

Then uncomment exactly two things:

1. **`hyprland.lua`** — the plugin load line:

   ```lua
   hl.plugin.load("/usr/lib64/gloview.so")
   ```

2. **`config/binds.lua`** — the whole guarded block at the end of the file:

   ```lua
   if hl.plugin.gloview then
       hl.bind(M .. " + SHIFT + O", hl.plugin.gloview.toggle, { description = "Toggle overview" })
       hl.bind(M .. " + ALT + O", hl.plugin.gloview.desktop, { description = "Desktop mode" })
       hl.bind(M .. " + CTRL + O", hl.plugin.gloview.allworkspaces, { description = "All workspaces" })
   end
   ```

Those two files are the only places that reference it. Uncommenting one without
the other leaves a half-enabled state: loading the plugin with no binds does
nothing visible, and registering binds for a plugin that never loads fails.

The `if hl.plugin.gloview then` guard means the binds stay harmless if you later
remove the package — they simply register nothing.

---

## Everything else (if you need it)

| File | Contents |
|---|---|
| `config/inputs.lua` | Mouse sensitivity, touchscreen gestures, natural scroll |
| `config/windowrules.lua` | Per-app rules: float, size, opacity, auto-routing to the `gaming` workspace |
| `config/autostart.lua` | Runs on Hyprland start (`noctalia`, clipboard history) |
| `config/lid.lua` | Close the laptop lid → lock and suspend |
| `config/environment.lua` | NVIDIA environment variables (commented out). If you use UWSM, edit `~/.config/uwsm/env` instead |
| `noctalia.lua` | **Generated** — theme colors. Overwritten whenever the theme changes in Noctalia |

---

## When something breaks

Check first:

```bash
hyprctl configerrors
```

Then reload. `SUPER + SHIFT + R` is safe to use even in a broken state, since
`~/.config/hypr` can be restored from git.