--[[
    ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██╗
    ██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██║
    ██████╔╝██║     ██║   ██║██║     █████╔╝ ██║   ██║██║
    ██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██║
    ██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║
    ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝

    BlockUI v1.2.0 — Hub “grunge metal” (monokrom, skarp kant, metal-gradient)
    Valgfrit logo: CreateWindow{ LogoImage = "rbxassetid://…" } (upload dit emblem til Roblox)

    Usage:
        local BlockUI = require(pathToModule)  -- eller dit loadstring-setup

    Docs / Elements:
        Window  → CreateTab
        Tab     → CreateButton, CreateToggle, CreateSlider,
                  CreateInput, CreateDropdown, CreateLabel
        BlockUI → Notify, LoadConfiguration, SaveConfiguration
        CreateWindow → ToggleKey (Enum/liste/false), LogoImage ("rbxassetid://…")
        VIGTIG: Kun én ToggleKey-linje i tabellen — gentagne nøgler overskrives (sidste vinder).
--]]

local BlockUI = {}
BlockUI.Flags = {}
BlockUI._windows = {}
BlockUI._configFile = nil

-- ── Services ────────────────────────────────────────────────
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer    = Players.LocalPlayer
local PlayerGui      = LocalPlayer:WaitForChild("PlayerGui")

-- ── 9-slice panel (Zypher-asset; tones med ImageColor3 = metal/grunge) ──
local SLICE_ASSET = "rbxassetid://3570695787"
local SLICE_RECT = Rect.new(100, 100, 100, 100)
local SLICE_SCALE = 0.028

local S = {
    -- Monokrom “slagmetall / kul” hub
    bg             = Color3.fromRGB(22, 22, 24),
    grayContrast   = Color3.fromRGB(30, 30, 33),
    darkContrast   = Color3.fromRGB(26, 26, 29),
    charcoal       = Color3.fromRGB(12, 12, 14),
    sectionTone    = Color3.fromRGB(36, 36, 40),
    panelRaised    = Color3.fromRGB(44, 44, 48),
    text           = Color3.fromRGB(248, 248, 250),
    muted          = Color3.fromRGB(130, 130, 138),
    metalHighlight = Color3.fromRGB(210, 210, 216),
    metalMid       = Color3.fromRGB(110, 110, 118),
    accentCyan     = Color3.fromRGB(210, 210, 216),
    accentPurple   = Color3.fromRGB(95, 95, 102),
    toggleOn       = Color3.fromRGB(92, 92, 98),
    toggleThumb    = Color3.fromRGB(250, 250, 252),
    sliderFill     = Color3.fromRGB(188, 188, 196),
    danger         = Color3.fromRGB(200, 140, 140),
    warning        = Color3.fromRGB(200, 185, 150),
    success        = Color3.fromRGB(150, 185, 155),
    font           = Enum.Font.GothamBold,
    fontMono       = Enum.Font.Code,
    fontBody       = Enum.Font.Gotham,
    fontTitle      = Enum.Font.GothamBlack,
    radiusS        = UDim.new(0, 2),
    radiusM        = UDim.new(0, 3),
    border         = Color3.fromRGB(58, 58, 64),
    strokeEtch     = Color3.fromRGB(78, 78, 86),
    black          = Color3.fromRGB(6, 6, 8),
}
-- Bagudkompatibilitet for resten af filen
S.shell = S.bg
S.surface = S.darkContrast
S.surface2 = S.charcoal
S.surface3 = S.grayContrast
S.sidebarSel = S.panelRaised
S.fluentBlue = S.metalHighlight
S.toggleOnGlow = S.metalMid
S.accent2 = S.metalMid
S.accent = S.metalHighlight
S.accentBar = S.metalHighlight

local MAIN_W, MAIN_H = 700, 460
local SIDEBAR_W = 152
local TOP_STRIP = 4
local HEADER_H = 44
local CORNER_MAIN = UDim.new(0, 2)
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

-- Bruger-callbacks må aldrig stoppe UI-opbygning (nil Character, osv.)
local function runCallback(fn, ...)
    if not fn then
        return
    end
    local packed = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(function()
            return fn(table.unpack(packed, 1, packed.n))
        end)
        if not ok then
            warn("[BlockUI] Callback fejl: ", err)
        end
    end)
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
                   or S.metalHighlight

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
    local logoImage = cfg.LogoImage
    if type(logoImage) == "number" then
        logoImage = "rbxassetid://" .. tostring(logoImage)
    end
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

    local headerH = (winSub ~= "") and 52 or HEADER_H
    local bodyTop = TOP_STRIP + headerH

    local main = new("Frame", {
        Size             = UDim2.new(0, MAIN_W, 0, MAIN_H),
        Position         = UDim2.new(0.5, -MAIN_W / 2, 0.5, -MAIN_H / 2),
        BackgroundColor3 = S.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, gui)
    corner(main, CORNER_MAIN)
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 16, 18)),
            ColorSequenceKeypoint.new(0.45, Color3.fromRGB(28, 28, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 23)),
        }),
    }, main)
    new("UIStroke", {
        Color            = S.strokeEtch,
        Thickness        = 1,
        Transparency     = 0.12,
        ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
    }, main)

    local upline = new("Frame", {
        Name             = "Upline",
        Size             = UDim2.new(1, 0, 0, TOP_STRIP),
        BackgroundColor3 = Color3.fromRGB(60, 60, 65),
        BorderSizePixel  = 0,
        ZIndex           = 10,
    }, main)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 42)),
            ColorSequenceKeypoint.new(0.35, Color3.fromRGB(95, 95, 102)),
            ColorSequenceKeypoint.new(0.7, Color3.fromRGB(72, 72, 78)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 36)),
        }),
    }, upline)

    local titlebar = new("Frame", {
        Size             = UDim2.new(1, 0, 0, headerH),
        Position         = UDim2.fromOffset(0, TOP_STRIP),
        BackgroundColor3 = S.grayContrast,
        BorderSizePixel  = 0,
        ZIndex           = 5,
    }, main)
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 36, 40)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 24, 28)),
        }),
    }, titlebar)

    local hasLogo = type(logoImage) == "string" and logoImage ~= ""
    local titleLeft = 14
    if hasLogo then
        titleLeft = 56
        local logoHolder = new("Frame", {
            Size             = UDim2.fromOffset(40, 40),
            Position         = UDim2.new(0, 10, 0.5, -20),
            BackgroundColor3 = S.charcoal,
            BorderSizePixel  = 0,
            ZIndex           = 6,
        }, titlebar)
        corner(logoHolder, UDim.new(0, 2))
        new("UIStroke", {
            Color = S.border,
            Thickness = 1,
            Transparency = 0.35,
        }, logoHolder)
        new("ImageLabel", {
            Size             = UDim2.new(1, -6, 1, -6),
            Position         = UDim2.fromScale(0.5, 0.5),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image            = logoImage,
            ScaleType        = Enum.ScaleType.Fit,
            ZIndex           = 7,
        }, logoHolder)
    end

    local titleStack = new("Frame", {
        Size             = UDim2.new(1, hasLogo and -152 or -96, 1, 0),
        Position         = UDim2.fromOffset(titleLeft, 0),
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
        FontFace         = Font.fromEnum(S.fontTitle),
        TextSize         = 17,
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
        BackgroundColor3 = S.charcoal,
        BackgroundTransparency = 1,
        Text             = "×",
        TextColor3       = S.muted,
        FontFace         = Font.fromEnum(Enum.Font.GothamMedium),
        TextSize         = 20,
        AutoButtonColor  = false,
    }, titlebar)
    corner(closeBtn, UDim.new(0, 2))
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

    local nextTabY = 15
    local sidebar = new("ScrollingFrame", {
        Name             = "Sidebar",
        BackgroundColor3 = S.grayContrast,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(0, bodyTop),
        Size             = UDim2.new(0, SIDEBAR_W, 1, -bodyTop),
        CanvasSize       = UDim2.new(0, 0, 0, 200),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ZIndex           = 2,
    }, main)

    new("UIPadding", {
        PaddingTop  = UDim.new(0, 0),
        PaddingLeft = UDim.new(0, 0),
    }, sidebar)

    local tabSelector = new("ImageLabel", {
        Name             = "Categoriesselector",
        BackgroundTransparency = 1,
        Position         = UDim2.fromOffset(8, nextTabY),
        Size             = UDim2.new(1, -16, 0, 30),
        Image            = SLICE_ASSET,
        ImageColor3      = S.panelRaised,
        ScaleType        = Enum.ScaleType.Slice,
        SliceCenter      = SLICE_RECT,
        SliceScale       = SLICE_SCALE,
        ZIndex           = 1,
    }, sidebar)
    new("UIStroke", {
        Color = S.border,
        Thickness = 1,
        Transparency = 0.55,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, tabSelector)

    new("Frame", {
        Size             = UDim2.new(0, 1, 1, -bodyTop),
        Position         = UDim2.fromOffset(SIDEBAR_W, bodyTop),
        BackgroundColor3 = S.border,
        BorderSizePixel  = 0,
        ZIndex           = 3,
    }, main)

    local contentArea = new("Frame", {
        Size             = UDim2.new(1, -SIDEBAR_W, 1, -bodyTop),
        Position         = UDim2.fromOffset(SIDEBAR_W, bodyTop),
        BackgroundColor3 = S.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 1,
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
            if type(entry) == "table" and entry.btn then
                entry.btn.TextColor3 = isOn and S.metalHighlight or S.muted
                if isOn and tabSelector and entry.tabY ~= nil then
                    tween(tabSelector, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(8, entry.tabY),
                    })
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

        local tabY = nextTabY
        nextTabY = nextTabY + 34
        sidebar.CanvasSize = UDim2.new(0, 0, 0, nextTabY + 16)

        local rowWrap = new("Frame", {
            Size             = UDim2.new(1, -16, 0, 30),
            Position         = UDim2.fromOffset(8, tabY),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ZIndex           = 3,
        }, sidebar)

        local btn = new("TextButton", {
            Size             = UDim2.new(1, 0, 1, 0),
            Position         = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            Text             = tabText,
            TextColor3       = S.muted,
            FontFace         = Font.fromEnum(S.fontTitle),
            TextSize         = 15,
            TextXAlignment   = Enum.TextXAlignment.Left,
            TextYAlignment   = Enum.TextYAlignment.Center,
            AutoButtonColor  = false,
            ZIndex           = 4,
        }, rowWrap)

        new("UIPadding", {
            PaddingLeft  = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
        }, btn)

        tabs[tabName] = { wrap = rowWrap, btn = btn, tabY = tabY }

        -- Tab content frame with scrolling
        local tabFrame = new("ScrollingFrame", {
            Size             = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = S.metalMid,
            CanvasSize       = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible          = false,
        }, contentArea)

        local layout = new("UIListLayout", {
            SortOrder        = Enum.SortOrder.LayoutOrder,
            Padding          = UDim.new(0, 10),
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
        -- Frame har ikke MouseButton1Click — brug InputBegan til klik på kant/stribe
        rowWrap.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                pickTab()
            end
        end)

        -- Auto-activate first tab
        if not activeTab then
            switchToTab(tabName)
        end

        -- ── Tab object ───────────────────────────────────────
        local Tab = {}
        local order = 0
        local function nextOrder() order = order + 1; return order end

        -- ── Button (Zypher-lignende 9-slice ImageButton) ───────
        function Tab:CreateButton(elCfg)
            elCfg = elCfg or {}
            local iconPrefix = (elCfg.Icon and elCfg.Icon ~= "") and (elCfg.Icon .. "  ") or ""
            local labelText = iconPrefix .. (elCfg.Name or "Button")
            if elCfg.ButtonText and elCfg.ButtonText ~= "" then
                labelText = labelText .. "  ·  " .. elCfg.ButtonText
            end

            local imgBtn = new("ImageButton", {
                Size             = UDim2.new(1, 0, 0, 32),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                Image            = SLICE_ASSET,
                ImageColor3      = S.darkContrast,
                ScaleType        = Enum.ScaleType.Slice,
                SliceCenter      = SLICE_RECT,
                SliceScale       = SLICE_SCALE,
                AutoButtonColor  = false,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("UIStroke", {
                Color = S.border,
                Thickness = 1,
                Transparency = 0.5,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, imgBtn)

            local caption = new("TextLabel", {
                Size             = UDim2.new(1, -24, 1, 0),
                Position         = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text             = labelText,
                TextColor3       = S.text,
                FontFace         = Font.fromEnum(S.fontTitle),
                TextSize         = 15,
                TextXAlignment   = Enum.TextXAlignment.Left,
                TextYAlignment   = Enum.TextYAlignment.Center,
                Active           = false,
            }, imgBtn)

            imgBtn.MouseButton1Click:Connect(function()
                runCallback(elCfg.Callback)
            end)

            local Button = {}
            function Button:Set(name)
                caption.Text = tostring(name)
            end
            return Button
        end

        -- ── Toggle (Zypher-lignende række + slice-switch) ─────
        function Tab:CreateToggle(elCfg)
            elCfg = elCfg or {}
            local flag = elCfg.Flag
            local value = elCfg.CurrentValue or false
            if flag then BlockUI.Flags[flag] = value end

            local rowH = elCfg.Description and 56 or 36
            local toggleBtn = new("ImageButton", {
                Size             = UDim2.new(1, 0, 0, rowH),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                Image            = SLICE_ASSET,
                ImageColor3      = S.darkContrast,
                ScaleType        = Enum.ScaleType.Slice,
                SliceCenter      = SLICE_RECT,
                SliceScale       = SLICE_SCALE,
                AutoButtonColor  = false,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("UIStroke", {
                Color = S.border,
                Thickness = 1,
                Transparency = 0.55,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, toggleBtn)

            local iconT = (elCfg.Icon and elCfg.Icon ~= "") and (elCfg.Icon .. "  ") or ""
            local titleY = elCfg.Description and 6 or 0
            new("TextLabel", {
                Size             = UDim2.new(1, -80, 0, 22),
                Position         = UDim2.new(0, 12, 0, titleY + (elCfg.Description and 0 or 7)),
                BackgroundTransparency = 1,
                Text             = iconT .. (elCfg.Name or "Toggle"),
                TextColor3       = S.text,
                FontFace         = Font.fromEnum(S.fontTitle),
                TextSize         = 14,
                TextXAlignment   = Enum.TextXAlignment.Left,
                TextYAlignment   = Enum.TextYAlignment.Top,
                Active           = false,
            }, toggleBtn)

            if elCfg.Description then
                new("TextLabel", {
                    Size             = UDim2.new(1, -80, 0, 18),
                    Position         = UDim2.fromOffset(12, 30),
                    BackgroundTransparency = 1,
                    Text             = elCfg.Description,
                    TextColor3       = S.muted,
                    FontFace         = Font.fromEnum(S.fontBody),
                    TextSize         = 11,
                    TextXAlignment   = Enum.TextXAlignment.Left,
                    Active           = false,
                }, toggleBtn)
            end

            local toggleBack = new("ImageLabel", {
                Size             = UDim2.new(0, 54, 0, 26),
                Position         = UDim2.new(1, -62, 0.5, -13),
                BackgroundTransparency = 1,
                Image            = SLICE_ASSET,
                ImageColor3      = S.charcoal,
                ScaleType        = Enum.ScaleType.Slice,
                SliceCenter      = SLICE_RECT,
                SliceScale       = SLICE_SCALE,
                Active           = false,
            }, toggleBtn)

            local toggleKnob = new("ImageLabel", {
                Size             = UDim2.new(0, 24, 0, 18),
                Position         = UDim2.fromOffset(4, 4),
                BackgroundTransparency = 1,
                Image            = SLICE_ASSET,
                ImageColor3      = Color3.fromRGB(200, 200, 208),
                ScaleType        = Enum.ScaleType.Slice,
                SliceCenter      = SLICE_RECT,
                SliceScale       = SLICE_SCALE,
                Active           = false,
            }, toggleBack)

            local function setState(val, silent)
                value = val
                if flag then BlockUI.Flags[flag] = val end
                if val then
                    tween(toggleBack, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        ImageColor3 = S.toggleOn,
                    })
                    tween(toggleKnob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(26, 4),
                        ImageColor3 = S.toggleThumb,
                    })
                else
                    tween(toggleBack, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        ImageColor3 = S.charcoal,
                    })
                    tween(toggleKnob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(4, 4),
                        ImageColor3 = Color3.fromRGB(200, 200, 208),
                    })
                end
                if not silent and elCfg.Callback then
                    runCallback(elCfg.Callback, val)
                end
            end

            setState(value, true)

            toggleBtn.MouseButton1Click:Connect(function()
                setState(not value)
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

            local row = new("ImageLabel", {
                Size             = UDim2.new(1, 0, 0, 64),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                Image            = SLICE_ASSET,
                ImageColor3      = S.darkContrast,
                ScaleType        = Enum.ScaleType.Slice,
                SliceCenter      = SLICE_RECT,
                SliceScale       = SLICE_SCALE,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("UIStroke", {
                Color = S.border,
                Thickness = 1,
                Transparency = 0.55,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, row)

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
            new("UIStroke", { Color = S.metalMid, Thickness = 1, Transparency = 0.25 }, sliderThumb)

            local function updateSlider(val, skipCallback)
                val = math.clamp(math.round(val / inc) * inc, range[1], range[2])
                value = val
                if flag then BlockUI.Flags[flag] = val end
                local pct = (val - range[1]) / (range[2] - range[1])
                fill.Size = UDim2.new(pct, 0, 1, 0)
                sliderThumb.Position = UDim2.new(pct, 0, 0.5, 0)
                valLabel.Text = tostring(val) .. " " .. suffix
                if not skipCallback and elCfg.Callback then
                    runCallback(elCfg.Callback, val)
                end
            end

            -- Første gang: opdatér kun udseende — ellers fejler det hvis Character er nil
            updateSlider(value, true)

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
                runCallback(elCfg.Callback, value)
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
                        runCallback(elCfg.Callback, selected)
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
                runCallback(elCfg.Callback, selected)
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

        -- ── Section (Zypher-lignende slice-header) ─────────────
        function Tab:CreateSection(elCfg)
            elCfg = elCfg or {}
            local wrap = new("ImageLabel", {
                Size             = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                Image            = SLICE_ASSET,
                ImageColor3      = S.sectionTone,
                ScaleType        = Enum.ScaleType.Slice,
                SliceCenter      = SLICE_RECT,
                SliceScale       = SLICE_SCALE,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            new("UIStroke", {
                Color = S.border,
                Thickness = 1,
                Transparency = 0.6,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, wrap)

            new("TextLabel", {
                Size             = UDim2.new(0.55, 0, 0, 22),
                Position         = UDim2.fromOffset(6, -6),
                BackgroundTransparency = 1,
                Text             = string.upper(elCfg.Name or "SECTION"),
                TextColor3       = S.metalHighlight,
                FontFace         = Font.fromEnum(S.fontTitle),
                TextSize         = 14,
                TextXAlignment   = Enum.TextXAlignment.Left,
                TextYAlignment   = Enum.TextYAlignment.Bottom,
                Active           = false,
            }, wrap)
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
  EKSEMPEL (HttpGet + faner der virker)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Raw-URL (brug /main/… ikke /refs/heads/main/…):
  https://raw.githubusercontent.com/GulleDK11/rflhub/main/BlockUI.lua

  Du må kun have ÉN ToggleKey i CreateWindow{ … } — ellers overskriver Lua
  de forrige (sidste nøgle vinder). Skriv fx kun:
      ToggleKey = Enum.KeyCode.Insert,

local BlockUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/GulleDK11/rflhub/main/BlockUI.lua"))()

local function getHumanoid()
    local ch = game.Players.LocalPlayer.Character
    return ch and ch:FindFirstChildWhichIsA("Humanoid")
end

local Window = BlockUI:CreateWindow({
    Name     = "Mit Script",
    Subtitle = "Hub · grunge metal",
    ToggleKey = Enum.KeyCode.Insert,
    -- Upload dit stjerne/crescent-logo til Roblox → brug rbxassetid her:
    -- LogoImage = "rbxassetid://1234567890",
})

local Main = Window:CreateTab({ Name = "Main" })
local Visuals = Window:CreateTab({ Name = "Visuals" })

Main:CreateSection({ Name = "Movement" })

Main:CreateToggle({
    Name         = "Speed Hack",
    Description  = "Brug slideren når denne er tændt",
    CurrentValue = false,
    Flag         = "SpeedHack",
    Callback     = function(val)
        local h = getHumanoid()
        if not h then
            return
        end
        if val then
            h.WalkSpeed = BlockUI.Flags["WalkSpeed"] or 16
        else
            h.WalkSpeed = 16
        end
    end,
})

Main:CreateSlider({
    Name         = "Walk Speed",
    Range        = { 0, 200 },
    Increment    = 5,
    Suffix       = "studs/s",
    CurrentValue = 16,
    Flag         = "WalkSpeed",
    Callback     = function(val)
        if not BlockUI.Flags["SpeedHack"] then
            return
        end
        local h = getHumanoid()
        if h then
            h.WalkSpeed = val
        end
    end,
})

Main:CreateButton({
    Name     = "Teleport to Spawn",
    Callback = function()
        local ch = game.Players.LocalPlayer.Character
        if ch then
            ch:MoveTo(Vector3.new(0, 5, 0))
            BlockUI:Notify({ Title = "Teleporteret", Content = "Du er ved spawnen nu.", Type = "success" })
        end
    end,
})
]]
