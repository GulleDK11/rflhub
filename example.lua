--[[
	GulleUI — example hub (all controls + key flow).

	Entry: UI:CreateWindowAfterKey — Junkie key gate (jnkie.com); set Junkie.Service / Identifier / Provider from your dashboard.
	To try the builtin whitelist instead: KeySystem = "builtin", Keys = { "demo" }, remove or comment Junkie.
	Alternative without key UI: UI:OpenAfterValidate({ Validate = function() return true end, Window = ..., Build = ... })

	Local file: comment out HttpGet and use readfile (executor).
]]

-- local Library = loadstring(readfile("GulleUILibrary.lua"))()
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GulleDK11/rflhub/refs/heads/main/GulleUILibrary"))()

-- Optional: only these PlaceIds may open the UI (hub/key). Omit = no check.
-- local UI = Library:Init({ AllowedPlaceIds = { 1234567890, game.PlaceId } })
local UI = Library:Init()

UI:CreateWindowAfterKey({
	KeySystem = "junkie",
	Junkie = {
		Service = "YOUR_SERVICE", -- dashboard → service name
		Identifier = "12345", -- dashboard → user ID
		Provider = "Mixed", -- your provider name
		-- If Junkie shows "No script key provided" before the key field, enable ONE of:
		-- Keyless = true,
		-- BootstrapScriptKey = "paste_script_key_from_dashboard",
		LibraryURL = "https://jnkie.com/sdk/library.lua",
		UseGetKeyLink = true,
	},
	-- Builtin demo (only if KeySystem = "builtin"): Keys = { "demo" },
	Title = "Key system",
	Description = "Enter your Junkie key to continue.",
	OnSuccess = function(key)
		print("[GulleUI] Key OK:", key)
	end,
	OnCancel = function()
		warn("[GulleUI] Key screen closed.")
	end,
	Window = {
		Name = "Gulle Test Hub",
		Subtitle = "Age Of Titans",
		LoadingTitle = "Gulle Test Hub",
		LoadingSubtitle = "Loading…",
		ToggleUIKeybind = Enum.KeyCode.RightShift,
		ConfigurationSaving = {
			Enabled = true,
			FolderName = "",
			FileName = tostring(game.PlaceId),
		},
		Logo = "rbxassetid://74523675899900",
		LogoPosition = "Loading",
		-- Mobile: after hiding the hub (−/×), a small top-center logo chip appears on touch devices; tap to reopen. PC uses keybind only unless:
		MobileOpenButtonTouchOnly = true,
		MobileOpenButton = true,
		-- MobileOpenButton = false, -- disable the chip entirely
		-- MobileOpenButtonSize = 44, -- px side length (clamped 36–56); corner radius from Theme.Tokens.Window.MobileOpenButtonCorner
		MobileOpenButtonImage = "rbxassetid://74523675899900", -- optional; overrides Logo for the chip only
		-- Larger logo on loading: `Theme = { Tokens = { Window = { LogoLoadingSize = 120 } } }`
--		Theme = Library.BlockyTheme,
	},
	Build = function(Window)
-- Tabs
local TabMain = Window:CreateTab({ Name = "Main", Icon = "rbxassetid://74523675899900" })
local TabVisuals = Window:CreateTab({ Name = "Visuals", Icon = "rbxassetid://74523675899900" })
local TabConfig = Window:CreateTab({ Name = "Config", Icon = "rbxassetid://74523675899900" })

-- === Main: 2 columns × 2 sections (CreateSectionBundle) + divider in one section ===
local MainGrid = TabMain:CreateSectionBundle({
	Left = {
		{ Name = "Core", Description = "Label, toggle, button — divider separates rows in the same section." },
		{ Name = "Movement", Description = "Slider and dropdown in their own section under Core." },
	},
	Right = {
		{ Name = "Input", Description = "Text fields in their own block." },
		{ Name = "Style & info", Description = "Color picker, keybind, and paragraph." },
	},
})
local SecCore = MainGrid.Left[1]
local SecMove = MainGrid.Left[2]
local SecIn = MainGrid.Right[1]
local SecStyle = MainGrid.Right[2]

SecCore:CreateLabel({ Text = "Labels are for short headings inside a section." })

SecCore:CreateToggle({
	Name = "God Mode",
	Default = false,
	Flag = "god_mode",
	Callback = function(v)
		print("[Toggle] God Mode:", v)
	end,
})

SecCore:CreateDivider({})

SecCore:CreateButton({
	Name = "Ping (Notify)",
	Callback = function()
		Window:Notify({ Title = "Button", Content = "Notify works.", Duration = 3 })
	end,
})

SecMove:CreateSlider({
	Name = "Walk speed",
	Min = 16,
	Max = 100,
	Default = 16,
	Flag = "walk_speed",
	Increment = 1,
	Callback = function(v)
		print("[Slider]", v)
	end,
})

SecMove:CreateDropdown({
	Name = "Mode",
	Options = { "Legit", "Rage", "Safe" },
	Default = "Legit",
	Flag = "mode_dd",
	Callback = function(v)
		print("[Dropdown]", v)
	end,
})

SecIn:CreateInput({
	Name = "Config name",
	Default = "my_config",
	Placeholder = "Type here…",
	Flag = "cfg_name",
	Callback = function(t)
		print("[Input]", t)
	end,
})

SecIn:CreateInput({
	Name = "Live text",
	Placeholder = "TextChanged",
	Flag = "live_txt",
	Trigger = "TextChanged",
	Callback = function(t)
		print("[Input TC]", t)
	end,
})

SecStyle:CreateColorPicker({
	Name = "Accent test",
	Default = Color3.fromRGB(59, 130, 246),
	Flag = "pick_col",
	Callback = function(c)
		print("[Color]", c)
	end,
})

SecStyle:CreateKeybind({
	Name = "Panic key",
	Default = Enum.KeyCode.P,
	Flag = "panic_kb",
	Callback = function(k)
		print("[Keybind]", k)
	end,
})

SecStyle:CreateParagraph({
	Content = "Paragraph: longer description. Four sections (2 left, 2 right) — use CreateDivider inside a section when you want to split rows.",
})

-- === Visuals: rolibwaita-style New* (split columns) ===
local SecVis = TabVisuals:CreateSection({ Name = "Visuals", Description = "Left: New* aliases." })

SecVis:NewToggle({
	Name = "ESP",
	CurrentState = false,
	Flag = "esp_on",
	Callback = function(v)
		print("[NewToggle] ESP", v)
	end,
})

SecVis:NewSlider({
	Name = "ESP Distance",
	MinMax = { "50", "500" },
	Increment = 10,
	CurrentValue = 100,
	Flag = "esp_dist",
	Callback = function(v)
		print("[NewSlider]", v)
	end,
})

SecVis:NewDropdown({
	Name = "Box type",
	Choices = { "Corner", "Full", "None" },
	CurrentState = "Corner",
	Flag = "esp_box",
	Callback = function(v)
		print("[NewDropdown]", v)
	end,
})

local SecVisRight = TabVisuals:NewSection({
	Name = "Actions",
	Description = "Right column.",
	Column = "Right",
})

SecVisRight:NewTextBox({
	Name = "Filter",
	PlaceholderText = "Player name…",
	Text = "",
	Trigger = "FocusLost",
	Callback = function(t)
		print("[NewTextBox]", t)
	end,
})

SecVisRight:NewButton({
	Name = "Notify — normal (accent)",
	Callback = function()
		Window:Notify({ Title = "Normal", Message = "No Type → grey card; title only uses accent color.", Duration = 3 })
	end,
})
SecVisRight:NewButton({
	Name = "Notify — info",
	Callback = function()
		Window:Notify({ Title = "Info", Message = "Type info → blue title (theme Info).", Duration = 3, Type = "info" })
	end,
})
SecVisRight:NewButton({
	Name = "Notify — warning",
	Callback = function()
		Window:Notify({
			Title = "Warning",
			Message = "Type warning → yellow title.",
			Duration = 3,
			Type = "warning",
		})
	end,
})
SecVisRight:NewButton({
	Name = "Notify — error",
	Callback = function()
		Window:Notify({ Title = "Error", Message = "Type error → red title.", Duration = 3, Type = "error" })
	end,
})
SecVisRight:NewButton({
	Name = "Notify — success",
	Callback = function()
		Window:Notify({
			Title = "Success",
			Message = "Type success → green title.",
			Duration = 3,
			Type = "success",
		})
	end,
})

-- === Config ===
local SecCfg = TabConfig:CreateSection({ Name = "Configuration", Description = "Left: save/load." })

SecCfg:CreateButton({
	Name = "Save (to executor folder)",
	Callback = function()
		local ok = Window:SaveConfiguration()
		Window:Notify({
			Title = "Config",
			Message = ok and ("Saved as " .. tostring(game.PlaceId) .. ".json in the executor folder.") or "Could not save (writefile?).",
			Duration = 3,
			Type = ok and "success" or "error",
		})
	end,
})

SecCfg:CreateButton({
	Name = "Load (from executor folder)",
	Callback = function()
		local ok = Window:LoadConfiguration()
		Window:Notify({
			Title = "Config",
			Message = ok and "Loaded from the executor folder." or "No file or readfile failed.",
			Duration = 3,
			Type = ok and "success" or "error",
		})
	end,
})

SecCfg:CreateButton({
	Name = "Kill script (close UI)",
	Callback = function()
		pcall(function()
			Window:Destroy()
		end)
		pcall(function()
			local s = script
			if s and s.Destroy then
				s:Destroy()
			end
		end)
	end,
})

local SecCfgRight = TabConfig:CreateSection({ Name = "Demo", Column = "Right" })

SecCfgRight:CreateToggle({
	Name = "Demo flag (SetFlag)",
	Default = false,
	Flag = "demo_lib_flag",
	Callback = function(v)
		UI:SetFlag("demo_lib_flag", v)
		print("GetFlag:", UI:GetFlag("demo_lib_flag"))
	end,
})

print("GulleUI example hub opened — RightShift toggles UI. Footer: @", game.Players.LocalPlayer.Name)
	end,
})
