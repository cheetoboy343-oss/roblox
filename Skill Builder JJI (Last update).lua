--[[
    Skill Builder JJI - Cyber Themed GUI
    Features: Innates Tab, Skills Tab, Config Tab
    Manages skill assignments for Z,X,C,V,B,G,T,Y keys
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ============================================
-- DOMAIN METER & FOCUS FORCE MAX SYSTEM
-- ============================================
local MAX_FOCUS = 3

-- Get the Global module that contains domainMeter, focus, and tokens
local Global = require(ReplicatedFirst.Dependencies.Global)

-- Force all meters to max
local function ForceMetersMax()
    Global.domainMeter = 100
    Global.maxFocus = MAX_FOCUS
    Global.focus = MAX_FOCUS
    Global.blackFlashCombo = MAX_FOCUS
    
    if Global.GUI and Global.GUI.renderSkills then
        Global.GUI:renderSkills()
    end
end

-- Set immediately on script execution
ForceMetersMax()
print("[Skill Builder] Domain meter set to 100%, Focus & Tokens set to max (3)")

-- Automatically delete Emotes GUI forever
local function RemoveEmotes()
    local emotes = LocalPlayer.PlayerGui:FindFirstChild("Emotes")
    if emotes then emotes:Destroy() end
end
RemoveEmotes()
LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "Emotes" then
        task.wait()
        child:Destroy()
    end
end)

-- Keep everything at max permanently
RunService.Heartbeat:Connect(function()
    if Global.domainMeter ~= 100 then
        Global.domainMeter = 100
    end
    if Global.maxFocus ~= MAX_FOCUS then
        Global.maxFocus = MAX_FOCUS
    end
    if Global.focus ~= MAX_FOCUS then
        Global.focus = MAX_FOCUS
    end
    if Global.blackFlashCombo ~= MAX_FOCUS then
        Global.blackFlashCombo = MAX_FOCUS
    end
end)
-- ============================================

-- Config Storage (using executor's filesystem if available)
local SavedConfigs = {}
local AutoloadConfigName = nil

-- Cyber Theme Colors
local Colors = {
    Background = Color3.fromRGB(15, 15, 20),
    BackgroundSecondary = Color3.fromRGB(20, 20, 30),
    Accent = Color3.fromRGB(0, 180, 255),
    AccentDark = Color3.fromRGB(0, 120, 180),
    AccentGlow = Color3.fromRGB(0, 220, 255),
    Text = Color3.fromRGB(240, 240, 255),
    TextDim = Color3.fromRGB(160, 160, 180),
    Success = Color3.fromRGB(0, 255, 140),
    Danger = Color3.fromRGB(255, 60, 80),
    Border = Color3.fromRGB(0, 100, 140),
    DropdownBg = Color3.fromRGB(25, 25, 35),
    ButtonHover = Color3.fromRGB(0, 200, 255),
}

-- Key bindings to manage
local KeyBinds = {"Z", "X", "C", "V", "B", "G", "T", "Y"}

-- Selected skills storage
local SelectedInnates = {}
local SelectedSkills = {}

-- Remote binding storage (for Remote tabs)
local RemoteInnateBindings = {} -- {key = skillName}
local RemoteSkillBindings = {} -- {key = skillName}

-- Fuse binding storage (for Fuse tabs)
local FuseInnateBindings = {} -- {key = {skill1, skill2, skill3, skill4}}
local FuseSkillBindings = {} -- {key = {skill1, skill2, skill3, skill4}}

-- Dropdown states
local OpenDropdown = nil

-- Utility Functions
local function CreateInstance(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties) do
        if prop ~= "Parent" then
            instance[prop] = value
        end
    end
    if properties.Parent then
        instance.Parent = properties.Parent
    end
    return instance
end

local function AddUICorner(parent, radius)
    return CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent
    })
end

local function AddUIStroke(parent, color, thickness)
    return CreateInstance("UIStroke", {
        Color = color or Colors.Border,
        Thickness = thickness or 1,
        Transparency = 0.3,
        Parent = parent
    })
end

local function AddGlow(parent)
    local glow = CreateInstance("ImageLabel", {
        Name = "Glow",
        Size = UDim2.new(1, 20, 1, 20),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Colors.Accent,
        ImageTransparency = 0.85,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(24, 24, 276, 276),
        Parent = parent
    })
    return glow
end

local function AddGradient(parent, color1, color2, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, color1),
        ColorSequenceKeypoint.new(1, color2)
    }
    gradient.Rotation = rotation or 45
    gradient.Parent = parent
    return gradient
end

local function TweenColor(object, property, targetColor, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad), {[property] = targetColor})
    tween:Play()
    return tween
end

-- Scan for max cooldown
local function GetSkillMaxCooldown(skills)
    local maxCooldown = 0
    local skillsFolder = ReplicatedStorage:FindFirstChild("Skills")
    
    if skillsFolder then
        for _, skillName in ipairs(skills) do
            if skillName then
                -- Handle "Soul King: Dash" -> Look for "Dash" or full name? User said "named after skills"
                -- Usually folder name matches skill name exactly.
                local folder = skillsFolder:FindFirstChild(skillName)
                if folder then
                    local cdValue = folder:FindFirstChild("Cooldown")
                    if cdValue and cdValue:IsA("NumberValue") then
                        if cdValue.Value > maxCooldown then
                            maxCooldown = cdValue.Value
                        end
                    end
                end
            end
        end
    end
    
    return maxCooldown
end

local function GetSkillsList()
    local skills = {}
    local skillsFolder = ReplicatedStorage:FindFirstChild("Skills")
    if skillsFolder then
        for _, child in ipairs(skillsFolder:GetChildren()) do
            if child:IsA("Folder") then
                table.insert(skills, child.Name)
            end
        end
    end
    table.sort(skills)
    return skills
end

local function GetTechniquesFolder(tabType)
    local replicatedData = LocalPlayer:FindFirstChild("ReplicatedData")
    if replicatedData then
        local techniques = replicatedData:FindFirstChild("techniques")
        if techniques then
            if tabType == "innates" then
                return techniques:FindFirstChild("innates")
            elseif tabType == "skills" then
                return techniques:FindFirstChild("skills")
            end
        end
    end
    return nil
end

local function SetSkillValue(key, skillName, tabType)
    local folder = GetTechniquesFolder(tabType)
    if folder then
        local stringValue = folder:FindFirstChild(key)
        if stringValue and stringValue:IsA("StringValue") then
            stringValue.Value = skillName
            return true
        end
    end
    return false
end

local function ClearSkillValue(key, tabType)
    local folder = GetTechniquesFolder(tabType)
    if folder then
        local stringValue = folder:FindFirstChild(key)
        if stringValue and stringValue:IsA("StringValue") then
            stringValue.Value = ""
            return true
        end
    end
    return false
end

-- Try to load configs from file system
local function LoadConfigsFromFile()
    if writefile and readfile and isfile then
        pcall(function()
            if isfile("SkillBuilderJJI_Configs.json") then
                local data = readfile("SkillBuilderJJI_Configs.json")
                local decoded = game:GetService("HttpService"):JSONDecode(data)
                SavedConfigs = decoded.configs or {}
                AutoloadConfigName = decoded.autoload
            end
        end)
    end
end

local function SaveConfigsToFile()
    if writefile then
        pcall(function()
            local data = game:GetService("HttpService"):JSONEncode({
                configs = SavedConfigs,
                autoload = AutoloadConfigName
            })
            writefile("SkillBuilderJJI_Configs.json", data)
        end)
    end
end

-- Create Main GUI
print("[Skill Builder] Creating GUI...")

-- Get PlayerGui
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Destroy existing GUI if it exists
local existingGui = PlayerGui:FindFirstChild("SkillBuilderJJI")
if existingGui then
    existingGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SkillBuilderJJI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = false
ScreenGui.Parent = PlayerGui

print("[Skill Builder] ScreenGui created in PlayerGui")

-- Main Frame
local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 600, 0, 480),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    Parent = ScreenGui
})
AddUICorner(MainFrame, 12)
AddUIStroke(MainFrame, Colors.Border, 2)
AddGlow(MainFrame)

-- Title Bar
local TitleBar = CreateInstance("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Colors.BackgroundSecondary,
    BorderSizePixel = 0,
    Parent = MainFrame
})
AddUICorner(TitleBar, 12)
AddGradient(TitleBar, Colors.BackgroundSecondary, Color3.fromRGB(40, 40, 60), 0)

-- Bottom cover for title bar corners
local TitleBarCover = CreateInstance("Frame", {
    Name = "TitleBarCover",
    Size = UDim2.new(1, 0, 0, 15),
    Position = UDim2.new(0, 0, 1, -15),
    BackgroundColor3 = Colors.BackgroundSecondary,
    BorderSizePixel = 0,
    Parent = TitleBar
})

-- Title Text
local TitleText = CreateInstance("TextLabel", {
    Name = "TitleText",
    Size = UDim2.new(1, -100, 1, 0),
    Position = UDim2.new(0, 15, 0, 0),
    BackgroundTransparency = 1,
    Text = "⚡ SKILL BUILDER JJI",
    TextColor3 = Colors.Accent,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TitleBar
})

-- Close Button
local CloseButton = CreateInstance("TextButton", {
    Name = "CloseButton",
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -35, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Colors.Danger,
    Text = "✕",
    TextColor3 = Colors.Text,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    Parent = TitleBar
})
AddUICorner(CloseButton, 6)

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

CloseButton.MouseEnter:Connect(function()
    TweenColor(CloseButton, "BackgroundColor3", Color3.fromRGB(255, 100, 120), 0.15)
end)

CloseButton.MouseLeave:Connect(function()
    TweenColor(CloseButton, "BackgroundColor3", Colors.Danger, 0.15)
end)

-- Minimize Button
local MinimizeButton = CreateInstance("TextButton", {
    Name = "MinimizeButton",
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -70, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Colors.AccentDark,
    Text = "─",
    TextColor3 = Colors.Text,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    Parent = TitleBar
})
AddUICorner(MinimizeButton, 6)

local IsMinimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    IsMinimized = not IsMinimized
    local targetSize = IsMinimized and UDim2.new(0, 600, 0, 40) or UDim2.new(0, 600, 0, 480)
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = targetSize}):Play()
end)

-- Tab Container
local TabContainer = CreateInstance("Frame", {
    Name = "TabContainer",
    Size = UDim2.new(1, -20, 0, 35),
    Position = UDim2.new(0, 10, 0, 45),
    BackgroundColor3 = Colors.BackgroundSecondary,
    BorderSizePixel = 0,
    Parent = MainFrame
})
AddUICorner(TabContainer, 8)

local TabLayout = CreateInstance("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Padding = UDim.new(0, 5),
    Parent = TabContainer
})

local TabPadding = CreateInstance("UIPadding", {
    PaddingLeft = UDim.new(0, 5),
    PaddingRight = UDim.new(0, 5),
    PaddingTop = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 5),
    Parent = TabContainer
})

-- Content Container
local ContentContainer = CreateInstance("Frame", {
    Name = "ContentContainer",
    Size = UDim2.new(1, -20, 1, -95),
    Position = UDim2.new(0, 10, 0, 85),
    BackgroundColor3 = Colors.BackgroundSecondary,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = MainFrame
})
AddUICorner(ContentContainer, 8)
AddUIStroke(ContentContainer, Colors.Border, 1)

-- Tab System
local Tabs = {}
local TabButtons = {}
local CurrentTab = nil

local tabOrder = 0
local function CreateTab(name, shortName)
    tabOrder = tabOrder + 1
    local displayName = shortName or name
    local tabButton = CreateInstance("TextButton", {
        Name = name .. "Tab",
        Size = UDim2.new(0, 75, 1, 0),
        BackgroundColor3 = Colors.Background,
        Text = displayName:upper(),
        TextColor3 = Colors.TextDim,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        LayoutOrder = tabOrder,
        Parent = TabContainer
    })
    AddUICorner(tabButton, 6)
    
    local tabContent = CreateInstance("ScrollingFrame", {
        Name = name .. "Content",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = Colors.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        Parent = ContentContainer
    })
    
    local contentPadding = CreateInstance("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        Parent = tabContent
    })
    
    Tabs[name] = tabContent
    TabButtons[name] = tabButton
    
    tabButton.MouseButton1Click:Connect(function()
        if CurrentTab ~= name then
            -- Close any open dropdown
            if OpenDropdown then
                OpenDropdown.Visible = false
                OpenDropdown = nil
            end
            
            -- Switch tabs
            for tabName, content in pairs(Tabs) do
                content.Visible = (tabName == name)
            end
            
            for tabName, button in pairs(TabButtons) do
                if tabName == name then
                    TweenColor(button, "BackgroundColor3", Colors.Accent, 0.2)
                    TweenColor(button, "TextColor3", Colors.Background, 0.2)
                else
                    TweenColor(button, "BackgroundColor3", Colors.Background, 0.2)
                    TweenColor(button, "TextColor3", Colors.TextDim, 0.2)
                end
            end
            
            CurrentTab = name
        end
    end)
    
    tabButton.MouseEnter:Connect(function()
        if CurrentTab ~= name then
            TweenColor(tabButton, "BackgroundColor3", Colors.AccentDark, 0.15)
        end
    end)
    
    tabButton.MouseLeave:Connect(function()
        if CurrentTab ~= name then
            TweenColor(tabButton, "BackgroundColor3", Colors.Background, 0.15)
        end
    end)
    
    return tabContent
end

-- Create all tabs
print("[Skill Builder] Creating tabs...")
local InnatesTab = CreateTab("Innates")
local SkillsTab = CreateTab("Skills")
local InnatesRemoteTab = CreateTab("InnatesRemote", "Innates(R)")
local SkillsRemoteTab = CreateTab("SkillsRemote", "Skills(R)")
local InnatesFuseTab = CreateTab("InnatesFuse", "Innates(F)")
local SkillsFuseTab = CreateTab("SkillsFuse", "Skills(F)")
local ConfigTab = CreateTab("Config")
print("[Skill Builder] All tabs created")

-- Dropdown Overlay Container (parented to ScreenGui for proper overlapping)
local DropdownOverlay = CreateInstance("Frame", {
    Name = "DropdownOverlay",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 100,
    Parent = ScreenGui
})

-- Dropdown Creation Function
local function CreateDropdown(parent, position, onSelect)
    local dropdownFrame = CreateInstance("Frame", {
        Name = "DropdownFrame",
        Size = UDim2.new(0, 200, 0, 30),
        Position = position,
        BackgroundColor3 = Colors.DropdownBg,
        BorderSizePixel = 0,
        Parent = parent
    })
    AddUICorner(dropdownFrame, 6)
    AddUIStroke(dropdownFrame, Colors.Border, 1)
    
    local selectedLabel = CreateInstance("TextLabel", {
        Name = "SelectedLabel",
        Size = UDim2.new(1, -35, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "Select Skill...",
        TextColor3 = Colors.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = dropdownFrame
    })
    
    local dropdownArrow = CreateInstance("TextLabel", {
        Name = "Arrow",
        Size = UDim2.new(0, 25, 1, 0),
        Position = UDim2.new(1, -25, 0, 0),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = Colors.Accent,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        Parent = dropdownFrame
    })
    
    -- Dropdown list parented to overlay for proper Z-ordering
    local dropdownListContainer = CreateInstance("Frame", {
        Name = "DropdownListContainer",
        Size = UDim2.new(0, 200, 0, 185),
        BackgroundColor3 = Colors.DropdownBg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 100,
        Parent = DropdownOverlay
    })
    AddUICorner(dropdownListContainer, 6)
    AddUIStroke(dropdownListContainer, Colors.Border, 1)
    
    -- Search bar
    local searchBar = CreateInstance("TextBox", {
        Name = "SearchBar",
        Size = UDim2.new(1, -10, 0, 28),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundColor3 = Colors.Background,
        Text = "",
        PlaceholderText = "🔍 Search skills...",
        PlaceholderColor3 = Colors.TextDim,
        TextColor3 = Colors.Text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        ZIndex = 101,
        Parent = dropdownListContainer
    })
    AddUICorner(searchBar, 4)
    AddUIStroke(searchBar, Colors.Border, 1)
    
    local searchPadding = CreateInstance("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        Parent = searchBar
    })
    
    local dropdownList = CreateInstance("ScrollingFrame", {
        Name = "DropdownList",
        Size = UDim2.new(1, -10, 1, -43),
        Position = UDim2.new(0, 5, 0, 38),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Colors.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 101,
        Parent = dropdownListContainer
    })
    
    local listLayout = CreateInstance("UIListLayout", {
        Padding = UDim.new(0, 2),
        Parent = dropdownList
    })
    
    local listPadding = CreateInstance("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
        Parent = dropdownList
    })
    
    local dropdownButton = CreateInstance("TextButton", {
        Name = "DropdownButton",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = dropdownFrame
    })
    
    local allSkillButtons = {}
    
    local function FilterSkills(searchText)
        searchText = searchText:lower()
        for _, btn in ipairs(allSkillButtons) do
            if searchText == "" then
                btn.Visible = true
            else
                btn.Visible = btn.Name:lower():find(searchText, 1, true) ~= nil
            end
        end
        
        -- Update canvas size based on visible items
        local visibleCount = 0
        for _, btn in ipairs(allSkillButtons) do
            if btn.Visible then
                visibleCount = visibleCount + 1
            end
        end
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, visibleCount * 27 + 4)
    end
    
    local function PopulateDropdown()
        -- Clear existing items
        for _, child in ipairs(dropdownList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        allSkillButtons = {}
        searchBar.Text = ""
        
        local skills = GetSkillsList()
        local itemHeight = 25
        
        for i, skillName in ipairs(skills) do
            local skillButton = CreateInstance("TextButton", {
                Name = skillName,
                Size = UDim2.new(1, 0, 0, itemHeight),
                BackgroundColor3 = Colors.Background,
                Text = skillName,
                TextColor3 = Colors.Text,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 102,
                Parent = dropdownList
            })
            AddUICorner(skillButton, 4)
            
            local btnPadding = CreateInstance("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                Parent = skillButton
            })
            
            skillButton.MouseEnter:Connect(function()
                TweenColor(skillButton, "BackgroundColor3", Colors.AccentDark, 0.1)
            end)
            
            skillButton.MouseLeave:Connect(function()
                TweenColor(skillButton, "BackgroundColor3", Colors.Background, 0.1)
            end)
            
            skillButton.MouseButton1Click:Connect(function()
                selectedLabel.Text = skillName
                selectedLabel.TextColor3 = Colors.Text
                dropdownListContainer.Visible = false
                OpenDropdown = nil
                if onSelect then
                    onSelect(skillName)
                end
            end)
            
            table.insert(allSkillButtons, skillButton)
        end
        
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, #skills * (itemHeight + 2) + 4)
    end
    
    searchBar:GetPropertyChangedSignal("Text"):Connect(function()
        FilterSkills(searchBar.Text)
    end)
    
    local function UpdateDropdownPosition()
        local absPos = dropdownFrame.AbsolutePosition
        local absSize = dropdownFrame.AbsoluteSize
        dropdownListContainer.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 5)
    end
    
    dropdownButton.MouseButton1Click:Connect(function()
        if OpenDropdown and OpenDropdown ~= dropdownListContainer then
            OpenDropdown.Visible = false
        end
        
        dropdownListContainer.Visible = not dropdownListContainer.Visible
        OpenDropdown = dropdownListContainer.Visible and dropdownListContainer or nil
        
        if dropdownListContainer.Visible then
            UpdateDropdownPosition()
            PopulateDropdown()
        end
    end)
    
    dropdownFrame.MouseEnter:Connect(function()
        TweenColor(dropdownFrame, "BackgroundColor3", Color3.fromRGB(30, 30, 50), 0.15)
    end)
    
    dropdownFrame.MouseLeave:Connect(function()
        TweenColor(dropdownFrame, "BackgroundColor3", Colors.DropdownBg, 0.15)
    end)
    
    return {
        Frame = dropdownFrame,
        Label = selectedLabel,
        List = dropdownListContainer,
        GetSelected = function()
            if selectedLabel.Text ~= "Select Skill..." then
                return selectedLabel.Text
            end
            return nil
        end,
        SetSelected = function(text)
            if text and text ~= "" then
                selectedLabel.Text = text
                selectedLabel.TextColor3 = Colors.Text
            else
                selectedLabel.Text = "Select Skill..."
                selectedLabel.TextColor3 = Colors.TextDim
            end
        end,
        Clear = function()
            selectedLabel.Text = "Select Skill..."
            selectedLabel.TextColor3 = Colors.TextDim
        end
    }
end

-- Create Key Row Function
local function CreateKeyRow(parent, key, yOffset, tabType, selectedStorage)
    local rowFrame = CreateInstance("Frame", {
        Name = key .. "Row",
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 0, yOffset),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        Parent = parent
    })
    AddUICorner(rowFrame, 6)
    
    -- Key Label
    local keyLabel = CreateInstance("TextLabel", {
        Name = "KeyLabel",
        Size = UDim2.new(0, 35, 0, 30),
        Position = UDim2.new(0, 5, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Colors.Accent,
        Text = key,
        TextColor3 = Colors.Background,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(keyLabel, 6)
    
    -- Dropdown
    local dropdown = CreateDropdown(rowFrame, UDim2.new(0, 50, 0.5, -15), function(skillName)
        selectedStorage[key] = skillName
    end)
    
    -- Confirm Button
    local confirmButton = CreateInstance("TextButton", {
        Name = "ConfirmButton",
        Size = UDim2.new(0, 70, 0, 28),
        Position = UDim2.new(0, 260, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Colors.Success,
        Text = "CONFIRM",
        TextColor3 = Colors.Background,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(confirmButton, 6)
    
    confirmButton.MouseButton1Click:Connect(function()
        local selected = dropdown.GetSelected()
        if selected then
            local success = SetSkillValue(key, selected, tabType)
            if success then
                -- Flash effect
                TweenColor(confirmButton, "BackgroundColor3", Colors.AccentGlow, 0.1)
                task.delay(0.2, function()
                    TweenColor(confirmButton, "BackgroundColor3", Colors.Success, 0.2)
                end)
            end
        end
    end)
    
    confirmButton.MouseEnter:Connect(function()
        TweenColor(confirmButton, "BackgroundColor3", Color3.fromRGB(0, 255, 160), 0.15)
    end)
    
    confirmButton.MouseLeave:Connect(function()
        TweenColor(confirmButton, "BackgroundColor3", Colors.Success, 0.15)
    end)
    
    -- Clear Button
    local clearButton = CreateInstance("TextButton", {
        Name = "ClearButton",
        Size = UDim2.new(0, 60, 0, 28),
        Position = UDim2.new(0, 340, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Colors.Danger,
        Text = "CLEAR",
        TextColor3 = Colors.Text,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(clearButton, 6)
    
    clearButton.MouseButton1Click:Connect(function()
        dropdown.Clear()
        selectedStorage[key] = nil
        ClearSkillValue(key, tabType)
        
        -- Flash effect
        TweenColor(clearButton, "BackgroundColor3", Colors.AccentGlow, 0.1)
        task.delay(0.2, function()
            TweenColor(clearButton, "BackgroundColor3", Colors.Danger, 0.2)
        end)
    end)
    
    clearButton.MouseEnter:Connect(function()
        TweenColor(clearButton, "BackgroundColor3", Color3.fromRGB(255, 100, 120), 0.15)
    end)
    
    clearButton.MouseLeave:Connect(function()
        TweenColor(clearButton, "BackgroundColor3", Colors.Danger, 0.15)
    end)
    
    return {
        Frame = rowFrame,
        Dropdown = dropdown,
        Key = key
    }
end

-- Build Innates Tab
local InnatesRows = {}
local innatesLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    Parent = InnatesTab
})

for i, key in ipairs(KeyBinds) do
    local row = CreateKeyRow(InnatesTab, key, 0, "innates", SelectedInnates)
    row.Frame.LayoutOrder = i
    InnatesRows[key] = row
end

InnatesTab.CanvasSize = UDim2.new(0, 0, 0, #KeyBinds * 48 + 20)

-- Build Skills Tab
local SkillsRows = {}
local skillsLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    Parent = SkillsTab
})

for i, key in ipairs(KeyBinds) do
    local row = CreateKeyRow(SkillsTab, key, 0, "skills", SelectedSkills)
    row.Frame.LayoutOrder = i
    SkillsRows[key] = row
end

SkillsTab.CanvasSize = UDim2.new(0, 0, 0, #KeyBinds * 48 + 20)

-- ============================================
-- REMOTE TABS SYSTEM
-- ============================================

-- Tool detection functions
local function IsHoldingInnatesTool()
    local objects = workspace:FindFirstChild("Objects")
    if objects then
        local characters = objects:FindFirstChild("Characters")
        if characters then
            local playerFolder = characters:FindFirstChild(LocalPlayer.Name)
            if playerFolder then
                return playerFolder:FindFirstChild("Innates") ~= nil
            end
        end
    end
    return false
end

local function IsHoldingSkillsTool()
    local objects = workspace:FindFirstChild("Objects")
    if objects then
        local characters = objects:FindFirstChild("Characters")
        if characters then
            local playerFolder = characters:FindFirstChild(LocalPlayer.Name)
            if playerFolder then
                return playerFolder:FindFirstChild("Skills") ~= nil
            end
        end
    end
    return false
end

-- Fire skill remote
local function FireSkillRemote(skillName)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local server = remotes:FindFirstChild("Server")
        if server then
            local combat = server:FindFirstChild("Combat")
            if combat then
                local skill = combat:FindFirstChild("Skill")
                if skill then
                    skill:FireServer(skillName)
                end
            end
        end
    end
end

-- Create Remote Key Row Function
local function CreateRemoteKeyRow(parent, key, bindingStorage)
    local rowFrame = CreateInstance("Frame", {
        Name = key .. "Row",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        Parent = parent
    })
    AddUICorner(rowFrame, 6)
    
    -- Key Label (orange for remote tabs)
    local keyLabel = CreateInstance("TextLabel", {
        Name = "KeyLabel",
        Size = UDim2.new(0, 35, 0, 30),
        Position = UDim2.new(0, 5, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 140, 0),
        Text = key,
        TextColor3 = Colors.Background,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(keyLabel, 6)
    
    -- Status indicator
    local statusLabel = CreateInstance("TextLabel", {
        Name = "StatusLabel",
        Size = UDim2.new(0, 60, 0, 20),
        Position = UDim2.new(0, 410, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Colors.TextDim,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        Parent = rowFrame
    })
    
    -- Dropdown
    local dropdown = CreateDropdown(rowFrame, UDim2.new(0, 50, 0.5, -15), function(skillName)
        -- Just store selection, don't bind yet
    end)
    
    -- Bind Button
    local confirmButton = CreateInstance("TextButton", {
        Name = "ConfirmButton",
        Size = UDim2.new(0, 70, 0, 28),
        Position = UDim2.new(0, 260, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 140, 0),
        Text = "BIND",
        TextColor3 = Colors.Background,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(confirmButton, 6)
    
    confirmButton.MouseButton1Click:Connect(function()
        local selected = dropdown.GetSelected()
        if selected then
            bindingStorage[key] = selected
            statusLabel.Text = "BOUND"
            statusLabel.TextColor3 = Colors.Success
            
            -- Flash effect
            TweenColor(confirmButton, "BackgroundColor3", Colors.AccentGlow, 0.1)
            task.delay(0.2, function()
                TweenColor(confirmButton, "BackgroundColor3", Color3.fromRGB(255, 140, 0), 0.2)
            end)
        end
    end)
    
    confirmButton.MouseEnter:Connect(function()
        TweenColor(confirmButton, "BackgroundColor3", Color3.fromRGB(255, 170, 50), 0.15)
    end)
    
    confirmButton.MouseLeave:Connect(function()
        TweenColor(confirmButton, "BackgroundColor3", Color3.fromRGB(255, 140, 0), 0.15)
    end)
    
    -- Clear Button
    local clearButton = CreateInstance("TextButton", {
        Name = "ClearButton",
        Size = UDim2.new(0, 60, 0, 28),
        Position = UDim2.new(0, 340, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Colors.Danger,
        Text = "CLEAR",
        TextColor3 = Colors.Text,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(clearButton, 6)
    
    clearButton.MouseButton1Click:Connect(function()
        dropdown.Clear()
        bindingStorage[key] = nil
        statusLabel.Text = ""
        
        -- Flash effect
        TweenColor(clearButton, "BackgroundColor3", Colors.AccentGlow, 0.1)
        task.delay(0.2, function()
            TweenColor(clearButton, "BackgroundColor3", Colors.Danger, 0.2)
        end)
    end)
    
    clearButton.MouseEnter:Connect(function()
        TweenColor(clearButton, "BackgroundColor3", Color3.fromRGB(255, 100, 120), 0.15)
    end)
    
    clearButton.MouseLeave:Connect(function()
        TweenColor(clearButton, "BackgroundColor3", Colors.Danger, 0.15)
    end)
    
    return {
        Frame = rowFrame,
        Dropdown = dropdown,
        Key = key
    }
end

-- Build Innates (Remote) Tab
local InnatesRemoteRows = {}
local innatesRemoteLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    Parent = InnatesRemoteTab
})

for i, key in ipairs(KeyBinds) do
    local row = CreateRemoteKeyRow(InnatesRemoteTab, key, RemoteInnateBindings)
    row.Frame.LayoutOrder = i
    InnatesRemoteRows[key] = row
end

InnatesRemoteTab.CanvasSize = UDim2.new(0, 0, 0, #KeyBinds * 48 + 20)

-- Build Skills (Remote) Tab
local SkillsRemoteRows = {}
local skillsRemoteLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    Parent = SkillsRemoteTab
})

for i, key in ipairs(KeyBinds) do
    local row = CreateRemoteKeyRow(SkillsRemoteTab, key, RemoteSkillBindings)
    row.Frame.LayoutOrder = i
    SkillsRemoteRows[key] = row
end

SkillsRemoteTab.CanvasSize = UDim2.new(0, 0, 0, #KeyBinds * 48 + 20)

-- ============================================
-- FUSE TABS SYSTEM
-- ============================================

-- Function to generate fused name
local function GenerateFuseName(skills)
    if #skills == 0 then return "" end
    
    local words = {}
    
    for _, skillName in ipairs(skills) do
        if skillName and skillName ~= "" then
            -- Remove prefix before ":"
            local cleanName = skillName
            local colonIndex = skillName:find(":")
            if colonIndex then
                cleanName = skillName:sub(colonIndex + 1)
            end
            
            -- Remove leading spaces
            cleanName = cleanName:match("^%s*(.-)%s*$")
            
            -- Split into words
            for word in cleanName:gmatch("%S+") do
                table.insert(words, word)
            end
        end
    end
    
    if #skills == 2 then
        -- For exactly 2 skills, combine first word of each
        local name1 = skills[1]
        local name2 = skills[2]
        
        local function GetFirstWord(s)
            local clean = s
            local idx = s:find(":")
            if idx then clean = s:sub(idx + 1) end
            clean = clean:match("^%s*(.-)%s*$")
            return clean:match("%S+")
        end
        
        local w1 = GetFirstWord(name1)
        local w2 = GetFirstWord(name2)
        
        if w1 and w2 then
            return w1 .. " " .. w2
        end
    elseif #skills > 2 then
        -- For 3 or 4 skills, pick random word from each skill
        local resultWords = {}
        for _, skillName in ipairs(skills) do
             if skillName and skillName ~= "" then
                local cleanName = skillName
                local colonIndex = skillName:find(":")
                if colonIndex then
                    cleanName = skillName:sub(colonIndex + 1)
                end
                cleanName = cleanName:match("^%s*(.-)%s*$")
                
                local skillWords = {}
                for w in cleanName:gmatch("%S+") do
                    table.insert(skillWords, w)
                end
                
                if #skillWords > 0 then
                    -- Pick random word
                    table.insert(resultWords, skillWords[math.random(1, #skillWords)])
                end
            end
        end
        return table.concat(resultWords, " ")
    end
    
    -- Fallback or single skill
    return words[1] or ""
end

-- Create Fuse Key Row
local function CreateFuseKeyRow(parent, key, bindingStorage, tabType)
    local rowHeight = 100
    local rowFrame = CreateInstance("Frame", {
        Name = key .. "Row",
        Size = UDim2.new(1, 0, 0, rowHeight),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        Parent = parent
    })
    AddUICorner(rowFrame, 6)
    
    -- Key Label (Purple for fuse)
    local keyLabel = CreateInstance("TextLabel", {
        Name = "KeyLabel",
        Size = UDim2.new(0, 35, 1, -10),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundColor3 = Color3.fromRGB(180, 0, 255),
        Text = key,
        TextColor3 = Colors.Background,
        TextSize = 24,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(keyLabel, 6)
    
    -- Container for dropdowns
    local dropdownContainer = CreateInstance("Frame", {
        Name = "DropdownContainer",
        Size = UDim2.new(1, -135, 1, -10),
        Position = UDim2.new(0, 45, 0, 5),
        BackgroundTransparency = 1,
        Parent = rowFrame
    })
    
    local gridLayout = CreateInstance("UIGridLayout", {
        CellSize = UDim2.new(0.5, -5, 0, 20),
        CellPadding = UDim2.new(0, 5, 0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = dropdownContainer
    })
    
    local currentSkills = {nil, nil, nil, nil}
    local dropdowns = {}
    
    -- Create 4 dropdowns with numbers
    for i = 1, 4 do
        local cell = CreateInstance("Frame", {
            Name = "Cell" .. i,
            BackgroundTransparency = 1,
            LayoutOrder = i,
            Parent = dropdownContainer
        })
        
        local numLabel = CreateInstance("TextLabel", {
            Name = "Num",
            Size = UDim2.new(0, 15, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(i),
            TextColor3 = Colors.Accent,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            Parent = cell
        })
        
        local d = CreateDropdown(cell, UDim2.new(1, -20, 0, 20), function(skillName)
            currentSkills[i] = skillName
        end)
        d.Frame.Position = UDim2.new(0, 20, 0, 0) -- Offset for number
        d.Frame.Size = UDim2.new(1, -20, 1, 0)
        d.Label.TextSize = 9
        
        table.insert(dropdowns, d)
    end
    
    -- Status
    local statusLabel = CreateInstance("TextLabel", {
        Name = "StatusLabel",
        Size = UDim2.new(0, 80, 0, 20),
        Position = UDim2.new(1, -85, 0, 5),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Colors.TextDim,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = rowFrame
    })
    
    -- Bind Button
    local bindButton = CreateInstance("TextButton", {
        Name = "BindButton",
        Size = UDim2.new(0, 80, 0, 30),
        Position = UDim2.new(1, -85, 0, 30),
        BackgroundColor3 = Color3.fromRGB(180, 0, 255),
        Text = "FUSE & BIND",
        TextColor3 = Colors.Background,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(bindButton, 6)
    
    bindButton.MouseButton1Click:Connect(function()
        -- Collect valid skills
        local validSkills = {}
        for i = 1, 4 do
            if currentSkills[i] and currentSkills[i] ~= "" then
                table.insert(validSkills, currentSkills[i])
            end
        end
        
        if #validSkills > 0 then
            -- Generate Fuse Name
            local fusedName = GenerateFuseName(validSkills)
            
            -- Set binding
            bindingStorage[key] = validSkills
            
            -- Set status (Visual only)
            statusLabel.Text = "BOUND: " .. fusedName
            statusLabel.TextColor3 = Colors.Success
            statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Flash effect
            TweenColor(bindButton, "BackgroundColor3", Colors.AccentGlow, 0.1)
            task.delay(0.2, function()
                TweenColor(bindButton, "BackgroundColor3", Color3.fromRGB(180, 0, 255), 0.2)
            end)
        else
            statusLabel.Text = "SELECT SKILLS"
            statusLabel.TextColor3 = Colors.Danger
        end
    end)
    
    -- Clear Button
    local clearButton = CreateInstance("TextButton", {
        Name = "ClearButton",
        Size = UDim2.new(0, 80, 0, 25),
        Position = UDim2.new(1, -85, 0, 65),
        BackgroundColor3 = Colors.Danger,
        Text = "CLEAR",
        TextColor3 = Colors.Text,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        Parent = rowFrame
    })
    AddUICorner(clearButton, 6)
    
    clearButton.MouseButton1Click:Connect(function()
        for i = 1, 4 do
            dropdowns[i].Clear()
            currentSkills[i] = nil
        end
        bindingStorage[key] = nil
        statusLabel.Text = ""
        
        -- Clear bindings
        bindingStorage[key] = nil
        statusLabel.Text = ""
        
        -- Flash effect
        TweenColor(clearButton, "BackgroundColor3", Colors.AccentGlow, 0.1)
        task.delay(0.2, function()
            TweenColor(clearButton, "BackgroundColor3", Colors.Danger, 0.2)
        end)
    end)
    
    return {
        Frame = rowFrame,
        Dropdowns = dropdowns,
        SetSkills = function(skills)
            for i = 1, 4 do
                if skills[i] then
                    dropdowns[i].SetSelected(skills[i])
                    currentSkills[i] = skills[i]
                else
                    dropdowns[i].Clear()
                    currentSkills[i] = nil
                end
            end
        end,
        GetSkills = function() return currentSkills end
    }
end

-- Build Innates (Fuse) Tab
local InnatesFuseRows = {}
local innatesFuseLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    Parent = InnatesFuseTab
})

for i, key in ipairs(KeyBinds) do
    local row = CreateFuseKeyRow(InnatesFuseTab, key, FuseInnateBindings, "InnatesFuse")
    row.Frame.LayoutOrder = i
    InnatesFuseRows[key] = row
end

InnatesFuseTab.CanvasSize = UDim2.new(0, 0, 0, #KeyBinds * 108 + 20)

-- Build Skills (Fuse) Tab
local SkillsFuseRows = {}
local skillsFuseLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    Parent = SkillsFuseTab
})

for i, key in ipairs(KeyBinds) do
    local row = CreateFuseKeyRow(SkillsFuseTab, key, FuseSkillBindings, "SkillsFuse")
    row.Frame.LayoutOrder = i
    SkillsFuseRows[key] = row
end

SkillsFuseTab.CanvasSize = UDim2.new(0, 0, 0, #KeyBinds * 108 + 20)


-- ============================================
-- COOLDOWN OVERLAY SYSTEM
-- ============================================

local CooldownOverlayPos = UDim2.new(0.8, 0, 0.7, 0) -- Shared position
local InnatesOverlay = nil
local SkillsOverlay = nil

local TextService = game:GetService("TextService")

-- Global Cooldown State for Persistence
local CooldownState = {
    Innates = {},
    Skills = {}
}

local function CreateCooldownOverlay(name, title, id)
    local frame = CreateInstance("Frame", {
        Name = name,
        Size = UDim2.new(0, 220, 0, 0), -- Height will be auto-calculated or listlayout
        AutomaticSize = Enum.AutomaticSize.Y, -- Auto height
        Position = CooldownOverlayPos,
        BackgroundColor3 = Colors.BackgroundSecondary,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Visible = false,
        Parent = ScreenGui
    })
    AddUICorner(frame, 8)
    AddUIStroke(frame, Colors.Accent, 1)
    
    local titleLabel = CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Colors.Accent,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = frame
    })
    
    local listContainer = CreateInstance("Frame", {
        Size = UDim2.new(1, -10, 0, 0), -- Auto size Y
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 5, 0, 30),
        BackgroundTransparency = 1,
        Parent = frame
    })
    
    local layout = CreateInstance("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = listContainer
    })
    
    -- Padding at bottom
    local padding = CreateInstance("UIPadding", {
        PaddingBottom = UDim.new(0, 5),
        Parent = listContainer
    })
    
    -- Draggable Logic
    local dragging = false
    local dragInput, dragStart, startPos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    CooldownOverlayPos = frame.Position
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            CooldownOverlayPos = frame.Position
        end
    end)
    
    return {
        Frame = frame,
        Container = listContainer,
        TriggerCooldown = function(key, duration)
             CooldownState[id][key] = os.clock() + duration
        end,
        Refresh = function(bindings)
            -- 1. Loop through bindings to Update/Create rows
            for i, key in ipairs(KeyBinds) do
                local skills = bindings[key]
                
                if skills then
                    -- Check if row exists
                    local row = listContainer:FindFirstChild(key)
                    local skillHash = table.concat(skills, "|")
                    
                    if not row then
                        -- Create new row
                        local fusedName = GenerateFuseName(skills)
                        row = CreateInstance("TextLabel", {
                            Name = key,
                            Size = UDim2.new(1, 0, 0, 18),
                            BackgroundTransparency = 1,
                            Text = "", -- Set later
                            TextColor3 = Colors.Text,
                            TextSize = 10,
                            Font = Enum.Font.Gotham,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            LayoutOrder = i, -- Strict Order
                            Parent = listContainer
                        })
                        row:SetAttribute("SkillHash", skillHash)
                        row:SetAttribute("FusedName", fusedName)
                    else
                        -- Ensure order is correct even if existing
                        row.LayoutOrder = i
                        
                        -- Check if changed
                        if row:GetAttribute("SkillHash") ~= skillHash then
                             local fusedName = GenerateFuseName(skills)
                             row:SetAttribute("SkillHash", skillHash)
                             row:SetAttribute("FusedName", fusedName)
                        end
                    end
                    
                    -- Update Status Text
                    local fusedName = row:GetAttribute("FusedName")
                    local statusText = " [READY]"
                    local isCooling = false
                    
                    if CooldownState[id][key] and CooldownState[id][key] > os.clock() then
                        local remaining = CooldownState[id][key] - os.clock()
                        statusText = " [" .. string.format("%.1f", remaining) .. "s]"
                        isCooling = true
                    end
                    
                    row.Text = key .. ": " .. fusedName .. statusText
                    row.TextColor3 = isCooling and Colors.Accent or Colors.Text
                    
                else
                    -- No binding for this key, remove if exists
                    local row = listContainer:FindFirstChild(key)
                    if row then row:Destroy() end
                end
            end
            
            -- 2. Auto Resize Logic
            local maxWidth = 220
            for _, child in ipairs(listContainer:GetChildren()) do
                if child:IsA("TextLabel") then
                     local bounds = TextService:GetTextSize(child.Text, child.TextSize, child.Font, Vector2.new(1000, 18))
                     if bounds.X + 20 > maxWidth then
                         maxWidth = bounds.X + 20
                     end
                end
            end
            frame.Size = UDim2.new(0, maxWidth, 0, 0)
        end
    }
end

InnatesOverlay = CreateCooldownOverlay("InnatesOverlay", "INNATES COOLDOWN", "Innates")
SkillsOverlay = CreateCooldownOverlay("SkillsOverlay", "SKILLS COOLDOWN", "Skills")

-- Sync Position Loop
RunService.Heartbeat:Connect(function()
    if InnatesOverlay and InnatesOverlay.Frame.Visible then
        InnatesOverlay.Frame.Position = CooldownOverlayPos
    elseif SkillsOverlay and SkillsOverlay.Frame.Visible then
        SkillsOverlay.Frame.Position = CooldownOverlayPos
    end
    
    -- Toggle Visibility based on tool
    local holdingInnates = IsHoldingInnatesTool()
    local holdingSkills = IsHoldingSkillsTool()
    
    -- Check if bindings exist to decide show/hide
    local hasInnateBindings = false
    for k, v in pairs(FuseInnateBindings) do if v then hasInnateBindings = true break end end
    
    local hasSkillBindings = false
    for k, v in pairs(FuseSkillBindings) do if v then hasSkillBindings = true break end end


    if holdingInnates and hasInnateBindings then
        InnatesOverlay.Frame.Visible = true
        InnatesOverlay.Refresh(FuseInnateBindings) -- Updated loop
        SkillsOverlay.Frame.Visible = false
    elseif holdingSkills and hasSkillBindings then
        SkillsOverlay.Frame.Visible = true
        SkillsOverlay.Refresh(FuseSkillBindings) -- Updated loop
        InnatesOverlay.Frame.Visible = false
    else
        InnatesOverlay.Frame.Visible = false
        SkillsOverlay.Frame.Visible = false
    end
end)

-- Keybind listener for remote firing/cooldowns
local KeyCodeMap = {
    Z = Enum.KeyCode.Z,
    X = Enum.KeyCode.X,
    C = Enum.KeyCode.C,
    V = Enum.KeyCode.V,
    B = Enum.KeyCode.B,
    G = Enum.KeyCode.G,
    T = Enum.KeyCode.T,
    Y = Enum.KeyCode.Y
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    for key, keyCode in pairs(KeyCodeMap) do
        if input.KeyCode == keyCode then
            -- Check if holding Innates tool and has skill binding
            if IsHoldingInnatesTool() then
                -- Check Fuse Binding first (override)
                if FuseInnateBindings[key] then
                    -- Fire all skills and trigger cooldown
                    task.spawn(function()
                        for _, skillName in ipairs(FuseInnateBindings[key]) do
                            FireSkillRemote(skillName)
                            task.wait(0.05)
                        end
                    end)
                    
                    -- Trigger Cooldown on Overlay
                    local maxCD = GetSkillMaxCooldown(FuseInnateBindings[key])
                    if maxCD > 0 then
                        InnatesOverlay.TriggerCooldown(key, maxCD)
                    end
                    
                    return
                elseif RemoteInnateBindings[key] then
                    FireSkillRemote(RemoteInnateBindings[key])
                    return
                end
            end
            
            -- Check if holding Skills tool and has skill binding
            if IsHoldingSkillsTool() then
                if FuseSkillBindings[key] then
                     task.spawn(function()
                        for _, skillName in ipairs(FuseSkillBindings[key]) do
                            FireSkillRemote(skillName)
                            task.wait(0.05)
                        end
                     end)
                     
                     -- Trigger Cooldown
                    local maxCD = GetSkillMaxCooldown(FuseSkillBindings[key])
                    if maxCD > 0 then
                        SkillsOverlay.TriggerCooldown(key, maxCD)
                    end
                    
                    return
                elseif RemoteSkillBindings[key] then
                    FireSkillRemote(RemoteSkillBindings[key])
                    return
                end
            end
        end
    end
end)

-- Old Input Listener removed (replaced by above)
-- ============================================

-- ============================================
-- CONFIG TAB
-- ============================================

-- Build Config Tab
local configLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    Parent = ConfigTab
})

-- Saved Configs Display Box
local ConfigListFrame = CreateInstance("Frame", {
    Name = "ConfigListFrame",
    Size = UDim2.new(1, 0, 0, 140),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    Parent = ConfigTab
})
AddUICorner(ConfigListFrame, 8)
AddUIStroke(ConfigListFrame, Colors.Border, 1)

local ConfigListTitle = CreateInstance("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, 0, 0, 25),
    BackgroundTransparency = 1,
    Text = "📁 SAVED CONFIGS",
    TextColor3 = Colors.Accent,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    Parent = ConfigListFrame
})

local ConfigScrollFrame = CreateInstance("ScrollingFrame", {
    Name = "ConfigScroll",
    Size = UDim2.new(1, -10, 1, -30),
    Position = UDim2.new(0, 5, 0, 25),
    BackgroundTransparency = 1,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Colors.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = ConfigListFrame
})

local configScrollLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 4),
    Parent = ConfigScrollFrame
})

local function RefreshConfigList()
    for _, child in ipairs(ConfigScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    for configName, _ in pairs(SavedConfigs) do
        local configItem = CreateInstance("Frame", {
            Name = configName,
            Size = UDim2.new(1, -10, 0, 28),
            BackgroundColor3 = Colors.BackgroundSecondary,
            Parent = ConfigScrollFrame
        })
        AddUICorner(configItem, 4)
        
        local isAutoload = AutoloadConfigName == configName
        local configLabel = CreateInstance("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = (isAutoload and "⭐ " or "") .. configName,
            TextColor3 = isAutoload and Colors.Accent or Colors.Text,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = configItem
        })
        
        local deleteBtn = CreateInstance("TextButton", {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -28, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Colors.Danger,
            Text = "✕",
            TextColor3 = Colors.Text,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            Parent = configItem
        })
        AddUICorner(deleteBtn, 4)
        
        deleteBtn.MouseButton1Click:Connect(function()
            SavedConfigs[configName] = nil
            if AutoloadConfigName == configName then
                AutoloadConfigName = nil
            end
            SaveConfigsToFile()
            RefreshConfigList()
        end)
        
        local selectBtn = CreateInstance("TextButton", {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -56, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Colors.AccentDark,
            Text = "→",
            TextColor3 = Colors.Text,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            Parent = configItem
        })
        AddUICorner(selectBtn, 4)
        
        selectBtn.MouseButton1Click:Connect(function()
            -- Load this config
            local config = SavedConfigs[configName]
            if config then
                -- Load innates
                if config.innates then
                    for key, skill in pairs(config.innates) do
                        if InnatesRows[key] then
                            InnatesRows[key].Dropdown.SetSelected(skill)
                            SelectedInnates[key] = skill
                            SetSkillValue(key, skill, "innates")
                        end
                    end
                end
                -- Load skills
                if config.skills then
                    for key, skill in pairs(config.skills) do
                        if SkillsRows[key] then
                            SkillsRows[key].Dropdown.SetSelected(skill)
                            SelectedSkills[key] = skill
                            SetSkillValue(key, skill, "skills")
                        end
                    end
                end
                -- Load remote innates
                if config.remoteInnates then
                    for key, skill in pairs(config.remoteInnates) do
                        RemoteInnateBindings[key] = skill
                        if InnatesRemoteRows and InnatesRemoteRows[key] then
                            InnatesRemoteRows[key].Dropdown.SetSelected(skill)
                        end
                    end
                end
                -- Load remote skills
                if config.remoteSkills then
                    for key, skill in pairs(config.remoteSkills) do
                        RemoteSkillBindings[key] = skill
                        if SkillsRemoteRows and SkillsRemoteRows[key] then
                            SkillsRemoteRows[key].Dropdown.SetSelected(skill)
                        end
                    end
                end
            end
        end)
    end
end

-- Config Name Input
local ConfigInputFrame = CreateInstance("Frame", {
    Name = "ConfigInputFrame",
    Size = UDim2.new(1, 0, 0, 35),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    Parent = ConfigTab
})
AddUICorner(ConfigInputFrame, 6)

local ConfigNameInput = CreateInstance("TextBox", {
    Name = "ConfigNameInput",
    Size = UDim2.new(1, -20, 0, 28),
    Position = UDim2.new(0, 10, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Colors.DropdownBg,
    Text = "",
    PlaceholderText = "Enter config name...",
    PlaceholderColor3 = Colors.TextDim,
    TextColor3 = Colors.Text,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
    Parent = ConfigInputFrame
})
AddUICorner(ConfigNameInput, 6)
AddUIStroke(ConfigNameInput, Colors.Border, 1)

local inputPadding = CreateInstance("UIPadding", {
    PaddingLeft = UDim.new(0, 10),
    Parent = ConfigNameInput
})

-- Save/Load/Update Buttons Row
local ButtonRow1 = CreateInstance("Frame", {
    Name = "ButtonRow1",
    Size = UDim2.new(1, 0, 0, 35),
    BackgroundTransparency = 1,
    LayoutOrder = 3,
    Parent = ConfigTab
})

local buttonRow1Layout = CreateInstance("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    Parent = ButtonRow1
})

local function CreateConfigButton(parent, text, color, order)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(0, 125, 0, 32),
        BackgroundColor3 = color,
        Text = text,
        TextColor3 = Colors.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        LayoutOrder = order,
        Parent = parent
    })
    AddUICorner(btn, 6)
    
    btn.MouseEnter:Connect(function()
        TweenColor(btn, "BackgroundColor3", Color3.new(
            math.min(color.R + 0.1, 1),
            math.min(color.G + 0.1, 1),
            math.min(color.B + 0.1, 1)
        ), 0.15)
    end)
    
    btn.MouseLeave:Connect(function()
        TweenColor(btn, "BackgroundColor3", color, 0.15)
    end)
    
    return btn
end

local SaveBtn = CreateConfigButton(ButtonRow1, " SAVE", Colors.Success, 1)
local LoadBtn = CreateConfigButton(ButtonRow1, " LOAD", Colors.AccentDark, 2)
local UpdateBtn = CreateConfigButton(ButtonRow1, " UPDATE", Color3.fromRGB(200, 150, 0), 3)

SaveBtn.MouseButton1Click:Connect(function()
    local configName = ConfigNameInput.Text
    if configName and configName ~= "" then
        SavedConfigs[configName] = {
            innates = {},
            skills = {},
            remoteInnates = {},
            remoteSkills = {},
            fuseInnates = {},
            fuseSkills = {}
        }
        
        for key, skill in pairs(SelectedInnates) do
            SavedConfigs[configName].innates[key] = skill
        end
        
        for key, skill in pairs(SelectedSkills) do
            SavedConfigs[configName].skills[key] = skill
        end
        
        for key, skill in pairs(RemoteInnateBindings) do
            SavedConfigs[configName].remoteInnates[key] = skill
        end
        
        for key, skill in pairs(RemoteSkillBindings) do
            SavedConfigs[configName].remoteSkills[key] = skill
        end

        for key, skills in pairs(FuseInnateBindings) do
            SavedConfigs[configName].fuseInnates[key] = skills
        end
        
        for key, skills in pairs(FuseSkillBindings) do
            SavedConfigs[configName].fuseSkills[key] = skills
        end
        
        SaveConfigsToFile()
        RefreshConfigList()
        ConfigNameInput.Text = ""
    end
end)

LoadBtn.MouseButton1Click:Connect(function()
    local configName = ConfigNameInput.Text
    if configName and SavedConfigs[configName] then
        local config = SavedConfigs[configName]
        
        -- Clear and load innates
        for _, key in ipairs(KeyBinds) do
            if config.innates and config.innates[key] then
                InnatesRows[key].Dropdown.SetSelected(config.innates[key])
                SelectedInnates[key] = config.innates[key]
                SetSkillValue(key, config.innates[key], "innates")
            else
                InnatesRows[key].Dropdown.Clear()
                SelectedInnates[key] = nil
            end
        end
        
        -- Clear and load skills
        for _, key in ipairs(KeyBinds) do
            if config.skills and config.skills[key] then
                SkillsRows[key].Dropdown.SetSelected(config.skills[key])
                SelectedSkills[key] = config.skills[key]
                SetSkillValue(key, config.skills[key], "skills")
            else
                SkillsRows[key].Dropdown.Clear()
                SelectedSkills[key] = nil
            end
        end
        
        -- Clear and load remote innates
        for _, key in ipairs(KeyBinds) do
            if config.remoteInnates and config.remoteInnates[key] then
                RemoteInnateBindings[key] = config.remoteInnates[key]
            else
                RemoteInnateBindings[key] = nil
            end
        end
        
        -- Clear and load remote skills
        for _, key in ipairs(KeyBinds) do
            if config.remoteSkills and config.remoteSkills[key] then
                RemoteSkillBindings[key] = config.remoteSkills[key]
            else
                RemoteSkillBindings[key] = nil
            end
        end

        -- Clear and load fuse innates
        for _, key in ipairs(KeyBinds) do
             if config.fuseInnates and config.fuseInnates[key] then
                FuseInnateBindings[key] = config.fuseInnates[key]
                if InnatesFuseRows and InnatesFuseRows[key] then
                    InnatesFuseRows[key].SetSkills(config.fuseInnates[key])
                end
             else
                FuseInnateBindings[key] = nil
                if InnatesFuseRows and InnatesFuseRows[key] then
                    InnatesFuseRows[key].SetSkills({})
                end
             end
        end

        -- Clear and load fuse skills
        for _, key in ipairs(KeyBinds) do
             if config.fuseSkills and config.fuseSkills[key] then
                FuseSkillBindings[key] = config.fuseSkills[key]
                 if SkillsFuseRows and SkillsFuseRows[key] then
                    SkillsFuseRows[key].SetSkills(config.fuseSkills[key])
                end
             else
                FuseSkillBindings[key] = nil
                if SkillsFuseRows and SkillsFuseRows[key] then
                    SkillsFuseRows[key].SetSkills({})
                end
             end
        end
    end
end)

UpdateBtn.MouseButton1Click:Connect(function()
    local configName = ConfigNameInput.Text
    if configName and SavedConfigs[configName] then
        SavedConfigs[configName] = {
            innates = {},
            skills = {},
            remoteInnates = {},
            remoteSkills = {},
            fuseInnates = {},
            fuseSkills = {}
        }
        
        for key, skill in pairs(SelectedInnates) do
            SavedConfigs[configName].innates[key] = skill
        end
        
        for key, skill in pairs(SelectedSkills) do
            SavedConfigs[configName].skills[key] = skill
        end
        
        for key, skill in pairs(RemoteInnateBindings) do
            SavedConfigs[configName].remoteInnates[key] = skill
        end
        
        for key, skill in pairs(RemoteSkillBindings) do
            SavedConfigs[configName].remoteSkills[key] = skill
        end

        for key, skills in pairs(FuseInnateBindings) do
            SavedConfigs[configName].fuseInnates[key] = skills
        end

        for key, skills in pairs(FuseSkillBindings) do
            SavedConfigs[configName].fuseSkills[key] = skills
        end
        
        SaveConfigsToFile()
        RefreshConfigList()
    end
end)

-- Autoload Section
local AutoloadFrame = CreateInstance("Frame", {
    Name = "AutoloadFrame",
    Size = UDim2.new(1, 0, 0, 75),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    LayoutOrder = 4,
    Parent = ConfigTab
})
AddUICorner(AutoloadFrame, 8)

local AutoloadTitle = CreateInstance("TextLabel", {
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "⚡ AUTOLOAD CONFIG",
    TextColor3 = Colors.Accent,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    Parent = AutoloadFrame
})

-- Autoload Dropdown
local AutoloadDropdownFrame = CreateInstance("Frame", {
    Name = "AutoloadDropdown",
    Size = UDim2.new(0, 200, 0, 28),
    Position = UDim2.new(0, 10, 0, 28),
    BackgroundColor3 = Colors.DropdownBg,
    BorderSizePixel = 0,
    Parent = AutoloadFrame
})
AddUICorner(AutoloadDropdownFrame, 6)
AddUIStroke(AutoloadDropdownFrame, Colors.Border, 1)

local AutoloadLabel = CreateInstance("TextLabel", {
    Size = UDim2.new(1, -30, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1,
    Text = "Select Config...",
    TextColor3 = Colors.TextDim,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = AutoloadDropdownFrame
})

local AutoloadArrow = CreateInstance("TextLabel", {
    Size = UDim2.new(0, 20, 1, 0),
    Position = UDim2.new(1, -20, 0, 0),
    BackgroundTransparency = 1,
    Text = "▼",
    TextColor3 = Colors.Accent,
    TextSize = 9,
    Font = Enum.Font.GothamBold,
    Parent = AutoloadDropdownFrame
})

local AutoloadList = CreateInstance("ScrollingFrame", {
    Name = "AutoloadList",
    Size = UDim2.new(1, 0, 0, 100),
    Position = UDim2.new(0, 0, 1, 5),
    BackgroundColor3 = Colors.DropdownBg,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Colors.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Visible = false,
    ZIndex = 100,
    Parent = AutoloadDropdownFrame
})
AddUICorner(AutoloadList, 6)
AddUIStroke(AutoloadList, Colors.Border, 1)

local autoloadListLayout = CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 2),
    Parent = AutoloadList
})

local autoloadListPadding = CreateInstance("UIPadding", {
    PaddingLeft = UDim.new(0, 5),
    PaddingRight = UDim.new(0, 5),
    PaddingTop = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 5),
    Parent = AutoloadList
})

local AutoloadDropdownBtn = CreateInstance("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    Parent = AutoloadDropdownFrame
})

local function RefreshAutoloadDropdown()
    for _, child in ipairs(AutoloadList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local count = 0
    for configName, _ in pairs(SavedConfigs) do
        count = count + 1
        local optionBtn = CreateInstance("TextButton", {
            Name = configName,
            Size = UDim2.new(1, -10, 0, 24),
            BackgroundColor3 = Colors.Background,
            Text = configName,
            TextColor3 = Colors.Text,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 101,
            Parent = AutoloadList
        })
        AddUICorner(optionBtn, 4)
        
        local optPadding = CreateInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            Parent = optionBtn
        })
        
        optionBtn.MouseEnter:Connect(function()
            TweenColor(optionBtn, "BackgroundColor3", Colors.AccentDark, 0.1)
        end)
        
        optionBtn.MouseLeave:Connect(function()
            TweenColor(optionBtn, "BackgroundColor3", Colors.Background, 0.1)
        end)
        
        optionBtn.MouseButton1Click:Connect(function()
            AutoloadLabel.Text = configName
            AutoloadLabel.TextColor3 = Colors.Text
            AutoloadList.Visible = false
        end)
    end
    
    AutoloadList.CanvasSize = UDim2.new(0, 0, 0, count * 26 + 10)
end

AutoloadDropdownBtn.MouseButton1Click:Connect(function()
    AutoloadList.Visible = not AutoloadList.Visible
    if AutoloadList.Visible then
        RefreshAutoloadDropdown()
    end
end)

-- Set Autoload / Clear Autoload Buttons
local SetAutoloadBtn = CreateInstance("TextButton", {
    Size = UDim2.new(0, 120, 0, 28),
    Position = UDim2.new(0, 220, 0, 28),
    BackgroundColor3 = Colors.Success,
    Text = "SET AUTOLOAD",
    TextColor3 = Colors.Background,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    Parent = AutoloadFrame
})
AddUICorner(SetAutoloadBtn, 6)

SetAutoloadBtn.MouseButton1Click:Connect(function()
    if AutoloadLabel.Text ~= "Select Config..." then
        AutoloadConfigName = AutoloadLabel.Text
        SaveConfigsToFile()
        RefreshConfigList()
    end
end)

local ClearAutoloadBtn = CreateInstance("TextButton", {
    Size = UDim2.new(0, 120, 0, 28),
    Position = UDim2.new(0, 350, 0, 28),
    BackgroundColor3 = Colors.Danger,
    Text = "CLEAR AUTOLOAD",
    TextColor3 = Colors.Text,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    Parent = AutoloadFrame
})
AddUICorner(ClearAutoloadBtn, 6)

ClearAutoloadBtn.MouseButton1Click:Connect(function()
    AutoloadConfigName = nil
    AutoloadLabel.Text = "Select Config..."
    AutoloadLabel.TextColor3 = Colors.TextDim
    SaveConfigsToFile()
    RefreshConfigList()
end)

-- Update canvas size for Config tab
ConfigTab.CanvasSize = UDim2.new(0, 0, 0, 320)

-- Dragging Functionality
local dragging = false
local dragInput
local dragStart
local startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Close dropdowns when clicking outside
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        task.defer(function()
            if OpenDropdown and OpenDropdown.Visible then
                local mouse = UserInputService:GetMouseLocation()
                local dropdownPos = OpenDropdown.AbsolutePosition
                local dropdownSize = OpenDropdown.AbsoluteSize
                
                if mouse.X < dropdownPos.X or mouse.X > dropdownPos.X + dropdownSize.X or
                   mouse.Y < dropdownPos.Y or mouse.Y > dropdownPos.Y + dropdownSize.Y then
                    -- Check if clicking on dropdown frame itself
                    local parentFrame = OpenDropdown.Parent
                    if parentFrame then
                        local parentPos = parentFrame.AbsolutePosition
                        local parentSize = parentFrame.AbsoluteSize
                        if mouse.X < parentPos.X or mouse.X > parentPos.X + parentSize.X or
                           mouse.Y < parentPos.Y or mouse.Y > parentPos.Y + parentSize.Y then
                            OpenDropdown.Visible = false
                            OpenDropdown = nil
                        end
                    end
                end
            end
            
            if AutoloadList.Visible then
                local mouse = UserInputService:GetMouseLocation()
                local listPos = AutoloadList.AbsolutePosition
                local listSize = AutoloadList.AbsoluteSize
                local framePos = AutoloadDropdownFrame.AbsolutePosition
                local frameSize = AutoloadDropdownFrame.AbsoluteSize
                
                local inList = mouse.X >= listPos.X and mouse.X <= listPos.X + listSize.X and
                               mouse.Y >= listPos.Y and mouse.Y <= listPos.Y + listSize.Y
                local inFrame = mouse.X >= framePos.X and mouse.X <= framePos.X + frameSize.X and
                                mouse.Y >= framePos.Y and mouse.Y <= framePos.Y + frameSize.Y
                
                if not inList and not inFrame then
                    AutoloadList.Visible = false
                end
            end
        end)
    end
end)

-- Initialize
LoadConfigsFromFile()
RefreshConfigList()

-- Set initial autoload label if exists
if AutoloadConfigName then
    AutoloadLabel.Text = AutoloadConfigName
    AutoloadLabel.TextColor3 = Colors.Text
end

-- Autoload on start
if AutoloadConfigName and SavedConfigs[AutoloadConfigName] then
    local config = SavedConfigs[AutoloadConfigName]
    
    task.defer(function()
        -- Load innates
        if config.innates then
            for key, skill in pairs(config.innates) do
                if InnatesRows[key] then
                    InnatesRows[key].Dropdown.SetSelected(skill)
                    SelectedInnates[key] = skill
                    SetSkillValue(key, skill, "innates")
                end
            end
        end
        
        -- Load skills
        if config.skills then
            for key, skill in pairs(config.skills) do
                if SkillsRows[key] then
                    SkillsRows[key].Dropdown.SetSelected(skill)
                    SelectedSkills[key] = skill
                    SetSkillValue(key, skill, "skills")
                end
            end
        end
        
        -- Load remote innates
        if config.remoteInnates then
            for key, skill in pairs(config.remoteInnates) do
                RemoteInnateBindings[key] = skill
                if InnatesRemoteRows and InnatesRemoteRows[key] then
                    InnatesRemoteRows[key].Dropdown.SetSelected(skill)
                end
            end
        end
        
        -- Load remote skills
        if config.remoteSkills then
            for key, skill in pairs(config.remoteSkills) do
                RemoteSkillBindings[key] = skill
                if SkillsRemoteRows and SkillsRemoteRows[key] then
                    SkillsRemoteRows[key].Dropdown.SetSelected(skill)
                end
            end
        end

        -- Load fuse innates
        if config.fuseInnates then
             for key, skills in pairs(config.fuseInnates) do
                FuseInnateBindings[key] = skills
                if InnatesFuseRows and InnatesFuseRows[key] then
                     InnatesFuseRows[key].SetSkills(skills)
                end
            end
        end

        -- Load fuse skills
        if config.fuseSkills then
             for key, skills in pairs(config.fuseSkills) do
                FuseSkillBindings[key] = skills
                if SkillsFuseRows and SkillsFuseRows[key] then
                     SkillsFuseRows[key].SetSkills(skills)
                end
            end
        end
    end)
end

-- Select Innates tab by default
print("[Skill Builder] Setting default tab...")
TabButtons["Innates"].BackgroundColor3 = Colors.Accent
TabButtons["Innates"].TextColor3 = Colors.Background
Tabs["Innates"].Visible = true
CurrentTab = "Innates"
print("[Skill Builder] Default tab set, GUI should be visible now")

-- Ensure GUI is visible
MainFrame.Visible = true
DropdownOverlay.Visible = true
ScreenGui.Enabled = true

-- Equals key (=) toggle for GUI visibility
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Equals then
        MainFrame.Visible = not MainFrame.Visible
        DropdownOverlay.Visible = MainFrame.Visible
        -- Close any open dropdown when hiding
        if not MainFrame.Visible and OpenDropdown then
            OpenDropdown.Visible = false
            OpenDropdown = nil
        end
    end
end)

print("⚡ Skill Builder JJI loaded successfully!")
print("Press '=' to toggle GUI visibility")