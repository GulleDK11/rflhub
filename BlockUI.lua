--[[
    ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██╗
    ██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██║
    ██████╔╝██║     ██║   ██║██║     █████╔╝ ██║   ██║██║
    ██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██║
    ██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║
    ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝

    BlockUI v2.0.0 — Custom hub (monokrom “stjerne/metal” efter logo, sølv-accent)
    CreateWindow → LogoImage, ShowProfile (default true), DeveloperUserIds, DevBadgeImage (rbxasset ved DEV)

    Usage:
        local BlockUI = require(pathToModule)  -- eller dit loadstring-setup

    Docs / Elements:
        Window  → CreateTab
        Tab     → CreateButton, CreateToggle, CreateSlider,
                  CreateInput, CreateDropdown, CreateLabel
        BlockUI → Notify, LoadConfiguration, SaveConfiguration
        CreateWindow → ToggleKey, LogoImage, ShowProfile, DeveloperUserIds, DevBadgeImage, ProfileTag
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

-- ── 9-slice panel (Zypher-asset) ──
local SLICE_ASSET = "rbxassetid://3570695787"
local SLICE_RECT = Rect.new(100, 100, 100, 100)
local SLICE_SCALE = 0.042

-- Palette: kul/stål som dit stjerne-logo — sølv/hvid som “mejslet” accent (ikke lilla UI)
local S = {
    bg             = Color3.fromRGB(12, 12, 14),
    bgLift         = Color3.fromRGB(22, 22, 26),
    grayContrast   = Color3.fromRGB(20, 20, 24),
    darkContrast   = Color3.fromRGB(28, 28, 32),
    charcoal       = Color3.fromRGB(8, 8, 10),
    sectionTone    = Color3.fromRGB(30, 30, 34),
    panelRaised    = Color3.fromRGB(38, 38, 44),
    sidebarFooter  = Color3.fromRGB(16, 16, 19),
    glass          = Color3.fromRGB(255, 255, 255),
    text           = Color3.fromRGB(248, 248, 250),
    muted          = Color3.fromRGB(130, 132, 140),
    accent         = Color3.fromRGB(198, 202, 212),
    accentSoft     = Color3.fromRGB(120, 124, 136),
    accentGlow     = Color3.fromRGB(235, 236, 240),
    metalHighlight = Color3.fromRGB(220, 222, 228),
    metalMid       = Color3.fromRGB(88, 90, 98),
    accentCyan     = Color3.fromRGB(198, 202, 212),
    accentPurple   = Color3.fromRGB(160, 165, 180),
    toggleOn       = Color3.fromRGB(210, 212, 220),
    toggleThumb    = Color3.fromRGB(255, 255, 255),
    sliderFill     = Color3.fromRGB(200, 202, 210),
    tagMember      = Color3.fromRGB(65, 72, 88),
    tagPremium     = Color3.fromRGB(200, 160, 70),
    tagDev         = Color3.fromRGB(95, 88, 120),
    danger         = Color3.fromRGB(210, 95, 105),
    warning        = Color3.fromRGB(210, 175, 85),
    success        = Color3.fromRGB(95, 190, 130),
    font           = Enum.Font.GothamBold,
    fontMono       = Enum.Font.Code,
    fontBody       = Enum.Font.Gotham,
    fontTitle      = Enum.Font.GothamBold,
    radiusS        = UDim.new(0, 10),
    radiusM        = UDim.new(0, 14),
    border         = Color3.fromRGB(48, 50, 56),
    strokeEtch     = Color3.fromRGB(90, 92, 100),
    black          = Color3.fromRGB(6, 6, 8),
}
-- Bagudkompatibilitet for resten af filen
S.shell = S.bg
S.surface = S.darkContrast
S.surface2 = S.charcoal
S.surface3 = S.grayContrast
S.sidebarSel = S.panelRaised
S.fluentBlue = S.accent
S.toggleOnGlow = S.accentGlow
S.accent2 = S.accentSoft
S.accentBar = S.accent

local MAIN_W, MAIN_H = 736, 492
local SIDEBAR_W = 178
local PROFILE_H = 100
local TOP_STRIP = 4
local HEADER_H = 52
local CORNER_MAIN = UDim.new(0, 16)
local INNER_PAD = 10
local function corner(inst, r)
    local c = inst:FindFirstChildOfClass("UICorner")
    if not c then
        c = Instance.new("UICorner")
        c.Parent = inst
    end
    c.CornerRadius = r or CORNER_MAIN
end

local function resolveUserProfileTag(cfg)
    cfg = cfg or {}
    if type(cfg.ProfileTag) == "string" and cfg.ProfileTag ~= "" then
        local c = cfg.ProfileTagColor
        if typeof(c) == "Color3" then
            return cfg.ProfileTag, c
        end
        return cfg.ProfileTag, S.tagMember
    end
    local lp = LocalPlayer
    local devIds = cfg.DeveloperUserIds
    if type(devIds) == "table" then
        for _, id in ipairs(devIds) do
            if id == lp.UserId then
                return "Dev", S.tagDev
            end
        end
    end
    if game.CreatorType == Enum.CreatorType.User and lp.UserId == game.CreatorId then
        return "Dev", S.tagDev
    end
    if lp.MembershipType == Enum.MembershipType.Premium then
        return "Premium", S.tagPremium
    end
    return "Member", S.tagMember
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
    local devBadgeImage = cfg.DevBadgeImage
    if type(devBadgeImage) == "number" then
        devBadgeImage = "rbxassetid://" .. tostring(devBadgeImage)
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

    local headerH = (winSub ~= "") and 58 or HEADER_H
    local bodyTop = TOP_STRIP + headerH
    local showProfile = cfg.ShowProfile ~= false

    local main = new("Frame", {
        Size             = UDim2.new(0, MAIN_W, 0, MAIN_H),
        Position         = UDim2.new(0.5, -MAIN_W / 2, 0.5, -MAIN_H / 2),
        BackgroundColor3 = S.bg,
        BorderSizePixel  = 0,
        -- false: ellers klipper UICorner profilfooteren i venstre bund
        ClipsDescendants = false,
    }, gui)
    corner(main, CORNER_MAIN)
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 20)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 10, 12)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 16)),
        }),
    }, main)
    new("UIStroke", {
        Color            = S.strokeEtch,
        Thickness        = 1,
        Transparency     = 0.35,
        ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
    }, main)

    local upline = new("Frame", {
        Name             = "Upline",
        Size             = UDim2.new(1, 0, 0, TOP_STRIP),
        BackgroundColor3 = S.accent,
        BorderSizePixel  = 0,
        ZIndex           = 10,
    }, main)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 72, 78)),
            ColorSequenceKeypoint.new(0.5, S.accentGlow),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 92, 100)),
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
            ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 16, 19)),
        }),
    }, titlebar)

    new("TextLabel", {
        Size             = UDim2.fromOffset(22, 22),
        Position         = UDim2.new(1, -56, 0, 10),
        BackgroundTransparency = 1,
        Text             = "✦",
        TextColor3       = S.accentSoft,
        TextTransparency = 0.45,
        FontFace         = Font.fromEnum(Enum.Font.GothamBold),
        TextSize         = 14,
        ZIndex           = 7,
    }, titlebar)

    local headerGlow = new("Frame", {
        Size             = UDim2.new(1, -28, 0, 2),
        Position         = UDim2.new(0, 14, 1, -3),
        BackgroundColor3 = S.accentGlow,
        BackgroundTransparency = 0.55,
        BorderSizePixel  = 0,
        ZIndex           = 6,
    }, titlebar)
    corner(headerGlow, UDim.new(1, 0))

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
        corner(logoHolder, UDim.new(0, 10))
        new("UIStroke", {
            Color = S.strokeEtch,
            Thickness = 1,
            Transparency = 0.4,
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

    local titleLbl = new("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text             = winName,
        TextColor3       = S.text,
        FontFace         = Font.fromEnum(Enum.Font.GothamBold),
        TextSize         = 19,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextYAlignment   = Enum.TextYAlignment.Center,
        LayoutOrder      = 1,
    }, titleStack)
    new("UIStroke", {
        Color            = S.accentSoft,
        Thickness        = 1,
        Transparency     = 0.9,
    }, titleLbl)

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
        Size             = UDim2.new(0, 34, 0, 34),
        Position         = UDim2.new(1, -42, 0.5, -17),
        BackgroundColor3 = S.darkContrast,
        BackgroundTransparency = 0.35,
        Text             = "×",
        TextColor3       = S.muted,
        FontFace         = Font.fromEnum(Enum.Font.GothamMedium),
        TextSize         = 18,
        AutoButtonColor  = false,
        ZIndex           = 8,
    }, titlebar)
    corner(closeBtn, UDim.new(0, 10))
    new("UIStroke", {
        Color = S.border,
        Thickness = 1,
        Transparency = 0.5,
    }, closeBtn)
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            BackgroundColor3 = S.panelRaised,
            TextColor3 = S.accentGlow,
        })
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.35,
            BackgroundColor3 = S.darkContrast,
            TextColor3 = S.muted,
        })
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

    local bodyBottomPad = bodyTop + INNER_PAD
    local sidebarCol = new("Frame", {
        Name             = "SidebarColumn",
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(INNER_PAD, bodyTop),
        Size             = UDim2.new(0, SIDEBAR_W, 1, -bodyBottomPad),
        ZIndex           = 5,
        ClipsDescendants = false,
    }, main)

    local nextTabY = 14
    local sidebar = new("ScrollingFrame", {
        Name             = "Sidebar",
        BackgroundColor3 = S.grayContrast,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = showProfile and UDim2.new(1, 0, 1, -PROFILE_H) or UDim2.new(1, 0, 1, 0),
        CanvasSize       = UDim2.new(0, 0, 0, 200),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ZIndex           = 2,
    }, sidebarCol)

    new("UIPadding", {
        PaddingTop  = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 0),
    }, sidebar)

    local tabSelector = new("ImageLabel", {
        Name             = "Categoriesselector",
        BackgroundTransparency = 1,
        Position         = UDim2.fromOffset(8, nextTabY),
        Size             = UDim2.new(1, -16, 0, 32),
        Image            = SLICE_ASSET,
        ImageColor3      = S.panelRaised,
        ScaleType        = Enum.ScaleType.Slice,
        SliceCenter      = SLICE_RECT,
        SliceScale       = SLICE_SCALE,
        ZIndex           = 1,
    }, sidebar)
    new("UIStroke", {
        Color = S.strokeEtch,
        Thickness = 1,
        Transparency = 0.45,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, tabSelector)

    if showProfile then
        local tagText, tagColor = resolveUserProfileTag(cfg)
        local profilePanel = new("Frame", {
            Name             = "ProfileFooter",
            Position         = UDim2.new(0, 0, 1, -PROFILE_H),
            Size             = UDim2.new(1, 0, 0, PROFILE_H),
            BackgroundColor3 = S.sidebarFooter,
            BackgroundTransparency = 0,
            BorderSizePixel  = 0,
            ZIndex           = 20,
        }, sidebarCol)
        corner(profilePanel, UDim.new(0, 12))
        new("UIStroke", {
            Color = S.border,
            Thickness = 1,
            Transparency = 0.35,
        }, profilePanel)
        new("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 26, 30)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 14)),
            }),
        }, profilePanel)
        new("Frame", {
            Size             = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = S.accentSoft,
            BackgroundTransparency = 0.5,
            BorderSizePixel  = 0,
            ZIndex           = 1,
        }, profilePanel)

        local avWrap = new("Frame", {
            Size             = UDim2.fromOffset(54, 54),
            Position         = UDim2.new(0, 10, 0.5, -27),
            BackgroundColor3 = S.border,
            BorderSizePixel  = 0,
            ZIndex           = 3,
        }, profilePanel)
        corner(avWrap, UDim.new(1, 0))
        new("UIStroke", {
            Color = S.accentGlow,
            Thickness = 1,
            Transparency = 0.55,
        }, avWrap)

        local avImg = new("ImageLabel", {
            Name             = "Avatar",
            Size             = UDim2.new(1, -4, 1, -4),
            Position         = UDim2.fromScale(0.5, 0.5),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            BackgroundColor3 = S.charcoal,
            BorderSizePixel  = 0,
            BackgroundTransparency = 0,
            Image            = "",
            ScaleType        = Enum.ScaleType.Fit,
            ZIndex           = 4,
        }, avWrap)
        corner(avImg, UDim.new(1, 0))

        new("TextLabel", {
            Size             = UDim2.new(1, -82, 0, 18),
            Position         = UDim2.fromOffset(72, 12),
            BackgroundTransparency = 1,
            Text             = LocalPlayer.DisplayName,
            TextColor3       = S.text,
            FontFace         = Font.fromEnum(Enum.Font.GothamBold),
            TextSize         = 15,
            TextXAlignment   = Enum.TextXAlignment.Left,
            TextTruncate     = Enum.TextTruncate.AtEnd,
            ZIndex           = 3,
        }, profilePanel)
        new("TextLabel", {
            Size             = UDim2.new(1, -82, 0, 14),
            Position         = UDim2.fromOffset(72, 30),
            BackgroundTransparency = 1,
            Text             = "@" .. LocalPlayer.Name,
            TextColor3       = S.muted,
            FontFace         = Font.fromEnum(S.fontBody),
            TextSize         = 11,
            TextXAlignment   = Enum.TextXAlignment.Left,
            TextTruncate     = Enum.TextTruncate.AtEnd,
            ZIndex           = 3,
        }, profilePanel)

        local badgeRow = new("Frame", {
            AutomaticSize    = Enum.AutomaticSize.XY,
            Position         = UDim2.fromOffset(72, 50),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ZIndex           = 4,
        }, profilePanel)
        new("UIListLayout", {
            FillDirection     = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding           = UDim.new(0, 6),
            SortOrder         = Enum.SortOrder.LayoutOrder,
        }, badgeRow)

        if string.upper(tagText) == "DEV" and type(devBadgeImage) == "string" and devBadgeImage ~= "" then
            local devIcon = new("ImageLabel", {
                Size             = UDim2.fromOffset(18, 18),
                BackgroundTransparency = 1,
                Image            = devBadgeImage,
                ScaleType        = Enum.ScaleType.Fit,
                LayoutOrder      = 1,
                ZIndex           = 5,
            }, badgeRow)
            corner(devIcon, UDim.new(0, 4))
        end

        local badgeLbl = new("TextLabel", {
            AutomaticSize    = Enum.AutomaticSize.XY,
            BackgroundColor3 = tagColor,
            BorderSizePixel  = 0,
            Text             = string.upper(tagText),
            TextColor3       = S.text,
            FontFace         = Font.fromEnum(Enum.Font.GothamBold),
            TextSize         = 10,
            LayoutOrder      = 2,
            ZIndex           = 5,
        }, badgeRow)
        corner(badgeLbl, UDim.new(0, 8))
        new("UIPadding", {
            PaddingLeft   = UDim.new(0, 8),
            PaddingRight  = UDim.new(0, 8),
            PaddingTop    = UDim.new(0, 3),
            PaddingBottom = UDim.new(0, 3),
        }, badgeLbl)

        task.defer(function()
            local ok, url = pcall(function()
                return Players:GetUserThumbnailAsync(
                    LocalPlayer.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size180x180
                )
            end)
            if ok and type(url) == "string" and url ~= "" and avImg.Parent then
                avImg.Image = url
            end
        end)
    end

    local splitX = INNER_PAD + SIDEBAR_W
    new("Frame", {
        Size             = UDim2.new(0, 1, 1, -bodyBottomPad),
        Position         = UDim2.fromOffset(splitX, bodyTop),
        BackgroundColor3 = S.border,
        BorderSizePixel  = 0,
        ZIndex           = 4,
    }, main)

    local contentArea = new("Frame", {
        Size             = UDim2.new(1, -(splitX + 1 + INNER_PAD), 1, -bodyBottomPad),
        Position         = UDim2.fromOffset(splitX + 1, bodyTop),
        BackgroundColor3 = S.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 3,
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
                entry.btn.TextColor3 = isOn and S.accentGlow or S.muted
                if entry.wrap then
                    if isOn then
                        tween(entry.wrap, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            BackgroundTransparency = 0.25,
                            BackgroundColor3 = S.panelRaised,
                        })
                    else
                        tween(entry.wrap, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            BackgroundTransparency = 1,
                        })
                    end
                end
                if isOn and tabSelector and entry.tabY ~= nil then
                    tween(tabSelector, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
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
        nextTabY = nextTabY + 38
        sidebar.CanvasSize = UDim2.new(0, 0, 0, nextTabY + 16)

        local rowWrap = new("Frame", {
            Size             = UDim2.new(1, -16, 0, 32),
            Position         = UDim2.fromOffset(8, tabY),
            BackgroundTransparency = 1,
            BackgroundColor3 = S.panelRaised,
            BorderSizePixel  = 0,
            ZIndex           = 3,
        }, sidebar)
        corner(rowWrap, UDim.new(0, 10))

        local btn = new("TextButton", {
            Size             = UDim2.new(1, 0, 1, 0),
            Position         = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            Text             = tabText,
            TextColor3       = S.muted,
            FontFace         = Font.fromEnum(S.fontTitle),
            TextSize         = 14,
            TextXAlignment   = Enum.TextXAlignment.Left,
            TextYAlignment   = Enum.TextYAlignment.Center,
            AutoButtonColor  = false,
            ZIndex           = 4,
        }, rowWrap)

        new("UIPadding", {
            PaddingLeft  = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
        }, btn)

        tabs[tabName] = { wrap = rowWrap, btn = btn, tabY = tabY }

        rowWrap.MouseEnter:Connect(function()
            tween(rowWrap, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0.5,
                BackgroundColor3 = S.panelRaised,
            })
        end)
        rowWrap.MouseLeave:Connect(function()
            if activeTab == tabName then
                return
            end
            tween(rowWrap, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1,
            })
        end)

        -- Tab content frame with scrolling
        local tabFrame = new("ScrollingFrame", {
            Size             = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = S.accent,
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
                Size             = UDim2.new(1, 0, 0, 38),
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
            corner(imgBtn, S.radiusS)
            new("UIStroke", {
                Color = S.accent,
                Thickness = 1,
                Transparency = 0.68,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, imgBtn)

            local caption = new("TextLabel", {
                Size             = UDim2.new(1, -24, 1, 0),
                Position         = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text             = labelText,
                TextColor3       = S.text,
                FontFace         = Font.fromEnum(S.fontTitle),
                TextSize         = 14,
                TextXAlignment   = Enum.TextXAlignment.Left,
                TextYAlignment   = Enum.TextYAlignment.Center,
                Active           = false,
            }, imgBtn)

            imgBtn.MouseEnter:Connect(function()
                tween(imgBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    ImageColor3 = S.sectionTone,
                })
            end)
            imgBtn.MouseLeave:Connect(function()
                tween(imgBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    ImageColor3 = S.darkContrast,
                })
            end)

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
            corner(toggleBtn, S.radiusS)
            new("UIStroke", {
                Color = S.accent,
                Thickness = 1,
                Transparency = 0.72,
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
            corner(row, S.radiusS)
            new("UIStroke", {
                Color = S.accent,
                Thickness = 1,
                Transparency = 0.72,
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
            new("UIStroke", { Color = S.accent, Thickness = 1, Transparency = 0.35 }, sliderThumb)

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

        -- ── Section (moderne: accent-stribe + små caps) ───────
        function Tab:CreateSection(elCfg)
            elCfg = elCfg or {}
            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)

            local accentBar = new("Frame", {
                Size             = UDim2.new(0, 3, 0, 13),
                Position         = UDim2.fromOffset(0, 5),
                BackgroundColor3 = S.accent,
                BorderSizePixel  = 0,
            }, row)
            corner(accentBar, UDim.new(0, 2))
            new("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, S.accentSoft),
                    ColorSequenceKeypoint.new(1, S.accentGlow),
                }),
            }, accentBar)

            new("TextLabel", {
                Size             = UDim2.new(1, -14, 1, 0),
                Position         = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text             = string.upper(elCfg.Name or "SECTION"),
                TextColor3       = S.muted,
                FontFace         = Font.fromEnum(Enum.Font.GothamBold),
                TextSize         = 11,
                TextXAlignment   = Enum.TextXAlignment.Left,
                TextYAlignment   = Enum.TextYAlignment.Center,
                Active           = false,
            }, row)

            new("Frame", {
                Size             = UDim2.new(1, -12, 0, 1),
                Position         = UDim2.new(0, 12, 1, -1),
                BackgroundColor3 = S.border,
                BackgroundTransparency = 0.4,
                BorderSizePixel  = 0,
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

    do
        local tp = main.Position
        main.Position = UDim2.new(tp.X.Scale, tp.X.Offset, tp.Y.Scale, tp.Y.Offset + 32)
        tween(main, TweenInfo.new(0.48, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = tp,
        })
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
    Subtitle = "Powered by BlockUI",
    ToggleKey = Enum.KeyCode.RightControl,
    LogoImage = 74523675899900,
    -- Dit Roblox UserId (tal) — ikke det samme som et billede-id
    DeveloperUserIds = { 10770498428 },
    -- Lille ikon ved siden af “DEV” (rbxasset / tal)
    DevBadgeImage = 10770498428,
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
