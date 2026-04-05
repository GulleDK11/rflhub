--[[
	GulleUI — Single-file Roblox executor UI library
	Built from Instances only. No external UI libs.
]]

local Library = {}
local Core = {}
local Elements = {}
local Services = {}
local Utils = {}

-- #region Services bootstrap
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local function getGuiParent()
	if gethui and type(gethui) == "function" then
		return gethui()
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end
-- #endregion

-- #region Utils
function Utils.Clamp(n, min, max)
	return math.max(min, math.min(max, n))
end

function Utils.DeepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = Utils.DeepCopy(v)
	end
	return c
end

function Utils.Create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Children" then
			if type(k) == "string" and k:sub(1, 1) == "_" then
				-- skip internal
			else
				inst[k] = v
			end
		end
	end
	for _, ch in ipairs(children or props and props.Children or {}) do
		ch.Parent = inst
	end
	return inst
end

function Utils.Tween(inst, ti, props)
	local t = TweenService:Create(inst, ti, props)
	t:Play()
	return t
end

function Utils.Ripple(button, color, duration)
	local abs = button.AbsoluteSize
	local circle = Utils.Create("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = button.ZIndex + 1,
		Parent = button,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = circle })
	Utils.Tween(circle, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(math.max(abs.X, abs.Y) * 2, math.max(abs.X, abs.Y) * 2),
		BackgroundTransparency = 1,
	})
	task.delay(duration or 0.35, function()
		if circle then
			circle:Destroy()
		end
	end)
end
-- #endregion

-- #region StateService
Services.StateService = {
	Flags = {},
	_listeners = {},
}

function Services.StateService:SetFlag(flag, value)
	if not flag or flag == "" then
		return
	end
	local old = self.Flags[flag]
	self.Flags[flag] = value
	if old ~= value then
		local L = self._listeners[flag]
		if L then
			for _, fn in ipairs(L) do
				task.spawn(fn, value, old)
			end
		end
	end
end

function Services.StateService:GetFlag(flag)
	return self.Flags[flag]
end

function Services.StateService:OnFlagChanged(flag, fn)
	self._listeners[flag] = self._listeners[flag] or {}
	table.insert(self._listeners[flag], fn)
end
-- #endregion

-- #region ThemeService
Services.ThemeService = {
	Current = {
		Background = Color3.fromRGB(18, 18, 22),
		Surface = Color3.fromRGB(28, 28, 34),
		SurfaceHover = Color3.fromRGB(36, 36, 44),
		Accent = Color3.fromRGB(88, 101, 242),
		AccentMuted = Color3.fromRGB(68, 78, 200),
		Text = Color3.fromRGB(240, 240, 245),
		TextDim = Color3.fromRGB(160, 160, 175),
		Border = Color3.fromRGB(45, 45, 55),
		Success = Color3.fromRGB(67, 181, 129),
		Error = Color3.fromRGB(237, 66, 69),
		Warning = Color3.fromRGB(250, 166, 26),
	},
}

function Services.ThemeService:ModifyTheme(partial)
	for k, v in pairs(partial or {}) do
		self.Current[k] = v
	end
	if self._apply then
		self._apply()
	end
end

function Services.ThemeService:RegisterApply(fn)
	self._apply = fn
end
-- #endregion

-- #region KeybindService
Services.KeybindService = {
	_connections = {},
	_bindings = {},
	_listening = nil,
}

function Services.KeybindService:Bind(id, inputEnum, callback, opts)
	opts = opts or {}
	self:Unbind(id)
	local con = UserInputService.InputBegan:Connect(function(input, gp)
		if gp and not opts.IgnoreGameProcessed then
			return
		end
		if input.KeyCode == inputEnum or input.UserInputType == inputEnum then
			if opts.Hold then
				callback(true)
			else
				callback()
			end
		end
	end)
	local con2
	if opts.Hold then
		con2 = UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == inputEnum or input.UserInputType == inputEnum then
				callback(false)
			end
		end)
	end
	self._bindings[id] = { con, con2, inputEnum = inputEnum }
end

function Services.KeybindService:Unbind(id)
	local b = self._bindings[id]
	if not b then
		return
	end
	if b[1] then
		b[1]:Disconnect()
	end
	if b[2] then
		b[2]:Disconnect()
	end
	self._bindings[id] = nil
end

function Services.KeybindService:DisconnectAll()
	for id in pairs(self._bindings) do
		self:Unbind(id)
	end
end
-- #endregion

-- #region NotificationService
Services.NotificationService = {
	_queue = {},
	_processing = false,
	_container = nil,
}

function Services.NotificationService:_ensureContainer(parent)
	if self._container and self._container.Parent then
		return
	end
	self._container = Utils.Create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		ZIndex = 200,
		Parent = parent,
	})
	local list = Utils.Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self._container,
	})
	Utils.Create("UIPadding", {
		PaddingBottom = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
		Parent = self._container,
	})
end

function Services.NotificationService:_next()
	if #self._queue == 0 then
		self._processing = false
		return
	end
	self._processing = true
	local item = table.remove(self._queue, 1)
	local theme = Services.ThemeService.Current
	local card = Utils.Create("Frame", {
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(0, 280, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self._container,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = card })
	Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.4, Parent = card })
	local pad = Utils.Create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = card,
	})
	local title = Utils.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = item.Title or "Notice",
		Parent = card,
	})
	local body = Utils.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = item.Message or "",
		Parent = card,
		LayoutOrder = 1,
	})
	card.Position = UDim2.new(1, 40, 1, 0)
	card.BackgroundTransparency = 1
	title.TextTransparency = 1
	body.TextTransparency = 1
	Utils.Tween(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 0.05,
	})
	Utils.Tween(title, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { TextTransparency = 0 })
	Utils.Tween(body, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { TextTransparency = 0 })
	task.delay(item.Duration or 3.5, function()
		if not card.Parent then
			self:_next()
			return
		end
		Utils.Tween(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 40, 1, 0),
			BackgroundTransparency = 1,
		})
		Utils.Tween(title, TweenInfo.new(0.3), { TextTransparency = 1 })
		Utils.Tween(body, TweenInfo.new(0.3), { TextTransparency = 1 })
		task.delay(0.32, function()
			card:Destroy()
			self:_next()
		end)
	end)
end

function Services.NotificationService:Notify(data)
	data = type(data) == "table" and data or { Title = "Notice", Message = tostring(data) }
	table.insert(self._queue, data)
	if not self._processing then
		self:_next()
	end
end
-- #endregion

-- #region ConfigService
Services.ConfigService = {
	Profile = "default",
	Folder = "GulleUI",
}

local function configPath(profile)
	return Services.ConfigService.Folder .. "/" .. (profile or Services.ConfigService.Profile) .. ".json"
end

function Services.ConfigService:Save(profile)
	profile = profile or self.Profile
	local ok, json = pcall(function()
		return HttpService:JSONEncode(Services.StateService.Flags)
	end)
	if not ok then
		return false
	end
	if writefile then
		pcall(function()
			if not isfolder or not isfolder(self.Folder) then
				if makefolder then
					makefolder(self.Folder)
				end
			end
			writefile(configPath(profile), json)
		end)
		return true
	end
	return false
end

function Services.ConfigService:Load(profile)
	profile = profile or self.Profile
	if not readfile or not isfile or not isfile(configPath(profile)) then
		return false
	end
	local ok, json = pcall(function()
		return readfile(configPath(profile))
	end)
	if not ok or not json then
		return false
	end
	local ok2, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok2 or type(data) ~= "table" then
		return false
	end
	for k, v in pairs(data) do
		Services.StateService:SetFlag(k, v)
	end
	return true
end

function Services.ConfigService:SetProfile(name)
	self.Profile = name or "default"
end
-- #endregion

-- #region DependencyService
Services.DependencyService = {
	_links = {},
}

function Services.DependencyService:Link(flagA, flagB, mapFn)
	self._links[flagA] = self._links[flagA] or {}
	table.insert(self._links[flagA], { other = flagB, map = mapFn })
	Services.StateService:OnFlagChanged(flagA, function(v)
		for _, L in ipairs(self._links[flagA]) do
			local nv = L.map and L.map(v) or v
			Services.StateService:SetFlag(L.other, nv)
		end
	end)
end
-- #endregion

-- #region Core internal UI builders
function Core._ApplyThemeToWindow(window)
	local theme = Services.ThemeService.Current
	if window._root then
		window._root.BackgroundColor3 = theme.Background
	end
	if window._surface then
		window._surface.BackgroundColor3 = theme.Surface
	end
	if window._title then
		window._title.TextColor3 = theme.Text
	end
	if window._accentBar then
		window._accentBar.BackgroundColor3 = theme.Accent
	end
end

function Core.CreateWindow(opts)
	opts = opts or {}
	local theme = Services.ThemeService.Current
	local screen = Utils.Create("ScreenGui", {
		Name = opts.Name or "GulleUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = getGuiParent(),
	})

	local scale = Utils.Create("UIScale", { Scale = 0.94, Parent = screen })

	local main = Utils.Create("Frame", {
		Name = "Main",
		BackgroundColor3 = theme.Background,
		Size = UDim2.fromOffset(560, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = screen,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = main })
	Utils.Create("UIStroke", {
		Color = theme.Border,
		Thickness = 1,
		Transparency = 0.35,
		Parent = main,
	})

	local accent = Utils.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = main,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = accent })

	local titleBar = Utils.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 10),
		Parent = main,
	})

	local title = Utils.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = theme.Text,
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		Text = opts.Title or "GulleUI",
		Parent = titleBar,
	})

	local lockBtn = Utils.Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = theme.Surface,
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -36, 0.5, -18),
		Parent = titleBar,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = lockBtn })
	Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.5, Parent = lockBtn })
	local lockIcon = Utils.Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = theme.TextDim,
		Text = "🔒",
		Parent = lockBtn,
	})

	local body = Utils.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -70),
		Position = UDim2.fromOffset(12, 58),
		Parent = main,
	})

	local tabList = Utils.Create("ScrollingFrame", {
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 130, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = tabList })
	Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.5, Parent = tabList })
	Utils.Create("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = tabList,
	})
	local tabLayout = Utils.Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabList,
	})

	local contentHost = Utils.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -142, 1, 0),
		Position = UDim2.fromOffset(142, 0),
		Parent = body,
	})

	local pages = Utils.Create("Folder", { Name = "Pages", Parent = contentHost })

	local loading = Utils.Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Visible = true,
		Parent = main,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = loading })
	local loadLabel = Utils.Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = theme.Text,
		Text = "Loading…",
		ZIndex = 51,
		Parent = loading,
	})

	local keyOverlay = Utils.Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 60,
		Parent = main,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = keyOverlay })
	local keyBox = Utils.Create("Frame", {
		BackgroundColor3 = theme.Surface,
		Size = UDim2.fromOffset(260, 120),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 61,
		Parent = keyOverlay,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = keyBox })
	Utils.Create("UIStroke", { Color = theme.Border, Parent = keyBox })
	local keyTitle = Utils.Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Enter key",
		ZIndex = 62,
		Parent = keyBox,
	})
	local keyInput = Utils.Create("TextBox", {
		BackgroundColor3 = theme.Background,
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -32, 0, 32),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = theme.Text,
		PlaceholderText = "Key…",
		PlaceholderColor3 = theme.TextDim,
		ClearTextOnFocus = false,
		ZIndex = 62,
		Parent = keyBox,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = keyInput })
	Utils.Create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = keyInput,
	})
	local keySubmit = Utils.Create("TextButton", {
		BackgroundColor3 = theme.Accent,
		Position = UDim2.new(0.5, -50, 1, -40),
		Size = UDim2.fromOffset(100, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Unlock",
		AutoButtonColor = false,
		ZIndex = 62,
		Parent = keyBox,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = keySubmit })

	local window = {
		_screen = screen,
		_mainFrame = main,
		_root = main,
		_surface = tabList,
		_title = title,
		_accentBar = accent,
		_tabList = tabList,
		_tabLayout = tabLayout,
		_pages = pages,
		_tabs = {},
		_activeTab = nil,
		_locked = false,
		_key = opts.Key,
		_dragConns = {},
		_destroyed = false,
	}

	function window:SetLocked(locked)
		self._locked = locked
		main.Interactable = not locked
		for _, p in ipairs(pages:GetChildren()) do
			if p:IsA("GuiObject") then
				p.Interactable = not locked
			end
		end
	end

	function window:LockUI()
		self:SetLocked(true)
		keyOverlay.Visible = true
		keyInput.Text = ""
	end

	function window:UnlockUI()
		self:SetLocked(false)
		keyOverlay.Visible = false
	end

	local function tryUnlock()
		if not window._key then
			window:UnlockUI()
			return
		end
		if keyInput.Text == window._key then
			window:UnlockUI()
			Services.NotificationService:Notify({ Title = "Unlocked", Message = "UI unlocked.", Duration = 2 })
		else
			Services.NotificationService:Notify({ Title = "Invalid", Message = "Wrong key.", Duration = 2 })
		end
	end
	keySubmit.MouseButton1Click:Connect(tryUnlock)

	lockBtn.MouseButton1Click:Connect(function()
		window:LockUI()
	end)

	-- Drag title bar
	local dragging, dragStart, startPos
	table.insert(window._dragConns, titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end))
	table.insert(window._dragConns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
	table.insert(window._dragConns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	Services.ThemeService:RegisterApply(function()
		Core._ApplyThemeToWindow(window)
	end)

	function window:Destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true
		for _, c in ipairs(self._dragConns) do
			c:Disconnect()
		end
		screen:Destroy()
	end

	function window:CreateTab(name)
		local theme = Services.ThemeService.Current
		local btn = Utils.Create("TextButton", {
			Text = name,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = theme.TextDim,
			BackgroundColor3 = theme.SurfaceHover,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			AutoButtonColor = false,
			Parent = tabList,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })

		local page = Utils.Create("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme.Accent,
			Visible = false,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = pages,
		})
		local pagePad = Utils.Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 8),
			Parent = page,
		})
		local pageList = Utils.Create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = page,
		})

		local tabObj = {
			_window = window,
			_button = btn,
			_page = page,
			_layout = pageList,
		}

		function tabObj:CreateSection(titleText)
			return Elements.CreateSection(self, titleText)
		end

		local function selectTab()
			for _, t in ipairs(window._tabs) do
				t._page.Visible = false
				Utils.Tween(t._button, TweenInfo.new(0.2), {
					BackgroundTransparency = 1,
					TextColor3 = theme.TextDim,
				})
			end
			page.Visible = true
			window._activeTab = tabObj
			Utils.Tween(btn, TweenInfo.new(0.2), {
				BackgroundTransparency = 0,
				TextColor3 = theme.Text,
			})
			btn.BackgroundColor3 = theme.SurfaceHover
		end

		btn.MouseButton1Click:Connect(function()
			selectTab()
		end)

		btn.MouseEnter:Connect(function()
			if window._activeTab ~= tabObj then
				Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.5 })
			end
		end)
		btn.MouseLeave:Connect(function()
			if window._activeTab ~= tabObj then
				Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
			end
		end)

		table.insert(window._tabs, tabObj)
		if #window._tabs == 1 then
			selectTab()
		end

		return tabObj
	end

	-- Loading animation
	task.defer(function()
		Utils.Tween(scale, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 })
		task.wait(0.35)
		Utils.Tween(loading, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		Utils.Tween(loadLabel, TweenInfo.new(0.35), { TextTransparency = 1 })
		task.wait(0.4)
		loading.Visible = false
	end)

	Services.NotificationService:_ensureContainer(screen)

	if opts.Key then
		window:LockUI()
	end

	return window
end
-- #endregion

-- #region Elements
local _keybindSeq = 0

function Elements.CreateSection(tab, titleText)
	local theme = Services.ThemeService.Current
	local wrap = Utils.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = tab._page,
	})
	Utils.Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = wrap,
	})

	local header = Utils.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
		Text = string.upper(titleText or "Section"),
		LayoutOrder = 0,
		Parent = wrap,
	})

	local box = Utils.Create("Frame", {
		BackgroundColor3 = theme.Surface,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = wrap,
	})
	Utils.Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = box })
	Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.55, Parent = box })
	Utils.Create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = box,
	})
	local list = Utils.Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = box,
	})

	local section = { _box = box, _list = list, _tab = tab }

	function section:CreateToggle(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		local flag = opts.Flag
		local def = opts.Default == true
		if flag then
			Services.StateService:SetFlag(flag, Services.StateService:GetFlag(flag) ~= nil and Services.StateService:GetFlag(flag) or def)
		end
		local value = flag and Services.StateService:GetFlag(flag) or def

		local row = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			Parent = list,
		})
		local name = Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -54, 1, 0),
			Text = opts.Name or "Toggle",
			Parent = row,
		})

		local switch = Utils.Create("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(46, 24),
			Position = UDim2.new(1, -46, 0.5, -12),
			Text = "",
			AutoButtonColor = false,
			Parent = row,
		})
		local track = Utils.Create("Frame", {
			BackgroundColor3 = value and theme.Accent or theme.SurfaceHover,
			Size = UDim2.fromScale(1, 1),
			BorderSizePixel = 0,
			Parent = switch,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
		local knob = Utils.Create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(18, 18),
			Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
			BorderSizePixel = 0,
			Parent = track,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

		local function setState(v, animate)
			value = v
			if flag then
				Services.StateService:SetFlag(flag, v)
			end
			if animate then
				Utils.Tween(track, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
					BackgroundColor3 = v and theme.Accent or theme.SurfaceHover,
				})
				Utils.Tween(
					knob,
					TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{ Position = v and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }
				)
			else
				track.BackgroundColor3 = v and theme.Accent or theme.SurfaceHover
				knob.Position = v and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
			end
			if opts.Callback then
				task.spawn(opts.Callback, v)
			end
		end

		switch.MouseButton1Click:Connect(function()
			setState(not value, true)
		end)

		if flag then
			Services.StateService:OnFlagChanged(flag, function(v)
				if type(v) == "boolean" and v ~= value then
					setState(v, true)
				end
			end)
		end

		return {
			Set = function(_, v)
				setState(v, true)
			end,
			Get = function()
				return value
			end,
		}
	end

	function section:CreateButton(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		local btn = Utils.Create("TextButton", {
			BackgroundColor3 = theme.SurfaceHover,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = theme.Text,
			Text = opts.Name or "Button",
			Size = UDim2.new(1, 0, 0, 36),
			AutoButtonColor = false,
			Parent = list,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
		Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.6, Parent = btn })

		btn.MouseButton1Click:Connect(function()
			Utils.Ripple(btn, theme.Accent, 0.4)
			if opts.Callback then
				task.spawn(opts.Callback)
			end
		end)
		btn.MouseEnter:Connect(function()
			Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = theme.Accent })
		end)
		btn.MouseLeave:Connect(function()
			Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = theme.SurfaceHover })
		end)
	end

	function section:CreateSlider(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		local flag = opts.Flag
		local minv = opts.Min or 0
		local maxv = opts.Max or 100
		local def = opts.Default or minv
		if flag then
			Services.StateService:SetFlag(flag, Services.StateService:GetFlag(flag) ~= nil and Services.StateService:GetFlag(flag) or def)
		end
		local value = flag and Services.StateService:GetFlag(flag) or def
		value = Utils.Clamp(tonumber(value) or def, minv, maxv)

		local wrap = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 46),
			Parent = list,
		})
		local top = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = wrap,
		})
		Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.65, 0, 1, 0),
			Text = opts.Name or "Slider",
			Parent = top,
		})
		local valLabel = Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.35, 0, 1, 0),
			Position = UDim2.new(0.65, 0, 0, 0),
			Text = tostring(value),
			Parent = top,
		})

		local track = Utils.Create("Frame", {
			BackgroundColor3 = theme.SurfaceHover,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 8),
			BorderSizePixel = 0,
			Parent = wrap,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
		local fill = Utils.Create("Frame", {
			BackgroundColor3 = theme.Accent,
			Size = UDim2.new((value - minv) / (maxv - minv), 0, 1, 0),
			BorderSizePixel = 0,
			Parent = track,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

		local dragging = false
		local function setFromX(x)
			local rel = Utils.Clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local nv = minv + rel * (maxv - minv)
			if opts.Rounding then
				nv = math.floor(nv + 0.5)
			end
			value = Utils.Clamp(nv, minv, maxv)
			fill.Size = UDim2.new((value - minv) / (maxv - minv), 0, 1, 0)
			valLabel.Text = tostring(value)
			if flag then
				Services.StateService:SetFlag(flag, value)
			end
			if opts.Callback then
				task.spawn(opts.Callback, value)
			end
		end

		local inputBegan = track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		local inputEnded = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		local inputChanged = UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
			then
				setFromX(input.Position.X)
			end
		end)

		return {
			Set = function(_, v)
				value = Utils.Clamp(tonumber(v) or value, minv, maxv)
				fill.Size = UDim2.new((value - minv) / (maxv - minv), 0, 1, 0)
				valLabel.Text = tostring(value)
				if flag then
					Services.StateService:SetFlag(flag, value)
				end
			end,
			Get = function()
				return value
			end,
		}
	end

	function section:CreateDropdown(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		local flag = opts.Flag
		local options = opts.Options or {}
		local def = opts.Default or options[1] or ""
		if flag then
			Services.StateService:SetFlag(flag, Services.StateService:GetFlag(flag) ~= nil and Services.StateService:GetFlag(flag) or def)
		end
		local current = flag and Services.StateService:GetFlag(flag) or def

		local wrap = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = list,
		})
		Utils.Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = wrap,
		})
		Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 18),
			Text = opts.Name or "Dropdown",
			LayoutOrder = 0,
			Parent = wrap,
		})
		local openBtn = Utils.Create("TextButton", {
			BackgroundColor3 = theme.SurfaceHover,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = theme.Text,
			Text = tostring(current),
			AutoButtonColor = false,
			Parent = wrap,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = openBtn })
		Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.6, Parent = openBtn })
		Utils.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = openBtn,
		})

		local listFrame = Utils.Create("Frame", {
			BackgroundColor3 = theme.Surface,
			Size = UDim2.new(1, 0, 0, 0),
			Visible = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			ClipsDescendants = true,
			ZIndex = 5,
			LayoutOrder = 2,
			Parent = wrap,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = listFrame })
		Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.5, Parent = listFrame })
		Utils.Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			Parent = listFrame,
		})
		local optLayout = Utils.Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			Parent = listFrame,
		})

		local open = false
		local function rebuild()
			for _, c in ipairs(listFrame:GetChildren()) do
				if c:IsA("TextButton") then
					c:Destroy()
				end
			end
			for _, opt in ipairs(options) do
				local b = Utils.Create("TextButton", {
					Text = tostring(opt),
					Font = Enum.Font.Gotham,
					TextSize = 13,
					TextColor3 = theme.Text,
					BackgroundColor3 = theme.SurfaceHover,
					Size = UDim2.new(1, 0, 0, 28),
					AutoButtonColor = false,
					ZIndex = 6,
					Parent = listFrame,
				})
				Utils.Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = b })
				b.MouseButton1Click:Connect(function()
					current = opt
					openBtn.Text = tostring(current)
					if flag then
						Services.StateService:SetFlag(flag, current)
					end
					open = false
					listFrame.Visible = false
					if opts.Callback then
						task.spawn(opts.Callback, current)
					end
				end)
			end
		end
		rebuild()

		openBtn.MouseButton1Click:Connect(function()
			open = not open
			listFrame.Visible = open
			if open then
				listFrame.Size = UDim2.new(1, 0, 0, 0)
				Utils.Tween(listFrame, TweenInfo.new(0.2), { BackgroundTransparency = 0 })
			end
		end)

		return {
			Refresh = function(_, newOpts)
				options = newOpts or options
				rebuild()
			end,
			Set = function(_, v)
				current = v
				openBtn.Text = tostring(current)
				if flag then
					Services.StateService:SetFlag(flag, current)
				end
			end,
		}
	end

	function section:CreateInput(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		local flag = opts.Flag
		local def = opts.Default or ""
		if flag then
			Services.StateService:SetFlag(flag, Services.StateService:GetFlag(flag) ~= nil and Services.StateService:GetFlag(flag) or def)
		end

		local wrap = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 58),
			Parent = list,
		})
		Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 18),
			Text = opts.Name or "Input",
			Parent = wrap,
		})
		local box = Utils.Create("TextBox", {
			BackgroundColor3 = theme.Background,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 32),
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = theme.Text,
			Text = tostring(flag and Services.StateService:GetFlag(flag) or def),
			PlaceholderText = opts.Placeholder or "",
			PlaceholderColor3 = theme.TextDim,
			ClearTextOnFocus = false,
			Parent = wrap,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })
		Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.55, Parent = box })
		Utils.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = box,
		})

		box.FocusLost:Connect(function()
			local t = box.Text
			if flag then
				Services.StateService:SetFlag(flag, t)
			end
			if opts.Callback then
				task.spawn(opts.Callback, t)
			end
		end)

		if flag then
			Services.StateService:OnFlagChanged(flag, function(v)
				if tostring(v) ~= box.Text then
					box.Text = tostring(v)
				end
			end)
		end
	end

	function section:CreateColorPicker(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		local flag = opts.Flag
		local def = opts.Default or Color3.fromRGB(255, 255, 255)
		if flag then
			local existing = Services.StateService:GetFlag(flag)
			if existing == nil then
				Services.StateService:SetFlag(flag, { def.R * 255, def.G * 255, def.B * 255 })
			end
		end
		local function getColor()
			if flag then
				local c = Services.StateService:GetFlag(flag)
				if type(c) == "table" and c[1] then
					return Color3.fromRGB(c[1], c[2], c[3])
				end
			end
			return def
		end
		local col = getColor()

		local wrap = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = list,
		})
		Utils.Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = wrap,
		})
		local row = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = 0,
			Parent = wrap,
		})
		Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -40, 1, 0),
			Text = opts.Name or "Color",
			Parent = row,
		})
		local preview = Utils.Create("Frame", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, -28, 0.5, -14),
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			Parent = row,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = preview })
		Utils.Create("UIStroke", { Color = theme.Border, Parent = preview })

		local sliders = { "R", "G", "B" }
		local vals = { math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255) }

		local function push()
			local c = Color3.fromRGB(vals[1], vals[2], vals[3])
			preview.BackgroundColor3 = c
			if flag then
				Services.StateService:SetFlag(flag, { vals[1], vals[2], vals[3] })
			end
			if opts.Callback then
				task.spawn(opts.Callback, c)
			end
		end

		for i, label in ipairs(sliders) do
			local sw = Utils.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = i,
				Parent = wrap,
			})
			Utils.Create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 24, 1, 0),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = theme.TextDim,
				Text = label,
				Parent = sw,
			})
			local track = Utils.Create("Frame", {
				BackgroundColor3 = theme.SurfaceHover,
				Position = UDim2.fromOffset(28, 11),
				Size = UDim2.new(1, -28, 0, 8),
				BorderSizePixel = 0,
				Parent = sw,
			})
			Utils.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
			local fill = Utils.Create("Frame", {
				BackgroundColor3 = theme.Accent,
				Size = UDim2.new(vals[i] / 255, 0, 1, 0),
				BorderSizePixel = 0,
				Parent = track,
			})
			Utils.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
			local drag = false
			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					drag = true
					local rel = Utils.Clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					vals[i] = math.floor(rel * 255)
					fill.Size = UDim2.new(rel, 0, 1, 0)
					push()
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					drag = false
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if
					drag
					and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
				then
					local rel = Utils.Clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					vals[i] = math.floor(rel * 255)
					fill.Size = UDim2.new(rel, 0, 1, 0)
					push()
				end
			end)
		end
	end

	function section:CreateKeybind(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		local flag = opts.Flag
		local def = opts.Default or Enum.KeyCode.Unknown
		local key = def
		if flag then
			local stored = Services.StateService:GetFlag(flag)
			if stored == nil then
				Services.StateService:SetFlag(flag, tostring(def.Name))
			else
				key = Enum.KeyCode[stored] or def
			end
		end

		local row = Utils.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			Parent = list,
		})
		Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -120, 1, 0),
			Text = opts.Name or "Keybind",
			Parent = row,
		})
		local bindBtn = Utils.Create("TextButton", {
			BackgroundColor3 = theme.SurfaceHover,
			Size = UDim2.fromOffset(112, 30),
			Position = UDim2.new(1, -112, 0.5, -15),
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = theme.Text,
			Text = key.Name ~= "Unknown" and key.Name or "…",
			AutoButtonColor = false,
			Parent = row,
		})
		Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = bindBtn })
		Utils.Create("UIStroke", { Color = theme.Border, Thickness = 1, Transparency = 0.55, Parent = bindBtn })

		local bindId = "gulle_kb_" .. tostring(_keybindSeq)
		_keybindSeq = _keybindSeq + 1

		local function applyBinding()
			Services.KeybindService:Unbind(bindId)
			if opts.Callback and key and key ~= Enum.KeyCode.Unknown then
				Services.KeybindService:Bind(bindId, key, function()
					task.spawn(opts.Callback, key)
				end)
			end
		end
		applyBinding()

		local conn
		bindBtn.MouseButton1Click:Connect(function()
			bindBtn.Text = "…"
			if conn then
				conn:Disconnect()
			end
			Services.KeybindService:Unbind(bindId)
			conn = UserInputService.InputBegan:Connect(function(input, gp)
				if gp then
					return
				end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					key = input.KeyCode
					bindBtn.Text = key.Name ~= "Unknown" and key.Name or "…"
					conn:Disconnect()
					conn = nil
					if flag then
						Services.StateService:SetFlag(flag, key.Name)
					end
					applyBinding()
					if opts.Callback then
						task.spawn(opts.Callback, key)
					end
				end
			end)
		end)
	end

	function section:CreateLabel(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Text = opts.Text or opts.Name or "Label",
			Parent = list,
		})
	end

	function section:CreateParagraph(opts)
		opts = opts or {}
		local theme = Services.ThemeService.Current
		Utils.Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Text = opts.Text or opts.Content or "",
			Parent = list,
		})
	end

	return section
end
-- #endregion

-- #region Library
function Library:Init()
	return {
		CreateWindow = function(_, opts)
			return Core.CreateWindow(opts)
		end,
		Services = Services,
		Theme = Services.ThemeService,
		Config = Services.ConfigService,
		Notify = function(_, data)
			Services.NotificationService:Notify(data)
		end,
		SetFlag = function(_, f, v)
			Services.StateService:SetFlag(f, v)
		end,
		GetFlag = function(_, f)
			return Services.StateService:GetFlag(f)
		end,
	}
end

return Library

--[[
	---------------------------------------------------------------------------
	LOADSTRING (single file, no local dependencies)
	Host this file as raw on GitHub, then:

	local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO/main/GulleUILibrary.lua"))()
	local UI = Library:Init()
	local Window = UI:CreateWindow({ Title = "My UI" })
	-- ... see ExampleUsage.lua in the same repo for a full demo.
	---------------------------------------------------------------------------
]]
