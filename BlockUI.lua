--[[
    ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██╗
    ██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██║
    ██████╔╝██║     ██║   ██║██║     █████╔╝ ██║   ██║██║
    ██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██║
    ██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║
    ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝

    BlockUI v1.0.3 — Fluent gray + toggle key + fix input
    Sharp. Fast. Clean.

    Usage:
        local BlockUI = require(pathToModule)  -- eller dit loadstring-setup

    Docs / Elements:
        Window  → CreateTab
        Tab     → CreateButton, CreateToggle, CreateSlider,
                  CreateInput, CreateDropdown, CreateLabel
        BlockUI → Notify, LoadConfiguration, SaveConfiguration
        CreateWindow → ToggleKey (Enum eller liste, default Insert; false = slå fra)
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

-- ── Style: grå Fluent + tydelig “ON”-blå ────────────────────
local S = {
    bg           = Color3.fromRGB(28, 28, 31),
    shell        = Color3.fromRGB(40, 40, 44),
    surface      = Color3.fromRGB(48, 48, 52),
    surface2     = Color3.fromRGB(56, 56, 62),
    surface3     = Color3.fromRGB(34, 34, 38),
    sidebarSel   = Color3.fromRGB(52, 56, 64),
    accent       = Color3.fromRGB(230, 232, 238),
    accentBar    = Color3.fromRGB(0, 120, 215),
    accent2      = Color3.fromRGB(96, 165, 250),
    fluentBlue   = Color3.fromRGB(0, 120, 215),
    toggleOn     = Color3.fromRGB(0, 120, 215),
    toggleOnGlow = Color3.fromRGB(120, 190, 255),
    text         = Color3.fromRGB(250, 250, 252),
    muted        = Color3.fromRGB(145, 147, 156),
    border       = Color3.fromRGB(72, 74, 82),
    danger       = Color3.fromRGB(232, 90, 90),
    warning      = Color3.fromRGB(230, 180, 60),
    success      = Color3.fromRGB(80, 200, 130),
    black        = Color3.fromRGB(12, 12, 14),
    font         = Enum.Font.GothamMedium,
    fontMono     = Enum.Font.Code,
    fontBody     = Enum.Font.Gotham,
    radiusS      = UDim.new(0, 6),
    radiusM      = UDim.new(0, 10),
}

local CORNER_MAIN = UDim.new(0, 12)
local SIDEBAR_W = 196
local function corner(inst, r)
    local c = inst:FindFirstChildOfClass("UICorner")
    if not c then
        c = Instance.new("UICorner")
        c.Parent = inst
    end
    c.CornerRadius = r or CORNER_MAIN
end

-- ── Utility ─────────────────────────────────────────────────
-- Ignorér egenskaber ældre Roblox-klienter ikke har (fx LetterSpacing på TextLabel)
local UNSUPPORTED_PROPS = {
    LetterSpacing = true,
}

local function new(cls, props, parent)
    props = props or {}
    -- Tekstlabels skal ikke fange museklik (blokerede knapper/toggles)
    if cls == "TextLabel" and props.Active == nil then
        props.Active = false
    end
    local obj = Instance.new(cls)
    for k, v in pairs(props) do
        if not UNSUPPORTED_PROPS[k] then
            obj[k] = v
        end
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

    local toggleKeys = {}
    if cfg.ToggleKey == false then
        toggleKeys = {}
    elseif cfg.ToggleKey == nil then
        toggleKeys = { Enum.KeyCode.Insert }
    elseif typeof(cfg.ToggleKey) == "EnumItem" then
        toggleKeys = { cfg.ToggleKey }
    elseif type(cfg.ToggleKey) == "table" then
        toggleKeys = cfg.ToggleKey
    end

    -- Root ScreenGui
    local gui = new("ScreenGui", {
        Name           = "BlockUI_" .. winName,
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
        DisplayOrder   = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    local titleBarH = (winSub ~= "") and 58 or 46

    -- Main frame (bred, blødere Fluent-shell)
    local main = new("Frame", {
        Size             = UDim2.new(0, 728, 0, 492),
        Position         = UDim2.new(0.5, -364, 0.5, -246),
        BackgroundColor3 = S.shell,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, gui)
    corner(main, CORNER_MAIN)
    new("UIStroke", {
        Color            = S.border,
        Thickness        = 1,
        Transparency     = 0.25,
        ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
    }, main)

    -- ── Titlebar (drag) — ingen “Apple”-knapper ──────────────
    local titlebar = new("Frame", {
        Size             = UDim2.new(1, 0, 0, titleBarH),
        BackgroundColor3 = S.surface3,
        BorderSizePixel  = 0,
    }, main)

    new("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = S.border,
        BorderSizePixel  = 0,
    }, titlebar)

    local titleStack = new("Frame", {
        Size             = UDim2.new(1, -96, 1, 0),
        Position         = UDim2.fromOffset(16, 0),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, titlebar)

    new("UIListLayout", {
        FillDirection      = Enum.FillDirection.Vertical,
        SortOrder          = Enum.SortOrder.LayoutOrder,
        VerticalAlignment  = Enum.VerticalAlignment.Center,
        Padding            = UDim.new(0, 2),
    }, titleStack)

    new("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text             = winName,
        TextColor3       = S.text,
        FontFace         = Font.fromEnum(Enum.Font.GothamSemibold),
        TextSize         = 16,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextYAlignment   = Enum.TextYAlignment.Center,
        LayoutOrder      = 1,
    }, titleStack)

    if winSub ~= "" then
        new("TextLabel", {
            Size             = UDim2.new(1, 0, 0, 0),
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text             = winSub,
            TextColor3       = S.muted,
            FontFace         = Font.fromEnum(S.fontBody),
            TextSize         = 12,
            TextXAlignment   = Enum.TextXAlignment.Left,
            LayoutOrder      = 2,
        }, titleStack)
    end

    local closeBtn = new("TextButton", {
        Size             = UDim2.new(0, 32, 0, 28),
        Position         = UDim2.new(1, -40, 0.5, -14),
        BackgroundColor3 = S.surface2,
        BackgroundTransparency = 1,
        Text             = "×",
        TextColor3       = S.muted,
        FontFace         = Font.fromEnum(Enum.Font.GothamMedium),
        TextSize         = 20,
        AutoButtonColor  = false,
    }, titlebar)
    corner(closeBtn, UDim.new(0, 5))
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, TweenInfo.new(0.1), { BackgroundTransparency = 0, TextColor3 = S.text })
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, TweenInfo.new(0.1), { BackgroundTransparency = 1, TextColor3 = S.muted })
    end)
    local toggleKeyConn = nil
    if #toggleKeys > 0 then
        toggleKeyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then
                return
            end
            if not input.KeyCode then
                return
            end
            for _, key in ipairs(toggleKeys) do
                if input.KeyCode == key then
                    gui.Enabled = not gui.Enabled
                    break
                end
            end
        end)
    end

    closeBtn.MouseButton1Click:Connect(function()
        if toggleKeyConn then
            toggleKeyConn:Disconnect()
            toggleKeyConn = nil
        end
        gui:Destroy()
    end)

    makeDraggable(main, titlebar)

    -- Venstre sidebar (NavigationView-stil)
    local sidebar = new("Frame", {
        Name             = "Sidebar",
        Size             = UDim2.new(0, SIDEBAR_W, 1, -titleBarH),
        Position         = UDim2.fromOffset(0, titleBarH),
        BackgroundColor3 = S.surface3,
        BorderSizePixel  = 0,
    }, main)

    new("Frame", {
        Size             = UDim2.new(0, 1, 1, 0),
        Position         = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = S.border,
        BorderSizePixel  = 0,
    }, sidebar)

    local tabList = new("Frame", {
        Size             = UDim2.new(1, -8, 1, -12),
        Position         = UDim2.fromOffset(4, 6),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, sidebar)

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0, 4),
    }, tabList)

    -- Indhold til højre for sidebar
    local contentArea = new("Frame", {
        Size             = UDim2.new(1, -SIDEBAR_W, 1, -titleBarH),
        Position         = UDim2.fromOffset(SIDEBAR_W, titleBarH),
        BackgroundColor3 = S.bg,
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
        for n, entry in pairs(tabs) do
            local isOn = (n == name)
            if type(entry) == "table" and entry.btn and entry.wrap then
                entry.btn.TextColor3 = isOn and S.fluentBlue or S.muted
                entry.wrap.BackgroundColor3 = isOn and S.sidebarSel or S.surface3
                if entry.ind and entry.ind:IsA("Frame") then
                    entry.ind.BackgroundTransparency = isOn and 0 or 1
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
        local tabIcon = tabCfg.Icon
        local tabText = tabName
        if tabIcon and tabIcon ~= "" then
            tabText = tabIcon .. "  " .. tabName
        end

        -- Række: indikator + knap (aldrig barn af TextButton → ingen streg over tekst)
        local rowWrap = new("Frame", {
            Size             = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = S.surface3,
            BorderSizePixel  = 0,
        }, tabList)
        corner(rowWrap, UDim.new(0, 7))
        new("UIStroke", {
            Color            = S.border,
            Thickness        = 1,
            Transparency     = 0.65,
            ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
        }, rowWrap)

        local selInd = new("Frame", {
            Name             = "SelIndicator",
            Size             = UDim2.new(0, 3, 1, -10),
            Position         = UDim2.new(0, 8, 0.5, 0),
            AnchorPoint      = Vector2.new(0, 0.5),
            BackgroundColor3 = S.fluentBlue,
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ZIndex           = 1,
            Active           = false,
        }, rowWrap)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, selInd)

        local btn = new("TextButton", {
            Size             = UDim2.new(1, -22, 1, -4),
            Position         = UDim2.fromOffset(19, 2),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            Text             = tabText,
            TextColor3       = S.muted,
            FontFace         = Font.fromEnum(Enum.Font.GothamMedium),
            TextSize         = 13,
            TextXAlignment   = Enum.TextXAlignment.Left,
            AutoButtonColor  = false,
            ZIndex           = 2,
        }, rowWrap)

        new("UIPadding", {
            PaddingLeft  = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 6),
        }, btn)

        tabs[tabName] = { wrap = rowWrap, btn = btn, ind = selInd }

        btn.MouseEnter:Connect(function()
            if activeTab ~= tabName then
                tween(rowWrap, TweenInfo.new(0.1), { BackgroundColor3 = S.surface })
            end
        end)
        btn.MouseLeave:Connect(function()
            if activeTab ~= tabName then
                tween(rowWrap, TweenInfo.new(0.1), { BackgroundColor3 = S.surface3 })
            end
        end)

        -- Tab content frame with scrolling
        local tabFrame = new("ScrollingFrame", {
            Size             = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = S.fluentBlue,
            CanvasSize       = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible          = false,
        }, contentArea)

        local layout = new("UIListLayout", {
            SortOrder        = Enum.SortOrder.LayoutOrder,
            Padding          = UDim.new(0, 0),
        }, tabFrame)

        new("UIPadding", {
            PaddingTop    = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft   = UDim.new(0, 14),
            PaddingRight  = UDim.new(0, 14),
        }, tabFrame)

        tabFrames[tabName] = tabFrame

        local function pickTab()
            switchToTab(tabName)
        end
        btn.MouseButton1Click:Connect(pickTab)
        rowWrap.MouseButton1Click:Connect(pickTab)

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
                Size             = UDim2.new(1, 0, 0, 48),
                BackgroundColor3 = S.surface,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            corner(row, S.radiusS)
            new("UIStroke", {
                Color           = S.border,
                Thickness       = 1,
                Transparency    = 0.4,
            }, row)

            local iconPrefix = (elCfg.Icon and elCfg.Icon ~= "") and (elCfg.Icon .. "  ") or ""
            new("TextLabel", {
                Size             = UDim2.new(1, -118, 1, 0),
                Position         = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text             = iconPrefix .. (elCfg.Name or "Button"),
                TextColor3       = S.text,
                Font             = S.fontBody,
                TextSize         = 14,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, row)

            local btn2 = new("TextButton", {
                Size             = UDim2.new(0, 88, 0, 30),
                Position         = UDim2.new(1, -100, 0.5, -15),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                Text             = elCfg.ButtonText or "Kør",
                TextColor3       = S.fluentBlue,
                FontFace         = Font.fromEnum(Enum.Font.GothamMedium),
                TextSize         = 13,
                AutoButtonColor  = false,
                ZIndex           = 2,
            }, row)
            new("UIStroke", { Color = S.fluentBlue, Thickness = 1, Transparency = 0.5 }, btn2)
            corner(btn2, UDim.new(0, 7))

            btn2.MouseEnter:Connect(function()
                tween(btn2, TweenInfo.new(0.12), {
                    BackgroundColor3 = S.fluentBlue,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                })
            end)
            btn2.MouseLeave:Connect(function()
                tween(btn2, TweenInfo.new(0.12), {
                    BackgroundColor3 = S.surface2,
                    TextColor3 = S.fluentBlue,
                })
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
                Size             = UDim2.new(1, 0, 0, elCfg.Description and 58 or 50),
                BackgroundColor3 = S.surface,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            corner(row, S.radiusS)
            new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.4 }, row)

            local function flipToggle()
                setState(not value)
            end

            local rowHit = new("TextButton", {
                Size             = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text             = "",
                AutoButtonColor  = false,
                ZIndex           = 1,
            }, row)

            local iconT = (elCfg.Icon and elCfg.Icon ~= "") and (elCfg.Icon .. "  ") or ""
            new("TextLabel", {
                Size             = UDim2.new(1, -130, 0, 20),
                Position         = UDim2.fromOffset(14, 10),
                BackgroundTransparency = 1,
                Text             = iconT .. (elCfg.Name or "Toggle"),
                TextColor3       = S.text,
                Font             = S.fontBody,
                TextSize         = 14,
                TextXAlignment   = Enum.TextXAlignment.Left,
                ZIndex           = 2,
            }, row)

            if elCfg.Description then
                new("TextLabel", {
                    Size             = UDim2.new(1, -130, 0, 16),
                    Position         = UDim2.fromOffset(14, 32),
                    BackgroundTransparency = 1,
                    Text             = elCfg.Description,
                    TextColor3       = S.muted,
                    Font             = S.fontBody,
                    TextSize         = 11,
                    TextXAlignment   = Enum.TextXAlignment.Left,
                    ZIndex           = 2,
                }, row)
            end

            local track = new("Frame", {
                Size             = UDim2.new(0, 42, 0, 22),
                Position         = UDim2.new(1, -56, 0.5, -11),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                ZIndex           = 3,
                Active           = false,
            }, row)
            new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
            local trackStroke = new("UIStroke", { Color = S.border, Thickness = 1 }, track)

            local thumb = new("Frame", {
                Size             = UDim2.new(0, 16, 0, 16),
                Position         = UDim2.fromOffset(3, 3),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel  = 0,
                ZIndex           = 3,
                Active           = false,
            }, track)
            new("UICorner", { CornerRadius = UDim.new(1, 0) }, thumb)

            local function setState(val, silent)
                value = val
                if flag then BlockUI.Flags[flag] = val end
                if val then
                    tween(track, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundColor3 = S.toggleOn,
                    })
                    tween(thumb, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(23, 3),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    })
                    trackStroke.Color = S.toggleOnGlow
                else
                    tween(track, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundColor3 = S.surface2,
                    })
                    tween(thumb, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(3, 3),
                        BackgroundColor3 = Color3.fromRGB(200, 200, 205),
                    })
                    trackStroke.Color = S.border
                end
                if not silent and elCfg.Callback then
                    task.spawn(elCfg.Callback, val)
                end
            end

            setState(value, true)

            rowHit.MouseButton1Click:Connect(flipToggle)

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
                TextColor3       = S.fluentBlue,
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
                BackgroundColor3 = S.fluentBlue,
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
            new("UIStroke", { Color = S.fluentBlue, Thickness = 1, Transparency = 0.35 }, sliderThumb)

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

    function Window:SetEnabled(enabled)
        gui.Enabled = enabled
    end

    function Window:Toggle()
        gui.Enabled = not gui.Enabled
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
    Subtitle = "Made with BlockUI v1.0.3",
    ToggleKey = { Enum.KeyCode.Insert, Enum.KeyCode.RightControl },
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
