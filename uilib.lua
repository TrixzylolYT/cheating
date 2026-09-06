--[[
    ModernUI v2.0 — by oTrixzy
    ----------------------------------------
    Window:
        ModernUI:CreateWindow({ Title = "...", ToggleKey = Enum.KeyCode.RightShift, Size = UDim2.fromOffset(560, 380), ConfigFolder = "MyConfigs" })
        Window:CreateTab(name, iconEmoji?)          -> Tab
        Window:AddConfigTab(name?)                  -> built-in save/load tab
        Window:Show() / Window:Hide() / Window:Toggle() / Window:Destroy()

    Elements (Tab methods):
        Tab:CreateSection(title)
        Tab:CreateDivider()
        Tab:CreateLabel(text)                       -> { Set(text) }
        Tab:CreateParagraph(title, body)
        Tab:CreateButton(text, callback)
        Tab:CreateToggle(text, default, callback, flag?)    -> { Set, Get }
        Tab:CreateSlider(text, min, max, default, step, callback, flag?) -> { Set, Get }
        Tab:CreateDropdown(text, options, default, callback, multiSelect?, flag?) -> { Set, Get, Refresh }
        Tab:CreateTextbox(text, placeholder, default, callback, flag?)   -> { Set, Get }
        Tab:CreateKeybind(text, defaultKey, callback, flag?)             -> { Set, Get }
        Tab:CreateColorPicker(text, default, callback, flag?)            -> { Set, Get }

    Extras:
        ModernUI:Notify({ Title = "...", Text = "...", Type = "info"|"success"|"warn"|"error", Duration = 4 })
        ModernUI:SaveConfig(name) / ModernUI:LoadConfig(name) / ModernUI:GetConfigs() / ModernUI:DeleteConfig(name)
        ModernUI.Theme.Accent = Color3.new(...)  (edit any theme color before CreateWindow)
]]

local ModernUI = {}
ModernUI.Version = "2.0"
ModernUI.ConfigFolder = "ModernUI_Configs"

--// Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

--// Theme (edit before creating a window)
ModernUI.Theme = {
    Font        = Enum.Font.Gotham,
    FontMedium  = Enum.Font.GothamMedium,
    FontSemi    = Enum.Font.GothamSemibold,
    FontBold    = Enum.Font.GothamBold,

    Background  = Color3.fromRGB(22, 22, 28),
    Sidebar     = Color3.fromRGB(17, 17, 22),
    Topbar      = Color3.fromRGB(26, 26, 33),
    Secondary   = Color3.fromRGB(28, 28, 36),
    Element     = Color3.fromRGB(37, 37, 46),
    ElementHover= Color3.fromRGB(45, 45, 56),
    Input       = Color3.fromRGB(31, 31, 39),
    Outline     = Color3.fromRGB(52, 52, 64),
    ToggleOff   = Color3.fromRGB(70, 70, 84),
    SliderTrack = Color3.fromRGB(60, 60, 72),

    Accent      = Color3.fromRGB(88, 101, 242),
    AccentDark  = Color3.fromRGB(66, 78, 190),

    Text        = Color3.fromRGB(235, 235, 240),
    SubText     = Color3.fromRGB(150, 150, 162),
}

local T = ModernUI.Theme

--// Safe GUI parent
local cachedParent
local function getGuiParent()
    if cachedParent then return cachedParent end
    local target = game:GetService("CoreGui")
    pcall(function()
        if gethui then target = gethui() end
    end)
    if not pcall(function() return target.Name end) then
        target = LocalPlayer:WaitForChild("PlayerGui")
    end
    cachedParent = target
    return cachedParent
end

--// Helpers
local function new(class, props)
    local inst = Instance.new(class)
    local parent = nil
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then parent = v else inst[k] = v end
        end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or T.Outline,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        Parent = parent,
    })
end

local function pad(parent, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
        PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
        Parent = parent,
    })
end

local function tween(obj, ti, goal, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(ti or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), goal)
    t:Play()
    return t
end

local function accentGradient(parent)
    return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.Accent, T.AccentDark), Parent = parent })
end

local function isClick(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function makeDraggable(target, handle)
    local dragging = false
    local dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if isClick(input) then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

--// Flag registry (for config saving)
ModernUI._Registry = {}
local Registry = ModernUI._Registry

local function registerFlag(flag, ctrl)
    if type(flag) == "string" and flag ~= "" then
        Registry[flag] = ctrl
    end
end

--//====================================================================--
--// NOTIFICATIONS
--//====================================================================--

local notifGui, notifContainer
local activeNotifs = {}

local function ensureNotifContainer()
    if notifGui and notifGui.Parent then return end
    notifGui = new("ScreenGui", {
        Name = "ModernUI_Notifications",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 1000,
        Parent = getGuiParent(),
    })
    notifContainer = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.new(0, 290, 1, -28),
        BackgroundTransparency = 1,
        Parent = notifGui,
    })
end

local function relayoutNotifs()
    local y = 0
    for _, n in ipairs(activeNotifs) do
        local target = UDim2.new(0, 0, 0, y)
        tween(n.Frame, 0.25, { Position = target })
        y = y + n.Frame.AbsoluteSize.Y + 8
    end
end

function ModernUI:Notify(cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    cfg = cfg or {}
    ensureNotifContainer()

    local typeColors = {
        info = T.Accent,
        success = Color3.fromRGB(70, 200, 120),
        warn = Color3.fromRGB(235, 180, 60),
        error = Color3.fromRGB(235, 80, 80),
    }
    local accent = typeColors[cfg.Type] or T.Accent

    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Secondary,
        BorderSizePixel = 0,
        Parent = notifContainer,
    })
    corner(frame, 8)
    stroke(frame, T.Outline, 1)

    new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = frame })
    pad(frame, 12, 12, 9, 9)
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

    if cfg.Title then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1,
            Font = T.FontSemi, TextSize = 13, TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.Title,
            LayoutOrder = 1, Parent = frame,
        })
    end

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Font = T.Font, TextSize = 12,
        TextColor3 = T.SubText, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.Text or "",
        LayoutOrder = 2, Parent = frame,
    })

    local progress = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 3,
        Parent = frame,
    })

    local entry = { Frame = frame }
    table.insert(activeNotifs, 1, entry)
    frame.Position = UDim2.new(0, 320, 0, 0)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayoutNotifs)

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        local idx = table.find(activeNotifs, entry)
        if idx then table.remove(activeNotifs, idx) end
        local t = tween(frame, 0.22, { Position = UDim2.new(0, 320, 0, frame.Position.Y.Offset) })
        t.Completed:Once(function()
            frame:Destroy()
            relayoutNotifs()
        end)
    end

    frame.InputBegan:Connect(function(input)
        if isClick(input) then dismiss() end
    end)

    local duration = cfg.Duration or 4
    tween(progress, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
    task.delay(duration, dismiss)
end

--//====================================================================--
--// WINDOW
--//====================================================================--

function ModernUI:CreateWindow(cfg)
    if type(cfg) == "string" then cfg = { Title = cfg } end
    cfg = cfg or {}

    if cfg.ConfigFolder then
        ModernUI.ConfigFolder = cfg.ConfigFolder
    end

    local tracked = {}
    local function track(conn)
        table.insert(tracked, conn)
        return conn
    end

    local guiParent = getGuiParent()
    local existing = guiParent:FindFirstChild("ModernUI")
    if existing then existing:Destroy() end

    local screenGui = new("ScreenGui", {
        Name = "ModernUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
        Parent = guiParent,
    })

    --// Main frame
    local winSize = cfg.Size or UDim2.fromOffset(560, 380)
    local Main = new("Frame", {
        Size = winSize,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = T.Background,
        BorderSizePixel = 0,
        Parent = screenGui,
    })
    corner(Main, 10)
    stroke(Main, T.Outline, 1, 0.5)

    local uiScale = new("UIScale", { Scale = 1, Parent = Main })

    --// Topbar
    local Topbar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = T.Topbar,
        BorderSizePixel = 0,
        Parent = Main,
    })
    corner(Topbar, 10)
    new("Frame", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = T.Topbar, BorderSizePixel = 0, Parent = Topbar })
    new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.Outline, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = Topbar })

    new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 14, 0.5, -4), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = Topbar })
        :FindFirstChildOfClass("UICorner") -- (safe: corner added below if missing)
    ;do
        local dot = Topbar:FindFirstChild WhichIsA -- placeholder removed below
    end

    local Title = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Font = T.FontBold, TextSize = 14, TextColor3 = T.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = cfg.Title or "Modern UI",
        Parent = Topbar,
    })

    local function topBtn(symbol, xOffset, callback)
        local b = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = T.FontBold, TextSize = 14, TextColor3 = T.SubText,
            Text = symbol, AutoButtonColor = false,
            Parent = Topbar,
        })
        corner(b, 6)
        b.MouseEnter:Connect(function()
            b.BackgroundTransparency = 0
            b.BackgroundColor3 = T.Element
            b.TextColor3 = T.Text
        end)
        b.MouseLeave:Connect(function()
            b.BackgroundTransparency = 1
            b.TextColor3 = T.SubText
        end)
        b.MouseButton1Click:Connect(callback)
        return b
    end

    --// Body
    local Body = new("Frame", {
        Position = UDim2.new(0, 0, 0, 38),
        Size = UDim2.new(1, 0, 1, -38),
        BackgroundTransparency = 1,
        Parent = Main,
    })

    local Sidebar = new("Frame", {
        Size = UDim2.new(0, 132, 1, 0),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        Parent = Body,
    })
    new("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.Outline, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = Sidebar })

    local tabList = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Sidebar })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })
    pad(tabList, 0, 0, 10, 0)

    local selectionBar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Visible = false,
        Parent = Sidebar,
    })
    corner(selectionBar, 2)
    accentGradient(selectionBar)

    local pageHolder = new("Frame", {
        Position = UDim2.new(0, 133, 0, 0),
        Size = UDim2.new(1, -133, 1, 0),
        BackgroundTransparency = 1,
        Parent = Body,
    })

    --// Window object
    local WindowObj = {
        Tabs = {},
        CurrentTab = nil,
        Visible = true,
        Minimized = false,
    }
    WindowObj.Gui = screenGui

    local function selectTab(data)
        WindowObj.CurrentTab = data.Name
        for _, d in ipairs(WindowObj.Tabs) do
            d.Page.Visible = false
            d.TextLabel.TextColor3 = T.SubText
            d.IconLabel.TextColor3 = T.SubText
        end
        data.Page.Visible = true
        data.TextLabel.TextColor3 = T.Text
        data.IconLabel.TextColor3 = T.Accent
        selectionBar.Visible = true
        local y = data.Button.AbsolutePosition.Y - tabList.AbsolutePosition.Y + 7
        tween(selectionBar, 0.25, { Position = UDim2.new(0, 0, 0, y) })
    end

    --// Show / Hide
    local function setUIVisible(v)
        WindowObj.Visible = v
        if v then
            Main.Visible = true
            uiScale.Scale = 0.95
            tween(uiScale, 0.22, { Scale = 1 })
        else
            local t = tween(uiScale, 0.18, { Scale = 0.95 })
            t.Completed:Once(function()
                if not WindowObj.Visible then
                    Main.Visible = false
                end
            end)
        end
    end

    function WindowObj:Show() setUIVisible(true) end
    function WindowObj:Hide() setUIVisible(false) end
    function WindowObj:Toggle() setUIVisible(not WindowObj.Visible) end

    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    track(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == toggleKey then
            setUIVisible(not WindowObj.Visible)
        end
    end))

    function WindowObj:SetToggleKey(key)
        toggleKey = key
    end

    --// Minimize / Close
    local function setMinimized(min)
        WindowObj.Minimized = min
        if min then
            Body.Visible = false
            tween(Main, 0.25, { Size = UDim2.new(winSize.X.Scale, winSize.X.Offset, 0, 38) })
        else
            Body.Visible = true
            tween(Main, 0.25, { Size = winSize })
        end
    end

    topBtn("✕", -10, function() WindowObj:Destroy() end)
    topBtn("−", -42, function() setMinimized(not WindowObj.Minimized) end)

    makeDraggable(Main, Topbar)

    function WindowObj:Destroy()
        for _, conn in ipairs(tracked) do
            pcall(function() conn:Disconnect() end)
        end
        screenGui:Destroy()
    end

    --//================================================================--
    --// TABS & ELEMENTS
    --//================================================================--

    function WindowObj:CreateTab(name, icon)
        local data = { Name = name }

        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = tabList,
        })

        local iconLabel = new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0.5, -10),
            Size = UDim2.fromOffset(20, 20),
            Font = T.Font, TextSize = 15, TextColor3 = T.SubText,
            Text = icon or "•",
            Parent = btn,
        })

        local textLabel = new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 38, 0, 0),
            Size = UDim2.new(1, -44, 1, 0),
            Font = T.FontSemi, TextSize = 13, TextColor3 = T.SubText,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = name,
            Parent = btn,
        })

        local page = new("ScrollingFrame", {
            Visible = false,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = T.Accent,
            ScrollBarImageTransparency = 0.4,
            Parent = pageHolder,
        })
        new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
        pad(page, 14, 14, 14, 14)

        data.Button = btn
        data.TextLabel = textLabel
        data.IconLabel = iconLabel
        data.Page = page
        table.insert(WindowObj.Tabs, data)

        btn.MouseEnter:Connect(function()
            if WindowObj.CurrentTab ~= name then textLabel.TextColor3 = T.Text end
        end)
        btn.MouseLeave:Connect(function()
            if WindowObj.CurrentTab ~= name then textLabel.TextColor3 = T.SubText end
        end)
        btn.MouseButton1Click:Connect(function()
            selectTab(data)
        end)

        if #WindowObj.Tabs == 1 then
            selectTab(data)
            task.defer(selectTab, data) -- re-align after first render
        end

        ----------------------------------------------------------------
        -- Element helpers
        ----------------------------------------------------------------

        local openPopupCloser = nil

        local function makeRow(h)
            local row = new("Frame", {
                Size = UDim2.new(1, -28, 0, h or 38),
                BackgroundColor3 = T.Element,
                BorderSizePixel = 0,
                Parent = page,
            })
            corner(row, 8)
            return row
        end

        local function hover(row)
            row.MouseEnter:Connect(function() row.BackgroundColor3 = T.ElementHover end)
            row.MouseLeave:Connect(function() row.BackgroundColor3 = T.Element end)
        end

        local function rowLabel(parent, text, widthOffset)
            return new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, widthOffset or -80, 1, 0),
                Font = T.FontSemi, TextSize = 13, TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = text,
                Parent = parent,
            })
        end

        local function attachRipple(row, clickBtn)
            clickBtn.InputBegan:Connect(function(input)
                if isClick(input) then
                    local rel = Vector2.new(input.Position.X, input.Position.Y) - row.AbsolutePosition
                    local circle = new("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromOffset(rel.X, rel.Y),
                        Size = UDim2.fromOffset(0, 0),
                        BackgroundColor3 = T.Text,
                        BackgroundTransparency = 0.75,
                        BorderSizePixel = 0,
                        ZIndex = 3,
                        Parent = row,
                    })
                    corner(circle, 999)
                    local d = math.max(row.AbsoluteSize.X, row.AbsoluteSize.Y) * 2.4
                    tween(circle, 0.45, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
                    task.delay(0.5, function() circle:Destroy() end)
                end
            end)
        end

        local TabObj = {}

        ----------------------------------------------------------------
        -- SECTION
        ----------------------------------------------------------------

        function TabObj:CreateSection(title)
            local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -28, 0, 26), Parent = page })
            local bar = new("Frame", { Size = UDim2.fromOffset(4, 14), Position = UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = holder })
            corner(bar, 2)
            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 14, 0, 0),
                Size = UDim2.new(1, -14, 1, 0),
                Font = T.FontBold, TextSize = 12, TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = string.upper(title or ""),
                Parent = holder,
            })
        end

        ----------------------------------------------------------------
        -- DIVIDER
        ----------------------------------------------------------------

        function TabObj:CreateDivider()
            new("Frame", {
                Size = UDim2.new(1, -28, 0, 1),
                BackgroundColor3 = T.Outline,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Parent = page,
            })
        end

        ----------------------------------------------------------------
        -- LABEL
        ----------------------------------------------------------------

        function TabObj:CreateLabel(text)
            local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -28, 0, 20), Parent = page })
            local label = new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = T.FontMedium, TextSize = 12, TextColor3 = T.SubText,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = text or "",
                Parent = holder,
            })
            return {
                Set = function(_, v) label.Text = tostring(v) end,
                Get = function() return label.Text end,
            }
        end

        ----------------------------------------------------------------
        -- PARAGRAPH
        ----------------------------------------------------------------

        function TabObj:CreateParagraph(title, body)
            local frame = new("Frame", {
                Size = UDim2.new(1, -28, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = T.Element,
                BorderSizePixel = 0,
                Parent = page,
            })
            corner(frame, 8)
            pad(frame, 12, 12, 10, 10)
            new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

            if title then
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1,
                    Font = T.FontSemi, TextSize = 13, TextColor3 = T.Text,
                    TextXAlignment = Enum.TextXAlignment.Left, Text = title,
                    LayoutOrder = 1, Parent = frame,
                })
            end
            new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Font = T.Font, TextSize = 12,
                TextColor3 = T.SubText, TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left, Text = body or "",
                LayoutOrder = 2, Parent = frame,
            })
        end

        ----------------------------------------------------------------
        -- BUTTON
        ----------------------------------------------------------------

        function TabObj:CreateButton(text, callback)
            local row = makeRow(38)
            row.ClipsDescendants = true
            hover(row)
            new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                Font = T.FontSemi, TextSize = 13, TextColor3 = T.Text, Text = text,
                Parent = row,
            })
            local click = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Parent = row })
            attachRipple(row, click)
            click.MouseButton1Click:Connect(function()
                if callback then task.spawn(callback) end
            end)
        end

        ----------------------------------------------------------------
        -- TOGGLE
        ----------------------------------------------------------------

        function TabObj:CreateToggle(text, default, callback, flag)
            local state = default == true

            local row = makeRow(38)
            hover(row)
            rowLabel(row, text)

            local pill = new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.fromOffset(42, 22),
                BackgroundColor3 = state and T.Accent or T.ToggleOff,
                BorderSizePixel = 0,
                Parent = row,
            })
            corner(pill, 99)
            local pillGrad = accentGradient(pill)
            pillGrad.Enabled = state

            local knob = new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Size = UDim2.fromOffset(16, 16),
                Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0, ZIndex = 2,
                Parent = pill,
            })
            corner(knob, 99)

            local function render(animate)
                local knobPos = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
                local pillColor = state and T.Accent or T.ToggleOff
                if animate then
                    tween(knob, 0.18, { Position = knobPos })
                    tween(pill, 0.18, { BackgroundColor3 = pillColor })
                else
                    knob.Position = knobPos
                    pill.BackgroundColor3 = pillColor
                end
                pillGrad.Enabled = state
            end

            local click = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Parent = row })
            click.MouseButton1Click:Connect(function()
                state = not state
                render(true)
                if callback then task.spawn(callback, state) end
            end)

            local ctrl = {}
            function ctrl:Set(v)
                state = v == true
                render(true)
                if callback then task.spawn(callback, state) end
            end
            function ctrl:Get() return state end

            registerFlag(flag, ctrl)
            return ctrl
        end

        ----------------------------------------------------------------
        -- SLIDER
        ----------------------------------------------------------------

        function TabObj:CreateSlider(text, minValue, maxValue, defaultValue, step, callback, flag)
            minValue = minValue or 0
            maxValue = maxValue or 100
            step = step or 1
            if maxValue < minValue then minValue, maxValue = maxValue, minValue end
            if step <= 0 then step = 1 end
            local value = math.clamp(defaultValue or minValue, minValue, maxValue)

            local row = makeRow(48)
            hover(row)

            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 4),
                Size = UDim2.new(1, -90, 0, 20),
                Font = T.FontSemi, TextSize = 13, TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = text,
                Parent = row,
            })

            local valueLabel = new("TextLabel", {
                Position = UDim2.new(1, -70, 0, 4),
                Size = UDim2.fromOffset(58, 20),
                BackgroundTransparency = 1,
                Font = T.FontMedium, TextSize = 12, TextColor3 = T.Accent,
                TextXAlignment = Enum.TextXAlignment.Right,
                Text = tostring(value),
                Parent = row,
            })

            local trackFrame = new("Frame", {
                Position = UDim2.new(0, 12, 1, -16),
                Size = UDim2.new(1, -24, 0, 6),
                BackgroundColor3 = T.SliderTrack,
                BorderSizePixel = 0,
                Parent = row,
            })
            corner(trackFrame, 99)

            local fill = new("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = T.Accent,
                BorderSizePixel = 0,
                Parent = trackFrame,
            })
            corner(fill, 99)
            accentGradient(fill)

            local knob = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(14, 14),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0, ZIndex = 2,
                Parent = trackFrame,
            })
            corner(knob, 99)
            stroke(knob, T.Accent, 1.5)

            local function fmt(v)
                if step >= 1 then return tostring(math.floor(v + 0.5)) end
                return tostring(math.round(v * 100) / 100)
            end

            local function set(v, fire)
                local steps = math.floor((v - minValue) / step + 0.5)
                v = math.clamp(minValue + steps * step, minValue, maxValue)
                value = v
                local alpha = (maxValue > minValue) and ((v - minValue) / (maxValue - minValue)) or 0
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
                valueLabel.Text = fmt(v)
                if fire and callback then task.spawn(callback, v) end
            end

            local function fromX(x)
                local w = trackFrame.AbsoluteSize.X
                if w <= 0 then return end
                local rel = math.clamp(x - trackFrame.AbsolutePosition.X, 0, w)
                set(minValue + (maxValue - minValue) * (rel / w), true)
            end

            local dragging = false
            trackFrame.InputBegan:Connect(function(input)
                if isClick(input) then
                    dragging = true
                    fromX(input.Position.X)
                end
            end)
            track(UserInputService.InputChanged:Connect(function(input)
                if dragging and isMove(input) then fromX(input.Position.X) end
            end))
            track(UserInputService.InputEnded:Connect(function(input)
                if isClick(input) then dragging = false end
            end))

            set(value, false)

            local ctrl = {}
            function ctrl:Set(v) set(tonumber(v) or value, true) end
            function ctrl:Get() return value end

            registerFlag(flag, ctrl)
            return ctrl
        end

        ----------------------------------------------------------------
        -- DROPDOWN
        ----------------------------------------------------------------

        function TabObj:CreateDropdown(text, options, default, callback, multiSelect, flag)
            options = options or {}
            multiSelect = multiSelect == true

            local selected
            if multiSelect then
                selected = {}
                if type(default) == "table" then
                    for _, v in ipairs(default) do table.insert(selected, v) end
                end
            else
                selected = default
            end

            local row = makeRow(38)
            hover(row)
            rowLabel(row, text, -110)

            local valueLabel = new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -76, 1, 0),
                Font = T.FontMedium, TextSize = 12, TextColor3 = T.SubText,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = "",
                Parent = row,
            })

            local chevron = new("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                Font = T.FontBold, TextSize = 12, TextColor3 = T.SubText,
                Text = "▾",
                Parent = row,
            })

            local popup, open = nil, false
            local optionButtons = {}

            local function refreshDisplay()
                if multiSelect then
                    valueLabel.Text = (#selected > 0) and table.concat(selected, ", ") or "None"
                else
                    valueLabel.Text = tostring(selected or "Select...")
                end
            end
            refreshDisplay()

            local setOpen
            local closeSelf = function() setOpen(false) end

            local function buildOptions()
                for _, b in ipairs(optionButtons) do b:Destroy() end
                table.clear(optionButtons)
                if not popup then return end

                for _, opt in ipairs(options) do
                    local optBtn = new("TextButton", {
                        Size = UDim2.new(1, -12, 0, 26),
                        BackgroundColor3 = T.Element,
                        BorderSizePixel = 0,
                        Font = T.FontMedium, TextSize = 12, TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = "   " .. tostring(opt),
                        AutoButtonColor = false,
                        Parent = popup,
                    })
                    corner(optBtn, 6)

                    local mark = new("TextLabel", {
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -8, 0.5, 0),
                        Size = UDim2.fromOffset(16, 16),
                        BackgroundTransparency = 1,
                        Font = T.FontBold, TextSize = 12, TextColor3 = T.Accent,
                        Text = "",
                        Parent = optBtn,
                    })

                    local function updateMark()
                        local isSel
                        if multiSelect then
                            isSel = table.find(selected, opt) ~= nil
                        else
                            isSel = selected == opt
                        end
                        mark.Text = isSel and "✓" or ""
                        optBtn.TextColor3 = isSel and T.Accent or T.Text
                    end
                    updateMark()

                    optBtn.MouseEnter:Connect(function() optBtn.BackgroundColor3 = T.ElementHover end)
                    optBtn.MouseLeave:Connect(function() optBtn.BackgroundColor3 = T.Element end)

                    optBtn.MouseButton1Click:Connect(function()
                        if multiSelect then
                            local idx = table.find(selected, opt)
                            if idx then table.remove(selected, idx) else table.insert(selected, opt) end
                            updateMark()
                            refreshDisplay()
                            if callback then task.spawn(callback, selected) end
                        else
                            selected = opt
                            refreshDisplay()
                            setOpen(false)
                            if callback then task.spawn(callback, opt) end
                        end
                    end)

                    table.insert(optionButtons, optBtn)
                end
            end

            setOpen = function(v)
                open = v
                chevron.Text = v and "▴" or "▾"
                if v then
                    if openPopupCloser and openPopupCloser ~= closeSelf then openPopupCloser() end
                    openPopupCloser = closeSelf

                    if not popup then
                        popup = new("ScrollingFrame", {
                            Position = UDim2.new(0, 0, 0, 42),
                            Size = UDim2.new(1, 0, 0, 0),
                            BackgroundColor3 = T.Secondary,
                            BorderSizePixel = 0,
                            ScrollBarThickness = 3,
                            ScrollBarImageColor3 = T.Accent,
                            ScrollBarImageTransparency = 0.4,
                            CanvasSize = UDim2.new(0, 0, 0, 0),
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            ZIndex = 5,
                            Parent = row,
                        })
                        corner(popup, 8)
                        stroke(popup, T.Outline, 1)
                        new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = popup })
                        pad(popup, 6, 6, 6, 6)
                        row.ZIndex = 10
                        buildOptions()
                    end
                    popup.Visible = true

                    local targetH = math.min(#options * 26 + math.max(#options - 1, 0) * 4 + 12, 170)
                    tween(popup, 0.22, { Size = UDim2.new(1, 0, 0, targetH) })
                else
                    if popup then
                        local t = tween(popup, 0.16, { Size = UDim2.new(1, 0, 0, 0) })
                        t.Completed:Once(function()
                            if not open and popup then
                                popup.Visible = false
                            end
                        end)
                    end
                    row.ZIndex = 1
                    if openPopupCloser == closeSelf then openPopupCloser = nil end
                end
            end

            local click = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Parent = row })
            click.MouseButton1Click:Connect(function() setOpen(not open) end)

            local ctrl = {}
            function ctrl:Refresh(newOptions)
                options = newOptions or options
                if popup then buildOptions() end
            end
            function ctrl:Set(v)
                if multiSelect then
                    selected = (type(v) == "table") and v or {}
                else
                    selected = v
                end
                refreshDisplay()
            end
            function ctrl:Get() return selected end

            registerFlag(flag, ctrl)
            return ctrl
        end

        ----------------------------------------------------------------
        -- TEXTBOX
        ----------------------------------------------------------------

        function TabObj:CreateTextbox(text, placeholder, default, callback, flag)
            local row = makeRow(38)
            hover(row)
            rowLabel(row, text, -160)

            local box = new("TextBox", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(140, 26),
                BackgroundColor3 = T.Input,
                BorderSizePixel = 0,
                Font = T.FontMedium, TextSize = 12, TextColor3 = T.Text,
                PlaceholderColor3 = T.SubText,
                PlaceholderText = placeholder or "",
                Text = default or "",
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Center,
                ClipsDescendants = true,
                Parent = row,
            })
            corner(box, 6)
            stroke(box, T.Outline, 1, 0.5)

            box.FocusLost:Connect(function()
                if callback then task.spawn(callback, box.Text) end
            end)

            local ctrl = {}
            function ctrl:Set(v) box.Text = tostring(v) end
            function ctrl:Get() return box.Text end

            registerFlag(flag, ctrl)
            return ctrl
        end

        ----------------------------------------------------------------
        -- KEYBIND
        ----------------------------------------------------------------

        function TabObj:CreateKeybind(text, defaultKey, callback, flag)
            local key = defaultKey
            local listening = false

            local row = makeRow(38)
            hover(row)
            rowLabel(row, text, -100)

            local keyBtn = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(80, 24),
                BackgroundColor3 = T.Input,
                BorderSizePixel = 0,
                Font = T.FontMedium, TextSize = 12, TextColor3 = T.SubText,
                Text = key and key.Name or "None",
                AutoButtonColor = false,
                Parent = row,
            })
            corner(keyBtn, 6)

            local function keyName(k)
                if typeof(k) == "EnumItem" then return k.Name end
                return tostring(k)
            end

            keyBtn.MouseButton1Click:Connect(function()
                if listening then return end
                listening = true
                keyBtn.Text = "..."

                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                        key = input.KeyCode
                    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
                        key = input.UserInputType
                    else
                        return
                    end
                    listening = false
                    keyBtn.Text = keyName(key)
                    conn:Disconnect()
                    if callback then task.spawn(callback, key) end
                end)
                track(conn)
            end)

            track(UserInputService.InputBegan:Connect(function(input, gp)
                if listening or not key or gp then return end
                if UserInputService:GetFocusedTextBox() then return end
                if input.KeyCode == key or input.UserInputType == key then
                    if callback then task.spawn(callback, key) end
                end
            end))

            local ctrl = {}
            function ctrl:Set(k)
                if type(k) == "string" then
                    for _, item in ipairs(Enum:GetEnumItems()) do
                        if item.Name == k then
                            key = item
                            break
                        end
                    end
                else
                    key = k
                end
                keyBtn.Text = key and keyName(key) or "None"
            end
            function ctrl:Get() return key end

            registerFlag(flag, ctrl)
            return ctrl
        end

        ----------------------------------------------------------------
        -- COLOR PICKER
        ----------------------------------------------------------------

        function TabObj:CreateColorPicker(text, default, callback, flag)
            local color = default or Color3.fromRGB(255, 255, 255)
            local h, s, v = color:ToHSV()

            local row = makeRow(38)
            hover(row)
            rowLabel(row, text, -80)

            local swatch = new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(42, 22),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                ZIndex = 2,
                Parent = row,
            })
            corner(swatch, 6)
            stroke(swatch, T.Outline, 1)

            local popup = nil
            local open = false

            -- popup internals (set when created)
            local svFrame, svGradient, svCursor, hueCursor

            local function applyColor(c, fire)
                color = c
                h, s, v = c:ToHSV()
                swatch.BackgroundColor3 = c
                if popup then
                    svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    svGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1))
                    svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                    hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                end
                if fire and callback then task.spawn(callback, c) end
            end

            local setOpen
            local closeSelf = function() setOpen(false) end

            local function buildPopup()
                popup = new("Frame", {
                    Position = UDim2.new(0, 0, 0, 42),
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundColor3 = T.Secondary,
                    BorderSizePixel = 0,
                    ZIndex = 5,
                    Parent = row,
                })
                corner(popup, 8)
                stroke(popup, T.Outline, 1)

                -- Saturation / Value box
                svFrame = new("Frame", {
                    Position = UDim2.new(0, 10, 0, 10),
                    Size = UDim2.new(1, -20, 0, 110),
                    BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 2,
                    Parent = popup,
                })
                corner(svFrame, 6)
                svGradient = new("UIGradient", {
                    Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1)),
                    Parent = svFrame,
                })

                local shade = new("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 2,
                    Parent = svFrame,
                })
                new("UIGradient", {
                    Rotation = 90,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    }),
                    Parent = shade,
                })

                svCursor = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(s, 0, 1 - v, 0),
                    Size = UDim2.fromOffset(10, 10),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 4,
                    Parent = svFrame,
                })
                corner(svCursor, 99)
                stroke(svCursor, Color3.new(0, 0, 0), 1)

                -- Hue bar
                local hueBar = new("Frame", {
                    Position = UDim2.new(0, 10, 0, 128),
                    Size = UDim2.new(1, -20, 0, 12),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 2,
                    Parent = popup,
                })
                corner(hueBar, 99)
                new("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 0)),
                    }),
                    Parent = hueBar,
                })

                hueCursor = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(h, 0, 0.5, 0),
                    Size = UDim2.fromOffset(10, 10),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 4,
                    Parent = hueBar,
                })
                corner(hueCursor, 99)
                stroke(hueCursor, Color3.new(0, 0, 0), 1)

                -- Input
                local svDragging = false
                local hueDragging = false

                local function setSVFromInput(x, y)
                    local rel = Vector2.new(x, y) - svFrame.AbsolutePosition
                    local size = svFrame.AbsoluteSize
                    s = math.clamp(rel.X / math.max(size.X, 1), 0, 1)
                    v = 1 - math.clamp(rel.Y / math.max(size.Y, 1), 0, 1)
                    svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                    applyColor(Color3.fromHSV(h, s, v), true)
                end

                local function setHueFromInput(x)
                    h = math.clamp((x - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
                    hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                    svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    svGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1))
                    applyColor(Color3.fromHSV(h, s, v), true)
                end

                svFrame.InputBegan:Connect(function(input)
                    if isClick(input) then
                        svDragging = true
                        setSVFromInput(input.Position.X, input.Position.Y)
                    end
                end)
                hueBar.InputBegan:Connect(function(input)
                    if isClick(input) then
                        hueDragging = true
                        setHueFromInput(input.Position.X)
                    end
                end)
                track(UserInputService.InputChanged:Connect(function(input)
                    if not isMove(input) then return end
                    if svDragging then setSVFromInput(input.Position.X, input.Position.Y) end
                    if hueDragging then setHueFromInput(input.Position.X) end
                end))
                track(UserInputService.InputEnded:Connect(function(input)
                    if isClick(input) then
                        svDragging = false
                        hueDragging = false
                    end
                end))
            end

            setOpen = function(v2)
                open = v2
                if v2 then
                    if openPopupCloser and openPopupCloser ~= closeSelf then openPopupCloser() end
                    openPopupCloser = closeSelf

                    if not popup then
                        buildPopup()
                        row.ZIndex = 10
                    end
                    popup.Visible = true
                    tween(popup, 0.22, { Size = UDim2.new(1, 0, 0, 150) })
                else
                    if popup then
                        local t = tween(popup, 0.16, { Size = UDim2.new(1, 0, 0, 0) })
                        t.Completed:Once(function()
                            if not open and popup then popup.Visible = false end
                        end)
                    end
                    row.ZIndex = 1
                    if openPopupCloser == closeSelf then openPopupCloser = nil end
                end
            end

            local click = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Parent = row })
            click.MouseButton1Click:Connect(function() setOpen(not open) end)

            applyColor(color, false)

            local ctrl = {}
            function ctrl:Set(c)
                if typeof(c) == "Color3" then applyColor(c, true) end
            end
            function ctrl:Get() return color end

            registerFlag(flag, ctrl)
            return ctrl
        end

        return TabObj
    end

    --//================================================================--
    --// BUILT-IN CONFIG TAB
    --//================================================================--

    function WindowObj:AddConfigTab(tabName)
        local tab = self:CreateTab(tabName or "Config", "⚙")

        if not (writefile and readfile and isfile and isfolder and makefolder and listfiles and delfile) then
            tab:CreateParagraph("Config System", "Your executor does not support file saving (writefile), so configs are unavailable.")
            return tab
        end

        local nameBox = ""

        tab:CreateTextbox("Config Name", "my_config", "", function(v) nameBox = v end)
        tab:CreateButton("Save Config", function()
            if nameBox == "" then
                ModernUI:Notify({ Title = "Config", Text = "Enter a config name first.", Type = "warn" })
                return
            end
            local ok, err = ModernUI:SaveConfig(nameBox)
            ModernUI:Notify({
                Title = "Config",
                Text = ok and ("Saved '" .. nameBox .. "'.") or ("Save failed: " .. tostring(err)),
                Type = ok and "success" or "error",
            })
        end)
        tab:CreateButton("Load Config", function()
            if nameBox == "" then
                ModernUI:Notify({ Title = "Config", Text = "Enter a config name first.", Type = "warn" })
                return
            end
            local ok, err = ModernUI:LoadConfig(nameBox)
            ModernUI:Notify({
                Title = "Config",
                Text = ok and ("Loaded '" .. nameBox .. "'.") or ("Load failed: " .. tostring(err)),
                Type = ok and "success" or "error",
            })
        end)
        tab:CreateButton("Delete Config", function()
            local ok = ModernUI:DeleteConfig(nameBox)
            ModernUI:Notify({
                Title = "Config",
                Text = ok and ("Deleted '" .. nameBox .. "'.") or ("Config not found."),
                Type = ok and "success" or "warn",
            })
        end)

        tab:CreateSection("Existing Configs")

        local listLabel
        local function listText()
            local names = ModernUI:GetConfigs()
            if #names == 0 then return "No configs saved yet." end
            return table.concat(names, ",  ")
        end
        listLabel = tab:CreateLabel(listText())

        local refreshCtrl = {}
        function refreshCtrl:Refresh() listLabel.Set(listText()) end

        -- refresh the list whenever save/load/delete runs
        tab:CreateButton("Refresh List", function() listLabel.Set(listText()) end)

        return tab
    end

    --// Entrance animation
    uiScale.Scale = 0.96
    task.defer(function()
        tween(uiScale, 0.25, { Scale = 1 })
    end)

    return WindowObj
end

--//====================================================================--
--// CONFIG API
--//====================================================================--

function ModernUI:SaveConfig(name)
    if not writefile then return false, "writefile not supported" end
    local data = {}
    for flag, ctrl in pairs(Registry) do
        local ok, v = pcall(function() return ctrl:Get() end)
        if ok and v ~= nil then
            if typeof(v) == "EnumItem" then v = v.Name end
            data[flag] = v
        end
    end
    if isfolder and not isfolder(ModernUI.ConfigFolder) then
        makefolder(ModernUI.ConfigFolder)
    end
    local ok, err = pcall(writefile, ModernUI.ConfigFolder .. "/" .. tostring(name) .. ".json", HttpService:JSONEncode(data))
    return ok, err
end

function ModernUI:LoadConfig(name)
    if not readfile then return false, "readfile not supported" end
    local path = ModernUI.ConfigFolder .. "/" .. tostring(name) .. ".json"
    if isfile and not isfile(path) then return false, "config not found" end
    local ok, content = pcall(readfile, path)
    if not ok then return false, content end
    local decoded, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not decoded then return false, "invalid config file" end
    for flag, value in pairs(data) do
        local ctrl = Registry[flag]
        if ctrl then
            pcall(function() ctrl:Set(value) end)
        end
    end
    return true
end

function ModernUI:GetConfigs()
    if not (isfolder and listfiles and isfolder(ModernUI.ConfigFolder)) then return {} end
    local names = {}
    for _, path in ipairs(listfiles(ModernUI.ConfigFolder)) do
        local file = string.match(path, "[^/\\]+$") or path
        local name = string.match(file, "^(.-)%.json$") or file
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function ModernUI:DeleteConfig(name)
    local path = ModernUI.ConfigFolder .. "/" .. tostring(name) .. ".json"
    if not (delfile and isfile and isfile(path)) then return false end
    delfile(path)
    return true
end

return ModernUI
