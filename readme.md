# GulleUI Library

Single-file Roblox UI built from Instances only. Default look: dark charcoal surfaces, orange accent, soft corners, pill toggles. Optional **blocky** preset: `Theme = Library.BlockyTheme`. String theme names (e.g. `"Ocean"`) are ignored — pass a **table** for `Theme`.

---

## Documentation

### Booting the library

Put this at the top of your script (replace the URL with your raw host or use `readfile` locally).

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GulleDK11/rflhub/refs/heads/main/GulleUILibrary"))()
local UI = Library:Init({
	-- AllowedPlaceIds = { game.PlaceId }, -- optional: only these PlaceIds may open the UI; else notify + error + destroy
})
```

### Init options

- **`AllowedPlaceIds`** — table of numeric `PlaceId`. If the current place is not in the list, a notify runs, then `script:Destroy()` (if it exists) and `error("GulleUI: Place not allowed.", 0)`. Omit for no check.
- **`UI:IsPlaceAllowed()`** — returns whether the current place passes the same rule.

Do **not** wrap the whole loader in `pcall` if you want that error to stop execution.

---

### Create a window

```lua
local Window = UI:CreateWindow({
	Name = "My Hub", -- or Title | string, window title
	Subtitle = "Optional subtitle", -- string; use "" to hide the second line
	Theme = Library.BlockyTheme, -- optional table; strings are ignored
	ToggleUIKeybind = Enum.KeyCode.RightShift, -- or "RightShift" string; toggles ScreenGui.Enabled
	UseCoreGui = false, -- false = PlayerGui; default prefers gethui() when available
	LoadingTitle = "Loading",
	LoadingSubtitle = "Please wait…",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "GulleUI", -- executor folder; "" often means executor root
		FileName = tostring(game.PlaceId), -- .json added if missing
	},
	PrintCredits = true, -- prints a one-liner to console
	SidebarRank = "Developer", -- optional bottom sidebar rank label
	DeveloperUserIds = { 123456789 }, -- optional; treated as Developer in sidebar
	HideSidebarProfile = false, -- if true, hides avatar / name / rank strip
	Logo = "rbxassetid://7734051451", -- or number asset id; optional (alias: LogoImage)
	LogoPosition = "LeftOfTitle", -- LeftOfTitle | AboveTitle | Sidebar | Loading (alias: LogoPlacement)
	-- LogoLoadingSize / theme tokens: Theme.Tokens.Window
	-- Mobile reopen chip (see section below): MobileOpenButton, MobileOpenButtonTouchOnly, …
})
```

**Chrome:** Drag the **title bar** to move. **−** / **×** hide the UI. **Bottom-right grip** resizes (min size from tokens). **Search** filters tab names (case-insensitive substring).

**Sidebar rank:** If you set **`SidebarRank`** to a non-empty string, that text is always shown. Otherwise the label is **`Developer`** when your `UserId` is in **`DeveloperUserIds`** (merged with the library’s built-in list in the source — edit `_defaultDeveloperUserIds` in `GulleUILibrary.lua` to change defaults) or when you own the place (`CreatorType.User` + `CreatorId`). Everyone else gets **`User`**.

**Tabs** use two columns (50/50 + gap). `CreateSection` defaults to the **left** column; use `Column = "Right"` for the right column.

---

### Mobile reopen button

When the hub **`ScreenGui`** is hidden (**−**, **×**), **PC players** can use **`ToggleUIKeybind`**; **phones** often do not. GulleUI can add a **second `ScreenGui`**: a small **rounded square** with your **logo** (or text) at the **top center**, below the top safe inset — **tap** to show the hub again.

- **Touch-only by default:** The chip is created only when **`UserInputService.TouchEnabled`** is true (typical phone/tablet). Set **`MobileOpenButtonTouchOnly = false`** to also show it on desktop (e.g. Studio tests).
- **Interaction:** **`Activated`** only (simple tap) — no dragging or viewport-follow logic.
- **`Destroy()`** removes both the hub and this chip.

```lua
local Window = UI:CreateWindow({
	Name = "Hub",
	Logo = "rbxassetid://7734051451", -- reused on the chip unless you override
	MobileOpenButton = true, -- default: on (still skipped on non-touch if TouchOnly default applies)
	-- MobileOpenButtonTouchOnly = false, -- also show chip on PC without touch
	-- MobileOpenButtonImage = "rbxassetid://…", -- optional; chip only (overrides Logo)
	-- MobileOpenButtonText = "UI", -- if there is no image, this label is shown
	-- MobileOpenButtonSize = 44, -- side length in px, clamped 36–56
	-- MobileOpenButtonCorner = 10, -- corner radius px (also Theme.Tokens.Window.MobileOpenButtonCorner)
	-- MobileOpenButtonMargin = 14, -- below top inset + horizontal safety clamp
	-- MobileOpenButtonDisplayOrder = 700, -- optional Z-order vs other ScreenGuis
})
```

**Theme:** `Theme.Tokens.Window.MobileOpenButtonSize` and **`MobileOpenButtonCorner`** (defaults **44** / **10**) apply if you do not pass the matching `CreateWindow` fields.

**`NewWindow` / `OpenAfterValidate` / `CreateWindowAfterKey`:** Pass the same fields on the window options table (`Window = { … }` where applicable). `NewWindow` forwards the mobile fields into `CreateWindow`.

---

### Open after validate

`CreateWindow` runs only when access is OK (sync or async). Good for keys/API checks without building the hub first.

```lua
UI:OpenAfterValidate({
	Validate = function()
		return true -- must return true to open
	end,
	-- ValidateAsync = function(done) done(true) or done(false, "reason") end,
	Window = { Name = "Hub", ToggleUIKeybind = Enum.KeyCode.RightShift },
	Build = function(Window)
		Window:CreateTab("Main"):CreateSection("General")
	end,
	OnDenied = function(err) end, -- optional
	PrintCredits = true,
})
```

---

### Create window after key

Shows a separate key `ScreenGui` first; `CreateWindow` runs only after a valid key. Not part of `CreateWindow` options.

```lua
local KeyUI = UI:CreateWindowAfterKey({
	Keys = { "demo" }, -- whitelist; or Key = "single"
	CaseInsensitive = true,
	AllowAny = false, -- if true and no Keys/Key, any non-empty string passes
	-- KeyValidate = function(key) return true end,
	-- KeyValidateAsync = function(key, done) done(true) end,
	Title = "Key required",
	Description = "Enter your key.",
	Placeholder = "Key",
	Window = { Name = "Hub" },
	Build = function(Window)
		Window:CreateTab("Main"):CreateSection("General")
	end,
	OnSuccess = function(key) end,
	OnCancel = function() end, -- close button
	OnFail = function(key) end, -- optional; sync invalid key (after wrong key message)
	-- KeyTheme = { Colors = {}, Tokens = {} },
})
-- KeyUI.Destroy()  -- optional manual teardown
-- KeyUI.Screen     -- ScreenGui
```

---

### Create a tab

```lua
local Tab = Window:CreateTab({
	Name = "Combat", -- string, required (or shorthand: CreateTab("Combat"))
	Icon = "rbxassetid://123", -- optional sidebar icon
})
```

---

### Create a section

```lua
local Section = Tab:CreateSection({
	Name = "General", -- string, required (or shorthand: CreateSection("General"))
	Description = "Optional blurb under the title",
	Column = "Right", -- optional: "Right" | "R" | 2 for right column; default left
})
```

---

### Create a section bundle

Multiple sections per column in one call. Returns `{ Left = { Section, … }, Right = { … } }`.

```lua
local G = Tab:CreateSectionBundle({
	Left = {
		{ Name = "Core", Description = "…" },
		{ Name = "Movement", Description = "…" },
	},
	Right = {
		{ Name = "Input" },
		{ Name = "Style" },
	},
})
local SecCore = G.Left[1]
```

---

### Create a button

```lua
local Button = Section:CreateButton({
	Name = "Run", -- string, required
	Callback = function()
		print("clicked")
	end,
})
-- Button:Remove()
```

---

### Create a toggle

```lua
local Toggle = Section:CreateToggle({
	Name = "ESP", -- string, required
	Default = false, -- optional initial value
	Flag = "esp", -- optional; ties to save/config + StateService
	Callback = function(on) end,
})
```

**`NewToggle`** alias: maps `CurrentState` → `Default`.

---

### Create a slider

```lua
local Slider = Section:CreateSlider({
	Name = "Distance", -- string, required
	Min = 0,
	Max = 500,
	Default = 100,
	Increment = 5, -- optional snap
	Flag = "dist", -- optional
	Callback = function(value) end,
})
```

**`NewSlider`:** uses `MinMax = { "0", "100" }`, `CurrentValue`, `Increment`.

---

### Create a dropdown

```lua
local Dropdown = Section:CreateDropdown({
	Name = "Mode", -- string, required
	Options = { "A", "B", "C" }, -- table, required
	Default = "A", -- optional
	Flag = "mode", -- optional
	Callback = function(choice) end,
})
-- Dropdown:Set(value), Dropdown:Get(), Dropdown:Refresh({ new options }), Dropdown:Remove()
```

**`NewDropdown`:** uses `Choices` instead of `Options`, `CurrentState` instead of `Default`.

---

### Create a text box (input)

```lua
local Input = Section:CreateInput({
	Name = "Username", -- string, required
	Default = "", -- initial text
	Placeholder = "Type here…",
	Flag = "user", -- optional
	Trigger = "FocusLost", -- or "TextChanged"
	Callback = function(text) end,
})
local t = Input:Get()
Input:Set("new text")
```

**`NewTextBox`:** maps `PlaceholderText`, `Text`, same triggers.

---

### Create a color picker

```lua
Section:CreateColorPicker({
	Name = "Accent",
	Default = Color3.fromRGB(255, 128, 64),
	Flag = "color",
	Callback = function(color) end,
})
```

---

### Create a keybind

```lua
Section:CreateKeybind({
	Name = "Toggle",
	Default = Enum.KeyCode.Q,
	Flag = "bind",
	Callback = function(key) end,
})
```

---

### Create a label

```lua
Section:CreateLabel({ Text = "Helper text" })
```

---

### Create a paragraph

```lua
Section:CreateParagraph({ Text = "Longer wrapped description." })
-- Content = "…" -- same as Text
```

---

### Create a divider

Horizontal line with extra vertical spacing (`Theme.Tokens.Section.DividerMarginY` by default).

```lua
Section:CreateDivider({})
Section:CreateDivider({ MarginY = 14, Thickness = 1, Transparency = 0.35 })
```

---

### Notify

```lua
Window:Notify({
	Title = "Saved",
	Message = "Configuration written.", -- or Content = "…" (same field)
	Duration = 3, -- seconds
	Type = "success", -- omit or "normal" | "info" | "warning" | "error" | "success" (also Level / Variant / NotifyType)
})
UI:Notify({ ... }) -- same, after Init
```

Neutral grey card; **title** color follows type (`Info` is blue in default theme). See `Theme.Tokens.Notification` for corner radius, frame stroke, fade durations.

---

### Remove an element

**`Element:Remove()`** works on controls (button, toggle, section, etc.).

---

### Global theme

```lua
UI:ModifyTheme({
	Colors = { Accent = Color3.fromRGB(200, 100, 40), Info = Color3.fromRGB(100, 180, 255) },
	Tokens = { Animation = { WindowOpenDuration = 0.25 } },
})
```

Only **tables** apply. String arguments are ignored (no preset names).

---

### Animation & layout tokens (reference)

Set under `Theme.Tokens` (global) or per-window `Theme = { Tokens = { … } }`.

**`Animation`** (highlights):

| Token | Role |
|--------|------|
| `WindowOpenDuration` | Hub fade + scale pop |
| `WindowOpenScaleStart` | UIScale start; `1` = no pop |
| `LoadingBarDuration` / `LoadingScreenMinDuration` / `LoadingFadeOutDuration` | Loading overlay timing |
| `WindowContentFadeIn` | Hub CanvasGroup fade |
| `WindowCanvasDetachAfterOpen` | Default `true`: move hub out of CanvasGroup after load for **sharp** UI when resizing; `false` keeps blur-prone CanvasGroup + close fade |
| `KeyGateOpenDuration` / `KeyGateCloseDuration` / … | Key screen |
| `TabButtonTweenDuration` / `TabContentFadeInDuration` / `TabContentFadeIn` | Sidebar + tab content |

**`Notification`:** `CornerRadius`, `FrameStrokeThickness`, `FrameStrokeTransparency`, `FadeInDuration`, `FadeOutDuration`.

**`Control`:** `DropdownRowOpen`, `DropdownListPadding`, `InnerStackPadding`, etc.

**`Section`:** `RowSpacing`, `DividerMarginY`, `RowPaddingY`, …

**`Tab`:** `ColumnGap`, `SidebarWidth`, …

**`Window` (extra):** `MobileOpenButtonSize`, `MobileOpenButtonCorner` — defaults for the mobile reopen chip (overridable per window with `CreateWindow` fields).

CanvasGroup fades need a supported engine; without it, those steps are skipped (tab button tweens still run).

---

### Blocky preset

```lua
UI:CreateWindow({
	Name = "Hub",
	Theme = Library.BlockyTheme, -- square corners, no pill toggles, stronger row strokes
})
```

---

### Technical notes

- Each tab’s scroll area uses a single **`PageContent`** child + padding so **`AutomaticCanvasSize`** works.
- Section controls parent to the section **rows frame**, not directly to `UIListLayout` (parenting rows to the layout breaks layout).

---

Inspired by the readable layout style of [rolibwaita](https://codeberg.org/Blukez/rolibwaita/src/branch/master/README.md) (section + commented examples).
