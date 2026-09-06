--[[
    ModernUI v3.0 — rewritten & improved
    ----------------------------------------
    Drop-in replacement for v2.0 (same API):

    Window:
        ModernUI:CreateWindow({ Title, ToggleKey, Size, ConfigFolder })
        Window:CreateTab(name, iconEmoji?) -> Tab
        Window:AddConfigTab(name?)
        Window:Show() / Window:Hide() / Window:Toggle() / Window:Destroy()

    Elements:
        Tab:CreateSection(title) / CreateDivider()
        Tab:CreateLabel(text) / CreateParagraph(title, body)
        Tab:CreateButton(text, callback)
        Tab:CreateToggle(text, default, callback, flag?)      -> { Set, Get }
        Tab:CreateSlider(text, min, max, default, step, callback, flag?) -> { Set, Get }
        Tab:CreateDropdown(text, options, default, callback, multiSelect?, flag?) -> { Set, Get, Refresh }
        Tab:CreateTextbox(text, placeholder, default, callback, flag?) -> { Set, Get }
        Tab:CreateKeybind(text, defaultKey, callback, flag?) -> { Set, Get }
        Tab:CreateColorPicker(text, default, callback, flag?) -> { Set, Get }

    Extras:
        ModernUI:Notify({ Title, Text, Type = "info"|"success"|"warn"|"error", Duration })
        ModernUI:SaveConfig(name) / :LoadConfig(name) / :GetConfigs() / :DeleteConfig(name)
        ModernUI.Theme.Accent = Color3  (set theme colors before CreateWindow)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local ModernUI = {
    Version = "3.0.0",
    Flags = {},
    Theme = {
        Background = Color3.fromRGB(17, 17, 23),
        Secondary  = Color3.fromRGB(25, 25, 33),
        Tertiary   = Color3.fromRGB(34, 34, 45),
        Hover      = Color3.fromRGB(46, 46, 60),
        Accent     = Color3.fromRGB(139, 92, 246),
        Text       = Color3.fromRGB(242, 242, 247),
        SubText    = Color3.fromRGB(150, 150, 168),
        Border     = Color3.fromRGB(52, 52, 66),
        Info       = Color3.fromRGB(88, 165, 255),
        Success    = Color3.fromRGB(70, 200, 120),
        Warning    = Color3.fromRGB(245, 190, 60),
        Error      = Color3.fromRGB(240, 84, 74),
    },
}
local T = ModernUI.Theme

local connections = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function new(class, props)
    local inst = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    inst.Parent = parent
    return inst
end

local function round(inst, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = inst })
end

local function outline(inst, color, th)
    return new("UIStroke", { Color = color or T.Border, Thickness = th or 1, Parent = inst })
end

local function tween(inst, time, props)
    local t = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function isPressed(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function pointIn(pos, absPos, absSize)
    return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
        and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

--// Notifications ----------------------------------------------------------

local notifyGui, notifyHolder

local function getNotifyGui()
    if notifyGui and notifyGui.Parent then return notifyHolder end
    notifyGui = new("ScreenGui", {
        Name = "ModernUI_Notifs", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global, IgnoreGuiInset = true, DisplayOrder = 1000,
    })
    local ok = pcall(function()
        if type(gethui) == "function" then
            notifyGui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(notifyGui)
            notifyGui.Parent = game:GetService("CoreGui")
        else
            notifyGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        end
    end)
    if not ok or not notifyGui.Parent then
        notifyGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    notifyHolder = new("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 320, 1, -28), Parent = notifyGui,
    })
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = notifyHolder })
    return notifyHolder
end

local NOTIFY_META = {
    info    = { color = T.Info,    icon = "i" },
    success = { color = T.Success, icon = "✓" },
    warn    = { color = T.Warning, icon = "!" },
    error   = { color = T.Error,   icon = "✕" },
}

function ModernUI:Notify(cfg)
    cfg = cfg or {}
    local meta = NOTIFY_META[cfg.Type or "info"] or NOTIFY_META.info
    local holder = getNotifyGui()

    local wrap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = holder })
    local card = new("Frame", { BackgroundColor3 = T.Secondary, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 340, 0, 0), BorderSizePixel = 0, Parent = wrap })
    round(card, 10)
    outline(card)
    new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = card })

    local bar = new("Frame", { BackgroundColor3 = meta.color, Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(0, 3, 1, -16), BorderSizePixel = 0, Parent = card })
    round(bar, 2)

    local icon = new("Frame", { BackgroundColor3 = meta.color, Position = UDim2.new(0, 10, 0, 8), Size = UDim2.fromOffset(26, 26), BorderSizePixel = 0, Parent = card })
    round(icon, 13)
    new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBold, Text = meta.icon, TextSize = 14, TextColor3 = T.Background, Parent = icon })

    local textHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 46, 0, 6), Size = UDim2.new(1, -56, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
    new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.GothamBold, Text = cfg.Title or "Notification", TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = textHolder })
    new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham, Text = cfg.Text or "", TextSize = 13, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = textHolder })
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = textHolder })

    task.delay(0.02, function() tween(card, 0.35, { Position = UDim2.new(0, 0, 0, 0) }) end)
    task.delay(cfg.Duration or 4, function()
        tween(card, 0.3, { Position = UDim2.new(0, 360, 0, 0) })
        task.wait(0.32)
        wrap:Destroy()
    end)
end

--// Config system ----------------------------------------------------------

local fileOK = type(writefile) == "function" and type(readfile) == "function"
    and type(isfolder) == "function" and type(makefolder) == "function"

local function configDir()
    return ModernUI._configFolder or "ModernUI"
end

function ModernUI:SaveConfig(name)
    if not fileOK then
        self:Notify({ Title = "Configs", Text = "Your executor doesn't support file saving", Type = "error" })
        return false
    end
    local data = {}
    for flag, obj in pairs(self.Flags) do
        local v = obj.Get()
        if typeof(v) == "Color3" then
            v = { __type = "Color3", R = v.R, G = v.G, B = v.B }
        elseif typeof(v) == "EnumItem" then
            v = { __type = "KeyCode", Name = v.Name }
        end
        data[flag] = v
    end
    if not isfolder(configDir()) then makefolder(configDir()) end
    local ok, err = pcall(writefile, configDir() .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    self:Notify({ Title = "Config", Text = ok and ("Saved '" .. name .. "'") or ("Save failed: " .. tostring(err)), Type = ok and "success" or "error" })
    return ok
end

local function decodeValue(v)
    if type(v) == "table" and v.__type == "Color3" then return Color3.new(v.R, v.G, v.B) end
    if type(v) == "table" and v.__type == "KeyCode" then
        local ok, k = pcall(Enum.KeyCode.FromName, v.Name or "")
        return ok and k or nil
    end
    return v
end

function ModernUI:LoadConfig(name)
    if not fileOK then
        self:Notify({ Title = "Configs", Text = "Your executor doesn't support file saving", Type = "error" })
        return false
    end
    local path = configDir() .. "/" .. name .. ".json"
    local exists = false
    pcall(function() exists = isfile(path) end)
    if not exists then
        self:Notify({ Title = "Config", Text = "Config '" .. name .. "' not found", Type = "error" })
        return false
    end
    local ok, content = pcall(readfile, path)
    if not ok then
        self:Notify({ Title = "Config", Text = "Failed to read config", Type = "error" })
        return false
    end
    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(data) ~= "table" then
        self:Notify({ Title = "Config", Text = "Config file is corrupted", Type = "error" })
        return false
    end
    for flag, v in pairs(data) do
        local obj = self.Flags[flag]
        local val = decodeValue(v)
        if obj and val ~= nil then pcall(obj.Set, val) end
    end
    self:Notify({ Title = "Config", Text = "Loaded '" .. name .. "'", Type = "success" })
    return true
end

function ModernUI:GetConfigs()
    if not fileOK or type(listfiles) ~= "function" then return {} end
    local out = {}
    local ok, files = pcall(listfiles, configDir())
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local n = string.match(f, "[/\\]([^/\\]-)%.json$")
            if n then table.insert(out, n) end
        end
    end
    return out
end

function ModernUI:DeleteConfig(name)
    if type(delfile) == "function" then
        pcall(delfile, configDir() .. "/" .. name .. ".json")
    end
end

--// Window -----------------------------------------------------------------

function ModernUI:CreateWindow(cfg)
    cfg = cfg or {}
    local size = cfg.Size or UDim2.fromOffset(560, 380)
    local toggleKey = cfg.ToggleKey
    ModernUI._configFolder = cfg.ConfigFolder or "ModernUI"

    local gui = new("ScreenGui", {
        Name = "ModernUI_" .. tostring(math.floor(os.clock() * 100000)),
        ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true, DisplayOrder = 999,
    })
    local ok = pcall(function()
        if type(gethui) == "function" then
            gui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = game:GetService("CoreGui")
        else
            gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        end
    end)
    if not ok or not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    local main = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = size, BackgroundColor3 = T.Background, BorderSizePixel = 0,
        GroupTransparency = 1, ClipsDescendants = true, Parent = gui,
    })
    round(main, 12)
    outline(main)
    tween(main, 0.35, { GroupTransparency = 0 })

    -- Topbar
    local topbar = new("Frame", { BackgroundColor3 = T.Secondary, Size = UDim2.new(1, 0, 0, 42), BorderSizePixel = 0, Parent = main })
    round(topbar, 12)
    new("Frame", { BackgroundColor3 = T.Secondary, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 21), Size = UDim2.new(1, 0, 0, 21), Parent = topbar })

    local dot = new("Frame", { BackgroundColor3 = T.Accent, Position = UDim2.new(0, 14, 0.5, -4), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Parent = topbar })
    round(dot, 4)

    new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(0, 320, 1, 0), Font = Enum.Font.GothamBold, Text = cfg.Title or "ModernUI", TextSize = 15, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = topbar })

    local function topBtn(text, x)
        local b = new("TextButton", { BackgroundTransparency = 1, Position = UDim2.new(1, x, 0, 0), Size = UDim2.fromOffset(36, 42), Font = Enum.Font.GothamBold, Text = text, TextSize = 15, TextColor3 = T.SubText, Parent = topbar })
        b.MouseEnter:Connect(function() b.TextColor3 = T.Text end)
        b.MouseLeave:Connect(function() b.TextColor3 = T.SubText end)
        return b
    end
    local closeBtn = topBtn("✕", -40)
    local maxBtn = topBtn("▢", -76)
    local minBtn = topBtn("–", -112)

    -- Body / sidebar / content
    local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -42), Parent = main })

    local sidebar = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(0, 152, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Border, BorderSizePixel = 0, Parent = body })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sidebar })
    new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = sidebar })

    new("Frame", { BackgroundColor3 = T.Border, BorderSizePixel = 0, Position = UDim2.new(0, 152, 0, 8), Size = UDim2.new(0, 1, 1, -16), Parent = body })

    local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 153, 0, 0), Size = UDim2.new(1, -153, 1, 0), Parent = body })

    -- Window object
    local tabs = {}
    local Window = {}

    local function paintTab(t, active)
        t.Indicator.BackgroundTransparency = active and 0 or 1
        t.ButtonLabel.TextColor3 = active and T.Text or T.SubText
        t.Button.BackgroundTransparency = active and 0 or 1
        t.Button.BackgroundColor3 = active and T.Tertiary or T.Secondary
    end

    local function selectTab(target)
        for _, t in ipairs(tabs) do
            t.Page.Visible = (t == target)
            paintTab(t, t == target)
        end
    end

    -- Dragging
    local dragging, dragStart, startPos
    topbar.InputBegan:Connect(function(input)
        if isPressed(input) then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Topbar buttons
    closeBtn.MouseButton1Click:Connect(function() Window:Hide() end)

    local minimized, prevMinSize = false, nil
    minBtn.MouseButton1Click:Connect(function()
        if not minimized then
            prevMinSize = main.Size
            minimized = true
            tween(main, 0.25, { Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 42) })
        else
            minimized = false
            tween(main, 0.25, { Size = prevMinSize })
        end
    end)

    local maximized = false
    maxBtn.MouseButton1Click:Connect(function()
        maximized = not maximized
        tween(main, 0.3, { Size = maximized and UDim2.fromScale(0.65, 0.7) or size })
    end)

    -- Toggle key
    if toggleKey then
        bind(UserInputService.InputBegan, function(input, gpe)
            if not gpe and input.KeyCode == toggleKey then
                Window:Toggle()
            end
        end)
    end

    local visible = true
    function Window:Show()
        visible = true
        main.Visible = true
        tween(main, 0.25, { GroupTransparency = 0 })
    end
    function Window:Hide()
        visible = false
        tween(main, 0.25, { GroupTransparency = 1 })
        task.delay(0.27, function()
            if not visible then main.Visible = false end
        end)
    end
    function Window:Toggle()
        if visible then Window:Hide() else Window:Show() end
    end
    function Window:Destroy()
        for _, c in ipairs(connections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(connections)
        gui:Destroy()
    end

    -- Tabs
    function Window:CreateTab(name, icon)
        local btn = new("TextButton", { BackgroundColor3 = T.Secondary, BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), Text = "", BorderSizePixel = 0, Parent = sidebar })
        round(btn, 8)
        local ind = new("Frame", { BackgroundColor3 = T.Accent, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0.5, -9), Size = UDim2.new(0, 3, 0, 18), BorderSizePixel = 0, Parent = btn })
        round(ind, 2)
        local lbl = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -12, 1, 0), Font = Enum.Font.GothamMedium, Text = (icon and (icon .. "  ") or "") .. name, TextSize = 13, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })

        local page = new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(1, -20, 1, -20), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent, BorderSizePixel = 0, Visible = false, Parent = content })
        new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

        local tab = { Name = name, Page = page, Button = btn, ButtonLabel = lbl, Indicator = ind }

        btn.MouseButton1Click:Connect(function() selectTab(tab) end)
        btn.MouseEnter:Connect(function()
            if not page.Visible then btn.BackgroundColor3 = T.Hover; btn.BackgroundTransparency = 0.5 end
        end)
        btn.MouseLeave:Connect(function()
            if not page.Visible then btn.BackgroundColor3 = T.Secondary; btn.BackgroundTransparency = 1 end
        end)

        table.insert(tabs, tab)
        if #tabs == 1 then selectTab(tab) end

        --// Element builders ---------------------------------------------

        local function addRow(height)
            local row = new("Frame", { BackgroundColor3 = T.Tertiary, Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, Parent = page })
            round(row, 8)
            return row
        end

        local function addTitle(parent, text)
            return new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), Font = Enum.Font.GothamMedium, Text = text, TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent })
        end

        local function registerFlag(flag, get, set)
            if flag then ModernUI.Flags[flag] = { Get = get, Set = set } end
        end

        function tab:CreateSection(title)
            local h = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = page })
            local bar = new("Frame", { BackgroundColor3 = T.Accent, Position = UDim2.new(0, 2, 0, 5), Size = UDim2.new(0, 3, 0, 14), BorderSizePixel = 0, Parent = h })
            round(bar, 2)
            new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -14, 1, 0), Font = Enum.Font.GothamBold, Text = string.upper(title or ""), TextSize = 12, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = h })
        end

        function tab:CreateDivider()
            new("Frame", { BackgroundColor3 = T.Border, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = page })
        end

        function tab:CreateLabel(text)
            local lbl2 = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.GothamMedium, Text = text or "", TextSize = 13, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = page })
            return {
                Set = function(v) lbl2.Text = v end,
                Get = function() return lbl2.Text end,
            }
        end

        function tab:CreateParagraph(title, bodyText)
            local p = new("Frame", { BackgroundColor3 = T.Secondary, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = page })
            round(p, 8)
            outline(p)
            new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = p })
            new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.GothamBold, Text = title or "", TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = p })
            local body2 = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham, Text = bodyText or "", TextSize = 12, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = p })
            new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p })
            return { Set = function(v) body2.Text = v end }
        end

        function tab:CreateButton(text, callback)
            local btn2 = new("TextButton", { BackgroundColor3 = T.Tertiary, Size = UDim2.new(1, 0, 0, 36), Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = page })
            round(btn2, 8)
            outline(btn2)
            local lbl2 = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamMedium, Text = text or "Button", TextSize = 13, TextColor3 = T.Text, Parent = btn2 })
            btn2.MouseEnter:Connect(function() tween(btn2, 0.15, { BackgroundColor3 = T.Hover }) end)
            btn2.MouseLeave:Connect(function() tween(btn2, 0.15, { BackgroundColor3 = T.Tertiary }) end)
            btn2.MouseButton1Click:Connect(function()
                tween(lbl2, 0.1, { TextColor3 = T.Accent })
                task.delay(0.18, function() tween(lbl2, 0.25, { TextColor3 = T.Text }) end)
                if callback then task.spawn(pcall, callback) end
            end)
            return { Set = function(v) lbl2.Text = v end }
        end

        function tab:CreateToggle(text, default, callback, flag)
            local state = default and true or false
            local row = new("TextButton", { BackgroundColor3 = T.Tertiary, Size = UDim2.new(1, 0, 0, 36), Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = page })
            round(row, 8)
            addTitle(row, text)

            local sw = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(40, 20), BackgroundColor3 = state and T.Accent or T.Border, BorderSizePixel = 0, Parent = row })
            round(sw, 10)
            local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = sw })
            round(knob, 6)

            local function paint(animate)
                local bg = state and T.Accent or T.Border
                local pos = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
                if animate then
                    tween(sw, 0.2, { BackgroundColor3 = bg })
                    tween(knob, 0.2, { Position = pos })
                else
                    sw.BackgroundColor3 = bg
                    knob.Position = pos
                end
            end

            row.MouseButton1Click:Connect(function()
                state = not state
                paint(true)
                if callback then task.spawn(pcall, callback, state) end
            end)

            registerFlag(flag, function() return state end, function(v)
                state = v and true or false
                paint(false)
            end)
            return {
                Set = function(v) state = v and true or false; paint(false) end,
                Get = function() return state end,
            }
        end

        function tab:CreateSlider(text, min, max, default, step, callback, flag)
            min, max = min or 0, max or 100
            step = step or 1
            if step <= 0 then step = 1 end
            local value = math.clamp(default or min, min, max)

            local row = addRow(46)
            addTitle(row, text)
            local valLabel = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(90, 14), Font = Enum.Font.GothamBold, Text = tostring(value), TextSize = 12, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })

            local bar = new("Frame", { Position = UDim2.new(0, 12, 1, -16), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = T.Border, BorderSizePixel = 0, Parent = row })
            round(bar, 3)
            local pct0 = (value - min) / (max - min)
            local fill = new("Frame", { Size = UDim2.new(pct0, 0, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = bar })
            round(fill, 3)
            local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(pct0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = T.Text, BorderSizePixel = 0, Parent = bar })
            round(knob, 7)
            outline(knob, T.Background, 2)

            local function setValue(v, fire)
                local pct = math.clamp((v - min) / (max - min), 0, 1)
                value = min + (max - min) * pct
                if step >= 1 then
                    value = math.floor(value / step + 0.5) * step
                else
                    value = math.floor(value * 100 + 0.5) / 100
                end
                value = math.clamp(value, min, max)
                valLabel.Text = tostring(step >= 1 and math.floor(value + 0.5) or value)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                knob.Position = UDim2.new(pct, 0, 0.5, 0)
                if fire and callback then task.spawn(pcall, callback, value) end
            end

            local sliding = false
            bar.InputBegan:Connect(function(input)
                if isPressed(input) then
                    sliding = true
                    local pct = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    setValue(min + (max - min) * pct, true)
                end
            end)
            bind(UserInputService.InputChanged, function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local pct = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    setValue(min + (max - min) * pct, true)
                end
            end)
            bind(UserInputService.InputEnded, function(input)
                if isPressed(input) then sliding = false end
            end)

            registerFlag(flag, function() return value end, function(v) setValue(v, false) end)
            return {
                Set = function(v) setValue(v, false) end,
                Get = function() return value end,
            }
        end

        function tab:CreateDropdown(text, options, default, callback, multiSelect, flag)
            options = options or {}
            local selected = {}
            if multiSelect then
                for _, v in ipairs(default or {}) do table.insert(selected, v) end
            else
                selected[1] = default
            end

            local row = addRow(36)
            addTitle(row, text)
            local btn2 = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 130, 0, 26), BackgroundColor3 = T.Secondary, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = row })
            round(btn2, 6)
            outline(btn2)
            local btnLabel = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -26, 1, 0), Font = Enum.Font.GothamMedium, Text = "", TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn2 })
            local arrow = new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(12, 12), Font = Enum.Font.GothamBold, Text = "▾", TextSize = 10, TextColor3 = T.SubText, Parent = btn2 })

            local open, popup = false, nil

            local function refreshLabel()
                if multiSelect then
                    btnLabel.Text = #selected > 0 and table.concat(selected, ", ") or "Select..."
                else
                    btnLabel.Text = tostring(selected[1] or "Select...")
                end
            end
            refreshLabel()

            local function closePopup()
                open = false
                if popup then popup:Destroy(); popup = nil end
                arrow.Text = "▾"
            end

            local function togglePopup()
                if open then closePopup() return end
                open = true
                arrow.Text = "▴"

                local popH = math.min(#options, 8) * 26 + 8
                local relX = btn2.AbsolutePosition.X - main.AbsolutePosition.X
                local relY = btn2.AbsolutePosition.Y - main.AbsolutePosition.Y
                local popY = relY + btn2.AbsoluteSize.Y + 4
                if popY + popH > main.AbsoluteSize.Y - 8 then
                    popY = relY - popH - 4
                end

                popup = new("Frame", { Position = UDim2.new(0, relX, 0, popY), Size = UDim2.new(0, btn2.AbsoluteSize.X, 0, popH), BackgroundColor3 = T.Secondary, BorderSizePixel = 0, ZIndex = 50, Parent = main })
                round(popup, 8)
                outline(popup)

                local list = new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, BorderSizePixel = 0, ZIndex = 50, Parent = popup })
                new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
                new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), Parent = list })

                for _, opt in ipairs(options) do
                    local ob = new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Secondary, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 51, Parent = list })
                    round(ob, 6)
                    local ol = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -8, 1, 0), Font = Enum.Font.Gotham, Text = tostring(opt), TextSize = 12, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 52, Parent = ob })

                    local function paintOption()
                        local isSel
                        if multiSelect then
                            isSel = table.find(selected, opt) ~= nil
                        else
                            isSel = selected[1] == opt
                        end
                        ol.TextColor3 = isSel and T.Accent or T.SubText
                        ob.BackgroundColor3 = isSel and T.Tertiary or T.Secondary
                    end
                    paintOption()

                    ob.MouseEnter:Connect(function() ob.BackgroundColor3 = T.Hover end)
                    ob.MouseLeave:Connect(function() paintOption() end)
                    ob.MouseButton1Click:Connect(function()
                        if multiSelect then
                            local i = table.find(selected, opt)
                            if i then table.remove(selected, i) else table.insert(selected, opt) end
                            refreshLabel()
                            paintOption()
                            if callback then task.spawn(pcall, callback, selected) end
                        else
                            selected = { opt }
                            refreshLabel()
                            paintOption()
                            if callback then task.spawn(pcall, callback, opt) end
                            closePopup()
                        end
                    end)
                end
            end

            btn2.MouseButton1Click:Connect(togglePopup)
            bind(page:GetPropertyChangedSignal("CanvasPosition"), closePopup)
            bind(UserInputService.InputBegan, function(input)
                if open and isPressed(input) and popup then
                    local p = input.Position
                    if not pointIn(p, popup.AbsolutePosition, popup.AbsoluteSize) and not pointIn(p, btn2.AbsolutePosition, btn2.AbsoluteSize) then
                        closePopup()
                    end
                end
            end)

            registerFlag(flag,
                function() return multiSelect and selected or selected[1] end,
                function(v)
                    if multiSelect then
                        selected = {}
                        if type(v) == "table" then
                            for _, x in ipairs(v) do table.insert(selected, x) end
                        end
                    else
                        selected = { v }
                    end
                    refreshLabel()
                end)
            return {
                Set = function(v)
                    if multiSelect then
                        selected = {}
                        if type(v) == "table" then
                            for _, x in ipairs(v) do table.insert(selected, x) end
                        end
                    else
                        selected = { v }
                    end
                    refreshLabel()
                end,
                Get = function() return multiSelect and selected or selected[1] end,
                Refresh = function(newOpts)
                    options = newOpts or options
                    if popup then closePopup(); togglePopup() end
                end,
            }
        end

        function tab:CreateTextbox(text, placeholder, default, callback, flag)
            local row = addRow(36)
            addTitle(row, text)
            local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 140, 0, 26), BackgroundColor3 = T.Secondary, Font = Enum.Font.Gotham, Text = default or "", PlaceholderText = placeholder or "", PlaceholderColor3 = T.SubText, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0, Parent = row })
            round(box, 6)
            outline(box)
            box:GetPropertyChangedSignal("Text"):Connect(function()
                box.TextColor3 = T.Text
            end)
            box.FocusLost:Connect(function(enter)
                if callback then task.spawn(pcall, callback, box.Text, enter) end
            end)
            registerFlag(flag, function() return box.Text end, function(v) box.Text = v end)
            return {
                Set = function(v) box.Text = v end,
                Get = function() return box.Text end,
            }
        end

        function tab:CreateKeybind(text, defaultKey, callback, flag)
            local key = defaultKey
            local listening = false
            local row = addRow(36)
            addTitle(row, text)
            local btn2 = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(90, 26), BackgroundColor3 = T.Secondary, Font = Enum.Font.GothamMedium, Text = key and key.Name or "None", TextSize = 12, TextColor3 = T.Text, AutoButtonColor = false, BorderSizePixel = 0, Parent = row })
            round(btn2, 6)
            outline(btn2)

            btn2.MouseButton1Click:Connect(function()
                listening = true
                btn2.Text = "..."
                btn2.TextColor3 = T.Accent
            end)

            bind(UserInputService.InputBegan, function(input, gpe)
                if listening then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        if input.KeyCode ~= Enum.KeyCode.Escape then
                            key = input.KeyCode
                        end
                        btn2.Text = key and key.Name or "None"
                        btn2.TextColor3 = T.Text
                    end
                    return
                end
                if key and not gpe and input.KeyCode == key then
                    if callback then task.spawn(pcall, callback) end
                end
            end)

            registerFlag(flag, function() return key end, function(v)
                key = v
                btn2.Text = key and key.Name or "None"
            end)
            return {
                Set = function(v) key = v; btn2.Text = v and v.Name or "None" end,
                Get = function() return key end,
            }
        end

        function tab:CreateColorPicker(text, default, callback, flag)
            local color = default or Color3.fromRGB(255, 255, 255)
            local h, s, v = color:ToHSV()
            local popup

            local row = addRow(36)
            addTitle(row, text)
            local swatch = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(40, 22), BackgroundColor3 = color, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = row })
            round(swatch, 6)
            outline(swatch)

            local function fire()
                if callback then task.spawn(pcall, callback, color) end
            end
            local function closePopup()
                if popup then popup:Destroy(); popup = nil end
            end

            local apply
            local function openPopup()
                closePopup()
                popup = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(230, 250), BackgroundColor3 = T.Secondary, BorderSizePixel = 0, ZIndex = 60, Parent = main })
                round(popup, 10)
                outline(popup)

                new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -44, 0, 20), Font = Enum.Font.GothamBold, Text = text or "Color", TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61, Parent = popup })
                local x = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "✕", TextSize = 14, TextColor3 = T.SubText, ZIndex = 61, Parent = popup })
                x.MouseButton1Click:Connect(closePopup)

                local sv = new("Frame", { Position = UDim2.new(0, 12, 0, 34), Size = UDim2.new(1, -24, 0, 130), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, ZIndex = 61, Parent = popup })
                round(sv, 6)
                local wOv = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 62, Parent = sv })
                round(wOv, 6)
                new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = wOv })
                local bOv = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 63, Parent = sv })
                round(bOv, 6)
                new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = bOv })

                local cursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(s, 1 - v), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 64, Parent = sv })
                round(cursor, 5)
                outline(cursor, Color3.new(0, 0, 0), 1)

                local hue = new("Frame", { Position = UDim2.new(0, 12, 0, 172), Size = UDim2.new(1, -24, 0, 12), BorderSizePixel = 0, ZIndex = 61, Parent = popup })
                round(hue, 6)
                new("UIGradient", { Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 0)),
                }), Parent = hue })
                local hueMark = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(h, 0, 0.5, 0), Size = UDim2.fromOffset(6, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 64, Parent = hue })
                round(hueMark, 3)
                outline(hueMark, Color3.new(0, 0, 0), 1)

                local rgbLabel = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 192), Size = UDim2.new(1, -24, 0, 16), Font = Enum.Font.Gotham, Text = "", TextSize = 12, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61, Parent = popup })

                local presetRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 216), Size = UDim2.new(1, -24, 0, 18), ZIndex = 61, Parent = popup })
                new("UIListLayout", { Padding = UDim.new(0, 6), FillDirection = Enum.FillDirection.Horizontal, Parent = presetRow })
                for _, pc in ipairs({
                    Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0),
                    Color3.fromRGB(231, 76, 60), Color3.fromRGB(241, 196, 15),
                    Color3.fromRGB(46, 204, 113), Color3.fromRGB(52, 152, 219),
                    Color3.fromRGB(139, 92, 246), Color3.fromRGB(255, 105, 180),
                }) do
                    local pb = new("TextButton", { Size = UDim2.fromOffset(20, 18), BackgroundColor3 = pc, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 62, Parent = presetRow })
                    round(pb, 4)
                    pb.MouseButton1Click:Connect(function()
                        h, s, v = pc:ToHSV()
                        apply(true)
                    end)
                end

                apply = function(fireCb)
                    color = Color3.fromHSV(h, s, v)
                    swatch.BackgroundColor3 = color
                    sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    cursor.Position = UDim2.fromScale(s, 1 - v)
                    hueMark.Position = UDim2.new(h, 0, 0.5, 0)
                    rgbLabel.Text = math.floor(color.R * 255 + 0.5) .. ", " .. math.floor(color.G * 255 + 0.5) .. ", " .. math.floor(color.B * 255 + 0.5)
                    if fireCb then fire() end
                end
                apply(false)

                local dSV, dHue = false, false
                sv.InputBegan:Connect(function(input)
                    if isPressed(input) then
                        dSV = true
                        s = math.clamp((input.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
                        v = math.clamp(1 - (input.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
                        apply(true)
                    end
                end)
                hue.InputBegan:Connect(function(input)
                    if isPressed(input) then
                        dHue = true
                        h = math.clamp((input.Position.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
                        apply(true)
                    end
                end)
                bind(UserInputService.InputChanged, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                        if dSV then
                            s = math.clamp((input.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
                            v = math.clamp(1 - (input.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
                            apply(true)
                        elseif dHue then
                            h = math.clamp((input.Position.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
                            apply(true)
                        end
                    end
                end)
                bind(UserInputService.InputEnded, function(input)
                    if isPressed(input) then dSV = false; dHue = false end
                end)
            end

            swatch.MouseButton1Click:Connect(function()
                if popup then closePopup() else openPopup() end
            end)
            bind(UserInputService.InputBegan, function(input)
                if popup and isPressed(input) then
                    local p = input.Position
                    if not pointIn(p, popup.AbsolutePosition, popup.AbsoluteSize) and not pointIn(p, swatch.AbsolutePosition, swatch.AbsoluteSize) then
                        closePopup()
                    end
                end
            end)

            registerFlag(flag, function() return color end, function(c)
                color = c
                h, s, v = c:ToHSV()
                swatch.BackgroundColor3 = c
            end)
            return {
                Set = function(c)
                    color = c
                    h, s, v = c:ToHSV()
                    swatch.BackgroundColor3 = c
                end,
                Get = function() return color end,
            }
        end

        return tab
    end

    function Window:AddConfigTab(name)
        local tab = Window:CreateTab(name or "Configs", "💾")
        local refresh

        tab:CreateSection("Save")
        local nameBox = tab:CreateTextbox("Config Name", "enter name...", "")
        tab:CreateButton("Save Current Config", function()
            local n = nameBox.Get()
            if n == "" then
                ModernUI:Notify({ Title = "Config", Text = "Enter a config name first", Type = "warn" })
                return
            end
            if ModernUI:SaveConfig(n) and refresh then refresh() end
        end)

        tab:CreateSection("Load")
        local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = tab.Page })
        new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })

        refresh = function()
            for _, c in ipairs(holder:GetChildren()) do
                if c:IsA("GuiObject") then c:Destroy() end
            end
            local configs = ModernUI:GetConfigs()
            if #configs == 0 then
                new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.Gotham, Text = fileOK and "No saved configs yet" or "File saving not supported", TextSize = 12, TextColor3 = T.SubText, Parent = holder })
            else
                for _, cfgName in ipairs(configs) do
                    local r = new("Frame", { BackgroundColor3 = T.Tertiary, Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, Parent = holder })
                    round(r, 6)
                    new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -110, 1, 0), Font = Enum.Font.GothamMedium, Text = cfgName, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })

                    local loadBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0), Size = UDim2.fromOffset(48, 20), BackgroundColor3 = T.Accent, Font = Enum.Font.GothamBold, Text = "Load", TextSize = 11, TextColor3 = T.Text, AutoButtonColor = false, BorderSizePixel = 0, Parent = r })
                    round(loadBtn, 5)
                    loadBtn.MouseButton1Click:Connect(function()
                        ModernUI:LoadConfig(cfgName)
                    end)

                    local delBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(22, 20), BackgroundColor3 = T.Error, Font = Enum.Font.GothamBold, Text = "✕", TextSize = 11, TextColor3 = T.Text, AutoButtonColor = false, BorderSizePixel = 0, Parent = r })
                    round(delBtn, 5)
                    delBtn.MouseButton1Click:Connect(function()
                        ModernUI:DeleteConfig(cfgName)
                        refresh()
                    end)
                end
            end
        end
        refresh()
        return tab
    end

    new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.Gotham, Text = "ModernUI v" .. ModernUI.Version, TextSize = 10, TextColor3 = T.SubText, TextTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Center, Parent = sidebar })

    return Window
end

return ModernUI
