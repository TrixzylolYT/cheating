local ModernUI = {}

function ModernUI:CreateWindow(titleText)
    -- Safe GUI Parenting (Supports standard executors)
    local targetParent = game:GetService("CoreGui")
    pcall(function() if gethui then targetParent = gethui() end end)
    if not pcall(function() local _ = targetParent.Name end) then
        targetParent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Clean up old instance if reloading
    if targetParent:FindFirstChild("ModernUILib") then
        targetParent.ModernUILib:Destroy()
    end

    -- Theme Colors
    local Theme = {
        Background = Color3.fromRGB(25, 25, 30),
        TopBar = Color3.fromRGB(30, 30, 35),
        TabArea = Color3.fromRGB(20, 20, 25),
        ElementBg = Color3.fromRGB(35, 35, 42),
        Accent = Color3.fromRGB(88, 101, 242), -- Sleek Blurple
        Text = Color3.fromRGB(240, 240, 240),
        TextMuted = Color3.fromRGB(150, 150, 150)
    }

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ModernUILib"
    ScreenGui.Parent = targetParent

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 450, 0, 300)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundColor3 = Theme.TopBar
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame
    Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)
    
    -- Hide bottom corners of topbar to blend with main frame
    local TopBarFix = Instance.new("Frame")
    TopBarFix.Size = UDim2.new(1, 0, 0, 8)
    TopBarFix.Position = UDim2.new(0, 0, 1, -8)
    TopBarFix.BackgroundColor3 = Theme.TopBar
    TopBarFix.BorderSizePixel = 0
    TopBarFix.Parent = TopBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 1, 0)
    Title.Position = UDim2.new(0, 20, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = titleText or "Modern UI Library"
    Title.TextColor3 = Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(0, 120, 1, -35)
    TabContainer.Position = UDim2.new(0, 0, 0, 35)
    TabContainer.BackgroundColor3 = Theme.TabArea
    TabContainer.BorderSizePixel = 0
    TabContainer.Parent = MainFrame
    
    local TabListLayout = Instance.new("UIListLayout", TabContainer)
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding", TabContainer).PaddingTop = UDim.new(0, 10)

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -120, 1, -35)
    ContentContainer.Position = UDim2.new(0, 120, 0, 35)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    local WindowObj = {
        Tabs = {},
        CurrentTab = nil
    }

    function WindowObj:CreateTab(tabName)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, 0, 0, 35)
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = "  " .. tabName
        TabBtn.TextColor3 = Theme.TextMuted
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 13
        TabBtn.TextXAlignment = Enum.TextXAlignment.Left
        TabBtn.Parent = TabContainer

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.BorderSizePixel = 0
        TabPage.ScrollBarThickness = 2
        TabPage.Visible = false
        TabPage.Parent = ContentContainer
        
        local PageLayout = Instance.new("UIListLayout", TabPage)
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 8)
        
        local PagePadding = Instance.new("UIPadding", TabPage)
        PagePadding.PaddingTop = UDim.new(0, 15)
        PagePadding.PaddingLeft = UDim.new(0, 15)
        PagePadding.PaddingRight = UDim.new(0, 15)

        -- Handle Tab Switching
        TabBtn.MouseButton1Click:Connect(function()
            for _, tabData in pairs(WindowObj.Tabs) do
                tabData.Page.Visible = false
                tabData.Button.TextColor3 = Theme.TextMuted
                tabData.Button.Font = Enum.Font.GothamMedium
            end
            TabPage.Visible = true
            TabBtn.TextColor3 = Theme.Accent
            TabBtn.Font = Enum.Font.GothamBold
        end)

        table.insert(WindowObj.Tabs, {Button = TabBtn, Page = TabPage})
        
        -- Auto-select first tab
        if #WindowObj.Tabs == 1 then
            TabPage.Visible = true
            TabBtn.TextColor3 = Theme.Accent
            TabBtn.Font = Enum.Font.GothamBold
        end

        local TabObj = {}

        function TabObj:CreateButton(btnText, callback)
            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(1, 0, 0, 35)
            Btn.BackgroundColor3 = Theme.ElementBg
            Btn.Text = btnText
            Btn.TextColor3 = Theme.Text
            Btn.Font = Enum.Font.GothamSemibold
            Btn.TextSize = 13
            Btn.AutoButtonColor = false
            Btn.Parent = TabPage
            Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

            -- Hover Effects
            Btn.MouseEnter:Connect(function() Btn.BackgroundColor3 = Color3.fromRGB(45, 45, 52) end)
            Btn.MouseLeave:Connect(function() Btn.BackgroundColor3 = Theme.ElementBg end)
            
            Btn.MouseButton1Click:Connect(function()
                Btn.BackgroundColor3 = Theme.Accent
                task.wait(0.1)
                Btn.BackgroundColor3 = Theme.ElementBg
                if callback then callback() end
            end)
        end

        function TabObj:CreateToggle(toggleText, defaultState, callback)
            local state = defaultState or false
            
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, 0, 0, 35)
            ToggleFrame.BackgroundColor3 = Theme.ElementBg
            ToggleFrame.Parent = TabPage
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(1, -60, 1, 0)
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.BackgroundTransparency = 1
            Label.Text = toggleText
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.GothamSemibold
            Label.TextSize = 13
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = ToggleFrame

            local ToggleBtn = Instance.new("TextButton")
            ToggleBtn.Size = UDim2.new(0, 40, 0, 20)
            ToggleBtn.Position = UDim2.new(1, -50, 0.5, -10)
            ToggleBtn.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(60, 60, 70)
            ToggleBtn.Text = ""
            ToggleBtn.Parent = ToggleFrame
            Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
            
            ToggleBtn.MouseButton1Click:Connect(function()
                state = not state
                ToggleBtn.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(60, 60, 70)
                if callback then callback(state) end
            end)
        end

        return TabObj
    end

    return WindowObj
end
