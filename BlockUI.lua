--[[
    ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██╗
    ██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██║
    ██████╔╝██║     ██║   ██║██║     █████╔╝ ██║   ██║██║
    ██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██║
    ██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║
    ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝

    BlockUI v1.0.1 — Modern Blocky Roblox UI Library
    Sharp. Fast. Clean.

    Usage:
        local BlockUI = require(pathToModule)  -- eller dit loadstring-setup

    Docs / Elements:
        Window  → CreateTab
        Tab     → CreateButton, CreateToggle, CreateSlider,
                  CreateInput, CreateDropdown, CreateLabel
        BlockUI → Notify, LoadConfiguration, SaveConfiguration
--]]

local BlockUI = {}
BlockUI.Flags = {}
BlockUI._windows = {}
BlockUI._configFile = nil

-- ── Services ────────────────────────────────────────────────
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RunService     = game:GetService("RunService")
local LocalPlayer    = Players.LocalPlayer
local PlayerGui      = LocalPlayer:WaitForChild("PlayerGui")

-- ── Style (modern dark + sharp accent) ─────────────────────
local S = {
    bg       = Color3.fromRGB(10,  11,  14),
    surface  = Color3.fromRGB(20,  21,  26),
    surface2 = Color3.fromRGB(28,  29,  36),
    surface3 = Color3.fromRGB(36,  38,  48),
    accent   = Color3.fromRGB(196, 255, 97),
    accentMuted = Color3.fromRGB(120, 160, 55),
    accent2  = Color3.fromRGB(99,  155, 255),
    text     = Color3.fromRGB(245, 246, 250),
    muted    = Color3.fromRGB(120, 122, 138),
    border   = Color3.fromRGB(48,  50,  62),
    danger   = Color3.fromRGB(255, 99,  99),
    warning  = Color3.fromRGB(255, 196, 61),
    success  = Color3.fromRGB(52,  211, 120),
    black    = Color3.fromRGB(8,   9,   12),
    font     = Enum.Font.GothamMedium,
    fontMono = Enum.Font.Code,
    fontBody = Enum.Font.Gotham,
    radiusS  = UDim.new(0, 6),
    radiusM  = UDim.new(0, 10),
}

local CORNER_MAIN = UDim.new(0, 8)
local function corner(inst, r)
    local c = inst:FindFirstChildOfClass("UICorner")
    if not c then
        c = Instance.new("UICorner")
        c.Parent = inst
    end
    c.CornerRadius = r or CORNER_MAIN
end

-- ── Utility ─────────────────────────────────────────────────
local function new(cls, props, parent)
    local obj = Instance.new(cls)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    if parent then obj.Parent = parent end
    return obj
end

local function tween(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

local function makeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function divider(parent)
    new("Frame", {
        Size            = UDim2.new(1, -24, 0, 1),
        Position        = UDim2.fromOffset(12, 0),
        BackgroundColor3 = S.border,
        BorderSizePixel = 0,
    }, parent)
end

-- ── Notification System ──────────────────────────────────────
local notifGui = new("ScreenGui", {
    Name            = "BlockUI_Notifs",
    ResetOnSpawn    = false,
    IgnoreGuiInset  = true,
    DisplayOrder    = 999,
    ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local notifHolder = new("Frame", {
    Size              = UDim2.new(0, 280, 1, 0),
    Position          = UDim2.new(1, -295, 0, 16),
    BackgroundTransparency = 1,
    AnchorPoint       = Vector2.new(0, 0),
}, notifGui)

new("UIListLayout", {
    SortOrder        = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding          = UDim.new(0, 8),
    FillDirection    = Enum.FillDirection.Vertical,
}, notifHolder)

function BlockUI:Notify(cfg)
    cfg = cfg or {}
    local title   = cfg.Title   or "Notification"
    local content = cfg.Content or ""
    local ntype   = cfg.Type    or "info"
    local duration = cfg.Duration or 4

    local accentCol = ntype == "success" and S.success
                   or ntype == "warning" and S.warning
                   or ntype == "error"   and S.danger
                   or S.accent2

    local card = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundColor3 = S.surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, notifHolder)
    corner(card, S.radiusS)
    new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.4 }, card)

    new("UIListLayout", {
        SortOrder              = Enum.SortOrder.LayoutOrder,
        FillDirection          = Enum.FillDirection.Vertical,
        HorizontalAlignment    = Enum.HorizontalAlignment.Center,
        Padding                = UDim.new(0, 0),
    }, card)

    new("Frame", {
        Name             = "AccentTop",
        Size             = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = accentCol,
        BorderSizePixel  = 0,
        LayoutOrder      = 0,
    }, card)

    local textCol = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        LayoutOrder      = 1,
    }, card)

    new("UIPadding", {
        PaddingTop    = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft   = UDim.new(0, 14),
        PaddingRight  = UDim.new(0, 14),
    }, textCol)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 4),
    }, textCol)

    new("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text             = title,
        TextColor3       = S.text,
        FontFace         = Font.fromEnum(S.font),
        TextSize         = 14,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextWrapped      = true,
        LayoutOrder      = 1,
    }, textCol)

    new("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text             = content,
        TextColor3       = S.muted,
        FontFace         = Font.fromEnum(S.fontBody),
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextWrapped      = true,
        LayoutOrder      = 2,
    }, textCol)

    -- slide in
    card.Position = UDim2.new(1, 24, 0, 0)
    tween(card, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
    })

    task.delay(duration, function()
        if not card.Parent then
            return
        end
        tween(card, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 28, 0, 0),
            BackgroundTransparency = 1,
        })
        task.wait(0.24)
        if card.Parent then
            card:Destroy()
        end
    end)

    return card
end

-- ── Configuration ────────────────────────────────────────────
local function configWrite(path, data)
    local fn
    pcall(function()
        fn = writefile
    end)
    if type(fn) ~= "function" then
        return false
    end
    return select(1, pcall(fn, path, data))
end

local function configRead(path)
    local fn
    pcall(function()
        fn = readfile
    end)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, res = pcall(fn, path)
    if ok and type(res) == "string" then
        return res
    end
    return nil
end

function BlockUI:SaveConfiguration()
    if not self._configFile then return end
    local data = {}
    for flag, val in pairs(self.Flags) do
        data[flag] = val
    end
    local ok, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if ok and encoded then
        configWrite(self._configFile .. ".json", encoded)
    end
end

function BlockUI:LoadConfiguration()
    if not self._configFile then return end
    local raw = configRead(self._configFile .. ".json")
    if not raw then return end
    local ok2, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not ok2 or type(data) ~= "table" then return end
    for flag, val in pairs(data) do
        if self.Flags[flag] ~= nil then
            self.Flags[flag] = val
        end
    end
end

-- ── CreateWindow ─────────────────────────────────────────────
function BlockUI:CreateWindow(cfg)
    cfg = cfg or {}
    local winName  = cfg.Name     or "BlockUI Window"
    local winSub   = cfg.Subtitle or ""
    local saveConfig = cfg.ConfigurationSaving

    if saveConfig and saveConfig.Enabled and saveConfig.FileName then
        self._configFile = saveConfig.FileName
    end

    -- Root ScreenGui
    local gui = new("ScreenGui", {
        Name           = "BlockUI_" .. winName,
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
        DisplayOrder   = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    -- Main frame
    local main = new("Frame", {
        Size             = UDim2.new(0, 440, 0, 500),
        Position         = UDim2.new(0.5, -220, 0.5, -250),
        BackgroundColor3 = S.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, gui)
    corner(main, CORNER_MAIN)
    new("UIStroke", {
        Color       = S.border,
        Thickness   = 1,
        Transparency = 0.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, main)

    -- ── Titlebar ────────────────────────────────────────────
    local titlebar = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = S.surface,
        BorderSizePixel  = 0,
    }, main)

    -- Window dots
    local dotColors = { S.danger, S.warning, S.success }
    for i, col in ipairs(dotColors) do
        local d = new("Frame", {
            Size             = UDim2.new(0, 8, 0, 8),
            Position         = UDim2.fromOffset(12 + (i - 1) * 13, 16),
            BackgroundColor3 = col,
            BorderSizePixel  = 0,
        }, titlebar)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
    end

    -- Title text
    new("TextLabel", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text             = winName:upper(),
        TextColor3       = S.muted,
        FontFace         = Font.fromEnum(S.fontMono),
        TextSize         = 11,
        LetterSpacing    = 1.6,
    }, titlebar)

    -- Close button
    local closeBtn = new("TextButton", {
        Size             = UDim2.new(0, 36, 1, 0),
        Position         = UDim2.new(1, -36, 0, 0),
        BackgroundTransparency = 1,
        Text             = "✕",
        TextColor3       = S.muted,
        FontFace         = Font.fromEnum(S.fontBody),
        TextSize         = 14,
        AutoButtonColor  = false,
    }, titlebar)
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, TweenInfo.new(0.12), { TextColor3 = S.danger })
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, TweenInfo.new(0.12), { TextColor3 = S.muted })
    end)
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    -- Bottom border of titlebar
    new("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = S.border,
        BorderSizePixel  = 0,
    }, titlebar)

    makeDraggable(main, titlebar)

    -- Subtitle strip
    if winSub ~= "" then
        local subBar = new("Frame", {
            Size             = UDim2.new(1, 0, 0, 26),
            Position         = UDim2.fromOffset(0, 40),
            BackgroundColor3 = S.surface2,
            BorderSizePixel  = 0,
        }, main)
        new("TextLabel", {
            Size             = UDim2.new(1, -16, 1, 0),
            Position         = UDim2.fromOffset(8, 0),
            BackgroundTransparency = 1,
            Text             = "// " .. winSub,
            TextColor3       = S.muted,
            FontFace         = Font.fromEnum(S.fontMono),
            TextSize         = 10,
            TextXAlignment   = Enum.TextXAlignment.Left,
        }, subBar)
        new("Frame", {
            Size             = UDim2.new(1, 0, 0, 1),
            Position         = UDim2.new(0, 0, 1, -1),
            BackgroundColor3 = S.border,
            BorderSizePixel  = 0,
        }, subBar)
    end

    local tabBarY = (winSub ~= "") and 66 or 40

    -- ── Tab Bar ─────────────────────────────────────────────
    local tabBar = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 34),
        Position         = UDim2.fromOffset(0, tabBarY),
        BackgroundColor3 = S.surface2,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, main)

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder     = Enum.SortOrder.LayoutOrder,
    }, tabBar)

    new("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = S.border,
        BorderSizePixel  = 0,
    }, tabBar)

    local contentY = tabBarY + 34

    -- Content area
    local contentArea = new("Frame", {
        Size             = UDim2.new(1, 0, 1, -contentY),
        Position         = UDim2.fromOffset(0, contentY),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, main)

    local tabs      = {}
    local tabFrames = {}
    local activeTab = nil

    local function switchToTab(name)
        for n, frame in pairs(tabFrames) do
            frame.Visible = (n == name)
        end
        for n, btn in pairs(tabs) do
            local u = btn:FindFirstChild("Underline")
            if u and u:IsA("Frame") then
                if n == name then
                    btn.TextColor3 = S.accent
                    u.BackgroundColor3 = S.accent
                    u.BackgroundTransparency = 0
                else
                    btn.TextColor3 = S.muted
                    u.BackgroundTransparency = 1
                end
            end
        end
        activeTab = name
    end

    -- ── Window object ────────────────────────────────────────
    local Window = {}

    function Window:CreateTab(tabCfg)
        tabCfg = tabCfg or {}
        local tabName = tabCfg.Name or "Tab"

        -- Tab button
        local btn = new("TextButton", {
            Size             = UDim2.new(0, 0, 1, 0),
            AutomaticSize    = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text             = tabName:upper(),
            TextColor3       = S.muted,
            FontFace         = Font.fromEnum(S.fontMono),
            TextSize         = 11,
            LetterSpacing    = 1.2,
            AutoButtonColor  = false,
        }, tabBar)

        -- Underline
        local underline = new("Frame", {
            Name             = "Underline",
            Size             = UDim2.new(1, -8, 0, 2),
            Position         = UDim2.new(0, 4, 1, -2),
            BackgroundColor3 = S.accent,
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
        }, btn)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, underline)

        new("UIPadding", {
            PaddingLeft  = UDim.new(0, 16),
            PaddingRight = UDim.new(0, 16),
        }, btn)

        tabs[tabName] = btn

        -- Tab content frame with scrolling
        local tabFrame = new("ScrollingFrame", {
            Size             = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = S.accent,
            CanvasSize       = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible          = false,
        }, contentArea)

        local layout = new("UIListLayout", {
            SortOrder        = Enum.SortOrder.LayoutOrder,
            Padding          = UDim.new(0, 0),
        }, tabFrame)

        new("UIPadding", {
            PaddingTop    = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8),
        }, tabFrame)

        tabFrames[tabName] = tabFrame

        btn.MouseButton1Click:Connect(function()
            switchToTab(tabName)
        end)

        -- Auto-activate first tab
        if not activeTab then
            switchToTab(tabName)
        end

        -- ── Tab object ───────────────────────────────────────
        local Tab = {}
        local order = 0
        local function nextOrder() order = order + 1; return order end

        -- ── Button ───────────────────────────────────────────
        function Tab:CreateButton(elCfg)
            elCfg = elCfg or {}
            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 46),
                BackgroundColor3 = S.surface,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0,0,1,-1),
                BackgroundColor3 = S.border,
                BorderSizePixel = 0,
            }, row)

            new("TextLabel", {
                Size             = UDim2.new(1, -100, 1, 0),
                Position         = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text             = elCfg.Name or "Button",
                TextColor3       = S.text,
                Font             = S.fontBody,
                TextSize         = 13,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, row)

            local btn2 = new("TextButton", {
                Size             = UDim2.new(0, 80, 0, 26),
                Position         = UDim2.new(1, -92, 0.5, -13),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                Text             = "RUN",
                TextColor3       = S.accent,
                FontFace         = Font.fromEnum(S.fontMono),
                TextSize         = 11,
            }, row)
            new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.25 }, btn2)
            corner(btn2, S.radiusS)

            btn2.MouseEnter:Connect(function()
                tween(btn2, TweenInfo.new(0.1), { BackgroundColor3 = S.accent, TextColor3 = S.black })
            end)
            btn2.MouseLeave:Connect(function()
                tween(btn2, TweenInfo.new(0.1), { BackgroundColor3 = S.surface2, TextColor3 = S.accent })
            end)
            btn2.MouseButton1Click:Connect(function()
                if elCfg.Callback then
                    task.spawn(elCfg.Callback)
                end
            end)

            local Button = {}
            function Button:Set(name)
                btn2.Text = tostring(name)
            end
            return Button
        end

        -- ── Toggle ───────────────────────────────────────────
        function Tab:CreateToggle(elCfg)
            elCfg = elCfg or {}
            local flag = elCfg.Flag
            local value = elCfg.CurrentValue or false
            if flag then BlockUI.Flags[flag] = value end

            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 54),
                BackgroundColor3 = S.surface,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = S.border, BorderSizePixel = 0 }, row)

            new("TextLabel", {
                Size             = UDim2.new(1, -70, 0, 20),
                Position         = UDim2.fromOffset(14, 10),
                BackgroundTransparency = 1,
                Text             = elCfg.Name or "Toggle",
                TextColor3       = S.text,
                Font             = S.fontBody,
                TextSize         = 13,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, row)

            if elCfg.Description then
                new("TextLabel", {
                    Size             = UDim2.new(1, -70, 0, 16),
                    Position         = UDim2.fromOffset(14, 30),
                    BackgroundTransparency = 1,
                    Text             = elCfg.Description,
                    TextColor3       = S.muted,
                    Font             = S.fontBody,
                    TextSize         = 11,
                    TextXAlignment   = Enum.TextXAlignment.Left,
                }, row)
            end

            -- Track
            local track = new("Frame", {
                Size             = UDim2.new(0, 38, 0, 20),
                Position         = UDim2.new(1, -52, 0.5, -10),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
            }, row)
            new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
            new("UIStroke", { Color = S.border, Thickness = 1 }, track)

            -- Thumb
            local thumb = new("Frame", {
                Size             = UDim2.new(0, 14, 0, 14),
                Position         = UDim2.fromOffset(2, 3),
                BackgroundColor3 = S.muted,
                BorderSizePixel  = 0,
            }, track)
            new("UICorner", { CornerRadius = UDim.new(1, 0) }, thumb)

            local function setState(val, silent)
                value = val
                if flag then BlockUI.Flags[flag] = val end
                local stro = track:FindFirstChildOfClass("UIStroke")
                if val then
                    tween(track, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                        BackgroundColor3 = Color3.fromRGB(45, 58, 22),
                    })
                    tween(thumb, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                        Position = UDim2.fromOffset(22, 3),
                        BackgroundColor3 = S.accent,
                    })
                    if stro then
                        stro.Color = S.accent
                    end
                else
                    tween(track, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { BackgroundColor3 = S.surface2 })
                    tween(thumb, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                        Position = UDim2.fromOffset(2, 3),
                        BackgroundColor3 = S.muted,
                    })
                    if stro then
                        stro.Color = S.border
                    end
                end
                if not silent and elCfg.Callback then
                    task.spawn(elCfg.Callback, val)
                end
            end

            setState(value, true)

            local function toggleClick(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    setState(not value)
                end
            end
            track.InputBegan:Connect(toggleClick)
            thumb.InputBegan:Connect(toggleClick)

            local Toggle = {}
            function Toggle:Set(val)
                setState(val, false)
            end
            return Toggle
        end

        -- ── Slider ───────────────────────────────────────────
        function Tab:CreateSlider(elCfg)
            elCfg = elCfg or {}
            local flag    = elCfg.Flag
            local range   = elCfg.Range or {0, 100}
            local inc     = elCfg.Increment or 1
            local suffix  = elCfg.Suffix or ""
            local value   = elCfg.CurrentValue or range[1]
            if flag then BlockUI.Flags[flag] = value end

            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 64),
                BackgroundColor3 = S.surface,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = S.border, BorderSizePixel = 0 }, row)

            new("TextLabel", {
                Size             = UDim2.new(1, -80, 0, 20),
                Position         = UDim2.fromOffset(14, 10),
                BackgroundTransparency = 1,
                Text             = elCfg.Name or "Slider",
                TextColor3       = S.text,
                Font             = S.fontBody,
                TextSize         = 13,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, row)

            local valLabel = new("TextLabel", {
                Size             = UDim2.new(0, 70, 0, 20),
                Position         = UDim2.new(1, -84, 0, 10),
                BackgroundTransparency = 1,
                Text             = tostring(value) .. " " .. suffix,
                TextColor3       = S.accent,
                FontFace         = Font.fromEnum(S.fontMono),
                TextSize         = 12,
                TextXAlignment   = Enum.TextXAlignment.Right,
            }, row)

            -- Track bg
            local trackBg = new("Frame", {
                Size             = UDim2.new(1, -28, 0, 6),
                Position         = UDim2.fromOffset(14, 40),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
            }, row)
            corner(trackBg, UDim.new(1, 0))

            -- Fill
            local fill = new("Frame", {
                Size             = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = S.accent,
                BorderSizePixel  = 0,
            }, trackBg)
            corner(fill, UDim.new(1, 0))

            -- Thumb
            local sliderThumb = new("Frame", {
                Size             = UDim2.new(0, 14, 0, 14),
                AnchorPoint      = Vector2.new(0.5, 0.5),
                Position         = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = S.text,
                BorderSizePixel  = 0,
            }, trackBg)
            corner(sliderThumb, UDim.new(1, 0))
            new("UIStroke", { Color = S.accent, Thickness = 1, Transparency = 0.35 }, sliderThumb)

            local function updateSlider(val)
                val = math.clamp(math.round(val / inc) * inc, range[1], range[2])
                value = val
                if flag then BlockUI.Flags[flag] = val end
                local pct = (val - range[1]) / (range[2] - range[1])
                fill.Size = UDim2.new(pct, 0, 1, 0)
                sliderThumb.Position = UDim2.new(pct, 0, 0.5, 0)
                valLabel.Text = tostring(val) .. " " .. suffix
                if elCfg.Callback then
                    task.spawn(elCfg.Callback, val)
                end
            end

            updateSlider(value)

            local draggingSlider = false
            local function sliderFromInput(inp)
                local abs = trackBg.AbsolutePosition
                local size = trackBg.AbsoluteSize
                if size.X <= 0 then
                    return
                end
                local pct = math.clamp((inp.Position.X - abs.X) / size.X, 0, 1)
                local v = range[1] + pct * (range[2] - range[1])
                updateSlider(v)
            end
            trackBg.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = true
                    sliderFromInput(inp)
                end
            end)
            sliderThumb.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = true
                    sliderFromInput(inp)
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = false
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if draggingSlider and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    sliderFromInput(inp)
                end
            end)

            local Slider = {}
            function Slider:Set(val)
                updateSlider(val)
            end
            return Slider
        end

        -- ── Input ────────────────────────────────────────────
        function Tab:CreateInput(elCfg)
            elCfg = elCfg or {}
            local flag = elCfg.Flag
            local value = elCfg.CurrentValue or ""
            if flag then BlockUI.Flags[flag] = value end

            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 62),
                BackgroundColor3 = S.surface,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = S.border, BorderSizePixel = 0 }, row)

            new("TextLabel", {
                Size             = UDim2.new(1, -16, 0, 18),
                Position         = UDim2.fromOffset(14, 8),
                BackgroundTransparency = 1,
                Text             = (elCfg.Name or "Input"):upper(),
                TextColor3       = S.muted,
                FontFace         = Font.fromEnum(S.fontMono),
                TextSize         = 9,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, row)

            local box = new("TextBox", {
                Size             = UDim2.new(1, -28, 0, 26),
                Position         = UDim2.fromOffset(14, 28),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                Text             = value,
                PlaceholderText  = elCfg.PlaceholderText or "Type here...",
                TextColor3       = S.text,
                PlaceholderColor3 = S.muted,
                FontFace         = Font.fromEnum(S.fontMono),
                TextSize         = 12,
                TextXAlignment   = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
            }, row)
            new("UIPadding", { PaddingLeft = UDim.new(0,8) }, box)
            new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.25 }, box)
            corner(box, S.radiusS)

            box.Focused:Connect(function()
                local s = box:FindFirstChildOfClass("UIStroke")
                if s then
                    tween(s, TweenInfo.new(0.1), { Color = S.accent })
                end
            end)
            box.FocusLost:Connect(function()
                local s = box:FindFirstChildOfClass("UIStroke")
                if s then
                    tween(s, TweenInfo.new(0.1), { Color = S.border })
                end
                value = box.Text
                if flag then BlockUI.Flags[flag] = value end
                if elCfg.Callback then task.spawn(elCfg.Callback, value) end
                if elCfg.RemoveTextAfterFocusLost then box.Text = "" end
            end)

            local Input = {}
            function Input:Set(text)
                box.Text = text
                value = text
                if flag then BlockUI.Flags[flag] = text end
            end
            return Input
        end

        -- ── Dropdown ─────────────────────────────────────────
        function Tab:CreateDropdown(elCfg)
            elCfg = elCfg or {}
            local flag     = elCfg.Flag
            local options  = elCfg.Options or {}
            local firstOpt = options[1]
            local selected = elCfg.CurrentOption
            if not selected or type(selected) ~= "table" then
                selected = firstOpt ~= nil and { firstOpt } or {}
            end
            local multi    = elCfg.MultipleOptions or false
            if flag then BlockUI.Flags[flag] = selected end

            local container = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 46),
                BackgroundColor3 = S.surface,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
                ClipsDescendants = false,
            }, tabFrame)
            new("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = S.border, BorderSizePixel = 0 }, container)

            new("TextLabel", {
                Size             = UDim2.new(1, -16, 0, 18),
                Position         = UDim2.fromOffset(14, 4),
                BackgroundTransparency = 1,
                Text             = (elCfg.Name or "Dropdown"):upper(),
                TextColor3       = S.muted,
                FontFace         = Font.fromEnum(S.fontMono),
                TextSize         = 9,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, container)

            local selBtn = new("TextButton", {
                Size             = UDim2.new(1, -28, 0, 24),
                Position         = UDim2.fromOffset(14, 18),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                Text             = "",
                AutoButtonColor  = false,
            }, container)
            new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.25 }, selBtn)
            corner(selBtn, S.radiusS)

            local selLabel = new("TextLabel", {
                Size             = UDim2.new(1, -24, 1, 0),
                Position         = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Text             = #selected > 0 and table.concat(selected, ", ") or "—",
                TextColor3       = S.text,
                FontFace         = Font.fromEnum(S.fontMono),
                TextSize         = 11,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, selBtn)

            new("TextLabel", {
                Size             = UDim2.new(0, 20, 1, 0),
                Position         = UDim2.new(1, -20, 0, 0),
                BackgroundTransparency = 1,
                Text             = "▼",
                TextColor3       = S.muted,
                FontFace         = Font.fromEnum(S.fontBody),
                TextSize         = 10,
            }, selBtn)

            -- Dropdown list (absolute, layered on top)
            local dropList = new("Frame", {
                Size             = UDim2.new(1, -28, 0, 0),
                Position         = UDim2.fromOffset(14, 46),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                Visible          = false,
                ZIndex           = 10,
            }, container)
            new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.25 }, dropList)
            corner(dropList, S.radiusS)
            new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, dropList)

            local isOpen = false

            local function refreshOptions(opts)
                for _, c in pairs(dropList:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for _, opt in ipairs(opts) do
                    local optBtn = new("TextButton", {
                        Size             = UDim2.new(1, 0, 0, 28),
                        BackgroundColor3 = S.surface2,
                        BorderSizePixel  = 0,
                        Text             = opt,
                        TextColor3       = S.text,
                        FontFace         = Font.fromEnum(S.fontBody),
                        TextSize         = 12,
                        AutoButtonColor  = false,
                        ZIndex           = 11,
                    }, dropList)
                    new("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = S.border, BorderSizePixel = 0, ZIndex = 11 }, optBtn)
                    optBtn.MouseEnter:Connect(function()
                        tween(optBtn, TweenInfo.new(0.08), { BackgroundColor3 = S.surface })
                    end)
                    optBtn.MouseLeave:Connect(function()
                        tween(optBtn, TweenInfo.new(0.08), { BackgroundColor3 = S.surface2 })
                    end)
                    optBtn.MouseButton1Click:Connect(function()
                        if multi then
                            local idx = table.find(selected, opt)
                            if idx then table.remove(selected, idx)
                            else table.insert(selected, opt) end
                        else
                            selected = { opt }
                            isOpen = false
                            dropList.Visible = false
                        end
                        selLabel.Text = #selected > 0 and table.concat(selected, ", ") or "—"
                        if flag then BlockUI.Flags[flag] = selected end
                        if elCfg.Callback then task.spawn(elCfg.Callback, selected) end
                    end)
                end
                local n = #opts
                dropList.Size = UDim2.new(1, 0, 0, n * 28)
            end

            refreshOptions(options)

            selBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                dropList.Visible = isOpen
            end)

            local Dropdown = {}
            function Dropdown:Refresh(opts)
                options = opts
                refreshOptions(opts)
            end
            function Dropdown:Set(opts)
                selected = opts
                selLabel.Text = #selected > 0 and table.concat(selected, ", ") or "—"
                if flag then BlockUI.Flags[flag] = selected end
                if elCfg.Callback then task.spawn(elCfg.Callback, selected) end
            end
            return Dropdown
        end

        -- ── Label ────────────────────────────────────────────
        function Tab:CreateLabel(elCfg)
            elCfg = elCfg or {}
            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)

            local lbl = new("TextLabel", {
                Size             = UDim2.new(1, -28, 1, 0),
                Position         = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text             = elCfg.Text or "",
                TextColor3       = S.muted,
                FontFace         = Font.fromEnum(S.fontBody),
                TextSize         = 12,
                TextXAlignment   = Enum.TextXAlignment.Left,
                TextWrapped      = true,
            }, row)

            local Label = {}
            function Label:Set(text)
                lbl.Text = text
            end
            return Label
        end

        -- ── Section divider ───────────────────────────────────
        function Tab:CreateSection(elCfg)
            elCfg = elCfg or {}
            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("Frame", { Size=UDim2.new(1,0,0,1), BackgroundColor3=S.border, BorderSizePixel=0 }, row)
            new("Frame", { Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BackgroundColor3=S.border, BorderSizePixel=0 }, row)

            new("TextLabel", {
                Size             = UDim2.new(1, -16, 1, 0),
                Position         = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Text             = "// " .. (elCfg.Name or "Section"):upper(),
                TextColor3       = S.muted,
                FontFace         = Font.fromEnum(S.fontMono),
                TextSize         = 9,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, row)
        end

        return Tab
    end

    table.insert(BlockUI._windows, Window)
    return Window
end

-- ── Done ─────────────────────────────────────────────────────
return BlockUI

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EXAMPLE USAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local BlockUI = require(script.Parent.BlockUI) -- eller dit modul

local Window = BlockUI:CreateWindow({
    Name     = "My Script",
    Subtitle = "Made with BlockUI v1.0.1",
    ConfigurationSaving = {
        Enabled  = true,
        FileName = "MyScript_Config",
    },
})

local Tab = Window:CreateTab({ Name = "Main" })
local Tab2 = Window:CreateTab({ Name = "Visuals" })

Tab:CreateSection({ Name = "Movement" })

Tab:CreateToggle({
    Name         = "Speed Hack",
    Description  = "Sets WalkSpeed to 100",
    CurrentValue = false,
    Flag         = "SpeedHack",
    Callback     = function(val)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = val and 100 or 16
    end,
})

Tab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {0, 200},
    Increment    = 5,
    Suffix       = "studs/s",
    CurrentValue = 16,
    Flag         = "WalkSpeed",
    Callback     = function(val)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = val
    end,
})

Tab:CreateButton({
    Name     = "Teleport to Spawn",
    Callback = function()
        game.Players.LocalPlayer.Character:MoveTo(Vector3.new(0,5,0))
        BlockUI:Notify({ Title = "Teleported", Content = "Moved to spawn.", Type = "success" })
    end,
})

Tab:CreateInput({
    Name                  = "Player Name",
    PlaceholderText       = "Enter username...",
    RemoveTextAfterFocusLost = false,
    Flag                  = "TargetPlayer",
    Callback              = function(text)
        print("Target set to:", text)
    end,
})

Tab:CreateDropdown({
    Name          = "Game Mode",
    Options       = {"Normal", "Hard", "Insane"},
    CurrentOption = {"Normal"},
    Flag          = "GameMode",
    Callback      = function(opts)
        print("Selected:", opts[1])
    end,
})

BlockUI:LoadConfiguration()
]]
