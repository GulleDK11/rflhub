--[[
    ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██╗
    ██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██║
    ██████╔╝██║     ██║   ██║██║     █████╔╝ ██║   ██║██║
    ██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██║
    ██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║
    ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝

    BlockUI v1.1.0 — Modern Blocky Roblox UI Library
    Fixed: dragging, executor compat, tab rendering
--]]

local BlockUI = {}
BlockUI.Flags = {}
BlockUI._windows = {}
BlockUI._configFile = nil

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

local S = {
    bg       = Color3.fromRGB(13,  13,  15),
    surface  = Color3.fromRGB(20,  20,  24),
    surface2 = Color3.fromRGB(28,  28,  34),
    accent   = Color3.fromRGB(200, 241, 53),
    accent2  = Color3.fromRGB(91,  143, 255),
    text     = Color3.fromRGB(235, 235, 235),
    muted    = Color3.fromRGB(100, 100, 115),
    border   = Color3.fromRGB(40,  40,  50),
    danger   = Color3.fromRGB(255, 95,  87),
    warning  = Color3.fromRGB(254, 188, 46),
    success  = Color3.fromRGB(40,  200, 64),
    black    = Color3.fromRGB(10,  10,  10),
    font     = Enum.Font.Code,
    fontBody = Enum.Font.Gotham,
}

-- ── Helpers ──────────────────────────────────────────────────
local function new(cls, props, parent)
    local ok, obj = pcall(Instance.new, cls)
    if not ok then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    if parent then obj.Parent = parent end
    return obj
end

local function tw(obj, t, props)
    pcall(function()
        TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad), props):Play()
    end)
end

local function stroke(parent, color, thickness)
    local s = new("UIStroke", { Color = color or S.border, Thickness = thickness or 1 }, parent)
    pcall(function() s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
    return s
end

-- ── Draggable ─────────────────────────────────────────────────
local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ── Notification ──────────────────────────────────────────────
local notifGui = new("ScreenGui", {
    Name = "BlockUI_Notifs", ResetOnSpawn = false, DisplayOrder = 999,
}, PlayerGui)
pcall(function() notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)

local notifHolder = new("Frame", {
    Size = UDim2.new(0, 270, 1, 0),
    Position = UDim2.new(1, -285, 0, 12),
    BackgroundTransparency = 1,
}, notifGui)
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 6),
    FillDirection = Enum.FillDirection.Vertical,
}, notifHolder)

function BlockUI:Notify(cfg)
    cfg = cfg or {}
    local ntype = cfg.Type or "info"
    local dur   = cfg.Duration or 4

    local bar = ntype == "success" and S.success
             or ntype == "warning" and S.warning
             or ntype == "error"   and S.danger
             or S.accent2

    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = S.surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 20, 0, 0),
        ClipsDescendants = true,
    }, notifHolder)
    stroke(card, S.border, 1)

    new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = bar, BorderSizePixel = 0 }, card)

    new("TextLabel", {
        Size = UDim2.new(1, -14, 0, 18),
        Position = UDim2.fromOffset(11, 9),
        BackgroundTransparency = 1,
        Text = cfg.Title or "Notification",
        TextColor3 = S.text,
        Font = S.font,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)

    new("TextLabel", {
        Size = UDim2.new(1, -14, 0, 18),
        Position = UDim2.fromOffset(11, 30),
        BackgroundTransparency = 1,
        Text = cfg.Content or "",
        TextColor3 = S.muted,
        Font = S.fontBody,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)

    tw(card, 0.22, { Position = UDim2.new(0, 0, 0, 0) })

    task.delay(dur, function()
        tw(card, 0.18, { Position = UDim2.new(1, 20, 0, 0) })
        task.wait(0.2)
        card:Destroy()
    end)
end

-- ── Config ────────────────────────────────────────────────────
function BlockUI:SaveConfiguration()
    if not self._configFile then return end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self.Flags)
    if ok then pcall(writefile, self._configFile..".json", encoded) end
end

function BlockUI:LoadConfiguration()
    if not self._configFile then return end
    local ok, raw = pcall(readfile, self._configFile..".json")
    if not ok or not raw then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if self.Flags[k] ~= nil then self.Flags[k] = v end
    end
end

-- ── CreateWindow ──────────────────────────────────────────────
function BlockUI:CreateWindow(cfg)
    cfg = cfg or {}
    local winName = cfg.Name or "BlockUI"
    local winSub  = cfg.Subtitle or ""
    local saveCfg = cfg.ConfigurationSaving
    if saveCfg and saveCfg.Enabled and saveCfg.FileName then
        self._configFile = saveCfg.FileName
    end

    -- Destroy old gui if exists
    local existing = PlayerGui:FindFirstChild("BlockUI_"..winName)
    if existing then existing:Destroy() end

    local gui = new("ScreenGui", {
        Name = "BlockUI_"..winName,
        ResetOnSpawn = false,
        DisplayOrder = 100,
    }, PlayerGui)
    pcall(function() gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)

    -- Main window — NOT ClipsDescendants so dropdown works
    local main = new("Frame", {
        Size = UDim2.new(0, 430, 0, 490),
        Position = UDim2.new(0.5, -215, 0.5, -245),
        BackgroundColor3 = S.bg,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    }, gui)
    stroke(main, S.border, 1)

    -- Inner clip frame for content (prevents overflow inside window)
    local clipFrame = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, main)

    -- ── Titlebar ──────────────────────────────────────────────
    local titlebar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = S.surface,
        BorderSizePixel = 0,
    }, clipFrame)

    -- Dots
    for i, col in ipairs({S.danger, S.warning, S.success}) do
        local dot = new("Frame", {
            Size = UDim2.new(0, 10, 0, 10),
            Position = UDim2.fromOffset(10 + (i-1)*16, 16),
            BackgroundColor3 = col,
            BorderSizePixel = 0,
        }, titlebar)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    end

    -- Title
    new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = winName:upper(),
        TextColor3 = S.muted,
        Font = S.font,
        TextSize = 12,
    }, titlebar)

    -- Close btn
    local closeBtn = new("TextButton", {
        Size = UDim2.new(0, 32, 1, 0),
        Position = UDim2.new(1, -32, 0, 0),
        BackgroundTransparency = 1,
        Text = "✕",
        TextColor3 = S.muted,
        Font = S.font,
        TextSize = 13,
        BorderSizePixel = 0,
    }, titlebar)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = S.danger end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = S.muted end)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- Bottom border
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = S.border,
        BorderSizePixel = 0,
    }, titlebar)

    -- Make MAIN draggable via titlebar
    makeDraggable(main, titlebar)

    -- ── Subtitle ──────────────────────────────────────────────
    local titlebarH = 42
    if winSub ~= "" then
        local sub = new("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            Position = UDim2.fromOffset(0, 42),
            BackgroundColor3 = S.surface2,
            BorderSizePixel = 0,
        }, clipFrame)
        new("TextLabel", {
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.fromOffset(8, 0),
            BackgroundTransparency = 1,
            Text = "// "..winSub,
            TextColor3 = S.muted,
            Font = S.font,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, sub)
        new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, -1),
            BackgroundColor3 = S.border,
            BorderSizePixel = 0,
        }, sub)
        titlebarH = 66
    end

    -- ── Tab Bar ───────────────────────────────────────────────
    local tabBar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.fromOffset(0, titlebarH),
        BackgroundColor3 = S.surface2,
        BorderSizePixel = 0,
    }, clipFrame)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, tabBar)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = S.border,
        BorderSizePixel = 0,
    }, tabBar)

    local contentY = titlebarH + 36

    -- Content clip
    local contentClip = new("Frame", {
        Size = UDim2.new(1, 0, 1, -contentY),
        Position = UDim2.fromOffset(0, contentY),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, clipFrame)

    local tabs      = {}
    local tabFrames = {}
    local activeTab = nil

    local function switchToTab(name)
        for n, f in pairs(tabFrames) do f.Visible = (n == name) end
        for n, b in pairs(tabs) do
            if n == name then
                b.TextColor3 = S.accent
                local ul = b:FindFirstChild("UL")
                if ul then ul.BackgroundTransparency = 0 end
            else
                b.TextColor3 = S.muted
                local ul = b:FindFirstChild("UL")
                if ul then ul.BackgroundTransparency = 1 end
            end
        end
        activeTab = name
    end

    local Window = {}

    function Window:CreateTab(tcfg)
        tcfg = tcfg or {}
        local tabName = tcfg.Name or "Tab"

        -- Tab button — fixed width instead of AutomaticSize
        local tabW = math.max(60, #tabName * 10 + 24)
        local tbtn = new("TextButton", {
            Size = UDim2.new(0, tabW, 1, 0),
            BackgroundTransparency = 1,
            Text = tabName:upper(),
            TextColor3 = S.muted,
            Font = S.font,
            TextSize = 11,
            BorderSizePixel = 0,
        }, tabBar)

        -- Underline indicator
        new("Frame", {
            Name = "UL",
            Size = UDim2.new(1, -8, 0, 2),
            Position = UDim2.new(0, 4, 1, -2),
            BackgroundColor3 = S.accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, tbtn)

        tabs[tabName] = tbtn

        -- Scrolling content
        local tabFrame = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = S.accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
        }, contentClip)
        pcall(function()
            tabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        end)

        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),
        }, tabFrame)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 6),
            PaddingBottom = UDim.new(0, 8),
        }, tabFrame)

        tabFrames[tabName] = tabFrame

        tbtn.MouseButton1Click:Connect(function()
            switchToTab(tabName)
        end)

        if not activeTab then
            switchToTab(tabName)
        end

        -- ── Tab API ───────────────────────────────────────────
        local Tab = {}
        local order = 0
        local function no() order = order + 1; return order end

        local function rowBase(h)
            local r = new("Frame", {
                Size = UDim2.new(1, 0, 0, h),
                BackgroundColor3 = S.surface,
                BorderSizePixel = 0,
                LayoutOrder = no(),
            }, tabFrame)
            new("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 1, -1),
                BackgroundColor3 = S.border,
                BorderSizePixel = 0,
            }, r)
            return r
        end

        -- BUTTON
        function Tab:CreateButton(e)
            e = e or {}
            local row = rowBase(48)
            new("TextLabel", {
                Size = UDim2.new(1, -110, 1, 0),
                Position = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text = e.Name or "Button",
                TextColor3 = S.text,
                Font = S.fontBody,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local btn = new("TextButton", {
                Size = UDim2.new(0, 76, 0, 28),
                Position = UDim2.new(1, -90, 0.5, -14),
                BackgroundColor3 = S.surface2,
                Text = "RUN",
                TextColor3 = S.accent,
                Font = S.font,
                TextSize = 11,
                BorderSizePixel = 0,
            }, row)
            stroke(btn, S.border, 1)

            btn.MouseEnter:Connect(function()
                tw(btn, 0.1, { BackgroundColor3 = S.accent, TextColor3 = S.black })
            end)
            btn.MouseLeave:Connect(function()
                tw(btn, 0.1, { BackgroundColor3 = S.surface2, TextColor3 = S.accent })
            end)
            btn.MouseButton1Click:Connect(function()
                if e.Callback then task.spawn(e.Callback) end
            end)

            local B = {}
            function B:Set(n) btn.Text = n end
            return B
        end

        -- TOGGLE
        function Tab:CreateToggle(e)
            e = e or {}
            local flag  = e.Flag
            local value = e.CurrentValue or false
            if flag then BlockUI.Flags[flag] = value end

            local rowH = e.Description and 56 or 48
            local row  = rowBase(rowH)

            new("TextLabel", {
                Size = UDim2.new(1, -70, 0, 20),
                Position = UDim2.fromOffset(14, e.Description and 9 or 14),
                BackgroundTransparency = 1,
                Text = e.Name or "Toggle",
                TextColor3 = S.text,
                Font = S.fontBody,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            if e.Description then
                new("TextLabel", {
                    Size = UDim2.new(1, -70, 0, 14),
                    Position = UDim2.fromOffset(14, 31),
                    BackgroundTransparency = 1,
                    Text = e.Description,
                    TextColor3 = S.muted,
                    Font = S.fontBody,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, row)
            end

            local track = new("Frame", {
                Size = UDim2.new(0, 40, 0, 22),
                Position = UDim2.new(1, -54, 0.5, -11),
                BackgroundColor3 = S.surface2,
                BorderSizePixel = 0,
            }, row)
            new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
            local tStroke = stroke(track, S.border, 1)

            local thumb = new("Frame", {
                Size = UDim2.new(0, 15, 0, 15),
                Position = UDim2.fromOffset(3, 3),
                BackgroundColor3 = S.muted,
                BorderSizePixel = 0,
            }, track)
            new("UICorner", { CornerRadius = UDim.new(1, 0) }, thumb)

            local function setState(val, silent)
                value = val
                if flag then BlockUI.Flags[flag] = val end
                if val then
                    tw(track, 0.15, { BackgroundColor3 = Color3.fromRGB(35, 55, 0) })
                    tw(thumb, 0.15, { Position = UDim2.fromOffset(22, 3), BackgroundColor3 = S.accent })
                    pcall(function() tStroke.Color = S.accent end)
                else
                    tw(track, 0.15, { BackgroundColor3 = S.surface2 })
                    tw(thumb, 0.15, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = S.muted })
                    pcall(function() tStroke.Color = S.border end)
                end
                if not silent and e.Callback then task.spawn(e.Callback, val) end
            end
            setState(value, true)

            row.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    setState(not value)
                end
            end)

            local T = {}
            function T:Set(v) setState(v, false) end
            return T
        end

        -- SLIDER
        function Tab:CreateSlider(e)
            e = e or {}
            local flag   = e.Flag
            local range  = e.Range or {0, 100}
            local inc    = e.Increment or 1
            local suffix = e.Suffix or ""
            local value  = e.CurrentValue or range[1]
            if flag then BlockUI.Flags[flag] = value end

            local row = rowBase(64)

            new("TextLabel", {
                Size = UDim2.new(1, -90, 0, 20),
                Position = UDim2.fromOffset(14, 10),
                BackgroundTransparency = 1,
                Text = e.Name or "Slider",
                TextColor3 = S.text,
                Font = S.fontBody,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local valLbl = new("TextLabel", {
                Size = UDim2.new(0, 80, 0, 20),
                Position = UDim2.new(1, -94, 0, 10),
                BackgroundTransparency = 1,
                Text = tostring(value).." "..suffix,
                TextColor3 = S.accent,
                Font = S.font,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
            }, row)

            local trackBg = new("Frame", {
                Size = UDim2.new(1, -28, 0, 4),
                Position = UDim2.fromOffset(14, 46),
                BackgroundColor3 = S.surface2,
                BorderSizePixel = 0,
            }, row)
            local fill = new("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = S.accent,
                BorderSizePixel = 0,
            }, trackBg)
            local handle = new("Frame", {
                Size = UDim2.new(0, 12, 0, 12),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = S.accent,
                BorderSizePixel = 0,
            }, trackBg)

            local function setVal(v)
                v = math.clamp(math.round(v / inc) * inc, range[1], range[2])
                value = v
                if flag then BlockUI.Flags[flag] = v end
                local pct = (range[2] - range[1]) == 0 and 0
                    or (v - range[1]) / (range[2] - range[1])
                fill.Size = UDim2.new(pct, 0, 1, 0)
                handle.Position = UDim2.new(pct, 0, 0.5, 0)
                valLbl.Text = tostring(v).." "..suffix
                if e.Callback then task.spawn(e.Callback, v) end
            end
            setVal(value)

            local sliding = false
            trackBg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = true
                    local abs = trackBg.AbsolutePosition
                    local sz  = trackBg.AbsoluteSize
                    local pct = math.clamp((i.Position.X - abs.X) / sz.X, 0, 1)
                    setVal(range[1] + pct * (range[2] - range[1]))
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
                    local abs = trackBg.AbsolutePosition
                    local sz  = trackBg.AbsoluteSize
                    local pct = math.clamp((i.Position.X - abs.X) / sz.X, 0, 1)
                    setVal(range[1] + pct * (range[2] - range[1]))
                end
            end)

            local Sl = {}
            function Sl:Set(v) setVal(v) end
            return Sl
        end

        -- INPUT
        function Tab:CreateInput(e)
            e = e or {}
            local flag  = e.Flag
            local value = e.CurrentValue or ""
            if flag then BlockUI.Flags[flag] = value end

            local row = rowBase(64)

            new("TextLabel", {
                Size = UDim2.new(1, -16, 0, 16),
                Position = UDim2.fromOffset(14, 7),
                BackgroundTransparency = 1,
                Text = (e.Name or "Input"):upper(),
                TextColor3 = S.muted,
                Font = S.font,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local box = new("TextBox", {
                Size = UDim2.new(1, -28, 0, 28),
                Position = UDim2.fromOffset(14, 27),
                BackgroundColor3 = S.surface2,
                BorderSizePixel = 0,
                Text = value,
                PlaceholderText = e.PlaceholderText or "Type here...",
                TextColor3 = S.text,
                PlaceholderColor3 = S.muted,
                Font = S.font,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
            }, row)
            new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
            local bStroke = stroke(box, S.border, 1)

            box.Focused:Connect(function()
                pcall(function() bStroke.Color = S.accent end)
            end)
            box.FocusLost:Connect(function()
                pcall(function() bStroke.Color = S.border end)
                value = box.Text
                if flag then BlockUI.Flags[flag] = value end
                if e.Callback then task.spawn(e.Callback, value) end
                if e.RemoveTextAfterFocusLost then box.Text = "" end
            end)

            local I = {}
            function I:Set(t)
                box.Text = t; value = t
                if flag then BlockUI.Flags[flag] = t end
            end
            return I
        end

        -- DROPDOWN
        function Tab:CreateDropdown(e)
            e = e or {}
            local flag     = e.Flag
            local options  = e.Options or {}
            local selected = e.CurrentOption or (options[1] and {options[1]} or {})
            local multi    = e.MultipleOptions or false
            if flag then BlockUI.Flags[flag] = selected end

            local row = rowBase(48)

            new("TextLabel", {
                Size = UDim2.new(1, -16, 0, 16),
                Position = UDim2.fromOffset(14, 5),
                BackgroundTransparency = 1,
                Text = (e.Name or "Dropdown"):upper(),
                TextColor3 = S.muted,
                Font = S.font,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)

            local selBtn = new("TextButton", {
                Size = UDim2.new(1, -28, 0, 26),
                Position = UDim2.fromOffset(14, 19),
                BackgroundColor3 = S.surface2,
                Text = "",
                AutoButtonColor = false,
                BorderSizePixel = 0,
            }, row)
            local dStroke = stroke(selBtn, S.border, 1)

            local selLbl = new("TextLabel", {
                Size = UDim2.new(1, -22, 1, 0),
                Position = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Text = table.concat(selected, ", "),
                TextColor3 = S.text,
                Font = S.font,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, selBtn)

            new("TextLabel", {
                Size = UDim2.new(0, 18, 1, 0),
                Position = UDim2.new(1, -18, 0, 0),
                BackgroundTransparency = 1,
                Text = "▾",
                TextColor3 = S.muted,
                Font = S.font,
                TextSize = 10,
            }, selBtn)

            -- Dropdown list — parented to main so it layers above everything
            local listFrame = new("Frame", {
                BackgroundColor3 = S.surface2,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 20,
                Size = UDim2.new(0, 1, 0, 1), -- set dynamically
            }, main)
            stroke(listFrame, S.accent, 1)
            new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)

            local isOpen = false

            local function closeList()
                isOpen = false
                listFrame.Visible = false
                pcall(function() dStroke.Color = S.border end)
            end

            local function buildList(opts)
                for _, c in pairs(listFrame:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for _, opt in ipairs(opts) do
                    local ob = new("TextButton", {
                        Size = UDim2.new(1, 0, 0, 28),
                        BackgroundColor3 = S.surface2,
                        Text = opt,
                        TextColor3 = S.text,
                        Font = S.font,
                        TextSize = 11,
                        AutoButtonColor = false,
                        BorderSizePixel = 0,
                        ZIndex = 21,
                    }, listFrame)
                    new("Frame", {
                        Size = UDim2.new(1, 0, 0, 1),
                        Position = UDim2.new(0, 0, 1, -1),
                        BackgroundColor3 = S.border,
                        BorderSizePixel = 0,
                        ZIndex = 21,
                    }, ob)
                    ob.MouseEnter:Connect(function()
                        tw(ob, 0.08, { BackgroundColor3 = S.surface })
                    end)
                    ob.MouseLeave:Connect(function()
                        tw(ob, 0.08, { BackgroundColor3 = S.surface2 })
                    end)
                    ob.MouseButton1Click:Connect(function()
                        if multi then
                            local idx = table.find(selected, opt)
                            if idx then table.remove(selected, idx)
                            else table.insert(selected, opt) end
                        else
                            selected = {opt}
                            closeList()
                        end
                        selLbl.Text = table.concat(selected, ", ")
                        if flag then BlockUI.Flags[flag] = selected end
                        if e.Callback then task.spawn(e.Callback, selected) end
                    end)
                end
                listFrame.Size = UDim2.new(0, selBtn.AbsoluteSize.X, 0, #opts * 28)
            end

            buildList(options)

            selBtn.MouseButton1Click:Connect(function()
                if isOpen then
                    closeList()
                else
                    isOpen = true
                    -- Position relative to main frame
                    local abs = selBtn.AbsolutePosition
                    local mainAbs = main.AbsolutePosition
                    local rx = abs.X - mainAbs.X
                    local ry = abs.Y - mainAbs.Y + selBtn.AbsoluteSize.Y
                    listFrame.Position = UDim2.fromOffset(rx, ry)
                    listFrame.Size = UDim2.new(0, selBtn.AbsoluteSize.X, 0, #options * 28)
                    listFrame.Visible = true
                    pcall(function() dStroke.Color = S.accent end)
                end
            end)

            local D = {}
            function D:Refresh(opts)
                options = opts
                buildList(opts)
            end
            function D:Set(opts)
                selected = opts
                selLbl.Text = table.concat(selected, ", ")
                if flag then BlockUI.Flags[flag] = selected end
                if e.Callback then task.spawn(e.Callback, selected) end
            end
            return D
        end

        -- LABEL
        function Tab:CreateLabel(e)
            e = e or {}
            local row = new("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = no(),
            }, tabFrame)
            local lbl = new("TextLabel", {
                Size = UDim2.new(1, -28, 1, 0),
                Position = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text = e.Text or "",
                TextColor3 = S.muted,
                Font = S.font,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            }, row)
            local L = {}
            function L:Set(t) lbl.Text = t end
            return L
        end

        -- SECTION
        function Tab:CreateSection(e)
            e = e or {}
            local row = new("Frame", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = S.surface2,
                BorderSizePixel = 0,
                LayoutOrder = no(),
            }, tabFrame)
            new("Frame", { Size = UDim2.new(1,0,0,1), BackgroundColor3 = S.border, BorderSizePixel = 0 }, row)
            new("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = S.border, BorderSizePixel = 0 }, row)
            -- Accent left bar
            new("Frame", { Size = UDim2.new(0,3,1,0), BackgroundColor3 = S.accent, BorderSizePixel = 0 }, row)
            new("TextLabel", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.fromOffset(10, 0),
                BackgroundTransparency = 1,
                Text = "// "..(e.Name or "Section"):upper(),
                TextColor3 = Color3.fromRGB(160, 160, 170),
                Font = S.font,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)
        end

        return Tab
    end

    table.insert(BlockUI._windows, Window)
    return Window
end

-- Boot notify
task.delay(0.5, function()
    BlockUI:Notify({
        Title   = "BlockUI v1.1.0",
        Content = "Library loaded successfully.",
        Type    = "success",
        Duration = 3,
    })
end)

return BlockUI

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EXAMPLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local BlockUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/GulleDK11/rflhub/refs/heads/main/BlockUI.lua"
))()

local Win = BlockUI:CreateWindow({
    Name     = "My Script",
    Subtitle = "BlockUI v1.1.0",
})

local Main = Win:CreateTab({ Name = "Main" })

Main:CreateSection({ Name = "Player" })

Main:CreateToggle({
    Name = "Speed", Description = "x6 walkspeed",
    CurrentValue = false, Flag = "speed",
    Callback = function(v)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v and 100 or 16
    end,
})

Main:CreateSlider({
    Name = "Jump Power", Range = {0, 200}, Increment = 5,
    Suffix = "pow", CurrentValue = 50, Flag = "jump",
    Callback = function(v)
        game.Players.LocalPlayer.Character.Humanoid.JumpPower = v
    end,
})

Main:CreateButton({
    Name = "Rejoin",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end,
})

BlockUI:LoadConfiguration()
]]
