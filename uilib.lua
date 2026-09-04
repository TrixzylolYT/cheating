local ModernUI = {}

function ModernUI:CreateWindow(titleText)
    -- Services
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    
    -- Safe GUI Parenting (Supports standard executors)
    local targetParent = game:GetService("CoreGui")

    pcall(function()
        if gethui then
            targetParent = gethui()
        end
    end)

    if not pcall(function()
        local _ = targetParent.Name
    end) then
        targetParent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Clean up old instance if reloading
    local oldGui = targetParent:FindFirstChild("ModernUILib")
    if oldGui then
        oldGui:Destroy()
    end

    -- Theme Colors
    local Theme = {
        Background = Color3.fromRGB(25, 25, 30),
        TopBar = Color3.fromRGB(30, 30, 35),
        TabArea = Color3.fromRGB(20, 20, 25),
        ElementBg = Color3.fromRGB(35, 35, 42),
        ElementHover = Color3.fromRGB(45, 45, 52),
        ToggleOff = Color3.fromRGB(60, 60, 70),
        SliderBackground = Color3.fromRGB(55, 55, 65),

        Accent = Color3.fromRGB(88, 101, 242),

        Text = Color3.fromRGB(240, 240, 240),
        TextMuted = Color3.fromRGB(150, 150, 150)
    }

    -- ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ModernUILib"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = targetParent

    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 450, 0, 300)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    -- Top Bar
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundColor3 = Theme.TopBar
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

    -- Hide bottom corners of topbar to blend with main frame
    local TopBarFix = Instance.new("Frame")
    TopBarFix.Name = "BottomFix"
    TopBarFix.Size = UDim2.new(1, 0, 0, 8)
    TopBarFix.Position = UDim2.new(0, 0, 1, -8)
    TopBarFix.BackgroundColor3 = Theme.TopBar
    TopBarFix.BorderSizePixel = 0
    TopBarFix.Parent = TopBar

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -20, 1, 0)
    Title.Position = UDim2.new(0, 20, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = titleText or "Modern UI Library"
    Title.TextColor3 = Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    -- Tab Container
    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(0, 120, 1, -35)
    TabContainer.Position = UDim2.new(0, 0, 0, 35)
    TabContainer.BackgroundColor3 = Theme.TabArea
    TabContainer.BorderSizePixel = 0
    TabContainer.Parent = MainFrame

    local TabListLayout = Instance.new("UIListLayout")
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabListLayout.Parent = TabContainer

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingTop = UDim.new(0, 10)
    TabPadding.Parent = TabContainer

    -- Content Container
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Size = UDim2.new(1, -120, 1, -35)
    ContentContainer.Position = UDim2.new(0, 120, 0, 35)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    -- Window Object
    local WindowObj = {
        Tabs = {},
        CurrentTab = nil
    }

    function WindowObj:CreateTab(tabName)
        -- Tab Button
        local TabBtn = Instance.new("TextButton")
        TabBtn.Name = tabName .. "Tab"
        TabBtn.Size = UDim2.new(1, 0, 0, 35)
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = "  " .. tabName
        TabBtn.TextColor3 = Theme.TextMuted
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 13
        TabBtn.TextXAlignment = Enum.TextXAlignment.Left
        TabBtn.AutoButtonColor = false
        TabBtn.Parent = TabContainer

        -- Tab Page
        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Name = tabName .. "Page"
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.BorderSizePixel = 0
        TabPage.ScrollBarThickness = 2
        TabPage.ScrollBarImageColor3 = Theme.Accent
        TabPage.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
        TabPage.Visible = false
        TabPage.Parent = ContentContainer

        -- Page Layout
        local PageLayout = Instance.new("UIListLayout")
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 8)
        PageLayout.Parent = TabPage

        -- Page Padding
        local PagePadding = Instance.new("UIPadding")
        PagePadding.PaddingTop = UDim.new(0, 15)
        PagePadding.PaddingLeft = UDim.new(0, 15)
        PagePadding.PaddingRight = UDim.new(0, 15)
        PagePadding.PaddingBottom = UDim.new(0, 15)
        PagePadding.Parent = TabPage

        -- Tab Switch
        TabBtn.MouseButton1Click:Connect(function()
            for _, tabData in ipairs(WindowObj.Tabs) do
                tabData.Page.Visible = false
                tabData.Button.TextColor3 = Theme.TextMuted
                tabData.Button.Font = Enum.Font.GothamMedium
            end

            TabPage.Visible = true
            TabBtn.TextColor3 = Theme.Accent
            TabBtn.Font = Enum.Font.GothamBold
            WindowObj.CurrentTab = tabName
        end)

        -- Store
        table.insert(WindowObj.Tabs, {
            Button = TabBtn,
            Page = TabPage,
            Name = tabName
        })

        -- Auto-select first tab
        if #WindowObj.Tabs == 1 then
            TabPage.Visible = true
            TabBtn.TextColor3 = Theme.Accent
            TabBtn.Font = Enum.Font.GothamBold
            WindowObj.CurrentTab = tabName
        end

        local TabObj = {}

        ----------------------------------------------------------------
        -- BUTTON
        ----------------------------------------------------------------

        function TabObj:CreateButton(btnText, callback)
            local Btn = Instance.new("TextButton")
            Btn.Name = btnText
            Btn.Size = UDim2.new(1, 0, 0, 35)
            Btn.BackgroundColor3 = Theme.ElementBg
            Btn.BorderSizePixel = 0
            Btn.Text = btnText
            Btn.TextColor3 = Theme.Text
            Btn.Font = Enum.Font.GothamSemibold
            Btn.TextSize = 13
            Btn.AutoButtonColor = false
            Btn.Parent = TabPage

            Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

            Btn.MouseEnter:Connect(function()
                Btn.BackgroundColor3 = Theme.ElementHover
            end)

            Btn.MouseLeave:Connect(function()
                Btn.BackgroundColor3 = Theme.ElementBg
            end)

            Btn.MouseButton1Click:Connect(function()
                Btn.BackgroundColor3 = Theme.Accent

                task.delay(0.1, function()
                    if Btn and Btn.Parent then
                        Btn.BackgroundColor3 = Theme.ElementBg
                    end
                end)

                if callback then
                    callback()
                end
            end)

            return Btn
        end

        ----------------------------------------------------------------
        -- TOGGLE
        ----------------------------------------------------------------

        function TabObj:CreateToggle(toggleText, defaultState, callback)
            local state = defaultState == true

            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Name = toggleText
            ToggleFrame.Size = UDim2.new(1, 0, 0, 35)
            ToggleFrame.BackgroundColor3 = Theme.ElementBg
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Parent = TabPage

            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)

            -- Label
            local Label = Instance.new("TextLabel")
            Label.Name = "Label"
            Label.Size = UDim2.new(1, -60, 1, 0)
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.BackgroundTransparency = 1
            Label.Text = toggleText
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.GothamSemibold
            Label.TextSize = 13
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = ToggleFrame

            -- Toggle Button
            local ToggleBtn = Instance.new("TextButton")
            ToggleBtn.Name = "Toggle"
            ToggleBtn.Size = UDim2.new(0, 40, 0, 20)
            ToggleBtn.Position = UDim2.new(1, -50, 0.5, -10)
            ToggleBtn.BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff
            ToggleBtn.Text = ""
            ToggleBtn.AutoButtonColor = false
            ToggleBtn.Parent = ToggleFrame

            Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)

            -- Toggle indicator
            local ToggleIndicator = Instance.new("Frame")
            ToggleIndicator.Name = "Indicator"
            ToggleIndicator.Size = UDim2.new(0, 16, 0, 16)
            ToggleIndicator.Position = UDim2.new(
                state and 1 or 0,
                state and -18 or 2,
                0.5,
                -8
            )
            ToggleIndicator.BackgroundColor3 = Theme.Text
            ToggleIndicator.BorderSizePixel = 0
            ToggleIndicator.Parent = ToggleBtn

            Instance.new("UICorner", ToggleIndicator).CornerRadius = UDim.new(1, 0)

            local function updateToggle()
                ToggleBtn.BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff

                ToggleIndicator.Position = UDim2.new(
                    state and 1 or 0,
                    state and -18 or 2,
                    0.5,
                    -8
                )
            end

            ToggleBtn.MouseButton1Click:Connect(function()
                state = not state
                updateToggle()

                if callback then
                    callback(state)
                end
            end)

            -- Optional click on the entire frame
            ToggleFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if input.Target ~= ToggleBtn then
                        state = not state
                        updateToggle()

                        if callback then
                            callback(state)
                        end
                    end
                end
            end)

            return {
                Set = function(_, newState)
                    state = newState == true
                    updateToggle()

                    if callback then
                        callback(state)
                    end
                end,

                Get = function()
                    return state
                end
            }
        end

        ----------------------------------------------------------------
        -- SLIDER
        ----------------------------------------------------------------

        function TabObj:CreateSlider(sliderText, minValue, maxValue, defaultValue, step, callback)
            minValue = minValue or 0
            maxValue = maxValue or 100
            defaultValue = defaultValue or minValue
            step = step or 1

            -- Prevent invalid configuration
            if maxValue < minValue then
                minValue, maxValue = maxValue, minValue
            end

            if step <= 0 then
                step = 1
            end

            local value = math.clamp(defaultValue, minValue, maxValue)

            -- Main slider container
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Name = sliderText
            SliderFrame.Size = UDim2.new(1, 0, 0, 50)
            SliderFrame.BackgroundColor3 = Theme.ElementBg
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Parent = TabPage

            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 6)

            -- Label
            local Label = Instance.new("TextLabel")
            Label.Name = "Label"
            Label.Size = UDim2.new(1, -75, 0, 25)
            Label.Position = UDim2.new(0, 10, 0, 3)
            Label.BackgroundTransparency = 1
            Label.Text = sliderText
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.GothamSemibold
            Label.TextSize = 13
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = SliderFrame

            -- Value Label
            local ValueLabel = Instance.new("TextLabel")
            ValueLabel.Name = "Value"
            ValueLabel.Size = UDim2.new(0, 55, 0, 25)
            ValueLabel.Position = UDim2.new(1, -65, 0, 3)
            ValueLabel.BackgroundTransparency = 1
            ValueLabel.Text = tostring(value)
            ValueLabel.TextColor3 = Theme.TextMuted
            ValueLabel.Font = Enum.Font.GothamMedium
            ValueLabel.TextSize = 12
            ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
            ValueLabel.Parent = SliderFrame

            -- Slider background
            local SliderBackground = Instance.new("Frame")
            SliderBackground.Name = "Background"
            SliderBackground.Size = UDim2.new(1, -20, 0, 6)
            SliderBackground.Position = UDim2.new(0, 10, 1, -14)
            SliderBackground.BackgroundColor3 = Theme.SliderBackground
            SliderBackground.BorderSizePixel = 0
            SliderBackground.Active = true
            SliderBackground.Parent = SliderFrame

            Instance.new("UICorner", SliderBackground).CornerRadius = UDim.new(1, 0)

            -- Fill
            local SliderFill = Instance.new("Frame")
            SliderFill.Name = "Fill"
            SliderFill.Size = UDim2.new(0, 0, 1, 0)
            SliderFill.BackgroundColor3 = Theme.Accent
            SliderFill.BorderSizePixel = 0
            SliderFill.Parent = SliderBackground

            Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

            -- Knob
            local Knob = Instance.new("Frame")
            Knob.Name = "Knob"
            Knob.AnchorPoint = Vector2.new(0.5, 0.5)
            Knob.Size = UDim2.new(0, 12, 0, 12)
            Knob.BackgroundColor3 = Theme.Text
            Knob.BorderSizePixel = 0
            Knob.Parent = SliderBackground

            Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

            -- Dragging state
            local dragging = false

            -- Step rounding
            local function roundToStep(number)
                local rounded = math.floor(
                    (number - minValue) / step + 0.5
                ) * step

                return math.clamp(
                    minValue + rounded,
                    minValue,
                    maxValue
                )
            end

            -- Update visuals + callback
            local function setValue(newValue, fireCallback)
                value = roundToStep(
                    math.clamp(newValue, minValue, maxValue)
                )

                local alpha = 0

                if maxValue ~= minValue then
                    alpha = (value - minValue) / (maxValue - minValue)
                end

                SliderFill.Size = UDim2.new(alpha, 0, 1, 0)

                Knob.Position = UDim2.new(
                    alpha,
                    0,
                    0.5,
                    0
                )

                -- Avoid ugly floating point output
                if math.abs(value - math.round(value)) < 0.000001 then
                    ValueLabel.Text = tostring(math.round(value))
                else
                    ValueLabel.Text = string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
                end

                if fireCallback and callback then
                    callback(value)
                end
            end

            -- Convert X position to a value
            local function updateFromMouse(x)
                local width = SliderBackground.AbsoluteSize.X

                if width <= 0 then
                    return
                end

                local relativeX = math.clamp(
                    x - SliderBackground.AbsolutePosition.X,
                    0,
                    width
                )

                local alpha = relativeX / width

                local newValue =
                    minValue +
                    ((maxValue - minValue) * alpha)

                setValue(newValue, true)
            end

            -- Click / begin dragging
            SliderBackground.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    updateFromMouse(input.Position.X)
                end
            end)

            -- Drag
            UserInputService.InputChanged:Connect(function(input)
                if not dragging then
                    return
                end

                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateFromMouse(input.Position.X)
                end
            end)

            -- Stop dragging
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)

            -- Initialize
            setValue(value, false)

            if callback then
                callback(value)
            end

            -- Return slider controls
            return {
                Set = function(_, newValue)
                    setValue(newValue, true)
                end,

                Get = function()
                    return value
                end
            }
        end

        return TabObj
    end

    return WindowObj
end

return ModernUI
