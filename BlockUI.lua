--[[
    ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██╗
    ██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██║
    ██████╔╝██║     ██║   ██║██║     █████╔╝ ██║   ██║██║
    ██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██║
    ██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║
    ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝

    BlockUI v3.1.0 — Firkantet UI, resize (PC + touch), dropdown-overlay (ingen clipping)
    CreateWindow → Resizable, MinWindowSize, MaxWindowSize, WindowSize, LoadNotify, LogoImage, …

    Usage:
        local BlockUI = require(pathToModule)  -- eller dit loadstring-setup

    Docs / Elements:
        Window  → CreateTab
        Tab     → CreateButton, CreateToggle, CreateSlider,
                  CreateInput, CreateDropdown, CreateLabel
        BlockUI → Notify, LoadConfiguration, SaveConfiguration
        CreateWindow → ToggleKey, LogoImage, ShowProfile, DeveloperUserIds, DevBadgeImage, ProfileTag,
                       LoadNotify*, Resizable, MinWindowSize, MaxWindowSize, WindowSize (Vector2 / {w,h})
        Window → SetTitle, SetSubtitle, SetSize, SetPosition, GetSize, GetPosition, Minimize, IsMinimized
        VIGTIG: Kun én ToggleKey-linje i tabellen — gentagne nøgler overskrives (sidste vinder).
--]]

local BlockUI = {}
BlockUI.Flags = {}
BlockUI._windows = {}
BlockUI._configFile = nil

-- ── Services ────────────────────────────────────────────────
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer    = Players.LocalPlayer
local PlayerGui      = LocalPlayer:WaitForChild("PlayerGui")

-- Palette + spacing (ét samlet designsystem)
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
    radiusS        = UDim.new(0, 0),
    radiusM        = UDim.new(0, 0),
    border         = Color3.fromRGB(48, 50, 56),
    strokeEtch     = Color3.fromRGB(90, 92, 100),
    black          = Color3.fromRGB(6, 6, 8),
    row            = Color3.fromRGB(20, 21, 26),
    rowHover       = Color3.fromRGB(28, 29, 36),
    btn            = Color3.fromRGB(36, 38, 48),
    btnHover       = Color3.fromRGB(48, 50, 62),
    trackBg        = Color3.fromRGB(22, 23, 28),
    tabPill        = Color3.fromRGB(32, 34, 42),
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

local MAIN_W, MAIN_H = 748, 500
local SIDEBAR_W = 184
local PROFILE_H = 102
local TOP_STRIP = 2
local HEADER_H = 54
-- Firkantet chrome (0 = ingen afrunding; Dollarware-lignende “kasse”-look)
local CORNER_MAIN = UDim.new(0, 0)
local INNER_PAD = 12
local GAP = 10
local ROW_R = UDim.new(0, 0)
local function corner(inst, r)
    r = r or CORNER_MAIN
    if r.Scale == 0 and r.Offset == 0 then
        local old = inst:FindFirstChildOfClass("UICorner")
        if old then
            old:Destroy()
        end
        return
    end
    local c = inst:FindFirstChildOfClass("UICorner")
    if not c then
        c = Instance.new("UICorner")
        c.Parent = inst
    end
    c.CornerRadius = r
end

local function getViewportSize()
    local cam = workspace.CurrentCamera
    if cam then
        return cam.ViewportSize.X, cam.ViewportSize.Y
    end
    return 800, 600
end

local function inputIsPressStart(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function inputIsDrag(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
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
    local dragging = false
    local dragStart
    local startPos
    handle.InputBegan:Connect(function(input)
        if inputIsPressStart(input) then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and inputIsDrag(input) and input.UserInputState == Enum.UserInputState.Change then
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
    Size              = UDim2.new(0, 320, 1, 0),
    Position          = UDim2.new(1, -336, 0, 20),
    BackgroundTransparency = 1,
    AnchorPoint       = Vector2.new(0, 0),
}, notifGui)

new("UIListLayout", {
    SortOrder         = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding           = UDim.new(0, GAP),
    FillDirection     = Enum.FillDirection.Vertical,
}, notifHolder)

function BlockUI:Notify(cfg)
    cfg = cfg or {}
    local title    = cfg.Title    or "Notifikation"
    local content  = cfg.Content  or ""
    local ntype    = cfg.Type     or "info"
    local duration = cfg.Duration or 4.2

    local accentCol = ntype == "success" and S.success
                   or ntype == "warning" and S.warning
                   or ntype == "error"   and S.danger
                   or S.accentGlow

    local card = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundColor3 = S.bgLift,
        BackgroundTransparency = 0.08,
        BorderSizePixel  = 0,
    }, notifHolder)
    corner(card, CORNER_MAIN)
    new("UIStroke", {
        Color = S.border,
        Thickness = 1,
        Transparency = 0.55,
    }, card)

    new("UIListLayout", {
        SortOrder       = Enum.SortOrder.LayoutOrder,
        Padding         = UDim.new(0, 0),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, card)

    local stripe = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = accentCol,
        BorderSizePixel  = 0,
        LayoutOrder      = 0,
    }, card)
    corner(stripe, CORNER_MAIN)

    local body = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        LayoutOrder      = 1,
    }, card)

    new("UIPadding", {
        PaddingTop    = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft   = UDim.new(0, 16),
        PaddingRight  = UDim.new(0, 16),
    }, body)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 4),
    }, body)

    local t1 = new("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text             = title,
        TextColor3       = S.text,
        FontFace         = Font.fromEnum(Enum.Font.GothamBold),
        TextSize         = 15,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextWrapped      = true,
        LayoutOrder      = 1,
    }, body)

    local t2 = new("TextLabel", {
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
    }, body)

    t1.TextTransparency = 1
    t2.TextTransparency = 1
    card.BackgroundTransparency = 1
    stripe.BackgroundTransparency = 1

    card.Position = UDim2.new(1, 40, 0, 0)
    tween(card, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0.08,
    })
    tween(stripe, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
    })
    tween(t1, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
    tween(t2, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })

    task.delay(duration, function()
        if not card.Parent then
            return
        end
        tween(card, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 48, 0, 0),
            BackgroundTransparency = 1,
        })
        tween(stripe, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
        })
        tween(t1, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
        tween(t2, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
        task.wait(0.28)
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

    local vw, vh = getViewportSize()
    local minWin = cfg.MinWindowSize
    if typeof(minWin) == "Vector2" then
        minWin = { math.max(200, math.floor(minWin.X)), math.max(160, math.floor(minWin.Y)) }
    elseif type(minWin) == "table" and minWin[1] and minWin[2] then
        minWin = { math.max(200, math.floor(minWin[1])), math.max(160, math.floor(minWin[2])) }
    else
        minWin = { 320, 220 }
    end
    local maxWin = cfg.MaxWindowSize
    if typeof(maxWin) == "Vector2" then
        maxWin = { math.floor(maxWin.X), math.floor(maxWin.Y) }
    elseif type(maxWin) == "table" and maxWin[1] and maxWin[2] then
        maxWin = { math.floor(maxWin[1]), math.floor(maxWin[2]) }
    else
        maxWin = { math.max(minWin[1], vw - 12), math.max(minWin[2], vh - 12) }
    end
    local initW, initH = MAIN_W, MAIN_H
    local ws = cfg.WindowSize
    if typeof(ws) == "Vector2" then
        initW, initH = math.floor(ws.X), math.floor(ws.Y)
    elseif type(ws) == "table" then
        initW = math.floor(ws[1] or ws.x or initW)
        initH = math.floor(ws[2] or ws.y or initH)
    else
        initW = math.clamp(math.floor(vw * 0.92), minWin[1], maxWin[1])
        initH = math.clamp(math.floor(vh * 0.88), minWin[2], maxWin[2])
        initW = math.min(initW, 748)
        initH = math.min(initH, 560)
    end
    initW = math.clamp(initW, minWin[1], maxWin[1])
    initH = math.clamp(initH, minWin[2], maxWin[2])

    local headerH = (winSub ~= "") and 58 or HEADER_H
    local bodyTop = TOP_STRIP + headerH
    local showProfile = cfg.ShowProfile ~= false
    local resizable = cfg.Resizable ~= false

    -- Dropdowns / overlays klippes ikke af scroll (Dollarware-lignende flytning til top-lag)
    local dropHost = new("Frame", {
        Name             = "BlockUI_DropHost",
        Size             = UDim2.fromScale(1, 1),
        Position         = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex           = 800,
        Active           = false,
        Selectable       = false,
    }, gui)
    local dropBackdrop = new("TextButton", {
        Name             = "DropBackdrop",
        Size             = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text             = "",
        AutoButtonColor  = false,
        ZIndex           = 1,
        Visible          = false,
    }, dropHost)
    local activeDropdownClose = nil
    dropBackdrop.MouseButton1Click:Connect(function()
        if activeDropdownClose then
            local fn = activeDropdownClose
            activeDropdownClose = nil
            fn()
        end
        dropBackdrop.Visible = false
    end)

    local main = new("Frame", {
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = UDim2.fromOffset(initW, initH),
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
    corner(headerGlow, CORNER_MAIN)

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
        corner(logoHolder, CORNER_MAIN)
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

    local subtitleLbl = nil
    if winSub ~= "" then
        subtitleLbl = new("TextLabel", {
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

    local minBtn = new("TextButton", {
        Size             = UDim2.new(0, 34, 0, 34),
        Position         = UDim2.new(1, -80, 0.5, -17),
        BackgroundColor3 = S.darkContrast,
        BackgroundTransparency = 0.35,
        Text             = "−",
        TextColor3       = S.muted,
        FontFace         = Font.fromEnum(Enum.Font.GothamMedium),
        TextSize         = 20,
        AutoButtonColor  = false,
        ZIndex           = 8,
    }, titlebar)
    corner(minBtn, CORNER_MAIN)
    new("UIStroke", {
        Color = S.border,
        Thickness = 1,
        Transparency = 0.5,
    }, minBtn)
    minBtn.MouseEnter:Connect(function()
        tween(minBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            BackgroundColor3 = S.panelRaised,
            TextColor3 = S.accentGlow,
        })
    end)
    minBtn.MouseLeave:Connect(function()
        tween(minBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.35,
            BackgroundColor3 = S.darkContrast,
            TextColor3 = S.muted,
        })
    end)
    if cfg.ShowMinButton == false then
        minBtn.Visible = false
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
    corner(closeBtn, CORNER_MAIN)
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

    local tabSelector = new("Frame", {
        Name             = "Categoriesselector",
        BackgroundColor3 = S.tabPill,
        BackgroundTransparency = 0.2,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(8, nextTabY),
        Size             = UDim2.new(1, -16, 0, 32),
        ZIndex           = 1,
    }, sidebar)
    corner(tabSelector, ROW_R)
    new("UIStroke", {
        Color = S.strokeEtch,
        Thickness = 1,
        Transparency = 0.5,
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
        corner(profilePanel, CORNER_MAIN)
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
        corner(avWrap, CORNER_MAIN)
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
        corner(avImg, CORNER_MAIN)

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
            corner(devIcon, CORNER_MAIN)
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
        corner(badgeLbl, CORNER_MAIN)
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
    local splitBar = new("Frame", {
        Name             = "SplitBar",
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
        -- false: dropdowns m.m. må ikke klippes (scroll + overlay)
        ClipsDescendants = false,
        ZIndex           = 3,
    }, main)

    local savedRestoreW, savedRestoreH = initW, initH
    local hubMinimized = false

    local resizeGrip = new("TextButton", {
        Name             = "ResizeGrip",
        Size             = UDim2.fromOffset(18, 18),
        Position         = UDim2.new(1, -18, 1, -18),
        BackgroundColor3 = S.btn,
        BackgroundTransparency = 0.2,
        Text             = "",
        AutoButtonColor  = false,
        ZIndex           = 60,
    }, main)
    corner(resizeGrip, CORNER_MAIN)
    new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.55 }, resizeGrip)
    if not resizable then
        resizeGrip.Visible = false
    end

    local sizing = false
    local sizeStartPos
    local sizeStartMain
    resizeGrip.InputBegan:Connect(function(input)
        if not resizable or hubMinimized then
            return
        end
        if inputIsPressStart(input) then
            sizing = true
            sizeStartPos = input.Position
            sizeStartMain = main.AbsoluteSize
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sizing = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not sizing or not inputIsDrag(input) or input.UserInputState ~= Enum.UserInputState.Change then
            return
        end
        local delta = input.Position - sizeStartPos
        local nw = math.clamp(sizeStartMain.X + delta.X, minWin[1], maxWin[1])
        local nh = math.clamp(sizeStartMain.Y + delta.Y, minWin[2], maxWin[2])
        main.Size = UDim2.fromOffset(nw, nh)
        savedRestoreW, savedRestoreH = nw, nh
    end)

    local function applyHubMinimize(on)
        hubMinimized = on
        if on then
            savedRestoreW = main.AbsoluteSize.X
            savedRestoreH = main.AbsoluteSize.Y
            sidebarCol.Visible = false
            contentArea.Visible = false
            splitBar.Visible = false
            resizeGrip.Visible = false
            main.Size = UDim2.fromOffset(savedRestoreW, bodyTop + INNER_PAD)
        else
            sidebarCol.Visible = true
            contentArea.Visible = true
            splitBar.Visible = true
            resizeGrip.Visible = resizable
            main.Size = UDim2.fromOffset(savedRestoreW, savedRestoreH)
        end
    end

    if cfg.ShowMinButton ~= false then
        minBtn.MouseButton1Click:Connect(function()
            applyHubMinimize(not hubMinimized)
        end)
    end

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
        corner(rowWrap, ROW_R)

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
            Padding          = UDim.new(0, GAP),
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

        -- ── Button (kort med UICorner) ─────────────────────────
        function Tab:CreateButton(elCfg)
            elCfg = elCfg or {}
            local storedIcon = elCfg.Icon
            local storedName = elCfg.Name or "Button"
            local storedButtonText = elCfg.ButtonText
            local function buildButtonCaption()
                local iconPrefix = (storedIcon and storedIcon ~= "") and (storedIcon .. "  ") or ""
                local t = iconPrefix .. storedName
                if storedButtonText and storedButtonText ~= "" then
                    t = t .. "  ·  " .. tostring(storedButtonText)
                end
                return t
            end

            local imgBtn = new("TextButton", {
                Size             = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = S.btn,
                BackgroundTransparency = 0,
                BorderSizePixel  = 0,
                Text             = "",
                AutoButtonColor  = false,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            corner(imgBtn, ROW_R)
            new("UIStroke", {
                Color = S.border,
                Thickness = 1,
                Transparency = 0.55,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, imgBtn)

            local caption = new("TextLabel", {
                Size             = UDim2.new(1, -24, 1, 0),
                Position         = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text             = buildButtonCaption(),
                TextColor3       = S.text,
                FontFace         = Font.fromEnum(S.fontTitle),
                TextSize         = 14,
                TextXAlignment   = Enum.TextXAlignment.Left,
                TextYAlignment   = Enum.TextYAlignment.Center,
                Active           = false,
            }, imgBtn)

            imgBtn.MouseEnter:Connect(function()
                tween(imgBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = S.btnHover,
                })
            end)
            imgBtn.MouseLeave:Connect(function()
                tween(imgBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = S.btn,
                })
            end)

            imgBtn.MouseButton1Click:Connect(function()
                runCallback(elCfg.Callback)
            end)

            local Button = {}
            function Button:Set(name, buttonText)
                if name ~= nil then
                    storedName = tostring(name)
                end
                if buttonText ~= nil then
                    storedButtonText = buttonText
                end
                caption.Text = buildButtonCaption()
            end
            function Button:SetIcon(icon)
                storedIcon = icon
                caption.Text = buildButtonCaption()
            end
            return Button
        end

        -- ── Toggle (række + pill-switch) ───────────────────────
        function Tab:CreateToggle(elCfg)
            elCfg = elCfg or {}
            local flag = elCfg.Flag
            local value = elCfg.CurrentValue or false
            if flag then BlockUI.Flags[flag] = value end

            local rowH = elCfg.Description and 58 or 40
            local toggleBtn = new("TextButton", {
                Size             = UDim2.new(1, 0, 0, rowH),
                BackgroundColor3 = S.row,
                BackgroundTransparency = 0,
                BorderSizePixel  = 0,
                Text             = "",
                AutoButtonColor  = false,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            corner(toggleBtn, ROW_R)
            new("UIStroke", {
                Color = S.border,
                Thickness = 1,
                Transparency = 0.55,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, toggleBtn)

            local iconT = (elCfg.Icon and elCfg.Icon ~= "") and (elCfg.Icon .. "  ") or ""
            local titleY = elCfg.Description and 8 or 0
            new("TextLabel", {
                Size             = UDim2.new(1, -80, 0, 22),
                Position         = UDim2.new(0, 14, 0, titleY + (elCfg.Description and 0 or 9)),
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
                    Position         = UDim2.fromOffset(14, 32),
                    BackgroundTransparency = 1,
                    Text             = elCfg.Description,
                    TextColor3       = S.muted,
                    FontFace         = Font.fromEnum(S.fontBody),
                    TextSize         = 11,
                    TextXAlignment   = Enum.TextXAlignment.Left,
                    Active           = false,
                }, toggleBtn)
            end

            local toggleBack = new("Frame", {
                Size             = UDim2.new(0, 52, 0, 28),
                Position         = UDim2.new(1, -66, 0.5, -14),
                BackgroundColor3 = S.trackBg,
                BorderSizePixel  = 0,
                Active           = false,
            }, toggleBtn)
            corner(toggleBack, CORNER_MAIN)
            new("UIStroke", {
                Color = S.border,
                Thickness = 1,
                Transparency = 0.45,
            }, toggleBack)

            local toggleKnob = new("Frame", {
                Size             = UDim2.new(0, 22, 0, 22),
                Position         = UDim2.fromOffset(3, 3),
                BackgroundColor3 = Color3.fromRGB(200, 200, 208),
                BorderSizePixel  = 0,
            }, toggleBack)
            corner(toggleKnob, CORNER_MAIN)
            new("UIStroke", {
                Color = S.accentSoft,
                Thickness = 1,
                Transparency = 0.4,
            }, toggleKnob)

            local function setState(val, silent)
                value = val
                if flag then BlockUI.Flags[flag] = val end
                if val then
                    tween(toggleBack, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundColor3 = S.toggleOn,
                    })
                    tween(toggleKnob, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(27, 3),
                        BackgroundColor3 = S.toggleThumb,
                    })
                else
                    tween(toggleBack, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundColor3 = S.trackBg,
                    })
                    tween(toggleKnob, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.fromOffset(3, 3),
                        BackgroundColor3 = Color3.fromRGB(200, 200, 208),
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

            local row = new("Frame", {
                Size             = UDim2.new(1, 0, 0, 66),
                BackgroundColor3 = S.row,
                BorderSizePixel  = 0,
                LayoutOrder      = nextOrder(),
            }, tabFrame)
            corner(row, ROW_R)
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
                Position         = UDim2.fromOffset(14, 42),
                BackgroundColor3 = S.trackBg,
                BorderSizePixel  = 0,
            }, row)
            corner(trackBg, CORNER_MAIN)

            -- Fill
            local fill = new("Frame", {
                Size             = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = S.fluentBlue,
                BorderSizePixel  = 0,
            }, trackBg)
            corner(fill, CORNER_MAIN)

            -- Thumb
            local sliderThumb = new("Frame", {
                Size             = UDim2.new(0, 14, 0, 14),
                AnchorPoint      = Vector2.new(0.5, 0.5),
                Position         = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = S.text,
                BorderSizePixel  = 0,
            }, trackBg)
            corner(sliderThumb, CORNER_MAIN)
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
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = true
                    sliderFromInput(inp)
                end
            end)
            sliderThumb.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = true
                    sliderFromInput(inp)
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = false
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if draggingSlider and inputIsDrag(inp) then
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
            corner(selBtn, CORNER_MAIN)

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

            -- Liste i ScreenGui-lag — ikke klippet af ScrollingFrame (Dollarware-stil)
            local dropList = new("Frame", {
                Size             = UDim2.fromOffset(120, 0),
                Position         = UDim2.fromOffset(0, 0),
                BackgroundColor3 = S.surface2,
                BorderSizePixel  = 0,
                Visible          = false,
                ZIndex           = 50,
            }, dropHost)
            new("UIStroke", { Color = S.border, Thickness = 1, Transparency = 0.25 }, dropList)
            corner(dropList, CORNER_MAIN)
            new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, dropList)

            local isOpen = false
            local canvasScrollConn = nil

            local closeDropdown
            local function positionDropList()
                if not selBtn.Parent then
                    return
                end
                local hp = dropHost.AbsolutePosition
                local ap = selBtn.AbsolutePosition
                local as = selBtn.AbsoluteSize
                local rows = math.max(0, #options)
                if rows < 1 then
                    rows = 1
                end
                dropList.Size = UDim2.fromOffset(math.max(72, math.floor(as.X)), rows * 28)
                dropList.Position = UDim2.fromOffset(
                    math.floor(ap.X - hp.X),
                    math.floor(ap.Y - hp.Y + as.Y)
                )
            end

            closeDropdown = function()
                if not isOpen then
                    return
                end
                isOpen = false
                dropList.Visible = false
                dropBackdrop.Visible = false
                if activeDropdownClose == closeDropdown then
                    activeDropdownClose = nil
                end
                if canvasScrollConn then
                    canvasScrollConn:Disconnect()
                    canvasScrollConn = nil
                end
            end

            local function openDropdown()
                if #options < 1 then
                    return
                end
                if activeDropdownClose and activeDropdownClose ~= closeDropdown then
                    activeDropdownClose()
                end
                isOpen = true
                activeDropdownClose = closeDropdown
                dropBackdrop.Visible = true
                positionDropList()
                dropList.Visible = true
                if canvasScrollConn then
                    canvasScrollConn:Disconnect()
                end
                canvasScrollConn = tabFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(positionDropList)
            end

            local function refreshOptions(opts)
                options = opts
                for _, c in pairs(dropList:GetChildren()) do
                    if c:IsA("TextButton") then
                        c:Destroy()
                    end
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
                        ZIndex           = 55,
                    }, dropList)
                    new("Frame", {
                        Size             = UDim2.new(1, 0, 0, 1),
                        Position         = UDim2.new(0, 0, 1, -1),
                        BackgroundColor3 = S.border,
                        BorderSizePixel  = 0,
                        ZIndex           = 54,
                    }, optBtn)
                    optBtn.MouseEnter:Connect(function()
                        tween(optBtn, TweenInfo.new(0.08), { BackgroundColor3 = S.surface })
                    end)
                    optBtn.MouseLeave:Connect(function()
                        tween(optBtn, TweenInfo.new(0.08), { BackgroundColor3 = S.surface2 })
                    end)
                    optBtn.MouseButton1Click:Connect(function()
                        if multi then
                            local idx = table.find(selected, opt)
                            if idx then
                                table.remove(selected, idx)
                            else
                                table.insert(selected, opt)
                            end
                        else
                            selected = { opt }
                            closeDropdown()
                        end
                        selLabel.Text = #selected > 0 and table.concat(selected, ", ") or "—"
                        if flag then
                            BlockUI.Flags[flag] = selected
                        end
                        runCallback(elCfg.Callback, selected)
                    end)
                end
                if isOpen then
                    positionDropList()
                end
            end

            refreshOptions(options)

            selBtn.MouseButton1Click:Connect(function()
                if isOpen then
                    closeDropdown()
                else
                    openDropdown()
                end
            end)

            local Dropdown = {}
            function Dropdown:Refresh(opts)
                refreshOptions(opts)
                if isOpen then
                    positionDropList()
                end
            end
            function Dropdown:Set(opts)
                selected = opts
                selLabel.Text = #selected > 0 and table.concat(selected, ", ") or "—"
                if flag then
                    BlockUI.Flags[flag] = selected
                end
                runCallback(elCfg.Callback, selected)
                if isOpen then
                    positionDropList()
                end
            end
            function Dropdown:Close()
                closeDropdown()
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
            corner(accentBar, CORNER_MAIN)
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

    function Window:SetTitle(text)
        titleLbl.Text = tostring(text)
    end

    function Window:SetSubtitle(text)
        local s = tostring(text or "")
        if subtitleLbl then
            subtitleLbl.Text = s
            subtitleLbl.Visible = s ~= ""
        elseif s ~= "" then
            warn("[BlockUI] SetSubtitle: vinduet har ingen undertitel — sæt Subtitle i CreateWindow først.")
        end
    end

    function Window:SetSize(width, height)
        local w = math.clamp(math.floor(width), minWin[1], maxWin[1])
        local h = math.clamp(math.floor(height), minWin[2], maxWin[2])
        main.Size = UDim2.fromOffset(w, h)
        if not hubMinimized then
            savedRestoreW, savedRestoreH = w, h
        end
    end

    function Window:SetPosition(x, y)
        if typeof(x) == "UDim2" then
            main.Position = x
            return
        end
        main.Position = UDim2.new(0.5, math.floor(x), 0.5, math.floor(y))
    end

    function Window:GetSize()
        local s = main.AbsoluteSize
        return s.X, s.Y
    end

    function Window:GetPosition()
        local p = main.AbsolutePosition
        local s = main.AbsoluteSize
        return p.X + s.X * 0.5, p.Y + s.Y * 0.5
    end

    function Window:Minimize(min)
        if min == nil then
            applyHubMinimize(not hubMinimized)
        else
            applyHubMinimize(min and true or false)
        end
    end

    function Window:IsMinimized()
        return hubMinimized
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

    if cfg.LoadNotify ~= false then
        task.defer(function()
            if not gui.Parent then
                return
            end
            local dur = cfg.LoadNotifyDuration
            if type(dur) ~= "number" then
                dur = 4.5
            end
            BlockUI:Notify({
                Title    = cfg.LoadNotifyTitle or winName,
                Content  = cfg.LoadNotifyText or "Scriptet er klar.",
                Type     = cfg.LoadNotifyType or "success",
                Duration = dur,
            })
        end)
    end

    table.insert(BlockUI._windows, Window)
    return Window
end

-- ── Done ─────────────────────────────────────────────────────
return BlockUI

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EKSEMPEL — dækker hele API’et
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  BlockUI:CreateWindow       → Name, Subtitle, ToggleKey, LogoImage,
                               ShowProfile, DeveloperUserIds, DevBadgeImage,
                               ProfileTag, ProfileTagColor,
                               LoadNotify*, ConfigurationSaving,
                               Resizable, MinWindowSize, MaxWindowSize, WindowSize,
                               ShowMinButton (default true)
  Window:CreateTab           → Name, Icon
  Window:SetTitle, SetSubtitle, SetSize, SetPosition, GetSize, GetPosition,
           Minimize, IsMinimized, SetEnabled, Toggle
  Tab:CreateSection, CreateLabel, CreateButton, CreateToggle, CreateSlider,
      CreateInput, CreateDropdown
  Retur: Button:Set(name, buttonText?), Button:SetIcon(icon)
         Toggle/Slider/Input/Label :Set …
         Dropdown:Refresh, :Set, :Close
  BlockUI:Notify, SaveConfiguration, LoadConfiguration

  UI er firkantet; resize nederst til højre (mus + touch). Dropdown åbner i top-lag.
  Inspireret af funktioner fra Dollarware (topitbopit) — ikke 1:1 samme kode/API.

  Raw-URL: https://raw.githubusercontent.com/GulleDK11/rflhub/main/BlockUI.lua
  Kun én nøgle per felt i tabeller — fx kun én linje ToggleKey.

local BlockUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/GulleDK11/rflhub/main/BlockUI.lua"))()
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local function getHumanoid()
    local ch = lp.Character
    return ch and ch:FindFirstChildWhichIsA("Humanoid")
end

local Window = BlockUI:CreateWindow({
    Name     = "Mit Script",
    Subtitle = "Komplet BlockUI-demo",
    -- Vindue: standard ~92% viewport (mobil/PC); eller fast størrelse:
    -- WindowSize = Vector2.new(520, 400),
    -- MinWindowSize = { 300, 200 },
    -- MaxWindowSize = { 900, 700 },
    -- Resizable = false,
    -- ShowMinButton = false,
    -- Én tast, flere taster, eller ingen GUI-toggle:
    ToggleKey = Enum.KeyCode.RightControl,
    -- ToggleKey = { Enum.KeyCode.Insert, Enum.KeyCode.RightControl },
    -- ToggleKey = false,
    LoadNotifyTitle    = "Klar",
    LoadNotifyText     = "Hubben er indlæst — alle elementer nedenfor er API-demo.",
    LoadNotifyDuration = 5,
    LoadNotifyType     = "success", -- "info" | "warning" | "error"
    -- LoadNotify = false,
    LogoImage = 74523675899900,
    ShowProfile = true,
    -- Skjul profilfooter: ShowProfile = false,
    -- Erstat med dit UserId for “Dev”-badge (liste):
    DeveloperUserIds = { 10770498428 },
    -- Lille billede ved siden af DEV (tal = rbxassetid):
    DevBadgeImage = 74523675899900,
    -- Manuel badge i stedet for Member/Premium/Dev:
    -- ProfileTag = "VIP",
    -- ProfileTagColor = Color3.fromRGB(200, 160, 70),
    -- Kræver writefile/readfile i din executor:
    -- ConfigurationSaving = { Enabled = true, FileName = "MyHub_BlockUI" },
})

-- Efter alle faner/flags er oprettet (valgfrit):
-- BlockUI:LoadConfiguration()

-- Window:SetTitle("Nyt navn")
-- Window:SetSize(600, 420)
-- Window:Minimize()  -- eller Window:Minimize(true/false)

local Main = Window:CreateTab({ Name = "Main" })
local Visuals = Window:CreateTab({ Name = "Visuals", Icon = "◇" })

-- ── Sektion + movement (Toggle, Slider, Flag, Callback) ─────
Main:CreateSection({ Name = "Movement" })

local speedToggle = Main:CreateToggle({
    Name         = "Speed Hack",
    Description  = "Brug slideren når denne er tændt",
    Icon         = "»",
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

local walkSlider = Main:CreateSlider({
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

Main:CreateSection({ Name = "Knapper" })

Main:CreateButton({
    Name       = "Teleport til spawn",
    Icon       = "◎",
    ButtonText = "0, 5, 0",
    Callback   = function()
        local ch = lp.Character
        if ch then
            ch:MoveTo(Vector3.new(0, 5, 0))
            BlockUI:Notify({
                Title    = "Teleporteret",
                Content  = "Du er ved spawnen.",
                Type     = "success",
                Duration = 3,
            })
        end
    end,
})

-- Button:Set("ny tekst") — opdaterer synlig label
local renameDemo = Main:CreateButton({
    Name     = "Klik for at omdøbe knappen",
    ButtonText = "demo",
    Callback = function()
        renameDemo:Set("Omdøbt", "script ✓")
    end,
})

Main:CreateButton({
    Name     = "Nulstil speed-toggle",
    Callback = function()
        speedToggle:Set(false)
    end,
})

Main:CreateButton({
    Name     = "Sæt walk speed-slider til 50",
    Callback = function()
        walkSlider:Set(50)
    end,
})

-- ── Notify-typer + Window API (udkommentér og bind til tast) ─
Main:CreateButton({
    Name     = "Vis info / advarsel / fejl-notify",
    Callback = function()
        BlockUI:Notify({ Title = "Info", Content = "Almindelig besked.", Type = "info", Duration = 2.5 })
        task.delay(0.35, function()
            BlockUI:Notify({ Title = "Advarsel", Content = "Eksempel.", Type = "warning", Duration = 2.5 })
        end)
        task.delay(0.7, function()
            BlockUI:Notify({ Title = "Fejl", Content = "Kun demo.", Type = "error", Duration = 2.5 })
        end)
    end,
})

--[[
    Window:SetEnabled(false)  -- skjul hele hubben
    Window:Toggle()           -- skjul/vis
]]

-- ── Label, Input, Dropdown (én + multi) ─────────────────────
Visuals:CreateSection({ Name = "Formular & lister" })

local statusLabel = Visuals:CreateLabel({
    Text = "Skriv i feltet nedenfor — label opdateres via :Set()",
})

local noteInput = Visuals:CreateInput({
    Name                  = "Notat",
    PlaceholderText       = "Skriv her…",
    CurrentValue          = "",
    Flag                  = "DemoNote",
    Callback              = function(text)
        statusLabel:Set(#text > 0 and ("Gemt: " .. text) or "Tomt notat.")
    end,
    -- RemoveTextAfterFocusLost = true,
})

Visuals:CreateButton({
    Name     = "Sæt input-tekst fra script",
    Callback = function()
        noteInput:Set("Sat via Input:Set()")
    end,
})

Visuals:CreateDropdown({
    Name           = "Enkeltvalg",
    Options        = { "Standard", "Høj kontrast", "Kompakt" },
    CurrentOption  = { "Standard" },
    Flag           = "DemoTheme",
    Callback       = function(selected)
        BlockUI:Notify({
            Title    = "Tema",
            Content  = table.concat(selected, ", "),
            Type     = "info",
            Duration = 2,
        })
    end,
})

local multiDrop = Visuals:CreateDropdown({
    Name              = "Flere valg",
    Options           = { "A", "B", "C" },
    CurrentOption     = {},
    MultipleOptions   = true,
    Flag              = "DemoTags",
    Callback          = function(selected)
        statusLabel:Set("Valgt: " .. (#selected > 0 and table.concat(selected, ", ") or "(ingen)"))
    end,
})

Visuals:CreateButton({
    Name     = "Dropdown:Refresh + :Set demo",
    Callback = function()
        multiDrop:Refresh({ "Nord", "Syd", "Øst", "Vest" })
        multiDrop:Set({ "Nord", "Vest" })
    end,
})

Visuals:CreateButton({
    Name     = "Gem flags til fil (ConfigurationSaving)",
    Callback = function()
        BlockUI:SaveConfiguration()
        BlockUI:Notify({
            Title    = "Config",
            Content  = "SaveConfiguration kørt (virker kun med fil-API i executor).",
            Type     = "info",
        })
    end,
})
]]
