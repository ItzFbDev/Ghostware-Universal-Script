-- SERVICES
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- GLOBAL CONFIG & SAVEFILE
local CONFIG_FILE = "GhostwareConfig.json"
local defaultConfig = {
    Aimbot = {
        Enabled = true,
        Keybind = Enum.KeyCode.C,
        Hitpart = "HumanoidRootPart",
        Strength = 0.5,
        Prediction = {X=0.12, Y=0.12, Z=0.12},
        DistanceLimit = 150,
        RecoilControl = true,
        RecoilStrength = 0.3,
        WallCheck = true,
    },
    ESP = {
        Enabled = true,
        DistanceLimit = 200,
        ShowBoxes = true,
        ShowHealthBars = true,
        ShowNames = true,
    }
}

-- Load config or create default
local config = defaultConfig
pcall(function()
    local data = readfile and readfile(CONFIG_FILE)
    if data then
        config = HttpService:JSONDecode(data)
    end
end)

-- SAVE CONFIG FUNCTION
local function saveConfig()
    if writefile then
        local encoded = HttpService:JSONEncode(config)
        writefile(CONFIG_FILE, encoded)
    end
end

-- UI Helper Function
local function Create(parent, props)
    local obj = Instance.new(props.ClassName or "Frame")
    for k,v in pairs(props) do
        if k ~= "ClassName" and k ~= "Parent" then
            obj[k] = v
        end
    end
    obj.Parent = parent or game.CoreGui
    return obj
end

-- Pulse effect for toggles (blue glow animation)
local function PulseEffect(guiObject)
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local tween = TweenService:Create(guiObject, tweenInfo, {BackgroundColor3 = Color3.fromRGB(0, 162, 255)})
    tween:Play()
    return tween
end

-- Bounce animation helper
local function BounceAnimation(guiObject)
    local bounceInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tweenUp = TweenService:Create(guiObject, bounceInfo, {Size = guiObject.Size + UDim2.new(0,10,0,5)})
    local tweenDown = TweenService:Create(guiObject, bounceInfo, {Size = guiObject.Size})
    tweenUp:Play()
    tweenUp.Completed:Wait()
    tweenDown:Play()
end

-- Create toggle button with pulse + bounce effect
local function CreateToggle(parent, text, default, callback)
    local toggleBtn = Create(parent, {
        ClassName = "TextButton",
        Text = text .. ": " .. (default and "ON" or "OFF"),
        Size = UDim2.new(0, 180, 0, 30),
        BackgroundColor3 = default and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(30, 30, 30),
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        AutoButtonColor = false,
    })

    local pulseTween = nil
    if default then
        pulseTween = PulseEffect(toggleBtn)
    end

    toggleBtn.MouseButton1Click:Connect(function()
        local toggled = not (toggleBtn.BackgroundColor3 == Color3.fromRGB(0, 162, 255))
        toggleBtn.BackgroundColor3 = toggled and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(30, 30, 30)
        toggleBtn.Text = text .. ": " .. (toggled and "ON" or "OFF")
        callback(toggled)

        BounceAnimation(toggleBtn)

        if toggled then
            if pulseTween then pulseTween:Play() else pulseTween = PulseEffect(toggleBtn) end
        else
            if pulseTween then pulseTween:Cancel() pulseTween = nil end
        end
    end)

    return toggleBtn
end

-- Create slider UI
local function CreateSlider(parent, text, min, max, default, width, callback)
    local container = Create(parent, {
        ClassName = "Frame",
        Size = UDim2.new(0, width, 0, 50),
        BackgroundTransparency = 1,
    })

    local label = Create(container, {
        ClassName = "TextLabel",
        Text = text .. ": " .. tostring(default),
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sliderBar = Create(container, {
        ClassName = "Frame",
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
        ClipsDescendants = true,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.3,
    })

    local sliderFill = Create(sliderBar, {
        ClassName = "Frame",
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 162, 255),
        BorderSizePixel = 0,
    })

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local function move(input)
                local pos = math.clamp(input.Position.X - sliderBar.AbsolutePosition.X, 0, sliderBar.AbsoluteSize.X)
                local val = (pos / sliderBar.AbsoluteSize.X) * (max - min) + min
                sliderFill.Size = UDim2.new(pos / sliderBar.AbsoluteSize.X, 0, 1, 0)
                label.Text = text .. ": " .. string.format("%.2f", val)
                callback(val)
            end
            move(input)
            local conn
            conn = UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement then
                    move(i)
                end
            end)
            UserInputService.InputEnded:Wait()
            conn:Disconnect()
        end
    end)

    return container
end

-- Create dropdown/expander menu for settings next to toggles
local function CreateDropdown(parent, title, width)
    local dropdownFrame = Create(parent, {
        ClassName = "Frame",
        Size = UDim2.new(0, width, 0, 30),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel = 0,
    })

    local titleLabel = Create(dropdownFrame, {
        ClassName = "TextLabel",
        Text = title,
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Position = UDim2.new(0, 10, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local toggleBtn = Create(dropdownFrame, {
        ClassName = "TextButton",
        Text = "+",
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -25, 0, 5),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        TextColor3 = Color3.new(1,1,1),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        AutoButtonColor = false,
    })

    local contentFrame = Create(parent, {
        ClassName = "Frame",
        Size = UDim2.new(0, width, 0, 0),
        BackgroundColor3 = Color3.fromRGB(25, 25, 25),
        ClipsDescendants = true,
        BorderSizePixel = 0,
        Position = UDim2.new(0, dropdownFrame.Position.X.Offset, 0, dropdownFrame.Position.Y.Offset + 30),
    })

    local expanded = false
    toggleBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            toggleBtn.Text = "-"
            local tween = TweenService:Create(contentFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(0, width, 0, 150)})
            tween:Play()
        else
            toggleBtn.Text = "+"
            local tween = TweenService:Create(contentFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(0, width, 0, 0)})
            tween:Play()
        end
    end)

    return dropdownFrame, contentFrame
end

-- ESP DRAWING
local ESPFolder = Instance.new("Folder", game.CoreGui)
ESPFolder.Name = "GhostwareESP"

local espObjects = {}

local function CreateESP(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(0, 162, 255)
    box.Thickness = 2
    box.Filled = false

    local healthBar = Drawing.new("Line")
    healthBar.Visible = false
    healthBar.Color = Color3.new(0, 1, 0)
    healthBar.Thickness = 4

    local nameLabel = Drawing.new("Text")
    nameLabel.Visible = false
    nameLabel.Color = Color3.fromRGB(255, 255, 255)
    nameLabel.Size = 16
    nameLabel.Center = true
    nameLabel.Outline = true
    nameLabel.Text = player.Name

    espObjects[player] = {
        Box = box,
        HealthBar = healthBar,
        NameLabel = nameLabel,
    }
end

local function RemoveESP(player)
    local data = espObjects[player]
    if data then
        data.Box:Remove()
        data.HealthBar:Remove()
        data.NameLabel:Remove()
        espObjects[player] = nil
    end
end

local function UpdateESP()
    for player, data in pairs(espObjects) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") then
            local rootPos = player.Character.HumanoidRootPart.Position
            local distance = (rootPos - Camera.CFrame.Position).Magnitude

            if distance > config.ESP.DistanceLimit or not config.ESP.Enabled or player == LocalPlayer then
                data.Box.Visible = false
                data.HealthBar.Visible = false
                data.NameLabel.Visible = false
            else
                local rootPos2D, onScreen = Camera:WorldToViewportPoint(rootPos)
                if onScreen then
                    local size = 1000 / distance
                    data.Box.Visible = config.ESP.ShowBoxes
                    data.Box.Size = size
                    data.Box.Position = Vector2.new(rootPos2D.X - size/2, rootPos2D.Y - size/2)

                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        local healthPercent = humanoid.Health / humanoid.MaxHealth
                        data.HealthBar.Visible = config.ESP.ShowHealthBars
                        if data.HealthBar.Visible then
                            data.HealthBar.From = Vector2.new(rootPos2D.X + size/2 + 5, rootPos2D.Y + size/2)
                            data.HealthBar.To = Vector2.new(rootPos2D.X + size/2 + 5, rootPos2D.Y + size/2 - size * healthPercent)
                            data.HealthBar.Color = Color3.fromHSV(healthPercent * 0.33, 1, 1)
                        else
                            data.HealthBar.Visible = false
                        end
                    end

                    data.NameLabel.Visible = config.ESP.ShowNames
                    data.NameLabel.Position = Vector2.new(rootPos2D.X, rootPos2D.Y - size/2 - 20)
                else
                    data.Box.Visible = false
                    data.HealthBar.Visible = false
                    data.NameLabel.Visible = false
                end
            end
        else
            data.Box.Visible = false
            data.HealthBar.Visible = false
            data.NameLabel.Visible = false
        end
    end
end

-- Add ESP to all current players
for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        CreateESP(plr)
    end
end

Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then
        CreateESP(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    RemoveESP(plr)
end)

-- AIMBOT
local AimbotTarget = nil
local HoldingAim = false

local function IsVisible(origin, targetPos)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local ray = Workspace:Raycast(origin, (targetPos - origin).Unit * (targetPos - origin).Magnitude, rayParams)
    if ray then
        -- hit something, check if it hit target or obstacle
        if ray.Instance and ray.Instance:IsDescendantOf(targetPos.Parent) then
            return true
        else
            return false
        end
    else
        return true
    end
end

local function GetClosestPlayer()
    local closestDist = math.huge
    local closestPlayer = nil
    local mousePos = UserInputService:GetMouseLocation()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild(config.Aimbot.Hitpart) then
            local rootPos = plr.Character[config.Aimbot.Hitpart].Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
                local worldDist = (rootPos - Camera.CFrame.Position).Magnitude
                if dist < closestDist and worldDist <= config.Aimbot.DistanceLimit then
                    if config.Aimbot.WallCheck then
                        if IsVisible(Camera.CFrame.Position, plr.Character[config.Aimbot.Hitpart]) then
                            closestDist = dist
                            closestPlayer = plr
                        end
                    else
                        closestDist = dist
                        closestPlayer = plr
                    end
                end
            end
        end
    end
    return closestPlayer
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.Aimbot.Keybind then
        HoldingAim = true
        AimbotTarget = GetClosestPlayer()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        -- Toggle GUI visibility (will add later)
        if gui.Enabled == nil then
            gui.Enabled = true
        else
            gui.Enabled = not gui.Enabled
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == config.Aimbot.Keybind then
        HoldingAim = false
        AimbotTarget = nil
    end
end)

RunService.RenderStepped:Connect(function()
    -- Aimbot logic
    if config.Aimbot.Enabled and HoldingAim and AimbotTarget and AimbotTarget.Character and AimbotTarget.Character:FindFirstChild(config.Aimbot.Hitpart) then
        local targetPart = AimbotTarget.Character[config.Aimbot.Hitpart]
        local pred = Vector3.new(config.Aimbot.Prediction.X, config.Aimbot.Prediction.Y, config.Aimbot.Prediction.Z or config.Aimbot.Prediction.X)
        local aimPos = targetPart.Position + targetPart.Velocity * pred
        local camPos = Camera.CFrame.Position
        local dir = (aimPos - camPos)
        local aimCF = CFrame.new(camPos, camPos + dir.Unit * dir.Magnitude * config.Aimbot.Strength)
        Camera.CFrame = aimCF

        -- Recoil control simulation (basic)
        if config.Aimbot.RecoilControl then
            local recoilOffset = Vector3.new(0, config.Aimbot.RecoilStrength, 0)
            Camera.CFrame = Camera.CFrame * CFrame.new(recoilOffset)
        end
    end

    UpdateESP()
end)

-- GUI CREATION
local gui = Instance.new("ScreenGui")
gui.Name = "GhostwareUI"
gui.ResetOnSpawn = false
gui.Parent = game.CoreGui

local mainFrame = Create(gui, {
    ClassName = "Frame",
    Size = UDim2.new(0, 400, 0, 450),
    Position = UDim2.new(0.5, -200, 0.5, -225),
    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
    BorderSizePixel = 0,
})

-- Title
local title = Create(mainFrame, {
    ClassName = "TextLabel",
    Text = "Ghostware Aimbot & ESP",
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(0, 162, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 28,
})

-- Close Button
local closeBtn = Create(mainFrame, {
    ClassName = "TextButton",
    Text = "X",
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -35, 0, 5),
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false,
})
closeBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

-- Save Button
local saveBtn = Create(mainFrame, {
    ClassName = "TextButton",
    Text = "Save Settings",
    Size = UDim2.new(0, 140, 0, 30),
    Position = UDim2.new(0, 10, 1, -40),
    BackgroundColor3 = Color3.fromRGB(0, 162, 255),
    TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false,
})
saveBtn.MouseButton1Click:Connect(function()
    saveConfig()
end)

-- --- AIMBOT UI ---
local aimbotToggle = CreateToggle(mainFrame, "Aimbot", config.Aimbot.Enabled, function(val)
    config.Aimbot.Enabled = val
end)

aimbotToggle.Position = UDim2.new(0, 10, 0, 60)

local aimbotDropdown, aimbotSettings = CreateDropdown(mainFrame, "Aimbot Settings", 380)
aimbotDropdown.Position = UDim2.new(0, 10, 0, 90)

-- Strength Slider
local strengthSlider = CreateSlider(aimbotSettings, "Strength", 0, 1, config.Aimbot.Strength, 360, function(val)
    config.Aimbot.Strength = val
end)
strengthSlider.Position = UDim2.new(0, 10, 0, 10)

-- Prediction sliders X Y Z
local predXSlider = CreateSlider(aimbotSettings, "Prediction X", 0, 1, config.Aimbot.Prediction.X, 175, function(val)
    config.Aimbot.Prediction.X = val
end)
predXSlider.Position = UDim2.new(0, 10, 0, 60)

local predYSlider = CreateSlider(aimbotSettings, "Prediction Y", 0, 1, config.Aimbot.Prediction.Y, 175, function(val)
    config.Aimbot.Prediction.Y = val
end)
predYSlider.Position = UDim2.new(0, 195, 0, 60)

local predZSlider = CreateSlider(aimbotSettings, "Prediction Z", 0, 1, config.Aimbot.Prediction.Z or config.Aimbot.Prediction.X, 175, function(val)
    config.Aimbot.Prediction.Z = val
end)
predZSlider.Position = UDim2.new(0, 195, 0, 110)

-- Distance limit slider
local distanceSlider = CreateSlider(aimbotSettings, "Distance Limit", 10, 300, config.Aimbot.DistanceLimit, 360, function(val)
    config.Aimbot.DistanceLimit = val
end)
distanceSlider.Position = UDim2.new(0, 10, 0, 110)

-- Recoil Control toggle
local recoilToggle = CreateToggle(aimbotSettings, "Recoil Control", config.Aimbot.RecoilControl, function(val)
    config.Aimbot.RecoilControl = val
end)
recoilToggle.Position = UDim2.new(0, 10, 0, 150)

-- Recoil Strength slider
local recoilStrengthSlider = CreateSlider(aimbotSettings, "Recoil Strength", 0, 1, config.Aimbot.RecoilStrength, 360, function(val)
    config.Aimbot.RecoilStrength = val
end)
recoilStrengthSlider.Position = UDim2.new(0, 10, 0, 190)

-- Wall check toggle
local wallCheckToggle = CreateToggle(aimbotSettings, "Wall Check", config.Aimbot.WallCheck, function(val)
    config.Aimbot.WallCheck = val
end)
wallCheckToggle.Position = UDim2.new(0, 10, 0, 230)


-- --- ESP UI ---
local espToggle = CreateToggle(mainFrame, "ESP", config.ESP.Enabled, function(val)
    config.ESP.Enabled = val
end)
espToggle.Position = UDim2.new(0, 10, 0, 300)

local espDropdown, espSettings = CreateDropdown(mainFrame, "ESP Settings", 380)
espDropdown.Position = UDim2.new(0, 10, 0, 330)

-- ESP Distance slider
local espDistanceSlider = CreateSlider(espSettings, "Distance Limit", 10, 500, config.ESP.DistanceLimit, 360, function(val)
    config.ESP.DistanceLimit = val
end)
espDistanceSlider.Position = UDim2.new(0, 10, 0, 10)

-- Boxes toggle
local boxesToggle = CreateToggle(espSettings, "Show Boxes", config.ESP.ShowBoxes, function(val)
    config.ESP.ShowBoxes = val
end)
boxesToggle.Position = UDim2.new(0, 10, 0, 50)

-- Health bars toggle
local healthToggle = CreateToggle(espSettings, "Show Health Bars", config.ESP.ShowHealthBars, function(val)
    config.ESP.ShowHealthBars = val
end)
healthToggle.Position = UDim2.new(0, 200, 0, 50)

-- Names toggle
local namesToggle = CreateToggle(espSettings, "Show Names", config.ESP.ShowNames, function(val)
    config.ESP.ShowNames = val
end)
namesToggle.Position = UDim2.new(0, 10, 0, 90)

-- Info Label (keybind info)
local infoLabel = Create(mainFrame, {
    ClassName = "TextLabel",
    Text = "Hold C to aim | RightShift to toggle GUI",
    Size = UDim2.new(1, 0, 0, 25),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamItalic,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
})

return gui
