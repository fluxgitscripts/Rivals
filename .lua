
repeat task.wait() until game:IsLoaded()

local function loadScript()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/fluxgitscripts/Rivals/refs/heads/main/.lua"))()
end

local success, err = pcall(loadScript)

if success then
    print("MoonHub erfolgreich geladen!")
else
    warn("Fehler beim Laden des Payloads: " .. tostring(err))
end

local OrionLib = loadstring(game:HttpGet('https://moon-hub.pages.dev/orion.lua'))()
local Window = OrionLib:MakeWindow({
    Name = "MoonHub - Rivals",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "OrionConfig",
    IntroEnabled = true,
    IntroText = "Loading MoonHub..."
})

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local SilentAimEnabled = false
local SilentAimWallCheck = false
local SilentAimAutoShoot = false
local SilentAimTeamCheck = false
local FOVRadius = 150
local targetPlayer = nil
local isLeftMouseDown = false
local isRightMouseDown = false
local autoClickConnection = nil

local TriggerbotEnabled = false
local TriggerbotDelay = 0.01
local lastTriggerTime = 0

local SpeedEnabled = false
local SpeedValue = 50
local NoclipEnabled = false
local FlyEnabled = false
local FlySpeed = 50
local flyParts = {}
local flyingConnection = nil

local Settings = {
    MaxDist = 2000,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    Visuals = { Names = false, Health = false },
    Skeleton = { Enabled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 2 },
}

local Cache = {}
local SkelDraws = {}
local Bones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"}, {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightFoot", "RightLowerLeg"}
}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Visible = false
FOVCircle.Filled = false
FOVCircle.Radius = FOVRadius

local BlatantState = {
    targetEntityName = "",
    teleportMode = "Instant",
    teleportKey = Enum.KeyCode.X,
    teleportHeight = 5,
    teleportDistance = 5,
    entityCache = {},
    entityNameMap = {},
    targetESP = false,
    autoTeleport = false,
    autoTeleportInterval = 3,
    lastAutoTeleportTime = 0
}
local espObjects = {}
local displayNameCache = {}

local function isVisible(targetPart)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Head") then return false end 
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, targetPart.Parent}
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
    local raycastResult = workspace:Raycast(origin, direction, params)
    return raycastResult == nil
end

local function isLobbyVisible()
    local success, visible = pcall(function()
        local mainGui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
        return mainGui.MainFrame.Lobby.Currency.Visible == true
    end)
    return success and visible
end

local function getClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDistance = FOVRadius
    local mousePosition = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            
            if SilentAimTeamCheck and player.Team == LocalPlayer.Team then
                continue
            end

            local head = player.Character.Head
            local headPosition, onScreen = Camera:WorldToViewportPoint(head.Position)

            if onScreen then
                if SilentAimWallCheck and not isVisible(head) then
                    continue
                end

                local screenPosition = Vector2.new(headPosition.X, headPosition.Y)
                local distance = (screenPosition - mousePosition).Magnitude

                if distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return closestPlayer
end
local function lockCameraToHead()
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") then
        local head = targetPlayer.Character.Head
        local headPosition = Camera:WorldToViewportPoint(head.Position)
        if headPosition.Z > 0 then
            local cameraPosition = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(cameraPosition, head.Position)
        end
    end
end

local function autoClick()
    if autoClickConnection then
        autoClickConnection:Disconnect()
        autoClickConnection = nil
    end
    
    autoClickConnection = RunService.Heartbeat:Connect(function()
        local shouldShoot = (isLeftMouseDown or isRightMouseDown)

        local maxDistance = AutoShootMaxDist or 500

        if SilentAimAutoShoot and targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            
            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude

            if dist <= maxDistance then
                shouldShoot = true
            end
        end

        if shouldShoot then
            if not isLobbyVisible() then
                mouse1click()
            end
        else
            -- Verbindung sauber trennen
            if autoClickConnection then
                autoClickConnection:Disconnect()
                autoClickConnection = nil
            end
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, isProcessed)
    if isProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isLeftMouseDown = true
        autoClick()
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseDown = true
        autoClick()
    end
end)

UserInputService.InputEnded:Connect(function(input, isProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isLeftMouseDown = false
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseDown = false
    end
end)

local function GetHealthColor(hum)
    local hp = hum.Health
    local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
    local p = math.clamp(hp / maxHp, 0, 1)
    return Color3.new(p < 0.5 and 1 or 2*(1-p), p > 0.5 and 1 or 2*p, 0)
end

local function CreateLabel(name, parent, color, size)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Font = Settings.Font
    label.TextSize = size or Settings.TextSize or 16
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.RichText = true
    label.Visible = false
    label.Parent = parent
    return label
end

local function CreateSkeleton(player)
    if player == LocalPlayer or SkelDraws[player] then return end
    local lines = {}
    for i = 1, #Bones do
        local line = Drawing.new("Line")
        line.Thickness = Settings.Skeleton.Thickness
        line.Color = Settings.Skeleton.Color
        line.Transparency = 1
        line.Visible = false
        table.insert(lines, line)
    end
    SkelDraws[player] = lines
end

local function UpdateSkeleton()
    for player, lines in pairs(SkelDraws) do
        local char = player.Character
        if char and Settings.Skeleton.Enabled and player.Parent ~= nil then
            for i, bonePair in ipairs(Bones) do
                local p1, p2 = char:FindFirstChild(bonePair[1]), char:FindFirstChild(bonePair[2])
                local line = lines[i]
                if p1 and p2 then
                    local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
                    local v2, on2 = Camera:WorldToViewportPoint(p2.Position)
                    if on1 and on2 and v1.Z > 0 and v2.Z > 0 then
                        line.From = Vector2.new(v1.X, v1.Y)
                        line.To = Vector2.new(v2.X, v2.Y)
                        line.Color = Settings.Skeleton.Color
                        -- Diese Zeile ist entscheidend:
                        line.Thickness = Settings.Skeleton.Thickness 
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, l in pairs(lines) do l.Visible = false end
        end
    end
end

local function AddESP(player)
    if Cache[player] or player == LocalPlayer then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_" .. player.Name
    bb.Size = UDim2.new(0, 200, 0, 45)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.Enabled = false

    local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if success and coreGui then
        bb.Parent = coreGui
    else
        bb.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local frame = Instance.new("Frame", bb)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout", frame)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)

    Cache[player] = {
        Gui = bb,
        Labels = {
            Name = CreateLabel("1", frame, Color3.fromRGB(255, 255, 255)),
            HP = CreateLabel("2", frame, Color3.fromRGB(255, 255, 255)),
        },
    }
end

local function UpdateESP()
    local myRoot = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character.PrimaryPart)
    
    for player, data in pairs(Cache) do
        if not data.Gui or not data.Gui.Parent then
            Cache[player] = nil
            AddESP(player)
            continue
        end

        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChild("Humanoid")
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)

        if head and root and hum and myRoot and hum.Health > 0 then
            local dist = (root.Position - myRoot.Position).Magnitude
            if dist < Settings.MaxDist then
                data.Gui.Adornee = head
                data.Gui.Enabled = true

                -- Name ESP mit Font-Support
                data.Labels.Name.Visible = Settings.Visuals.Names
                data.Labels.Name.Font = Settings.Font -- Zeile hinzugefügt
                if Settings.Visuals.Names then
                    data.Labels.Name.Text = player.DisplayName
                end

                -- Health ESP mit Font-Support
                data.Labels.HP.Visible = Settings.Visuals.Health
                data.Labels.HP.Font = Settings.Font -- Zeile hinzugefügt
                if Settings.Visuals.Health then
                    local c = GetHealthColor(hum)
                    data.Labels.HP.Text = string.format(
                        "<font color='rgb(%d,%d,%d)'>[%d HP]</font>",
                        math.floor(c.R*255),
                        math.floor(c.G*255),
                        math.floor(c.B*255),
                        math.floor(hum.Health)
                    )
                end
            else
                data.Gui.Enabled = false
            end
        else
            data.Gui.Enabled = false
        end
    end
end

local function formatPlayerName(player)
    local userId = player.UserId
    if not displayNameCache[userId] then
        displayNameCache[userId] = player.DisplayName or player.Name
    end
    local displayName = displayNameCache[userId]
    local userName = player.Name
    return displayName ~= userName and displayName .. " @" .. userName or displayName
end

local function getOriginalUsername(formattedName)
    return formattedName:match("@(.+)$") or formattedName
end

local function getEntityList()
    local entityList = {}
    local nameMap = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            pcall(function()
                local character = player.Character
                if character and character:FindFirstChild("Humanoid") then
                    local formattedName = formatPlayerName(player)
                    table.insert(entityList, formattedName)
                    nameMap[formattedName] = player.Name
                    BlatantState.entityCache[player.Name] = character
                end
            end)
        end
    end
    BlatantState.entityNameMap = nameMap
    return entityList
end

local function findTargetEntity()
    if BlatantState.targetEntityName == "" then return nil end
    if BlatantState.entityCache[BlatantState.targetEntityName] then
        local cached = BlatantState.entityCache[BlatantState.targetEntityName]
        if cached.Parent then return cached end
    end
    local targetPlayerObj = Players:FindFirstChild(BlatantState.targetEntityName)
    local character = targetPlayerObj and targetPlayerObj.Character or nil
    if character then BlatantState.entityCache[BlatantState.targetEntityName] = character end
    return character
end

local function getPrimaryPart(entity)
    if not entity then return nil end
    local success, primaryPart = pcall(function()
        return entity:FindFirstChild("HumanoidRootPart") or entity.PrimaryPart
    end)
    return success and primaryPart or nil
end

local function teleportToTarget()
    local targetEntity = findTargetEntity()
    if not targetEntity then return end
    local targetPart = getPrimaryPart(targetEntity)
    if not targetPart then return end
    local character = LocalPlayer.Character
    if not character then return end
    local primaryPart = getPrimaryPart(character)
    if not primaryPart then return end
    local targetPos = targetPart.Position
    if BlatantState.teleportMode == "Instant" then
        primaryPart.CFrame = CFrame.new(targetPos + Vector3.new(0, BlatantState.teleportHeight, 0))
    elseif BlatantState.teleportMode == "Behind" then
        primaryPart.CFrame = targetPart.CFrame * CFrame.new(0, BlatantState.teleportHeight, BlatantState.teleportDistance)
    elseif BlatantState.teleportMode == "Smooth" then
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(primaryPart, tweenInfo, {
            CFrame = CFrame.new(targetPos + Vector3.new(0, BlatantState.teleportHeight, 0))
        })
        tween:Play()
    end
end

local function clearTargetESP()
    for _, obj in pairs(espObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    espObjects = {}
end

local function updateTargetESP()
    clearTargetESP()
    if not BlatantState.targetESP then return end
    local targetEntity = findTargetEntity()
    if not targetEntity then return end
    pcall(function()
        local highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Adornee = targetEntity
        highlight.Parent = targetEntity
        table.insert(espObjects, highlight)
    end)
end

local MainTab = Window:MakeTab({Name = "Main", Icon = "rbxassetid://117875071229221"})
local SilentAimTab = Window:MakeTab({Name = "Silent Aim", Icon = "rbxassetid://10709818534"})
local TriggerTab = Window:MakeTab({Name = "Triggerbot", Icon = "rbxassetid://74133076168703"})
local VisualsTab = Window:MakeTab({Name = "Visuals", Icon = "rbxassetid://140499484856973"})
local MovementTab = Window:MakeTab({Name = "Movement", Icon = "rbxassetid://117259180607823"})
local BlatantTab = Window:MakeTab({Name = "Blatant", Icon = "rbxassetid://10653372143"})
local LightingTab = Window:MakeTab({Name = "Lighting", Icon = "rbxassetid://11780984626"})
local SpoofTab = Window:MakeTab({Name = "Spoof Device", Icon = "rbxassetid://76562583558887"})
local MiscTab = Window:MakeTab({Name = "Misc", Icon = "rbxassetid://10734950309"})

MainTab:AddSection({ Name = "Game Information" })
MainTab:AddParagraph("Game Information","Game Name: Rivals\nGame ID: "..game.GameId)
MainTab:AddSection({ Name = "MoonHub Community" })
MainTab:AddParagraph("MoonHub Discord.","Join our Discord.")

MainTab:AddButton({
    Name = "Join Discord",
    Callback = function()
        local success = pcall(function()
            if request then
                request({
                    Url = "http://127.0.0.1:6463/rpc?v=1",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json", ["Origin"] = "https://discord.com" },
                    Body = game:GetService("HttpService"):JSONEncode({
                        cmd = "INVITE_BROWSER",
                        args = { code = "moon-hub" },
                        nonce = tostring(math.random(1, 1000000))
                    })
                })
            end
        end)
        if not success then setclipboard("https://discord.gg/moon-hub") end
    end
})

local Sec = MainTab:AddSection({Name = "Appearance"})
Sec:AddThemeDropdown()
Sec:AddParticleDropdown()

SilentAimTab:AddSection({Name = "Silent Aim"})
SilentAimTab:AddParagraph("Important!", "Based on source mechanics: Camera manipulation requires specific fire handling.")
SilentAimTab:AddToggle({
    Name = "Enable Silent Aim",
    Default = false,
    Callback = function(v) 
        SilentAimEnabled = v 
        FOVCircle.Visible = v
    end
})
SilentAimTab:AddToggle({
    Name = "Wall Check",
    Default = false,
    Callback = function(v) SilentAimWallCheck = v end
})
SilentAimTab:AddToggle({
    Name = "Auto Shoot",
    Default = false,
    Callback = function(v) 
        SilentAimAutoShoot = v 
        if v then autoClick() end
    end
})

SilentAimTab:AddToggle({
    Name = "Team Check",
    Default = false,
    Callback = function(v) SilentAimTeamCheck = v end
})

SilentAimTab:AddSection({
    Name = "Settings"
})
SilentAimTab:AddSlider({
    Name = "FOV Size",
    Min = 50, Max = 800, Default = 150,
    Color = Color3.fromRGB(137, 207, 240),
    Callback = function(v) 
        FOVRadius = v 
        FOVCircle.Radius = v
    end
})

local AutoShootMaxDist = 500 

SilentAimTab:AddSlider({
    Name = "Auto Shoot Max Distance",
    Min = 10,
    Max = 2500,
    Default = 500,
    Color = Color3.fromRGB(255, 100, 100),
    Increment = 10,
    Suffix = " Studs",
    Callback = function(Value)
        AutoShootMaxDist = Value
    end
})

TriggerTab:AddSection({Name = "Auto-Fire"})
TriggerTab:AddToggle({
    Name = "Enable Triggerbot",
    Default = false,
    Callback = function(v) TriggerbotEnabled = v end
})
TriggerTab:AddSlider({
    Name = "Click Delay",
    Min = 0, Max = 1, Default = 0.01, Increment = 0.01,
    Color = Color3.fromRGB(137, 207, 240),
    Callback = function(v) TriggerbotDelay = v end
})

VisualsTab:AddSection({Name = "Player ESP"})
VisualsTab:AddToggle({ Name = "Show Names", Default = false, Callback = function(v) Settings.Visuals.Names = v end })
VisualsTab:AddToggle({ Name = "Show Health", Default = false, Callback = function(v) Settings.Visuals.Health = v end })
VisualsTab:AddToggle({ Name = "Show Skeleton", Default = false, Callback = function(v) Settings.Skeleton.Enabled = v end })
VisualsTab:AddSection({
    Name = "Settings"
})
VisualsTab:AddColorpicker({ Name = "Skeleton Color", Default = Color3.new(1,1,1), Callback = function(v) Settings.Skeleton.Color = v end })
VisualsTab:AddSlider({
    Name = "ESP Max Distance",
    Min = 100,
    Max = 5000,
    Default = 2000,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 50,
    ValueName = "Studs",
    Callback = function(Value)
        Settings.MaxDist = Value
    end    
})

VisualsTab:AddSlider({
    Name = "Skeleton Thickness",
    Min = 1,
    Max = 5,
    Default = 2,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "px",
    Callback = function(Value)
        Settings.Skeleton.Thickness = Value
    end    
})

VisualsTab:AddDropdown({
    Name = "ESP Font",
    Default = "GothamBold",
    Options = {"Arial", "SourceSans", "GothamBold", "Courier", "Arcade"},
    Callback = function(Value)
        Settings.Font = Enum.Font[Value]
    end
})

MovementTab:AddSection({Name = "Walkspeed"})
MovementTab:AddToggle({ Name = "Enable Walkspeed", Default = false, Callback = function(v) SpeedEnabled = v end })
MovementTab:AddSlider({ Name = "Speed Value", Min = 10, Max = 300, Default = 50, Color = Color3.fromRGB(137, 207, 240), Callback = function(v) SpeedValue = v end })
MovementTab:AddSection({Name = "Abilities"})
MovementTab:AddToggle({ Name = "Noclip", Default = false, Callback = function(v) NoclipEnabled = v end })
MovementTab:AddToggle({
    Name = "Fly",
    Default = false,
    Callback = function(v)
        FlyEnabled = v
        local character = LocalPlayer.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if v then
            for _, p in pairs(flyParts) do if p and p.Parent then p:Destroy() end end
            flyParts = {}
            local gyro = Instance.new("BodyGyro")
            gyro.P = 9000; gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); gyro.CFrame = hrp.CFrame; gyro.Parent = hrp
            table.insert(flyParts, gyro)
            local vel = Instance.new("BodyVelocity")
            vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge); vel.P = 1250; vel.Velocity = Vector3.new(0,0,0); vel.Parent = hrp
            table.insert(flyParts, vel)
            if flyingConnection then flyingConnection:Disconnect() end
            flyingConnection = RunService.Heartbeat:Connect(function()
                if not FlyEnabled then return end
                if gyro and gyro.Parent then gyro.CFrame = CFrame.new(hrp.Position, hrp.Position + Camera.CFrame.LookVector) end
                local moveDir = Vector3.new(0,0,0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
                if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end
                if vel and vel.Parent then vel.Velocity = moveDir * FlySpeed end
            end)
        else
            if flyingConnection then flyingConnection:Disconnect() flyingConnection = nil end
            for _, p in pairs(flyParts) do if p and p.Parent then p:Destroy() end end
            flyParts = {}
        end
    end
})

local EntityDropdown
BlatantTab:AddSection({Name = "Target"})
EntityDropdown = BlatantTab:AddDropdown({
    Name = "Choose Target",
    Default = "None",
    Options = getEntityList(),
    Callback = function(v)
        BlatantState.targetEntityName = BlatantState.entityNameMap[v] or getOriginalUsername(v)
        updateTargetESP()
    end
})
BlatantTab:AddButton({ Name = "Refresh List", Callback = function() EntityDropdown:Refresh(getEntityList(), true) end })
BlatantTab:AddSection({Name = "Teleport"})
BlatantTab:AddDropdown({ Name = "Teleport Mode", Options = {"Instant", "Smooth", "Behind"}, Default = "Instant", Callback = function(v) BlatantState.teleportMode = v end })
BlatantTab:AddButton({ Name = "Teleport to Target", Callback = function() teleportToTarget() end })
BlatantTab:AddToggle({ Name = "Target ESP", Default = false, Callback = function(v) BlatantState.targetESP = v; updateTargetESP() end })

local TimeControlEnabled = false
local SliderValue = Lighting.ClockTime
local BrightnessValue = Lighting.Brightness
local AmbientColorEnabled = false
local SelectedColor = Lighting.Ambient
local RainbowModeEnabled = false
local RainbowSpeed = 1
local OutdoorAmbientEnabled = false
local SelectedOutdoorColor = Lighting.OutdoorAmbient

LightingTab:AddSection({Name = "Time Control"})
LightingTab:AddToggle({ Name = "Enable Time Control", Default = false, Callback = function(v) TimeControlEnabled = v end })
LightingTab:AddSlider({ Name = "Time of Day", Min = 0, Max = 24, Default = Lighting.ClockTime, Color = Color3.fromRGB(137, 207, 240), Callback = function(v) SliderValue = v; if TimeControlEnabled then Lighting.ClockTime = v end end })

local rainbowStart = tick()
task.spawn(function()
    while true do
        task.wait(0.01)
        if TimeControlEnabled then Lighting.ClockTime = SliderValue end
        Lighting.Brightness = BrightnessValue
        if RainbowModeEnabled then
            Lighting.Ambient = Color3.fromHSV((tick() - rainbowStart) * RainbowSpeed % 1, 1, 1)
        elseif AmbientColorEnabled then
            Lighting.Ambient = SelectedColor
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if FOVCircle.Visible then
        FOVCircle.Position = UserInputService:GetMouseLocation()
    end

    if SilentAimEnabled and not isLobbyVisible() then
        targetPlayer = getClosestPlayerToMouse()
        if targetPlayer then
            lockCameraToHead()
            if SilentAimAutoShoot and not autoClickConnection then
                autoClick()
            end
        end
    else
        targetPlayer = nil
    end

    if TriggerbotEnabled and Mouse.Target then
        local p = Players:GetPlayerFromCharacter(Mouse.Target.Parent) or Players:GetPlayerFromCharacter(Mouse.Target.Parent.Parent)
        if p and p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local now = tick()
            if now - lastTriggerTime >= TriggerbotDelay then
                lastTriggerTime = now
                mouse1click()
            end
        end
    end

    if SpeedEnabled and LocalPlayer.Character then
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if hum and hrp and hum.MoveDirection.Magnitude > 0 then
        local targetVelocity = hum.MoveDirection * SpeedValue
        
        hrp.AssemblyLinearVelocity = Vector3.new(
            targetVelocity.X, 
            hrp.AssemblyLinearVelocity.Y, 
            targetVelocity.Z
        )
    end
end

    if NoclipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    
    if BlatantState.autoTeleport and BlatantState.targetEntityName ~= "" then
        local now = tick()
        if now - BlatantState.lastAutoTeleportTime >= BlatantState.autoTeleportInterval then
            BlatantState.lastAutoTeleportTime = now
            pcall(teleportToTarget)
        end
    end

    pcall(UpdateESP)
end)

RunService.RenderStepped:Connect(function()
    pcall(UpdateSkeleton)
end)

for _, p in pairs(Players:GetPlayers()) do AddESP(p); CreateSkeleton(p) end

Players.PlayerAdded:Connect(function(p)
    AddESP(p); CreateSkeleton(p)
    task.wait(2)
    pcall(function() EntityDropdown:Refresh(getEntityList(), true) end)
end)

Players.PlayerRemoving:Connect(function(p)
    if Cache[p] then pcall(function() Cache[p].Gui:Destroy() end); Cache[p] = nil end
    task.wait(0.5)
    pcall(function() EntityDropdown:Refresh(getEntityList(), true) end)
end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hookfn = hookfunction or replaceclosure
local getconnections = getconnections or get_signal_cons
local getgc = getgc or get_garbage_collection

local function runBypass()
    if not hookfn or not getgc then 
        warn("Executor unterstützt kein Hooking/GC - Bypass übersprungen")
        return 
    end
    
    pcall(function()
        for _, v in pairs(getgc(true)) do
            if typeof(v) == "function" then
                local ok, src = pcall(function() return debug.info(v, "s") end)
                if ok and type(src) == "string" and string.find(src, "AnalyticsPipelineController") then
                    hookfn(v, newcclosure(function(...) return task.wait(9e9) end))
                end
            end
        end
        
        local remote = ReplicatedStorage:WaitForChild("Remotes", 5):WaitForChild("AnalyticsPipeline", 5):WaitForChild("RemoteEvent", 5)
        if remote and getconnections then
            for _, conn in pairs(getconnections(remote.OnClientEvent)) do
                if conn.Function then hookfn(conn.Function, newcclosure(function(...) end)) end
            end
        end

        local oldkick
        oldkick = hookfn(LocalPlayer.Kick, newcclosure(function(self, ...)
            if self == LocalPlayer then return end
            return oldkick(self, ...)
        end))
    end)
end

local function doDeviceSpoof(wantedDevice)
    local ok, Remotes = pcall(function() return game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 2) end)
    if ok and Remotes then
        local fighterPath = Remotes:FindFirstChild("Replication") and Remotes.Replication:FindFirstChild("Fighter")
        if fighterPath and fighterPath:FindFirstChild("SetControls") then
            fighterPath.SetControls:FireServer(wantedDevice)
        else
            warn("Path 'SetControls' not found are you currently in a match?")
        end
    end
end

local SelectedDevice = "MouseKeyboard"

SpoofTab:AddSection({
    Name = "Device & Anticheat"
})

SpoofTab:AddDropdown({
    Name = "Target Device",
    Default = "MouseKeyboard",
    Options = {"Mouse Keyboard", "Phone", "Controller","VR"},
    Callback = function(Value)
        SelectedDevice = Value
    end    
})

SpoofTab:AddButton({
    Name = "Spoof Device",
    Callback = function()
        doDeviceSpoof(SelectedDevice)
    end    
})

SpoofTab:AddToggle({
    Name = "Auto-Spoof on Respawn",
    Default = true,
    Callback = function(Value)
        _G.AutoSpoof = Value
    end    
})

local TargetStreakValue = "0"
local LP = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")

local function applyStreakSpoof()
    local num = tostring(TargetStreakValue) or "0"
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local nametag = hrp and hrp:FindFirstChild("NametagGui")
    
    if nametag then
        local elements = nametag:FindFirstChild("Elements")
        local data = elements and elements:FindFirstChild("Data")
        local streakIcon = data and data:FindFirstChild("Streak")
        local valueLabel = streakIcon and streakIcon:FindFirstChild("Value")

        if streakIcon and valueLabel then
            local targetPos = UDim2.new(0.5, -58, 0.5, 0)
            
            if valueLabel.Text ~= num then
                valueLabel.Text = num
            end
            
            if streakIcon.Position ~= targetPos then
                streakIcon.Position = targetPos
            end
            
            streakIcon.Visible = true
            valueLabel.Visible = true
        end
    end
end

SpoofTab:AddSection({
    Name = "Visual Win Streak Spoof"
})

SpoofTab:AddTextbox({
	Name = "Enter Win Streak",
	Default = "5",
	TextDisappear = false,
	Callback = function(Value)
		TargetStreakValue = Value
	end	  
})

SpoofTab:AddToggle({
    Name = "Lock Streak [MUST BE ON FOR STREAK]",
    Default = true,
    Callback = function(Value)
        _G.LockStreakVisuals = Value
    end    
})

RunService:BindToRenderStep("StreakLock", Enum.RenderPriority.Last.Value + 1, function()
    if _G.LockStreakVisuals and TargetStreakValue ~= "0" then
        pcall(applyStreakSpoof)
    end
end)

RunService.Heartbeat:Connect(function()
    if _G.LockStreakVisuals and TargetStreakValue ~= "0" then
        pcall(applyStreakSpoof)
    end
end)

LP.CharacterAdded:Connect(function(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if hrp then
        local nametag = hrp:WaitForChild("NametagGui", 10)
        local elements = nametag:WaitForChild("Elements", 5)
        local data = elements:WaitForChild("Data", 5)
        local streakIcon = data:WaitForChild("Streak", 5)
        
        streakIcon:GetPropertyChangedSignal("Position"):Connect(function()
            if _G.LockStreakVisuals and TargetStreakValue ~= "0" then
                streakIcon.Position = UDim2.new(0.5, -58, 0.5, 0)
            end
        end)
    end
end)

game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    if _G.AutoSpoof then
        task.wait(3)
        doDeviceSpoof(SelectedDevice)
    end
end)

MiscTab:AddSection({ Name = "Graphics" })

MiscTab:AddButton({
	Name = "FPS Booster",
	Callback = function()
		local g = game
		local w = g.workspace
		local l = g.Lighting
		local t = w:FindFirstChildOfClass("Terrain")
		t.WaterWaveSize = 0
		t.WaterWaveSpeed = 0
		t.WaterReflectance = 0
		t.WaterTransparency = 0
		l.GlobalShadows = false
		l.FogEnd = 9e9
		settings().Rendering.QualityLevel = 1
		for i, v in pairs(g:GetDescendants()) do
			if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("MeshPart") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
				v.Material = "Plastic"
				v.Reflectance = 0
			elseif v:IsA("Decal") then
				v.Transparency = 1
			elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
				v.Enabled = false
			end
		end
	end    
})

MiscTab:AddToggle({
	Name = "Fullbright",
	Default = false,
	Callback = function(Value)
		if Value then
			game:GetService("Lighting").Ambient = Color3.new(1, 1, 1)
			game:GetService("Lighting").ColorShift_Bottom = Color3.new(1, 1, 1)
			game:GetService("Lighting").ColorShift_Top = Color3.new(1, 1, 1)
		else
			game:GetService("Lighting").Ambient = Color3.new(0.5, 0.5, 0.5) -- Standardwert
		end
	end    
})

local TargetFOV = 90

MiscTab:AddSlider({
    Name = "Field of View",
    Min = 90,
    Max = 120,
    Default = 90,
    Color = Color3.fromRGB(137, 207, 240),
    Increment = 1,
    ValueName = "FOV",
    Callback = function(Value)
        TargetFOV = Value
    end    
})

game:GetService("RunService"):BindToRenderStep("FOV_Lock", Enum.RenderPriority.Camera.Value + 1, function()
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = TargetFOV
    end
end)

MiscTab:AddSection({ Name = "Server" })
MiscTab:AddButton({
	Name = "Rejoin Server",
	Callback = function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
	end    
})

MiscTab:AddButton({
	Name = "Server Hop",
	Callback = function()
		local Http = game:GetService("HttpService")
		local TPS = game:GetService("TeleportService")
		local Api = "https://games.roblox.com/v1/games/"
		local _id = game.PlaceId
		local _servers = Api.._id.."/servers/Public?sortOrder=Desc&limit=100"
		local function ListServers(cursor)
			local Raw = game:HttpGet(_servers .. ((cursor and "&cursor="..cursor) or ""))
			return Http:JSONDecode(Raw)
		end
		local Next;
		repeat
			local Servers = ListServers(Next)
			for i,v in pairs(Servers.data) do
				if v.playing < v.maxPlayers and v.id ~= game.JobId then
					TPS:TeleportToPlaceInstance(_id, v.id)
					break
				end
			end
			Next = Servers.nextPageCursor
		until not Next
	end    
})

OrionLib:Init()
