--[[
    ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██╗
    ██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██║
    ██████╔╝██║     ██║   ██║██║     █████╔╝ ██║   ██║██║
    ██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██║
    ██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║
    ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝

    BlockUI v1.0.0 — Modern Blocky Roblox UI Library
    Sharp. Fast. Clean.

    Usage:
        local BlockUI = loadstring(game:HttpGet("YOUR_RAW_URL"))()

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

-- ── Style Constants ─────────────────────────────────────────
local S = {
    bg       = Color3.fromRGB(13,  13,  15),
    surface  = Color3.fromRGB(22,  22,  25),
    surface2 = Color3.fromRGB(30,  30,  35),
    accent   = Color3.fromRGB(200, 241, 53),
    accent2  = Color3.fromRGB(91,  143, 255),
    text     = Color3.fromRGB(240, 240, 240),
    muted    = Color3.fromRGB(107, 107, 122),
    border   = Color3.fromRGB(42,  42,  50),
    danger   = Color3.fromRGB(255, 95,  87),
    warning  = Color3.fromRGB(254, 188, 46),
    success  = Color3.fromRGB(40,  200, 64),
    black    = Color3.fromRGB(10,  10,  10),
    font     = Enum.Font.Code,
    fontBody = Enum.Font.Gotham,
}

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
        Size             = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = S.surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, notifHolder)

    -- left accent bar
    new("Frame", {
        Size             = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = accentCol,
        BorderSizePixel  = 0,
    }, card)

    -- title
    new("TextLabel", {
        Size             = UDim2.new(1, -16, 0, 20),
        Position         = UDim2.fromOffset(12, 10),
        BackgroundTransparency = 1,
        Text             = title,
        TextColor3       = S.text,
        Font             = S.font,
        TextSize         = 13,
        TextXAlignment   = Enum.TextXAlignment.Left,
        FontFace         = Font.fromEnum(Enum.Font.Code),
    }, card)

    -- content
    new("TextLabel", {
        Size             = UDim2.new(1, -16, 0, 20),
        Position         = UDim2.fromOffset(12, 32),
        BackgroundTransparency = 1,
        Text             = content,
        TextColor3       = S.muted,
        Font             = S.fontBody,
        TextSize         = 11,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, card)

    -- border top
    new("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = S.border,
        BorderSizePixel  = 0,
    }, card)

    -- slide in
    card.Position = UDim2.new(1, 20, 0, 0)
    tween(card, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    })

    task.delay(duration, function()
        tween(card, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            Position = UDim2.new(1, 20, 0, 0)
        })
        task.wait(0.25)
        card:Destroy()
    end)

    return card
end

-- ── Configuration ────────────────────────────────────────────
function BlockUI:SaveConfiguration()
    if not self._configFile then return end
    local data = {}
    for flag, val in pairs(self.Flags) do
        data[flag] = val
    end
    local ok, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if ok then
        pcall(writefile, self._configFile .. ".json", encoded)
    end
end

function BlockUI:LoadConfiguration()
    if not self._configFile then return end
    local ok, raw = pcall(readfile, self._configFile .. ".json")
    if not ok or not raw then return end
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
        DisplayOrder   = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    -- Main frame
    local main = new("Frame", {
        Size             = UDim2.new(0, 420, 0, 480),
        Position         = UDim2.new(0.5, -210, 0.5, -240),
        BackgroundColor3 = S.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, gui)

    -- Outer border (1px via UIStroke)
    new("UIStroke", {
        Color     = S.border,
        Thickness = 1,
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
        new("Frame", {
            Size             = UDim2.new(0, 9, 0, 9),
            Position         = UDim2.fromOffset(10 + (i - 1) * 14, 16),
            BackgroundColor3 = col,
            BorderSizePixel  = 0,
        }, titlebar)
    end

    -- Title text
    new("TextLabel", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text             = winName:upper(),
        TextColor3       = S.muted,
        Font             = S.font,
        TextSize         = 11,
        LetterSpacing    = 2,
    }, titlebar)

    -- Close button
    local closeBtn = new("TextButton", {
        Size             = UDim2.new(0, 30, 1, 0),
        Position         = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text             = "✕",
        TextColor3       = S.muted,
        Font             = S.font,
        TextSize         = 12,
    }, titlebar)
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
            Font             = S.font,
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
            if n == name then
                btn.TextColor3 = S.accent
                -- accent underline
                btn:FindFirstChild("Underline").BackgroundColor3 = S.accent
            else
                btn.TextColor3 = S.muted
                btn:FindFirstChild("Underline").BackgroundColor3 = Color3.new(0,0,0)
                btn:FindFirstChild("Underline").BackgroundTransparency = 1
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
            Font             = S.font,
            TextSize         = 11,
            Padding          = UDim.new(0, 16),
        }, tabBar)

        -- Underline
        local underline = new("Frame", {
            Name             = "Underline",
            Size             = UDim2.new(1, 0, 0, 2),
            Position         = UDim2.new(0, 0, 1, -2),
            BackgroundColor3 = S.accent,
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
        }, btn)

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
                Font             = S.font,
                TextSize         = 11,
            }, row)
            new("UIStroke", { Color = S.border, Thickness = 1 }, btn2)

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
                new("TextLabel", { Text = name }, btn2)
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
                if val then
                    tween(track, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(40, 60, 0) })
                    tween(thumb, TweenInfo.new(0.15), { Position = UDim2.fromOffset(22, 3), BackgroundColor3 = S.accent })
                    track:FindFirstChildOfClass("UIStroke").Color = S.accent
                else
                    tween(track, TweenInfo.new(0.15), { BackgroundColor3 = S.surface2 })
                    tween(thumb, TweenInfo.new(0.15), { Position = UDim2.fromOffset(2, 3), BackgroundColor3 = S.muted })
                    track:FindFirstChildOfClass("UIStroke").Color = S.border
                end
                if not silent and elCfg.Callback then
                    task.spawn(elCfg.Callback, val)
                end
            end

            setState(value, true)

            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    setState(not value)
                end
            end)
            row.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    setState(not value)
                end
            end)

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
                Size             = UDim2.new(1, 0, 0, 62),
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
                Font             = S.font,
                TextSize         = 12,
                TextXAlignment   = Enum.TextXAlignment.Right,
            }, row)

            -- Track bg
            local trackBg = new("Frame", {
                Size             = UDim2.new(1, -28, 0, 3),
                Position         = UDim2.fromOffset(14, 44),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
            }, row)

            -- Fill
            local fill = new("Frame", {
                Size             = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = S.accent,
                BorderSizePixel  = 0,
            }, trackBg)

            -- Thumb
            local sliderThumb = new("Frame", {
                Size             = UDim2.new(0, 10, 0, 10),
                AnchorPoint      = Vector2.new(0.5, 0.5),
                Position         = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = S.accent,
                BorderSizePixel  = 0,
            }, trackBg)

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
            trackBg.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = true
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = false
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if draggingSlider and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    local abs = trackBg.AbsolutePosition
                    local size = trackBg.AbsoluteSize
                    local pct = math.clamp((inp.Position.X - abs.X) / size.X, 0, 1)
                    local val = range[1] + pct * (range[2] - range[1])
                    updateSlider(val)
                end
            end)
            trackBg.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    local abs = trackBg.AbsolutePosition
                    local size = trackBg.AbsoluteSize
                    local pct = math.clamp((inp.Position.X - abs.X) / size.X, 0, 1)
                    local val = range[1] + pct * (range[2] - range[1])
                    updateSlider(val)
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
                Font             = S.font,
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
                Font             = S.font,
                TextSize         = 12,
                TextXAlignment   = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
            }, row)
            new("UIPadding", { PaddingLeft = UDim.new(0,8) }, box)
            new("UIStroke", { Color = S.border, Thickness = 1 }, box)

            box.Focused:Connect(function()
                tween(box:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.1), { Color = S.accent })
            end)
            box.FocusLost:Connect(function()
                tween(box:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.1), { Color = S.border })
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
            local selected = elCfg.CurrentOption or { options[1] }
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
                Font             = S.font,
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
            new("UIStroke", { Color = S.border, Thickness = 1 }, selBtn)

            local selLabel = new("TextLabel", {
                Size             = UDim2.new(1, -24, 1, 0),
                Position         = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Text             = table.concat(selected, ", "),
                TextColor3       = S.text,
                Font             = S.font,
                TextSize         = 11,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, selBtn)

            new("TextLabel", {
                Size             = UDim2.new(0, 20, 1, 0),
                Position         = UDim2.new(1, -20, 0, 0),
                BackgroundTransparency = 1,
                Text             = "▼",
                TextColor3       = S.muted,
                Font             = S.font,
                TextSize         = 8,
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
            new("UIStroke", { Color = S.border, Thickness = 1 }, dropList)
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
                        Font             = S.font,
                        TextSize         = 11,
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
                        selLabel.Text = table.concat(selected, ", ")
                        if flag then BlockUI.Flags[flag] = selected end
                        if elCfg.Callback then task.spawn(elCfg.Callback, selected) end
                    end)
                end
                dropList.Size = UDim2.new(1, -28, 0, #opts * 28)
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
                selLabel.Text = table.concat(selected, ", ")
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
                Font             = S.font,
                TextSize         = 11,
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
                Font             = S.font,
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
BlockUI:Notify({
    Title   = "BlockUI Loaded",
    Content = "v1.0.0 — Ready.",
    Type    = "success",
    Duration = 3,
})

return BlockUI

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EXAMPLE USAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local BlockUI = loadstring(game:HttpGet("YOUR_RAW_URL_HERE"))()

local Window = BlockUI:CreateWindow({
    Name     = "My Script",
    Subtitle = "Made with BlockUI v1.0.0",
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
