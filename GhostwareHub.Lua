--[[ 
    Universal Exploit Script for Roblox Shooters
    Games Supported: The Eastern War (R15), Arsenal, Rivals
    Features:
    - Multi-tab UI (Black/White/Red)
    - Aimbot with prediction, bone aiming, FOV, hit chance, team check, visibility check
    - Silent Aim hooking
    - Recoil/Spread bypass
    - TriggerBot with delay and hit chance
    - ESP with boxes, health, names, distance
    - Movement Mods (Speed, Jump, Fly)
    - Weapon switcher and auto reload
    - Fake lag
    - Anti-AFK
    - Config save/load
    - Keybind tab
    - UI Dragging
--]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Local Player
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

--// Globals and Config
local Config = {
    Aimbot = {
        Enabled = false,
        AimBone = "Head", -- Head, UpperTorso, HumanoidRootPart
        Prediction = true,
        PredictionFactor = 0.135, -- tweak for bullet speed
        MaxDistance = 16000,
        FOV = 45, -- degrees
        HitChance = 80, -- percent
        TeamCheck = true,
        WallCheck = true,
        Smoothness = 0.3,
    },
    SilentAim = {
        Enabled = false,
        AimBone = "Head",
        MaxDistance = 16000,
        TeamCheck = true,
    },
    RecoilBypass = {
        Enabled = false,
    },
    TriggerBot = {
        Enabled = false,
        Delay = 0.05,
        HitChance = 90,
        TeamCheck = true,
    },
    ESP = {
        Enabled = false,
        Boxes = true,
        HealthBars = true,
        Names = true,
        Distance = true,
        Thickness = 1.5,
        Range = 16000,
    },
    Movement = {
        Speed = {
            Enabled = false,
            Value = 20,
        },
        Jump = {
            Enabled = false,
            Value = 70,
        },
        Fly = {
            Enabled = false,
            Speed = 50,
        },
    },
    WeaponSwitcher = {
        Enabled = false,
    },
    AutoReload = {
        Enabled = false,
    },
    FakeLag = {
        Enabled = false,
        Amount = 0.1, -- delay in seconds
    },
    AntiAFK = {
        Enabled = true,
    },
    Keybinds = {
        ToggleAimbot = Enum.KeyCode.E,
        ToggleESP = Enum.KeyCode.F,
        ToggleTriggerBot = Enum.KeyCode.T,
        ToggleFly = Enum.KeyCode.G,
    }
}

-- Save file path (for exploits supporting file system)
local SavePath = "UniversalExploitConfig.json"

-- Utility Functions
local function IsAlive(plr)
    local character = plr.Character
    if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
        return true
    end
    return false
end

local function IsTeamMate(plr)
    if not LocalPlayer.Team or not plr.Team then return false end
    return LocalPlayer.Team == plr.Team
end

local function GetCharacter(plr)
    return plr.Character
end

-- Calculate Distance from LocalPlayer to target
local function GetDistance(targetPos)
    return (targetPos - Workspace.CurrentCamera.CFrame.Position).Magnitude
end

-- Get aim part with fallback
local function GetAimPart(character, boneName)
    if not character then return nil end
    local part = character:FindFirstChild(boneName) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    return part
end

-- Visibility check (raycast from camera to target)
local function IsVisible(targetPart)
    local origin = Workspace.CurrentCamera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    if raycastResult and raycastResult.Instance then
        return raycastResult.Instance:IsDescendantOf(targetPart.Parent)
    end
    return true -- no obstacle
end

-- Get closest target to mouse within FOV and range
local function GetClosestTarget()
    local camera = Workspace.CurrentCamera
    local mousePos = UserInputService:GetMouseLocation()
    local closestTarget = nil
    local shortestDistance = math.huge

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsAlive(plr) then
            if Config.Aimbot.TeamCheck and IsTeamMate(plr) then
                -- Skip teammates if team check enabled
            else
                local char = GetCharacter(plr)
                local aimPart = GetAimPart(char, Config.Aimbot.AimBone)
                if aimPart then
                    if Config.Aimbot.WallCheck and not IsVisible(aimPart) then
                        -- Skip if not visible
                    else
                        local distance = GetDistance(aimPart.Position)
                        if distance <= Config.Aimbot.MaxDistance then
                            -- Calculate screen position & check FOV
                            local screenPos, onScreen = camera:WorldToViewportPoint(aimPart.Position)
                            if onScreen then
                                local mouseVec2 = Vector2.new(mousePos.X, mousePos.Y)
                                local targetVec2 = Vector2.new(screenPos.X, screenPos.Y)
                                local delta = (mouseVec2 - targetVec2).Magnitude
                                if delta < shortestDistance and delta <= (Config.Aimbot.FOV * 15) then -- rough scale for FOV
                                    closestTarget = plr
                                    shortestDistance = delta
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return closestTarget
end

-- Predict target position for moving targets
local function PredictPosition(targetPart, velocity, predictionFactor)
    return targetPart.Position + (velocity * predictionFactor)
end

-- Smooth mouse movement towards a target position
local function SmoothAim(targetPos)
    local camera = Workspace.CurrentCamera
    local mouse = UserInputService:GetMouseLocation()

    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
    if onScreen then
        local mousePos = Vector2.new(mouse.X, mouse.Y)
        local targetVec = Vector2.new(screenPos.X, screenPos.Y)
        local newPos = mousePos:Lerp(targetVec, Config.Aimbot.Smoothness)
        mousemoverel(newPos.X - mousePos.X, newPos.Y - mousePos.Y)
    end
end

-- Silent Aim Implementation: Hook Raycast or Mouse.Hit for bullet direction override
local oldRaycast = Workspace.Raycast
local raycastHooked = false

local function HookRaycast()
    if raycastHooked then return end
    raycastHooked = true

    Workspace.Raycast = function(self, origin, direction, params)
        if Config.SilentAim.Enabled then
            -- Find best target in Silent Aim range
            local bestTarget = nil
            local closestDistance = math.huge
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and IsAlive(plr) then
                    if Config.SilentAim.TeamCheck and IsTeamMate(plr) then
                        -- skip teammates
                    else
                        local char = GetCharacter(plr)
                        local aimPart = GetAimPart(char, Config.SilentAim.AimBone)
                        if aimPart then
                            local dist = GetDistance(aimPart.Position)
                            if dist <= Config.SilentAim.MaxDistance then
                                if IsVisible(aimPart) then
                                    local diff = (origin - aimPart.Position).Magnitude
                                    if diff < closestDistance then
                                        bestTarget = aimPart
                                        closestDistance = diff
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if bestTarget then
                local newDir = (bestTarget.Position - origin).Unit * direction.Magnitude
                return oldRaycast(self, origin, newDir, params)
            end
        end
        return oldRaycast(self, origin, direction, params)
    end
end

-- Recoil/Spread bypass via Metamethod hook
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
local oldNewIndex = mt.__newindex
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if Config.RecoilBypass.Enabled then
        -- Example: For some guns, you can detect recoil or spread calls here
        -- You might want to nil or zero recoil/spread parameters here if applicable
        -- This is game-specific, pseudo example below:
        if tostring(self) == "Gun" and method == "Fire" then
            -- Remove recoil
            if args[1] and type(args[1]) == "table" then
                args[1].Recoil = 0
                args[1].Spread = 0
            end
        end
    end
    return oldNamecall(self, unpack(args))
end)

setreadonly(mt, true)

-- TriggerBot implementation
local TriggerBotRunning = false
local function TriggerBot()
    if not Config.TriggerBot.Enabled then return end
    if TriggerBotRunning then return end
    TriggerBotRunning = true

    spawn(function()
        while Config.TriggerBot.Enabled do
            wait(Config.TriggerBot.Delay)
            local camera = Workspace.CurrentCamera
            local mousePos = UserInputService:GetMouseLocation()

            local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

            local raycastResult = Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
            if raycastResult and raycastResult.Instance then
                local hitPart = raycastResult.Instance
                local plr = Players:GetPlayerFromCharacter(hitPart.Parent)
                if plr and plr ~= LocalPlayer and IsAlive(plr) then
                    if Config.TriggerBot.TeamCheck and IsTeamMate(plr) then
                        -- skip teammates
                    else
                        -- Hit chance check
                        if math.random(1,100) <= Config.TriggerBot.HitChance then
                            -- Fire your weapon - game specific code here
                            -- Usually remote event fire or tool activation
                            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                            if tool and tool:FindFirstChild("RemoteEvent") then
                                tool.RemoteEvent:FireServer()
                            end
                        end
                    end
                end
            end
            wait()
        end
        TriggerBotRunning = false
    end)
end

-- ESP Implementation
local ESPFolder = Instance.new("Folder", game.CoreGui)
ESPFolder.Name = "UniversalESP"

local ESPObjects = {}

local function CreateESPBox(plr)
    if ESPObjects[plr] then return ESPObjects[plr] end
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.new(1,0,0)
    box.Thickness = Config.ESP.Thickness
    box.Transparency = 1
    ESPObjects[plr] = {Box = box}
    return ESPObjects[plr]
end

local function RemoveESPBox(plr)
    if ESPObjects[plr] then
        if ESPObjects[plr].Box then
            ESPObjects[plr].Box:Remove()
        end
        ESPObjects[plr] = nil
    end
end

local function UpdateESP()
    local camera = Workspace.CurrentCamera
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsAlive(plr) and Config.ESP.Enabled then
            if Config.Aimbot.TeamCheck and IsTeamMate(plr) then
                RemoveESPBox(plr)
            else
                local char = GetCharacter(plr)
                if char then
                    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    if rootPart then
                        local pos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
                        if onScreen and GetDistance(rootPart.Position) <= Config.ESP.Range then
                            local esp = CreateESPBox(plr)
                            esp.Box.Visible = true
                            esp.Box.Color = Color3.new(1,0,0)
                            esp.Box.Thickness = Config.ESP.Thickness

                            local size = Vector3.new(2,5,0) -- approximate size
                            local topPos, topScreen = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0))
                            local bottomPos, bottomScreen = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

                            local height = math.abs(topPos.Y - bottomPos.Y)
                            local width = height / 2

                            esp.Box.Size = Vector2.new(width, height)
                            esp.Box.Position = Vector2.new(pos.X - width/2, pos.Y - height/2)
                        else
                            RemoveESPBox(plr)
                        end
                    end
                else
                    RemoveESPBox(plr)
                end
            end
        else
            RemoveESPBox(plr)
        end
    end
end

RunService.RenderStepped:Connect(UpdateESP)

-- Movement Mods (Speed, Jump, Fly)
local FlyEnabled = false
local FlySpeed = 50
local FlyBodyGyro
local FlyBodyVelocity

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Keybinds.ToggleFly then
        Config.Movement.Fly.Enabled = not Config.Movement.Fly.Enabled
        if Config.Movement.Fly.Enabled then
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                FlyBodyGyro = Instance.new("BodyGyro", character.HumanoidRootPart)
                FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                FlyBodyGyro.P = 9e4
                FlyBodyGyro.CFrame = character.HumanoidRootPart.CFrame

                FlyBodyVelocity = Instance.new("BodyVelocity", character.HumanoidRootPart)
                FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        else
            if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
            if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
        end
    end
end)

RunService.Stepped:Connect(function()
    if Config.Movement.Speed.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = Config.Movement.Speed.Value
    elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16 -- default
    end

    if Config.Movement.Jump.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.JumpPower = Config.Movement.Jump.Value
    elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.JumpPower = 50 -- default
    end

    if Config.Movement.Fly.Enabled and FlyBodyGyro and FlyBodyVelocity and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        FlyBodyGyro.CFrame = Workspace.CurrentCamera.CFrame
        local moveDir = Vector3.new()

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + Workspace.CurrentCamera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - Workspace.CurrentCamera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - Workspace.CurrentCamera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + Workspace.CurrentCamera.CFrame.RightVector
        end

        FlyBodyVelocity.Velocity = moveDir.Unit * Config.Movement.Fly.Speed
    end
end)

-- Weapon Switcher & Auto Reload (Game-specific placeholders)
local function SwitchToBestWeapon()
    -- Pseudocode: switch to best weapon in inventory
    if not Config.WeaponSwitcher.Enabled then return end
    local backpack = LocalPlayer.Backpack
    local bestWeapon = nil
    local bestRank = 0
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            -- Some way to rank weapons by damage or rarity
            local rank = item:GetAttribute("Rank") or 0
            if rank > bestRank then
                bestRank = rank
                bestWeapon = item
            end
        end
    end
    if bestWeapon then
        LocalPlayer.Character.Humanoid:EquipTool(bestWeapon)
    end
end

local function AutoReload()
    if not Config.AutoReload.Enabled then return end
    -- Game-specific auto reload placeholder
    -- Usually involves firing a remote or activating tool
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool and tool:FindFirstChild("ReloadEvent") then
        tool.ReloadEvent:FireServer()
    end
end

-- Fake Lag (game-specific, simulate lag by delaying input or networking)
local function EnableFakeLag()
    if not Config.FakeLag.Enabled then return end
    -- Example: delay local events or movement (complex in Roblox)
    -- This is just a placeholder for conceptual use
end

-- Anti AFK
if Config.AntiAFK.Enabled then
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
        wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    end)
end

-- UI Setup (using a lightweight library or manual drawing)
-- Due to complexity, here is a very basic UI skeleton with tabs and drag:

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalExploitUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 450, 0, 400)
MainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Active = true
MainFrame.Draggable = true -- Dragging feature on top

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22
Title.Text = "Universal Exploit - Black/White/Red Theme"
Title.TextStrokeTransparency = 0.7

-- Tabs container
local TabsContainer = Instance.new("Frame", MainFrame)
TabsContainer.Size = UDim2.new(1, 0, 1, -40)
TabsContainer.Position = UDim2.new(0, 0, 0, 40)
TabsContainer.BackgroundTransparency = 1

local Tabs = {}
local SelectedTab = nil

local function CreateTab(name)
    local button = Instance.new("TextButton", Title)
    button.Size = UDim2.new(0, 80, 1, 0)
    button.Position = UDim2.new(0, (#Tabs * 85), 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 14
    button.Text = name

    local content = Instance.new("Frame", TabsContainer)
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false

    Tabs[name] = {Button = button, Content = content}

    button.MouseButton1Click:Connect(function()
        if SelectedTab then
            Tabs[SelectedTab].Content.Visible = false
            Tabs[SelectedTab].Button.BackgroundColor3 = Color3.fromRGB(40,40,40)
        end
        SelectedTab = name
        content.Visible = true
        button.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    end)
end

-- Create Tabs
local tabNames = {"Aimbot", "ESP", "TriggerBot", "Movement", "Weapon", "Keybinds", "Config"}
for _, tname in ipairs(tabNames) do
    CreateTab(tname)
end
-- Select first tab by default
Tabs[tabNames[1]].Button:MouseButton1Click()

-- Function to add toggles, sliders, dropdowns for config
local function AddToggle(parent, label, configTable, key)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1

    local toggleLabel = Instance.new("TextLabel", frame)
    toggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    toggleLabel.Text = label
    toggleLabel.TextColor3 = Color3.fromRGB(255,255,255)
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Font = Enum.Font.Gotham
    toggleLabel.TextSize = 14
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local toggleButton = Instance.new("TextButton", frame)
    toggleButton.Size = UDim2.new(0.4, 0, 1, 0)
    toggleButton.Position = UDim2.new(0.6, 0, 0, 0)
    toggleButton.BackgroundColor3 = configTable[key] and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(60, 60, 60)
    toggleButton.Text = configTable[key] and "ON" or "OFF"
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 14
    toggleButton.TextColor3 = Color3.new(1,1,1)

    toggleButton.MouseButton1Click:Connect(function()
        configTable[key] = not configTable[key]
        toggleButton.BackgroundColor3 = configTable[key] and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(60, 60, 60)
        toggleButton.Text = configTable[key] and "ON" or "OFF"
    end)

    return frame
end

-- Function to add sliders (number inputs)
local function AddSlider(parent, label, configTable, key, minVal, maxVal)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundTransparency = 1

    local sliderLabel = Instance.new("TextLabel", frame)
    sliderLabel.Size = UDim2.new(1, 0, 0, 20)
    sliderLabel.Text = label .. ": " .. tostring(configTable[key])
    sliderLabel.TextColor3 = Color3.fromRGB(255,255,255)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Font = Enum.Font.Gotham
    sliderLabel.TextSize = 14
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left

    local sliderBar = Instance.new("TextButton", frame)
    sliderBar.Size = UDim2.new(1, 0, 0, 10)
    sliderBar.Position = UDim2.new(0, 0, 0, 25)
    sliderBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    sliderBar.Text = ""

    local function updateSlider(x)
        local relativeX = math.clamp(x - sliderBar.AbsolutePosition.X, 0, sliderBar.AbsoluteSize.X)
        local percentage = relativeX / sliderBar.AbsoluteSize.X
        local value = math.floor(minVal + (maxVal - minVal) * percentage)
        configTable[key] = value
        sliderLabel.Text = label .. ": " .. tostring(value)
    end

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            updateSlider(input.Position.X)
            local conn
            conn = UserInputService.InputChanged:Connect(function(moveInput)
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(moveInput.Position.X)
                else
                    conn:Disconnect()
                end
            end)
        end
    end)

    return frame
end

Certainly! Here's a comprehensive all-in-one Roblox Lua script skeleton integrating the requested features into a clean UI with tabs, toggles, sliders, and core functionality stubs. This script is intended as a base; the exact game specifics (like raycasting, weapon switching, remote events) will need adjustments per your target game.

```lua
--// Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

--// Config table for storing all settings
local Config = {
    Aimbot = {
        Enabled = false,
        SilentAim = true,
        AimFOV = 15,
        HitChance = 80,
        AimBone = "Head",
        Prediction = true,
        TeamCheck = true,
        WallCheck = true,
    },
    ESP = {
        Enabled = false,
        HealthBars = true,
        Names = true,
        Distance = true,
        TeamCheck = true,
        WallCheck = true,
    },
    TriggerBot = {
        Enabled = false,
        Delay = 0.1,
        HitChance = 70,
        TeamCheck = true,
        WallCheck = true,
    },
    Movement = {
        FlyEnabled = false,
        FlySpeed = 50,
        AntiAFK = true,
    },
    Weapon = {
        AutoSwitch = false,
        AutoReload = false,
    },
    FakeLag = {
        Enabled = false,
    },
    Keybinds = {
        ToggleAimbot = Enum.KeyCode.X,
        ToggleESP = Enum.KeyCode.Z,
        FlyToggle = Enum.KeyCode.V,
    },
}

--// Utility Functions
local function IsTeamMate(character)
    if not Config.Aimbot.TeamCheck then return false end
    if not character or not character:FindFirstChild("Humanoid") then return false end
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return false end
    return player.Team == LocalPlayer.Team
end

local function IsVisible(targetPart)
    if not Config.Aimbot.WallCheck then return true end
    local camera = Workspace.CurrentCamera
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * 500
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    return not raycastResult or raycastResult.Instance:IsDescendantOf(targetPart.Parent)
end

--// Aimbot core (Silent Aim example)
local function GetClosestTarget()
    local camera = Workspace.CurrentCamera
    local closestDist = Config.Aimbot.AimFOV
    local targetPart, targetPlayer = nil, nil
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(Config.Aimbot.AimBone) then
            if not IsTeamMate(player.Character) then
                local part = player.Character[Config.Aimbot.AimBone]
                if IsVisible(part) then
                    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - UserInputService:GetMouseLocation()).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            targetPart = part
                            targetPlayer = player
                        end
                    end
                end
            end
        end
    end
    return targetPart, targetPlayer
end

--// Prediction example (simple velocity-based)
local function PredictPosition(targetPart, velocity, predictionTime)
    return targetPart.Position + velocity * predictionTime
end

--// Hook into mouse input for silent aim
-- Placeholder: Depends on game, often involves hooking Raycast or mouse position on the server

--// ESP example (simple drawing)
local Drawing = Drawing
local ESPObjects = {}

local function CreateESPForPlayer(player)
    local esp = {}
    esp.Box = Drawing.new("Square")
    esp.Box.Color = Color3.fromRGB(255, 0, 0)
    esp.Box.Thickness = 2
    esp.Box.Visible = false

    esp.Name = Drawing.new("Text")
    esp.Name.Text = player.Name
    esp.Name.Size = 16
    esp.Name.Color = Color3.fromRGB(255, 255, 255)
    esp.Name.Visible = false

    return esp
end

-- Create ESP for all players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        ESPObjects[player] = CreateESPForPlayer(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    ESPObjects[player] = CreateESPForPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        ESPObjects[player].Box:Remove()
        ESPObjects[player].Name:Remove()
        ESPObjects[player] = nil
    end
end)

RunService.RenderStepped:Connect(function()
    local camera = Workspace.CurrentCamera
    for player, esp in pairs(ESPObjects) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local rootPart = player.Character.HumanoidRootPart
            if Config.ESP.Enabled and (not Config.ESP.TeamCheck or not IsTeamMate(player.Character)) then
                local pos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
                if onScreen then
                    esp.Box.Visible = true
                    esp.Name.Visible = true
                    local size = 50
                    esp.Box.Position = Vector2.new(pos.X - size/2, pos.Y - size/2)
                    esp.Box.Size = Vector2.new(size, size)
                    esp.Name.Position = Vector2.new(pos.X, pos.Y - size/2 - 15)
                else
                    esp.Box.Visible = false
                    esp.Name.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
            end
        else
            esp.Box.Visible = false
            esp.Name.Visible = false
        end
    end
end)

--// UI (Tabs + Toggles + Sliders)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalExploitUI"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 450, 0, 400)
MainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22
Title.Text = "Universal Exploit"
Title.TextStrokeTransparency = 0.7
Title.Parent = MainFrame

local TabsContainer = Instance.new("Frame")
TabsContainer.Size = UDim2.new(1, 0, 1, -40)
TabsContainer.Position = UDim2.new(0, 0, 0, 40)
TabsContainer.BackgroundTransparency = 1
TabsContainer.Parent = MainFrame

local Tabs = {}
local SelectedTab = nil

local function CreateTab(name)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 80, 1, 0)
    button.Position = UDim2.new(0, (#Tabs * 85), 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 14
    button.Text = name
    button.Parent = Title

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = TabsContainer

    Tabs[name] = {Button = button, Content = content}

    button.MouseButton1Click:Connect(function()
        if SelectedTab then
            Tabs[SelectedTab].Content.Visible = false
            Tabs[SelectedTab].Button.BackgroundColor3 = Color3.fromRGB(40,40,40)
        end
        SelectedTab = name
        content.Visible = true
        button.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    end)
end

-- Create all tabs
local tabNames = {"Aimbot", "ESP", "TriggerBot", "Movement", "Weapon", "Keybinds", "Config"}
for _, tname in ipairs(tabNames) do
    CreateTab(tname)
end
-- Select first tab by default
Tabs[tabNames[1]].Button:MouseButton1Click()

-- Helpers for UI Controls

local function AddToggle(parent, label, configTable, key)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    toggleLabel.Text = label
    toggleLabel.TextColor3 = Color3.fromRGB(255,255,255)
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Font = Enum.Font.Gotham
    toggleLabel.TextSize = 14
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0.4, 0, 1, 0)
    toggleButton.Position = UDim2.new(0.6, 0, 0, 0)
    toggleButton.BackgroundColor3 = configTable[key] and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(60, 60, 60)
    toggleButton.Text = configTable[key] and "ON" or "OFF"
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 14
    toggleButton.TextColor3 = Color3.new(1,1,1)
    toggleButton.Parent = frame

    toggleButton.MouseButton1Click:Connect(function()
        configTable[key] = not configTable[key]
        toggleButton.BackgroundColor3 = configTable[key] and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(60, 60, 60)
        toggleButton.Text = configTable[key] and "ON" or "OFF"
    end)

    return frame
end

local function AddSlider(parent, label, configTable, key, minVal, maxVal)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Size = UDim2.new(1, 0, 0, 20)
    sliderLabel.Text = label .. ": " .. tostring(configTable[key])
    sliderLabel.TextColor3 = Color3.fromRGB(255,255,255)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Font = Enum.Font.Gotham
    sliderLabel.TextSize = 14
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.Parent = frame

    local sliderBar = Instance.new("TextButton")
    sliderBar.Size = UDim2.new(1, 0, 0, 10)
    sliderBar.Position = UDim2.new(0, 0, 0, 25)
    sliderBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    sliderBar.Text = ""
    sliderBar.Parent = frame

    local function updateSlider(x)
        local relativeX = math.clamp(x - sliderBar.AbsolutePosition.X, 0, sliderBar.AbsoluteSize.X)
        local percentage = relativeX / sliderBar.AbsoluteSize.X
        local value = math.floor(minVal + (maxVal - minVal) * percentage)
        configTable[key] = value
        sliderLabel.Text = label .. ": " .. tostring(value)
    end

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            updateSlider(input.Position.X)
            local conn
            conn = UserInputService.InputChanged:Connect(function(moveInput)
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(moveInput.Position.X)
                else
                    conn:Disconnect()
                end
            end)
        end
    end)

    return frame
end

-- Populate Aimbot Tab UI
local aimbotTab = Tabs["Aimbot"].Content
AddToggle(aimbotTab, "Enable Aimbot", Config.Aimbot, "Enabled")
AddToggle(aimbotTab, "Silent Aim", Config.Aimbot, "SilentAim")
AddSlider(aimbotTab, "Aim FOV", Config.Aimbot, "AimFOV", 1, 50)
AddSlider(aimbotTab, "Hit Chance %", Config.Aimbot, "HitChance", 0, 100)
-- Aim Bone dropdown would require more complex UI - placeholder text for now
local aimBoneLabel = Instance.new("TextLabel", aimbotTab)
aimBoneLabel.Size = UDim2.new(1, -10, 0, 30)
aimBoneLabel.Position = UDim2.new(0, 0, 0, 140)
aimBoneLabel.Text = "Aim Bone: " .. Config.Aimbot.AimBone
aimBoneLabel.TextColor3 = Color3.new(1,1,1)
aimBoneLabel.BackgroundTransparency = 1
aimBoneLabel.Font = Enum.Font.Gotham
aimBoneLabel.TextSize = 14

-- Similarly add UI for other tabs as needed...

-- Keybind to toggle aimbot (example)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Keybinds.ToggleAimbot then
        Config.Aimbot.Enabled = not Config.Aimbot.Enabled
        print("Aimbot toggled:", Config.Aimbot.Enabled)
    elseif input.KeyCode == Config.Keybinds.ToggleESP then
        Config.ESP.Enabled = not Config.ESP.Enabled
        print("ESP toggled:", Config.ESP.Enabled)
    elseif input.KeyCode == Config.Keybinds.FlyToggle then
        Config.Movement.FlyEnabled = not Config.Movement.FlyEnabled
        print("Fly toggled:", Config.Movement.FlyEnabled)
    end
end)

-- Main loop for Aimbot (simplified example)
RunService.Stepped:Connect(function()
    if Config.Aimbot.Enabled then
        local targetPart, targetPlayer = GetClosestTarget()
        if targetPart then
            -- Silent aim example: modify server raycast/mouse position
            -- This is game-specific and requires hooking the game's shooting logic
            -- Placeholder print:
            print("Aiming at:", targetPlayer.Name)
        end
    end
end)

-- Auto reload and weapon switch loops (simplified)
RunService.Heartbeat:Connect(function()
    if Config.Weapon.AutoSwitch then
        -- Call your SwitchToBestWeapon function here
    end
    if Config.Weapon.AutoReload then
        -- Call your AutoReload function here
    end
end)

-- Anti AFK (already shown in your snippet)

print("Universal exploit loaded.")
