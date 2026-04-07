# GulleUI V2

Modern Roblox UI library focused on compact layouts, theme presets, key gating, and configuration persistence.

## Quick Start

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GulleDK11/rflhub/refs/heads/main/GulleUILibraryV2"))()
local UI = Library:Init()

local Window = UI:CreateWindow({
	Name = "My Hub",
	Subtitle = "V2",
	Theme = Library.V2ModernTheme, -- V2ModernTheme | V2SlateTheme | V2EmberTheme | V2BlockyTheme
	ToggleUIKeybind = Enum.KeyCode.RightShift,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "GulleUIV2",
		FileName = tostring(game.PlaceId),
	},
})
```

## Theme Presets

- `Library.V2ModernTheme`
- `Library.V2SlateTheme`
- `Library.V2EmberTheme`
- `Library.V2BlockyTheme`

Switch at runtime:

```lua
Window:ModifyTheme(Library.V2SlateTheme)
```

## Key Systems (Builtin + Junkie)

Use `CreateWindowAfterKey` to show key UI first and only build the hub after validation.

### Builtin

```lua
UI:CreateWindowAfterKey({
	KeySystem = "builtin",
	Key = "demo",
	Title = "Key required",
	Description = "Enter your key.",
	Window = {
		Name = "My Hub",
		Theme = Library.V2ModernTheme,
	},
	Build = function(Window)
		local Tab = Window:CreateTab({ Name = "Main", Icon = "rbxassetid://74523675899900" })
		Tab:CreateSection("General")
	end,
})
```

### Junkie

```lua
UI:CreateWindowAfterKey({
	KeySystem = "junkie",
	Junkie = {
		Service = "YOUR_SERVICE",
		Identifier = "12345",
		Provider = "Mixed",
	},
	Window = {
		Name = "My Hub",
		Theme = Library.V2ModernTheme,
	},
})
```

Notes:
- `KeySystem = "builtin" | "junkie" | "auto"`
- Supports `SaveKey`, `AutoUseSavedKey`, and `DeferWindowOpen`
- Key UI inherits `Window.Theme` accent/colors in V2

## Common Controls

```lua
local Tab = Window:CreateTab({ Name = "Aim", Icon = "rbxassetid://74523675899900" })
local Sections = Tab:CreateSectionBundle({
	Left = { { Name = "Main" } },
	Right = { { Name = "Settings" } },
})

Sections.Left[1]:CreateToggle({ Name = "Enabled", Default = false, Flag = "aim_enabled" })
Sections.Left[1]:CreateCircleToggle({ Name = "Visible Check", Default = true, Flag = "aim_vis" })
Sections.Left[1]:CreateSlider({ Name = "FOV", Min = 10, Max = 360, Default = 120, Increment = 1, Flag = "aim_fov" })
Sections.Left[1]:CreateDropdown({ Name = "Hit Part", Options = { "Head", "Torso" }, Default = "Head", Flag = "aim_part" })
Sections.Right[1]:CreateColorPicker({ Name = "FOV Color", Default = Color3.fromRGB(80, 150, 255), Flag = "fov_color" })
```

Slider value chip supports typing numbers directly (click value, type, press Enter/focus out).

## Notifications

```lua
Window:Notify({ Title = "Saved", Message = "Config saved.", Duration = 2.5, Type = "success" })
Window:Notify({ Title = "Warning", Message = "Check settings.", Duration = 2.5, Type = "warning" })
```

- Notifications render in an independent `ScreenGui`
- They stay visible even when the main UI is hidden/toggled
- In V2, type coloring is applied to title and tone-dot

## Examples

- Executor example: `ExampleV2.lua`
- Studio LocalScript example: `ExampleV2_Studio.lua`

