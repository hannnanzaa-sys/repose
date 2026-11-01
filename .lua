if not game:IsLoaded() then repeat wait() until game:IsLoaded() end

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer
local playerGui = LP:WaitForChild("PlayerGui")

local Perf = { ESP_Refresh = 0.5, Skill_Refresh = 0.02 }

-- ============================================================
-- 1. TELEPORT & FOLLOW
-- ============================================================
local selectedPlayer = nil
local isFollowing = false
local followThread = nil

local function TeleportToPlayer(targetName)
    local myChar = LP.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local targetPlayer = Players:FindFirstChild(targetName)
    if targetPlayer and targetPlayer.Character then
        local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0) end
    end
end

local function GetPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LP then table.insert(names, plr.Name) end end
    return names
end

-- ============================================================
-- 2. ESP SYSTEM
-- ============================================================
local ESP_Status = {Survivor = false, Killer = false, Pallets = false, Windows = false, Gens = false, Traps = false, Pumpkins = false}
local ESP_Colors = {Survivor = Color3.fromRGB(0, 255, 0), Killer = Color3.fromRGB(255, 0, 0), Pallets = Color3.fromRGB(0, 255, 255), Windows = Color3.fromRGB(255, 255, 0), Gens = Color3.fromRGB(150, 0, 255), Traps = Color3.fromRGB(255, 105, 180), Pumpkins = Color3.fromRGB(255, 140, 0)}
local ESP_Cache = {}

local function CreateHighlight(obj, color, name)
    if not obj then return end
    local hl = Instance.new("Highlight")
    hl.Name = "HANX_ESP_" .. name
    hl.Adornee = obj
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Parent = obj
    return hl
end

local function ClearESP()
    for obj, hl in pairs(ESP_Cache) do if hl and hl.Parent then hl:Destroy() end end
    ESP_Cache = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Highlight") and string.find(v.Name, "HANX_ESP_") then v:Destroy() end
    end
end

local function UpdateESP()
    for obj, hl in pairs(ESP_Cache) do
        if not obj.Parent then
            if ESP_Cache[obj] then ESP_Cache[obj]:Destroy(); ESP_Cache[obj] = nil end
        end
    end

    if ESP_Status.Survivor or ESP_Status.Killer then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local isKiller = plr.Team and plr.Team.Name:lower():find("killer")
                if (isKiller and ESP_Status.Killer) or (not isKiller and ESP_Status.Survivor) then
                    local color = isKiller and ESP_Colors.Killer or ESP_Colors.Survivor
                    local name = isKiller and "Killer" or "Survivor"
                    local expected = "HANX_ESP_" .. name
                    for _, child in ipairs(plr.Character:GetChildren()) do
                        if child:IsA("Highlight") and string.find(child.Name, "HANX_ESP_") and child.Name ~= expected then child:Destroy() end
                    end
                    if not plr.Character:FindFirstChild(expected) then CreateHighlight(plr.Character, color, name) end
                else
                    for _, child in ipairs(plr.Character:GetChildren()) do
                        if child:IsA("Highlight") and string.find(child.Name, "HANX_ESP_") then child:Destroy() end
                    end
                end
            end
        end
    end

    local map = workspace:FindFirstChild("Map")
    if map then
        for _, obj in ipairs(map:GetDescendants()) do
            local n = string.lower(obj.Name)
            local targetColor, typeName = nil, ""
            
            if n:find("pallet") and ESP_Status.Pallets then targetColor = ESP_Colors.Pallets; typeName = "Pallet"
            elseif n:find("window") and ESP_Status.Windows then targetColor = ESP_Colors.Windows; typeName = "Window"
            elseif n:find("generator") and ESP_Status.Gens then targetColor = ESP_Colors.Gens; typeName = "Gen"
            elseif (n:find("trap") or n:find("bear") or n:find("snare")) and ESP_Status.Traps then targetColor = ESP_Colors.Traps; typeName = "Trap"
            elseif (n:find("pumpkin") or n:find("labu")) and ESP_Status.Pumpkins then targetColor = ESP_Colors.Pumpkins; typeName = "Pumpkin"
            end

            if targetColor and (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("UnionOperation")) then
                if not ESP_Cache[obj] then ESP_Cache[obj] = CreateHighlight(obj, targetColor, typeName) end
            end
        end
    end
end

task.spawn(function() while task.wait(Perf.ESP_Refresh) do pcall(UpdateESP) end end)

-- ============================================================
-- 3. AUTO SKILL CHECK
-- ============================================================
local _G = _G or getgenv() or {}
if not _G.Ox then _G.Ox = {} end
_G.Ox.Auto = { SkillCheck = false, SkillCheckMode = "Normal" }
_G.Ox.State = _G.Ox.State or { busy = false }
_G.Ox.Connections = _G.Ox.Connections or { SkillHeartbeat = nil }

local function fn7()
    if _G.Ox.Connections.SkillHeartbeat then _G.Ox.Connections.SkillHeartbeat:Disconnect(); _G.Ox.Connections.SkillHeartbeat = nil end
    _G.Ox.Connections.SkillHeartbeat = RunService.RenderStepped:Connect(function()
        if not _G.Ox.Auto.SkillCheck or _G.Ox.State.busy then return end
        local skillCheckPromptGui = playerGui:FindFirstChild("SkillCheckPromptGui")
        if not skillCheckPromptGui then return end
        local check = skillCheckPromptGui:FindFirstChild("Check")
        if not check or not check.Visible then return end
        local line = check:FindFirstChild("Line")
        local goal = check:FindFirstChild("Goal")
        if not line or not goal then return end
        
        line.Rotation = goal.Rotation + 125
        _G.Ox.State.busy = true
        
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        
        local survivorMob = playerGui:FindFirstChild("Survivor-mob")
        local controls = survivorMob and survivorMob:FindFirstChild("Controls")
        local action = controls and (controls:FindFirstChild("action") or controls:FindFirstChild("check"))
        if action and action:IsA("GuiButton") then pcall(function() if firesignal then firesignal(action.MouseButton1Down); firesignal(action.MouseButton1Up) end end) end
        
        task.wait(0.5)
        _G.Ox.State.busy = false
    end)
end

-- ============================================================
-- 4. AUTO DROP PALLET (SURVIVOR)
-- ============================================================
local AutoPallet = { Enabled = false, Distance = 10, Cooldown = 2.5, LastDrop = 0, Thread = nil, UsedPallets = {} }

local function AP_IsSurvivorBusy(character)
    if not character then return true end
    if character:GetAttribute("Knocked") == true or character:GetAttribute("IsCarried") == true or character:GetAttribute("IsHooked") == true then return true end
    local check = character:FindFirstChild("CheckInterractable")
    if check then
        if check:GetAttribute("isVaulting") == true or check:GetAttribute("isRepairing") == true or check:GetAttribute("isUnhooking") == true or check:GetAttribute("isHealing") == true or check:GetAttribute("isSliding") == true then return true end
    end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return true end
    return false
end

local function AP_GetNearestKiller(myRoot)
    local nearest, nearestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Team and plr.Team.Name == "Killer" and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < nearestDist then nearestDist = dist; nearest = plr end
            end
        end
    end
    return nearest, nearestDist
end

local function AP_GetNearestPallet(myRoot)
    local map = workspace:FindFirstChild("Map")
    if not map then return nil, math.huge end
    local nearest, nearestDist = nil, math.huge
    for _, obj in ipairs(map:GetDescendants()) do
        if obj.Name == "PrimaryPartPallet" and obj:IsA("BasePart") then
            local parent = obj.Parent
            if parent then
                local dist = (obj.Position - myRoot.Position).Magnitude
                if dist < nearestDist then nearestDist = dist; nearest = {part = obj, model = parent} end
            end
        end
    end
    return nearest, nearestDist
end

local function AP_DropPallet(palletModel)
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if not remotes then return false end
    local dropEvent = nil
    for _, folderName in ipairs({"Pallet", "Window", "Mechanic", "Interact"}) do
        local folder = remotes:FindFirstChild(folderName)
        if folder then
            for _, eventName in ipairs({"PalletDropEvent", "DropPallet", "PalletEvent", "PalletDrop"}) do
                local ev = folder:FindFirstChild(eventName)
                if ev and ev:IsA("RemoteEvent") then dropEvent = ev; break end
            end
        end
        if dropEvent then break end
    end
    if not dropEvent then return false end
    local palletPoint = palletModel:FindFirstChild("PalletPoint") or palletModel:FindFirstChild("PalletPointSlide") or palletModel:FindFirstChildWhichIsA("BasePart")
    if not palletPoint then return false end
    pcall(function() dropEvent:FireServer(palletPoint) end)
    return true
end

local function AP_StartLoop()
    if AutoPallet.Thread then task.cancel(AutoPallet.Thread) end
    AutoPallet.UsedPallets = {}
    AutoPallet.Thread = task.spawn(function()
        while AutoPallet.Enabled do
            task.wait(0.2)
            if LP.Team and LP.Team.Name ~= "Survivors" then continue end
            if tick() - AutoPallet.LastDrop < AutoPallet.Cooldown then continue end
            pcall(function()
                local myChar = LP.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myRoot then return end
                if AP_IsSurvivorBusy(myChar) then return end
                local killer, killerDist = AP_GetNearestKiller(myRoot)
                if not killer or killerDist > AutoPallet.Distance then return end
                local pallet, palletDist = AP_GetNearestPallet(myRoot)
                if not pallet or palletDist > 14 then return end
                if AP_DropPallet(pallet.model) then AutoPallet.UsedPallets[pallet.model] = true; AutoPallet.LastDrop = tick() end
            end)
        end
    end)
end

local function AP_StopLoop()
    AutoPallet.Enabled = false
    if AutoPallet.Thread then task.cancel(AutoPallet.Thread); AutoPallet.Thread = nil end
    AutoPallet.UsedPallets = {}
end

-- ============================================================
-- 5. KILLER AIMBOT + AUTO M1
-- ============================================================
local KillerConfig = { Enabled = false, MaxDist = 12, Smoothness = 0.5, AutoM1 = false, Interval = 0.15, LastAttack = 0, POVCheck = true, Wallcheck = true, Highlight = nil, Conn = nil }
local KA_IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function KA_GetSurvivors()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Team and plr.Team.Name == "Survivors" and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 and plr.Character:GetAttribute("Knocked") ~= true and plr.Character:GetAttribute("IsHooked") ~= true then
                table.insert(list, {player = plr, hum = hum, root = root})
            end
        end
    end
    return list
end

local function KA_HasLOS(fromPos, targetPart)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LP.Character, targetPart.Parent}
    local dir = targetPart.Position - fromPos
    if dir.Magnitude < 0.1 then return true end
    return workspace:Raycast(fromPos, dir.Unit * dir.Magnitude, rp) == nil
end

local function KA_GetTarget()
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local best, bestDist = nil, math.huge
    for _, entry in ipairs(KA_GetSurvivors()) do
        local dist = (entry.root.Position - myRoot.Position).Magnitude
        if dist <= KillerConfig.MaxDist and dist < bestDist then bestDist = dist; best = entry end
    end
    return best
end

local function KA_IsInPOV(myRoot, targetRoot)
    if not KillerConfig.POVCheck then return true end
    local toTarget = targetRoot.Position - myRoot.Position
    local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
    if flat.Magnitude < 0.1 then return true end
    local look = KA_IsMobile and (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or myRoot.CFrame.LookVector) or myRoot.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.1 then return false end
    return flatLook.Unit:Dot(flat.Unit) >= 0.4
end

local function KA_FireAttack()
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local killers = remotes and remotes:FindFirstChild("Killers")
    if killers then
        for _, name in ipairs({"BasicAttack", "Attack", "M1", "BasicAttackEvent", "Melee"}) do
            local r = killers:FindFirstChild(name)
            if r and r:IsA("RemoteEvent") then pcall(function() r:FireServer() end); return end
        end
    end
    if KA_IsMobile then
        local pg = LP:FindFirstChild("PlayerGui")
        for _, child in ipairs(pg:GetChildren()) do
            if child:IsA("ScreenGui") and string.sub(child.Name, -4) == "-mob" and child.Name ~= "Survivor-mob" then
                local attack = child:FindFirstChild("Controls") and (child.Controls:FindFirstChild("attack") or child.Controls:FindFirstChild("Gui-mob"))
                if attack and attack.Visible and firesignal then pcall(function() firesignal(attack.MouseButton1Down); task.wait(0.02); firesignal(attack.MouseButton1Up) end); return end
            end
        end
    else
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    end
end

local function KA_StartLoop()
    if KillerConfig.Conn then KillerConfig.Conn:Disconnect() end
    KillerConfig.Conn = RunService.Heartbeat:Connect(function()
        if not KillerConfig.Enabled then return end
        local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local target = KA_GetTarget()
        if not target then if KillerConfig.Highlight then KillerConfig.Highlight.Adornee = nil end; return end

        if KillerConfig.Highlight then KillerConfig.Highlight.Adornee = target.player.Character else
            local hl = Instance.new("Highlight"); hl.Name = "HANX_Aim"; hl.FillColor = Color3.fromRGB(255, 50, 50); hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.FillTransparency = 0.5; hl.Adornee = target.player.Character; hl.Parent = game:GetService("CoreGui"); KillerConfig.Highlight = hl
        end
        local cam = workspace.CurrentCamera
        if cam then cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, target.root.Position), KillerConfig.Smoothness) end
        myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.new(myRoot.Position, Vector3.new(target.root.Position.X, myRoot.Position.Y, target.root.Position.Z)), KillerConfig.Smoothness)

        if KillerConfig.AutoM1 and tick() - KillerConfig.LastAttack >= KillerConfig.Interval then
            if KA_IsInPOV(myRoot, target.root) and (not KillerConfig.Wallcheck or KA_HasLOS(myRoot.Position, target.root)) then
                KillerConfig.LastAttack = tick()
                KA_FireAttack()
            end
        end
    end)
end

local function KA_StopLoop()
    if KillerConfig.Conn then KillerConfig.Conn:Disconnect(); KillerConfig.Conn = nil end
    if KillerConfig.Highlight then KillerConfig.Highlight:Destroy(); KillerConfig.Highlight = nil end
end

-- ============================================================
-- HANX HUB AUTO PARRY
-- ============================================================

-- Menggunakan Players, RunService, UserInputService,
-- VirtualInputManager, LP yang sudah ada di HANX HUB.

local AutoParry = {
    Enabled = false,
    Mode = "PC",
    Range = 18,
    Delay = 0.08,
    Cooldown = 0.35,
    KeyIndex = 1,
    KillerOnly = true,
    Facing = true,
    LastParry = 0,
    Count = 0,
    Seen = setmetatable({}, {__mode = "k"}),
    Connection = nil
}

local AP_Keys = {
    {"F", Enum.KeyCode.F},
    {"Q", Enum.KeyCode.Q},
    {"E", Enum.KeyCode.E},
    {"R", Enum.KeyCode.R}
}

local function AP_Press()
    if not AutoParry.Enabled then return end
    print("[HANX HUB] AP_Press terpanggil! Mode:", AutoParry.Mode)

    if AutoParry.Mode == "PC" then
        -- PC TIDAK DIUBAH
        local key = AP_Keys[AutoParry.KeyIndex][2]

        pcall(function()
            VirtualInputManager:SendKeyEvent(true, key, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)

    elseif AutoParry.Mode == "HP" then
        local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

for _, v in ipairs(pg:GetDescendants()) do
    if v:IsA("ImageButton") or v:IsA("TextButton") then
        print(
            "NAME:", v.Name,
            "| PATH:", v:GetFullName(),
            "| IMAGE:", v:IsA("ImageButton") and v.Image or "-",
            "| TEXT:", v:IsA("TextButton") and v.Text or "-"
        )
    end
end
        local pg = LP:FindFirstChild("PlayerGui")
        local mobileGui = pg and pg:FindFirstChild("Survivor-mob")
        local controls = mobileGui and mobileGui:FindFirstChild("Controls")
        local guiMob = controls and controls:FindFirstChild("Gui-mob")
        local back = guiMob and guiMob:FindFirstChild("back", true)

        if back and back:IsA("GuiButton") and back.Visible then
            pcall(function()
                if firesignal then
                    firesignal(back.MouseButton1Down)
                    task.wait(0.05)
                    firesignal(back.MouseButton1Up)
                else
                    back:Activate()
                end
            end)
        end
    end

    AutoParry.Count = AutoParry.Count + 1
end

local function AP_IsAttack(track)
    if track.Looped then return false end

    local priority = track.Priority

    return priority == Enum.AnimationPriority.Action
        or priority == Enum.AnimationPriority.Action2
        or priority == Enum.AnimationPriority.Action3
        or priority == Enum.AnimationPriority.Action4
end

local function AP_GoodTarget(player)
    if not AutoParry.KillerOnly then return true end

    local teamName = player.Team and player.Team.Name:lower() or ""

    if teamName:find("surv") then return false end
    if player.Team and LP.Team and player.Team == LP.Team then
        return false
    end

    return true
end

local function AP_Start()
    if AutoParry.Connection then
        AutoParry.Connection:Disconnect()
    end

    AutoParry.Connection = RunService.Heartbeat:Connect(function()
        if not AutoParry.Enabled then return end

        local character = LP.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP and player.Character then
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

                if targetRoot and humanoid then
                    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                        if not AutoParry.Seen[track] then
                            AutoParry.Seen[track] = true

                            if track.TimePosition <= 0.3
                                and AP_IsAttack(track)
                                and AP_GoodTarget(player)
                                and (targetRoot.Position - root.Position).Magnitude <= AutoParry.Range
                                and os.clock() - AutoParry.LastParry >= AutoParry.Cooldown then

                                local facing = true

                                if AutoParry.Facing then
                                    local direction = root.Position - targetRoot.Position
                                    direction = Vector3.new(direction.X, 0, direction.Z)

                                    if direction.Magnitude > 0.1 then
                                        facing = targetRoot.CFrame.LookVector:Dot(direction.Unit) > 0.35
                                    end
                                end

                                if facing then
                                    AutoParry.LastParry = os.clock()
                                    task.delay(AutoParry.Delay, AP_Press)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function AP_Stop()
    AutoParry.Enabled = false

    if AutoParry.Connection then
        AutoParry.Connection:Disconnect()
        AutoParry.Connection = nil
    end
end

-- HANX HUB ANTI FOG
local AntiFog = false
local FogBackup = {}

local function SetAntiFog(state)
    AntiFog = state

    if state then
        FogBackup.FogStart = Lighting.FogStart
        FogBackup.FogEnd = Lighting.FogEnd

        Lighting.FogStart = 0
        Lighting.FogEnd = 1000000

        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("Atmosphere") then
                if FogBackup[v] == nil then
                    FogBackup[v] = {
                        Density = v.Density,
                        Haze = v.Haze,
                        Glare = v.Glare
                    }
                end

                v.Density = 0
                v.Haze = 0
                v.Glare = 0
            end
        end
    else
        if FogBackup.FogStart then
            Lighting.FogStart = FogBackup.FogStart
            Lighting.FogEnd = FogBackup.FogEnd
        end

        for obj, data in pairs(FogBackup) do
            if typeof(obj) == "Instance" and obj.Parent then
                obj.Density = data.Density
                obj.Haze = data.Haze
                obj.Glare = data.Glare
            end
        end

        table.clear(FogBackup)
    end
end

-- ============================================================
-- 6. UI FRAMEWORK
-- ============================================================
local old = CoreGui:FindFirstChild("HANX_HUB_UI") if old then old:Destroy() end
local oldF = CoreGui:FindFirstChild("HANX_HUB_Logo") if oldF then oldF:Destroy() end
local oldS = CoreGui:FindFirstChild("HANX_HUB_Splash") if oldS then oldS:Destroy() end
local oldW = CoreGui:FindFirstChild("HANX_Watermark") if oldW then oldW:Destroy() end

local Theme = {
    Bg = Color3.fromRGB(12, 12, 16), Sidebar = Color3.fromRGB(18, 18, 24), Card = Color3.fromRGB(24, 24, 32),
    CardHover = Color3.fromRGB(32, 32, 42), Text = Color3.fromRGB(255, 255, 255), SubText = Color3.fromRGB(150, 150, 160),
    Neon = Color3.fromRGB(180, 80, 255), ToggleOff = Color3.fromRGB(45, 45, 55)
}

local function corner(inst, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst end
local function addStroke(inst, color, thickness, transparency) local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness or 1; s.Transparency = transparency or 0; s.Parent = inst return s end

local Screen = Instance.new("ScreenGui"); Screen.Name = "HANX_HUB_UI"; Screen.ResetOnSpawn = false; Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; Screen.IgnoreGuiInset = true; Screen.Enabled = false; Screen.Parent = CoreGui
local Window = Instance.new("Frame"); Window.Size = UDim2.fromOffset(580, 420); Window.Position = UDim2.new(0.5, -290, 0.5, -210); Window.BackgroundColor3 = Theme.Bg; Window.BorderSizePixel = 0; Window.Active = true; Window.ClipsDescendants = true; Window.Parent = Screen; corner(Window, 12); addStroke(Window, Theme.Neon, 1.5, 0.5)
local TopBar = Instance.new("Frame"); TopBar.Size = UDim2.new(1, 0, 0, 45); TopBar.BackgroundTransparency = 1; TopBar.Parent = Window
local Title = Instance.new("TextLabel"); Title.Size = UDim2.new(1, -100, 1, 0); Title.Position = UDim2.fromOffset(20, 0); Title.BackgroundTransparency = 1; Title.Text = "HANX HUB"; Title.TextColor3 = Theme.Neon; Title.Font = Enum.Font.GothamBlack; Title.TextSize = 16; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.Parent = TopBar
local Subtitle = Instance.new("TextLabel"); Subtitle.Size = UDim2.new(1, -100, 1, 0); Subtitle.Position = UDim2.fromOffset(110, 0); Subtitle.BackgroundTransparency = 1; Subtitle.Text = "| Violence District"; Subtitle.TextColor3 = Theme.SubText; Subtitle.Font = Enum.Font.GothamMedium; Subtitle.TextSize = 12; Subtitle.TextXAlignment = Enum.TextXAlignment.Left; Subtitle.Parent = TopBar

local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPos = Window.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = input.Position - dragStart; Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)

local FloatGui = Instance.new("ScreenGui"); FloatGui.Name = "HANX_HUB_Logo"; FloatGui.ResetOnSpawn = false; FloatGui.Parent = CoreGui
local LogoBtn = Instance.new("TextButton"); LogoBtn.Size = UDim2.fromOffset(55, 55); LogoBtn.Position = UDim2.new(0, 20, 0.5, -27); LogoBtn.BackgroundColor3 = Theme.Card; LogoBtn.Text = "H"; LogoBtn.TextColor3 = Theme.Neon; LogoBtn.Font = Enum.Font.GothamBlack; LogoBtn.TextSize = 24; LogoBtn.BorderSizePixel = 0; LogoBtn.Visible = false; LogoBtn.Active = true; LogoBtn.Parent = FloatGui; corner(LogoBtn, 27); addStroke(LogoBtn, Theme.Neon, 2, 0)
local lDrag, lStart, lPos
LogoBtn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then lDrag = true; lStart = i.Position; lPos = LogoBtn.Position; i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then lDrag = false end end) end end)
UserInputService.InputChanged:Connect(function(i) if lDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - lStart; LogoBtn.Position = UDim2.new(lPos.X.Scale, lPos.X.Offset + d.X, lPos.Y.Scale, lPos.Y.Offset + d.Y) end end)

local CloseBtn = Instance.new("TextButton"); CloseBtn.Size = UDim2.fromOffset(24, 24); CloseBtn.Position = UDim2.new(1, -35, 0, 10); CloseBtn.BackgroundTransparency = 1; CloseBtn.Text = "X"; CloseBtn.TextColor3 = Theme.SubText; CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 14; CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(function() dragging = false; lDrag = false; Screen:Remove(); FloatGui:Remove(); local w = CoreGui:FindFirstChild("HANX_Watermark") if w then w:Destroy() end end)
CloseBtn.MouseEnter:Connect(function() TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 80, 80)}):Play() end)
CloseBtn.MouseLeave:Connect(function() TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Theme.SubText}):Play() end)

local MinBtn = Instance.new("TextButton"); MinBtn.Size = UDim2.fromOffset(24, 24); MinBtn.Position = UDim2.new(1, -65, 0, 10); MinBtn.BackgroundTransparency = 1; MinBtn.Text = "-"; MinBtn.TextColor3 = Theme.SubText; MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 18; MinBtn.Parent = TopBar
MinBtn.MouseButton1Click:Connect(function() TweenService:Create(Window, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(0,0)}):Play(); task.wait(0.3); Window.Visible = false; LogoBtn.Visible = true end)
LogoBtn.MouseButton1Click:Connect(function() LogoBtn.Visible = false; Window.Visible = true; TweenService:Create(Window, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(580, 420)}):Play() end)

local Sidebar = Instance.new("Frame"); Sidebar.Size = UDim2.new(0, 150, 1, -55); Sidebar.Position = UDim2.fromOffset(10, 45); Sidebar.BackgroundColor3 = Theme.Sidebar; Sidebar.BorderSizePixel = 0; Sidebar.Parent = Window; corner(Sidebar, 8); addStroke(Sidebar, Color3.fromRGB(40,40,45), 1, 0)
local SideLayout = Instance.new("UIListLayout"); SideLayout.SortOrder = Enum.SortOrder.LayoutOrder; SideLayout.Padding = UDim.new(0, 5); SideLayout.Parent = Sidebar
local SidePad = Instance.new("UIPadding"); SidePad.PaddingTop = UDim.new(0, 12); SidePad.PaddingLeft = UDim.new(0, 8); SidePad.PaddingRight = UDim.new(0, 8); SidePad.Parent = Sidebar
local Content = Instance.new("Frame"); Content.Size = UDim2.new(1, -175, 1, -55); Content.Position = UDim2.fromOffset(165, 45); Content.BackgroundTransparency = 1; Content.ClipsDescendants = true; Content.Parent = Window

local Tabs, Pages = {}, {}
local function SelectTab(index) for i, t in ipairs(Tabs) do if i == index then t.BackgroundColor3 = Theme.Card; t.TextColor3 = Theme.Neon; Pages[i].Visible = true else t.BackgroundColor3 = Theme.Sidebar; t.TextColor3 = Theme.SubText; Pages[i].Visible = false end end end
local function CreateTab(name, icon)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, 0, 0, 34); btn.BackgroundColor3 = Theme.Sidebar; btn.Text = "  " .. icon .. "   " .. name; btn.TextColor3 = Theme.SubText; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 12; btn.TextXAlignment = Enum.TextXAlignment.Left; btn.BorderSizePixel = 0; btn.Parent = Sidebar; corner(btn, 6)
    btn.MouseEnter:Connect(function() if btn.BackgroundColor3 ~= Theme.Card then TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Card, TextColor3 = Theme.Text}):Play() end end)
    btn.MouseLeave:Connect(function() if btn.BackgroundColor3 ~= Theme.Card then TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Sidebar, TextColor3 = Theme.SubText}):Play() end end)
    local page = Instance.new("ScrollingFrame"); page.Size = UDim2.fromScale(1, 1); page.BackgroundTransparency = 1; page.BorderSizePixel = 0; page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = Theme.Neon; page.Visible = false; page.Parent = Content
    local list = Instance.new("UIListLayout"); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0, 8); list.Parent = page
    table.insert(Tabs, btn); table.insert(Pages, page)
    local tabIndex = #Tabs 
    btn.MouseButton1Click:Connect(function() SelectTab(tabIndex) end)
    return page
end

local function CreateMimiwButton(parent, text, defaultColor, note, callback)
    local hasNote = note and note ~= ""
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, -10, 0, hasNote and 55 or 40); btn.BackgroundColor3 = defaultColor or Theme.Card; btn.Text = ""; btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = parent; corner(btn, 8); local stroke = addStroke(btn, Theme.Neon, 1, 0.8)
    local mainText = Instance.new("TextLabel"); mainText.Size = UDim2.new(1, 0, 1, 0); mainText.Position = UDim2.new(0, 0, 0, hasNote and -8 or 0); mainText.BackgroundTransparency = 1; mainText.Text = text; mainText.TextColor3 = Theme.Text; mainText.Font = Enum.Font.GothamBold; mainText.TextSize = 13; mainText.TextXAlignment = Enum.TextXAlignment.Center; mainText.TextYAlignment = Enum.TextYAlignment.Center; mainText.Parent = btn
    if hasNote then
        local noteLbl = Instance.new("TextLabel")
        noteLbl.Size = UDim2.new(1, 0, 0, 14); noteLbl.Position = UDim2.new(0, 0, 1, -18); noteLbl.BackgroundTransparency = 1
        noteLbl.Text = note; noteLbl.TextColor3 = Theme.SubText; noteLbl.Font = Enum.Font.Gotham; noteLbl.TextSize = 9
        noteLbl.TextXAlignment = Enum.TextXAlignment.Center; noteLbl.TextYAlignment = Enum.TextYAlignment.Center; noteLbl.Parent = btn
        btn:SetAttribute("NoteLabel", noteLbl)
    end
    btn.MouseEnter:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0}):Play(); TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.CardHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.8}):Play(); TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = defaultColor or Theme.Card}):Play() end)
    btn.MouseButton1Click:Connect(function() if callback then pcall(callback, btn, mainText) end end)
    return btn, mainText
end

local function CreateCheckbox(parent, title, default, callback)
    local card = Instance.new("Frame"); card.Size = UDim2.new(1, -10, 0, 40); card.BackgroundColor3 = Theme.Card; card.BorderSizePixel = 0; card.Parent = parent; corner(card, 8); addStroke(card, Color3.fromRGB(50, 50, 60), 1, 0)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -50, 1, 0); lbl.Position = UDim2.fromOffset(15, 0); lbl.BackgroundTransparency = 1; lbl.Text = title; lbl.TextColor3 = Theme.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = card
    local tBg = Instance.new("Frame"); tBg.Size = UDim2.fromOffset(40, 20); tBg.Position = UDim2.new(1, -50, 0.5, -10); tBg.BackgroundColor3 = default and Theme.Neon or Theme.ToggleOff; tBg.BorderSizePixel = 0; tBg.Parent = card; corner(tBg, 10)
    local tStroke = addStroke(tBg, Theme.Neon, 1, default and 0.5 or 1)
    local dot = Instance.new("Frame"); dot.Size = UDim2.fromOffset(16, 16); dot.Position = default and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2); dot.BackgroundColor3 = Color3.new(1,1,1); dot.Parent = tBg; corner(dot, 8)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = tBg
    local state = default
    btn.MouseButton1Click:Connect(function() 
        state = not state
        if state then 
            TweenService:Create(tBg, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Neon}):Play()
            TweenService:Create(dot, TweenInfo.new(0.2), {Position = UDim2.fromOffset(22, 2)}):Play()
            TweenService:Create(tStroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
        else 
            TweenService:Create(tBg, TweenInfo.new(0.2), {BackgroundColor3 = Theme.ToggleOff}):Play()
            TweenService:Create(dot, TweenInfo.new(0.2), {Position = UDim2.fromOffset(2, 2)}):Play()
            TweenService:Create(tStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
        end
        if callback then pcall(callback, state) end 
    end)
end

local function CreateLabel(parent, text)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -10, 0, 30); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Theme.Neon; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
end

-- ============================================================
-- BUILD TABS
-- ============================================================
local HomePage = CreateTab("Home", "H")
local SurvivorPage = CreateTab("Survivor", "S")
local KillerPage = CreateTab("Killer", "K")
local PvPPage = CreateTab("Features", "F")
local UtilPage = CreateTab("teleport", "T")
local UtilityPage = CreateTab("Utility", "U")
local SocialPage = CreateTab("Social Media", "M")

-- ISI TAB HOME
local ProfileCard = Instance.new("Frame"); ProfileCard.Size = UDim2.new(1, -10, 0, 80); ProfileCard.BackgroundColor3 = Theme.Card; ProfileCard.BorderSizePixel = 0; ProfileCard.Parent = HomePage; corner(ProfileCard, 8); addStroke(ProfileCard, Theme.Neon, 1, 0.8)
local Avatar = Instance.new("ImageLabel"); Avatar.Size = UDim2.fromOffset(60, 60); Avatar.Position = UDim2.fromOffset(10, 10); Avatar.BackgroundColor3 = Theme.Sidebar; Avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..LP.UserId.."&w=150&h=150"; Avatar.Parent = ProfileCard; corner(Avatar, 30)
local NameLbl = Instance.new("TextLabel"); NameLbl.Size = UDim2.new(1, -80, 0, 20); NameLbl.Position = UDim2.fromOffset(80, 15); NameLbl.BackgroundTransparency = 1; NameLbl.Text = LP.DisplayName; NameLbl.TextColor3 = Theme.Text; NameLbl.Font = Enum.Font.GothamBold; NameLbl.TextSize = 16; NameLbl.TextXAlignment = Enum.TextXAlignment.Left; NameLbl.Parent = ProfileCard
local StatusLbl = Instance.new("TextLabel"); StatusLbl.Size = UDim2.new(1, -80, 0, 20); StatusLbl.Position = UDim2.fromOffset(80, 40); StatusLbl.BackgroundTransparency = 1; StatusLbl.Text = "Status: Free User"; StatusLbl.TextColor3 = Theme.Neon; StatusLbl.Font = Enum.Font.Gotham; StatusLbl.TextSize = 12; StatusLbl.TextXAlignment = Enum.TextXAlignment.Left; StatusLbl.Parent = ProfileCard

CreateLabel(HomePage, "Server Information")
local StatsCard = Instance.new("Frame"); StatsCard.Size = UDim2.new(1, -10, 0, 160); StatsCard.BackgroundColor3 = Theme.Card; StatsCard.BorderSizePixel = 0; StatsCard.Parent = HomePage; corner(StatsCard, 8); addStroke(StatsCard, Color3.fromRGB(50, 50, 60), 1, 0)
local function CreateStatRow(parent, icon, labelText, defaultVal, yOffset)
    local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 30); row.Position = UDim2.fromOffset(0, yOffset); row.BackgroundTransparency = 1; row.Parent = parent
    local ico = Instance.new("TextLabel"); ico.Size = UDim2.fromOffset(30, 30); ico.Position = UDim2.fromOffset(10, 0); ico.BackgroundTransparency = 1; ico.Text = icon; ico.TextColor3 = Theme.Neon; ico.Font = Enum.Font.GothamBold; ico.TextSize = 14; ico.Parent = row
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -100, 1, 0); lbl.Position = UDim2.fromOffset(40, 0); lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = Theme.SubText; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local val = Instance.new("TextLabel"); val.Name = "Value"; val.Size = UDim2.fromOffset(60, 30); val.Position = UDim2.new(1, -70, 0, 0); val.BackgroundTransparency = 1; val.Text = defaultVal; val.TextColor3 = Theme.Text; val.Font = Enum.Font.GothamBold; val.TextSize = 13; val.TextXAlignment = Enum.TextXAlignment.Right; val.Parent = row
    return val
end
local playerCountVal = CreateStatRow(StatsCard, "P", "Players Online", "0", 10)
local pingVal = CreateStatRow(StatsCard, "N", "Ping", "0 ms", 45)
local mapVal = CreateStatRow(StatsCard, "M", "Current Map", "Loading...", 80)
local uptimeVal = CreateStatRow(StatsCard, "T", "Time Played", "00:00:00", 115)
local startTime = tick()
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            playerCountVal.Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers)
            local ping = math.floor(LP:GetNetworkPing() * 1000)
            pingVal.Text = tostring(ping) .. " ms"
            local mapFolder = workspace:FindFirstChild("Map")
            local mapName = (mapFolder and mapFolder:GetChildren()[1]) and mapFolder:GetChildren()[1].Name or "Unknown"
            mapVal.Text = mapName
            local elapsed = tick() - startTime
            uptimeVal.Text = string.format("%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60), math.floor(elapsed % 60))
        end)
    end
end)

-- ISI TAB FEATURES (ESP)
CreateLabel(PvPPage, "ESP Settings")
CreateCheckbox(PvPPage, "Survivor ESP", false, function(s) ESP_Status.Survivor = s end)
CreateCheckbox(PvPPage, "Killer ESP", false, function(s) ESP_Status.Killer = s end)
CreateCheckbox(PvPPage, "Pallet ESP", false, function(s) ESP_Status.Pallets = s end)
CreateCheckbox(PvPPage, "Window ESP", false, function(s) ESP_Status.Windows = s end)
CreateCheckbox(PvPPage, "Generator ESP", false, function(s) ESP_Status.Gens = s end)
CreateCheckbox(PvPPage, "Trap ESP", false, function(s) ESP_Status.Traps = s end)
CreateCheckbox(PvPPage, "Pumpkin ESP", false, function(s) ESP_Status.Pumpkins = s end)

CreateMimiwButton(PvPPage, "FORCE REFRESH ESP", Theme.Card, "Tekan ini kalau ESP ilang", function(btn, txt)
    txt.Text = "Scanning Map..."
    ClearESP()
    task.wait(0.5)
    pcall(UpdateESP)
    task.wait(1)
    txt.Text = "FORCE REFRESH ESP"
    print("ESP Map di-refresh!")
end)

-- ISI TAB SURVIVOR

CreateLabel(SurvivorPage, "Movement")

CreateMimiwButton(
    SurvivorPage,
    "Fast Vault: OFF",
    Theme.Card,
    "Experimental fast vault",
    function(btn, txt)
        txt.Text = "Fast Vault: ON"
        txt.TextColor3 = Theme.Neon

        print("[HANX HUB] Fast Vault enabled")
    end
)

CreateLabel(SurvivorPage, "Auto SkillCheck")
local scBtn, scTxt = CreateMimiwButton(SurvivorPage, "Auto Skill Check: OFF", Theme.ToggleOff, "Mode: Normal", function(btn, txt)
    _G.Ox.Auto.SkillCheck = not _G.Ox.Auto.SkillCheck
    txt.Text = "Auto Skill Check: " .. (_G.Ox.Auto.SkillCheck and "ON" or "OFF")
    btn.BackgroundColor3 = _G.Ox.Auto.SkillCheck and Theme.Neon or Theme.ToggleOff
    txt.TextColor3 = _G.Ox.Auto.SkillCheck and Theme.Bg or Theme.Text
    if _G.Ox.Auto.SkillCheck then fn7() else if _G.Ox.Connections.SkillHeartbeat then _G.Ox.Connections.SkillHeartbeat:Disconnect(); _G.Ox.Connections.SkillHeartbeat = nil end end
end)

CreateLabel(SurvivorPage, "Auto Drop Pallet")
CreateMimiwButton(SurvivorPage, "Auto Drop Pallet: DISABLED", Theme.ToggleOff, "Fitur dinonaktifkan permanen", function(btn, txt)
    -- Gak ada fungsi, cuma biar keliatan aja
    txt.Text = "Auto Drop Pallet: DISABLED"
    btn.BackgroundColor3 = Theme.ToggleOff
    txt.TextColor3 = Theme.SubText
end)
--CreateMimiwButton(SurvivorPage, "Pallet Trigger Distance: 10", Theme.Card, "Jarak deteksi killer", function(btn, txt)
   -- AutoPallet.Distance = AutoPallet.Distance + 2
  --  if AutoPallet.Distance > 20 then AutoPallet.Distance = 6 end
  --  txt.Text = "Pallet Trigger Distance: " .. AutoPallet.Distance
--end)

-- ISI TAB KILLER
CreateLabel(KillerPage, "Killer Aimbot")
CreateMimiwButton(KillerPage, "Killer Aimbot: OFF", Theme.ToggleOff, "Aim ke survivor", function(btn, txt)
    KillerConfig.Enabled = not KillerConfig.Enabled
    if KillerConfig.Enabled then KA_StartLoop(); txt.Text = "Killer Aimbot: ON"; btn.BackgroundColor3 = Theme.Neon; txt.TextColor3 = Theme.Bg
    else if not KillerConfig.AutoM1 then KA_StopLoop() end; txt.Text = "Killer Aimbot: OFF"; btn.BackgroundColor3 = Theme.ToggleOff; txt.TextColor3 = Theme.Text end
end)
CreateMimiwButton(KillerPage, "Max Distance: 12", Theme.Card, "Range target aimbot", function(btn, txt)
    KillerConfig.MaxDist = KillerConfig.MaxDist + 2
    if KillerConfig.MaxDist > 30 then KillerConfig.MaxDist = 6 end
    txt.Text = "Max Distance: " .. KillerConfig.MaxDist
end)
CreateLabel(KillerPage, "Auto Attack")
CreateMimiwButton(KillerPage, "Auto Attack: OFF", Theme.ToggleOff, "Serang otomatis", function(btn, txt)
    KillerConfig.AutoM1 = not KillerConfig.AutoM1
    if KillerConfig.AutoM1 then
        if not KillerConfig.Enabled then KillerConfig.Enabled = true end
        KA_StartLoop(); txt.Text = "Auto Attack: ON"; btn.BackgroundColor3 = Theme.Neon; txt.TextColor3 = Theme.Bg
    else
        if not KillerConfig.Enabled then KA_StopLoop() end; txt.Text = "Auto M1: OFF"; btn.BackgroundColor3 = Theme.ToggleOff; txt.TextColor3 = Theme.Text
    end
end)

-- ISI TAB PLAYER (TELEPORT)
CreateLabel(UtilPage, "Player Teleport")
local selectBtn, selectTxt = CreateMimiwButton(UtilPage, "Select Player...", Theme.Card, "Click to view player list", function(btn, txt)
    local names = GetPlayerNames()
    if _G.HANX_TempList then _G.HANX_TempList:Destroy() end
    local listFrame = Instance.new("Frame"); listFrame.Name = "TempList"; listFrame.Size = UDim2.new(1, -10, 0, #names * 35); listFrame.BackgroundTransparency = 1; listFrame.Parent = UtilPage; _G.HANX_TempList = listFrame
    local uiList = Instance.new("UIListLayout"); uiList.Padding = UDim.new(0, 5); uiList.Parent = listFrame
    for _, name in ipairs(names) do
        local pBtn = Instance.new("TextButton"); pBtn.Size = UDim2.new(1, 0, 0, 30); pBtn.BackgroundColor3 = Theme.Sidebar; pBtn.Text = name; pBtn.TextColor3 = Theme.Text; pBtn.Font = Enum.Font.Gotham; pBtn.TextSize = 12; pBtn.Parent = listFrame; corner(pBtn, 6)
        pBtn.MouseButton1Click:Connect(function() selectedPlayer = name; txt.Text = "Selected: " .. name; txt.TextColor3 = Theme.Neon; listFrame:Destroy(); _G.HANX_TempList = nil end)
    end
end)

CreateMimiwButton(UtilPage, "Teleport to Player", Theme.Card, "Teleport instantly", function(btn, txt)
    if selectedPlayer then TeleportToPlayer(selectedPlayer); txt.Text = "Teleported!"; task.wait(1.5); txt.Text = "Teleport to Player"
    else txt.Text = "Select a player first!"; task.wait(1.5); txt.Text = "Teleport to Player" end
end)

local followBtn, followTxt = CreateMimiwButton(UtilPage, "Follow Player: OFF", Theme.ToggleOff, "Stalk the selected player", function(btn, txt)
    if not selectedPlayer then txt.Text = "Select a player first!"; task.wait(1.5); txt.Text = "Follow Player: OFF"; return end
    isFollowing = not isFollowing
    if isFollowing then
        txt.Text = "Follow Player: ON"; btn.BackgroundColor3 = Theme.Neon; txt.TextColor3 = Theme.Bg
        if followThread then task.cancel(followThread) end
        followThread = task.spawn(function()
            while isFollowing do
                local target = Players:FindFirstChild(selectedPlayer)
                if target and target.Character then
                    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
                    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if targetRoot and myRoot then local dist = (targetRoot.Position - myRoot.Position).Magnitude; if dist > 5 then myRoot.CFrame = myRoot.CFrame:Lerp(targetRoot.CFrame + Vector3.new(0, 3, 0), 0.2) end end
                else isFollowing = false; txt.Text = "Follow Player: OFF"; btn.BackgroundColor3 = Theme.ToggleOff; txt.TextColor3 = Theme.Text end
                task.wait(0.1)
            end
        end)
    else
        txt.Text = "Follow Player: OFF"; btn.BackgroundColor3 = Theme.ToggleOff; txt.TextColor3 = Theme.Text
        if followThread then task.cancel(followThread); followThread = nil end
    end
end)
CreateMimiwButton(UtilPage, "Reset Character", Theme.Card, "Respawn instantly", function()
    if LP.Character then local hum = LP.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.Health = 0 end end
end)

-- ============================================================
-- AUTO PARRY UI
-- ============================================================

CreateLabel(SurvivorPage, "Auto Parry")

CreateMimiwButton(
    SurvivorPage,
    "Auto Parry: OFF",
    Theme.ToggleOff,
    "Detect killer attack automatically",
    function(btn, txt)
        AutoParry.Enabled = not AutoParry.Enabled

        if AutoParry.Enabled then
            AP_Start()
        else
            AP_Stop()
        end

        txt.Text = "Auto Parry: " .. (AutoParry.Enabled and "ON" or "OFF")
        btn.BackgroundColor3 = AutoParry.Enabled and Theme.Neon or Theme.ToggleOff
        txt.TextColor3 = AutoParry.Enabled and Theme.Bg or Theme.Text
    end
)

CreateMimiwButton(
    SurvivorPage,
    "Mode: PC",
    Theme.Card,
    "Switch PC / HP Delta",
    function(btn, txt)
        AutoParry.Mode = AutoParry.Mode == "PC" and "HP" or "PC"
        txt.Text = "Mode: " .. AutoParry.Mode
    end
)

CreateMimiwButton(
    SurvivorPage,
    "Range: 18",
    Theme.Card,
    "Auto Parry detection range",
    function(btn, txt)
        AutoParry.Range = AutoParry.Range + 6
        if AutoParry.Range > 42 then
            AutoParry.Range = 12
        end
        txt.Text = "Range: " .. AutoParry.Range
    end
)

CreateMimiwButton(
    SurvivorPage,
    "Delay: 0.08",
    Theme.Card,
    "Auto Parry delay",
    function(btn, txt)
        AutoParry.Delay = AutoParry.Delay + 0.04
        if AutoParry.Delay > 0.3 then
            AutoParry.Delay = 0
        end

        AutoParry.Delay = math.floor(AutoParry.Delay * 100 + 0.5) / 100
        txt.Text = "Delay: " .. AutoParry.Delay
    end
)

CreateMimiwButton(
    SurvivorPage,
    "Parry Key: F",
    Theme.Card,
    "PC keyboard parry key",
    function(btn, txt)
        AutoParry.KeyIndex = AutoParry.KeyIndex % #AP_Keys + 1
        txt.Text = "Parry Key: " .. AP_Keys[AutoParry.KeyIndex][1]
    end
)

CreateMimiwButton(
    SurvivorPage,
    "Killer Only: ON",
    Theme.Card,
    "Only detect killer",
    function(btn, txt)
        AutoParry.KillerOnly = not AutoParry.KillerOnly
        txt.Text = "Killer Only: " .. (AutoParry.KillerOnly and "ON" or "OFF")
    end
)

CreateMimiwButton(
    SurvivorPage,
    "Facing Check: ON",
    Theme.Card,
    "Check killer facing direction",
    function(btn, txt)
        AutoParry.Facing = not AutoParry.Facing
        txt.Text = "Facing Check: " .. (AutoParry.Facing and "ON" or "OFF")
    end
)

-- ISI TAB UTILITY (FITUR BARU)



CreateLabel(UtilityPage, "Settings")

-- FULLBRIGHT + ANTI FOG
local isFullbright = false
local antiFogEnabled = false

local originalBrightness = Lighting.Brightness
local originalFogStart = Lighting.FogStart
local originalFogEnd = Lighting.FogEnd
local originalAmbient = Lighting.Ambient

local originalAtmosphere = {}

local function SetAntiFog(state)
    antiFogEnabled = state

    if state then
        Lighting.FogStart = 0
        Lighting.FogEnd = 1000000

        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("Atmosphere") then
                if not originalAtmosphere[v] then
                    originalAtmosphere[v] = {
                        Density = v.Density,
                        Haze = v.Haze,
                        Glare = v.Glare
                    }
                end

                v.Density = 0
                v.Haze = 0
                v.Glare = 0
            end
        end
    else
        Lighting.FogStart = originalFogStart
        Lighting.FogEnd = originalFogEnd

        for obj, data in pairs(originalAtmosphere) do
            if obj.Parent then
                obj.Density = data.Density
                obj.Haze = data.Haze
                obj.Glare = data.Glare
            end
        end
    end
end

CreateMimiwButton(
    UtilityPage,
    "Fullbright: OFF",
    Theme.ToggleOff,
    "Bikin map terang",
    function(btn, txt)
        isFullbright = not isFullbright

        txt.Text = "Fullbright: " .. (isFullbright and "ON" or "OFF")
        btn.BackgroundColor3 = isFullbright and Theme.Neon or Theme.ToggleOff
        txt.TextColor3 = isFullbright and Theme.Bg or Theme.Text

        if isFullbright then
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        else
            Lighting.Brightness = originalBrightness
            Lighting.Ambient = originalAmbient
        end
    end
)

CreateMimiwButton(
    UtilityPage,
    "Anti Fog: OFF",
    Theme.ToggleOff,
    "Mengurangi kabut map",
    function(btn, txt)
        SetAntiFog(not antiFogEnabled)

        txt.Text = "Anti Fog: " .. (antiFogEnabled and "ON" or "OFF")
        btn.BackgroundColor3 = antiFogEnabled and Theme.Neon or Theme.ToggleOff
        txt.TextColor3 = antiFogEnabled and Theme.Bg or Theme.Text
    end
)




local antiAfkEnabled = false
--CreateLabel(UtilityPage, "System")
CreateMimiwButton(UtilityPage, "Anti-AFK: OFF", Theme.ToggleOff, "Cegah kick pas idle", function(btn, txt)
    antiAfkEnabled = not antiAfkEnabled
    txt.Text = "Anti-AFK: " .. (antiAfkEnabled and "ON" or "OFF")
    btn.BackgroundColor3 = antiAfkEnabled and Theme.Neon or Theme.ToggleOff
    txt.TextColor3 = antiAfkEnabled and Theme.Bg or Theme.Text
    if antiAfkEnabled then
        task.spawn(function()
            while antiAfkEnabled do
                task.wait(60)
                pcall(function()
                    local VirtualUser = game:GetService("VirtualUser")
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end)
    end
end)

--FIX LAG BY HANX HUB
CreateLabel(UtilityPage, "Performance")

local LowGraphicsEnabled = false
local SavedGraphics = {}
local GraphicsConnection
local Processing = false

local function OptimizeObject(obj)
    if not LowGraphicsEnabled then return end

    local property = nil

    if obj:IsA("ParticleEmitter")
        or obj:IsA("Trail")
        or obj:IsA("Beam")
        or obj:IsA("Smoke")
        or obj:IsA("Fire")
        or obj:IsA("Sparkles") then

        property = "Enabled"

    elseif obj:IsA("BasePart") then
        property = "CastShadow"
    end

    if not property then return end

    local success, original = pcall(function()
        return obj[property]
    end)

    if not success then return end

    if not SavedGraphics[obj] then
        SavedGraphics[obj] = {}
    end

    if SavedGraphics[obj][property] == nil then
        SavedGraphics[obj][property] = original
    end

    pcall(function()
        obj[property] = false
    end)
end

local function EnableLowGraphics()
    if Processing then return end
    Processing = true

    task.spawn(function()
        local objects = game:GetDescendants()

        for i, obj in ipairs(objects) do
            if not LowGraphicsEnabled then break end

            OptimizeObject(obj)

            if i % 100 == 0 then
                task.wait()
            end
        end

        Processing = false
    end)

    GraphicsConnection = game.DescendantAdded:Connect(function(obj)
        if LowGraphicsEnabled then
            OptimizeObject(obj)
        end
    end)
end

local function DisableLowGraphics()
    if GraphicsConnection then
        GraphicsConnection:Disconnect()
        GraphicsConnection = nil
    end

    for obj, properties in pairs(SavedGraphics) do
        if obj and obj.Parent then
            for property, value in pairs(properties) do
                pcall(function()
                    obj[property] = value
                end)
            end
        end
    end

    table.clear(SavedGraphics)
end

CreateMimiwButton(
    UtilityPage,
    "Low Graphics: OFF",
    Theme.Card,
    "Reduce visual effects without changing map colors",
    function(btn, txt)

        LowGraphicsEnabled = not LowGraphicsEnabled

        if LowGraphicsEnabled then
            EnableLowGraphics()

            txt.Text = "Low Graphics: ON"
            txt.TextColor3 = Theme.Neon
        else
            DisableLowGraphics()

            txt.Text = "Low Graphics: OFF"
            txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
)
--REJOIN
CreateLabel(UtilityPage, "Server Tools")

CreateMimiwButton(
    UtilityPage,
    "Rejoin Server",
    Theme.Card,
    "Reconnect fix bug",
    function(btn, txt)

        txt.Text = "Rejoining..."
        txt.TextColor3 = Theme.Neon

        local Players = game:GetService("Players")
        local TeleportService = game:GetService("TeleportService")
        local player = Players.LocalPlayer

        local failed = false

        local connection
        connection = TeleportService.TeleportInitFailed:Connect(
            function(failedPlayer, result, message)
                if failedPlayer ~= player or failed then
                    return
                end

                failed = true
                warn("[HANX HUB] Teleport failed:", result, message)

                txt.Text = "Teleport Failed"
                txt.TextColor3 = Color3.fromRGB(255, 70, 70)

                if connection then
                    connection:Disconnect()
                end
            end
        )

        local success, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)

        if not success then
            warn("[HANX HUB] Rejoin error:", err)
            txt.Text = "Rejoin Failed"
            txt.TextColor3 = Color3.fromRGB(255, 70, 70)

            if connection then
                connection:Disconnect()
            end
        end
    end
)

-- ISI TAB SOCIAL MEDIA
CreateLabel(SocialPage, "Join Our Community")
CreateLabel(SocialPage, "Follow for updates and more scripts!")

CreateMimiwButton(SocialPage, "DISCORD SERVER", Theme.Card, "Click to open invite link", function(btn, txt)
    if setclipboard then setclipboard("https://discord.gg/p6RrUTr8V"); txt.Text = "Opening Link..."; txt.TextColor3 = Theme.Neon
        local success = pcall(function() if openbrowser then openbrowser("https://discord.gg/p6RrUTr8V") elseif request then request({Url = "https://discord.gg/p6RrUTr8V", Method = "GET"}) end end)
        if not success then txt.Text = "Link Copied! Paste di browser." end
        task.wait(2); txt.Text = "DISCORD SERVER"; txt.TextColor3 = Theme.Text end
end)

CreateMimiwButton(SocialPage, "YOUTUBE CHANNEL", Theme.Card, "Subscribe for more scripts!", function(btn, txt)
    if setclipboard then setclipboard("https://youtube.com/@hanxhub"); txt.Text = "Opening Link..."; txt.TextColor3 = Theme.Neon
        local success = pcall(function() if openbrowser then openbrowser("https://youtube.com/@hanxhub") elseif request then request({Url = "https://youtube.com/@hanxhub", Method = "GET"}) end end)
        if not success then txt.Text = "Link Copied! Paste di browser." end
        task.wait(2); txt.Text = "YOUTUBE CHANNEL"; txt.TextColor3 = Theme.Text end
end)

CreateMimiwButton(SocialPage, "TIKTOK", Theme.Card, "Follow for tips & tricks", function(btn, txt)
    if setclipboard then setclipboard("https://tiktok.com/@whoohnbro_"); txt.Text = "Opening Link..."; txt.TextColor3 = Theme.Neon
        local success = pcall(function() if openbrowser then openbrowser("https://tiktok.com/@whoohnbro_") elseif request then request({Url = "https://tiktok.com/@whoohnbro_", Method = "GET"}) end end)
        if not success then txt.Text = "Link Copied! Paste di browser." end
        task.wait(2); txt.Text = "TIKTOK"; txt.TextColor3 = Theme.Text end
end)

CreateMimiwButton(SocialPage, "SAWERIA", Theme.Card, "Support for more content!", function(btn, txt)
    if setclipboard then setclipboard("https://saweria.co/hanxhub"); txt.Text = "Opening Link..."; txt.TextColor3 = Theme.Neon
        local success = pcall(function() if openbrowser then openbrowser("https://saweria.co/hanxhub") elseif request then request({Url = "https://saweria.co/hanxhub", Method = "GET"}) end end)
        if not success then txt.Text = "Link Copied! Paste di browser." end
        task.wait(2); txt.Text = "SAWERIA"; txt.TextColor3 = Theme.Text end
end)

-- WATERMARK & KEYBINDS
local WatermarkGui = Instance.new("ScreenGui")
WatermarkGui.Name = "HANX_Watermark"
WatermarkGui.ResetOnSpawn = false
WatermarkGui.Parent = CoreGui
local Watermark = Instance.new("TextLabel")
Watermark.Size = UDim2.fromOffset(150, 20); Watermark.Position = UDim2.new(0, 10, 0, 10); Watermark.BackgroundTransparency = 1; Watermark.Text = "HANX HUB | Free User"; Watermark.TextColor3 = Theme.Neon; Watermark.TextStrokeTransparency = 0; Watermark.Font = Enum.Font.GothamBold; Watermark.TextSize = 12; Watermark.Parent = WatermarkGui

local keybindState = { ESP = false }
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.V then
        keybindState.ESP = not keybindState.ESP
        ESP_Status.Survivor = keybindState.ESP; ESP_Status.Killer = keybindState.ESP
    end
end)

-- SPLASH SCREEN
local SplashGui = Instance.new("ScreenGui"); SplashGui.Name = "HANX_HUB_Splash"; SplashGui.ResetOnSpawn = false; SplashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; SplashGui.IgnoreGuiInset = true; SplashGui.DisplayOrder = 999; SplashGui.Parent = CoreGui
local SplashBg = Instance.new("Frame"); SplashBg.Size = UDim2.fromScale(1, 1); SplashBg.BackgroundColor3 = Color3.new(0,0,0); SplashBg.BackgroundTransparency = 1; SplashBg.BorderSizePixel = 0; SplashBg.Parent = SplashGui
local SplashBox = Instance.new("Frame"); SplashBox.Size = UDim2.fromOffset(280, 120); SplashBox.Position = UDim2.new(0.5, -140, 0.5, -60); SplashBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18); SplashBox.BackgroundTransparency = 0.2; SplashBox.BorderSizePixel = 0; SplashBox.Parent = SplashGui; corner(SplashBox, 10); addStroke(SplashBox, Theme.Neon, 1, 0.5)
local SplashTitle = Instance.new("TextLabel"); SplashTitle.Size = UDim2.new(1, 0, 0, 40); SplashTitle.Position = UDim2.new(0, 0, 0, 20); SplashTitle.BackgroundTransparency = 1; SplashTitle.Text = "HANX HUB"; SplashTitle.TextColor3 = Theme.Neon; SplashTitle.Font = Enum.Font.GothamBlack; SplashTitle.TextSize = 24; SplashTitle.Parent = SplashBox
local SplashSub = Instance.new("TextLabel"); SplashSub.Size = UDim2.new(1, 0, 0, 20); SplashSub.Position = UDim2.new(0, 0, 0, 55); SplashSub.BackgroundTransparency = 1; SplashSub.Text = "Loading scripts..."; SplashSub.TextColor3 = Theme.SubText; SplashSub.Font = Enum.Font.Gotham; SplashSub.TextSize = 12; SplashSub.Parent = SplashBox
local BarBg = Instance.new("Frame"); BarBg.Size = UDim2.new(1, -40, 0, 6); BarBg.Position = UDim2.new(0, 20, 1, -20); BarBg.BackgroundColor3 = Theme.Sidebar; BarBg.BorderSizePixel = 0; BarBg.Parent = SplashBox; corner(BarBg, 3)
local BarFill = Instance.new("Frame"); BarFill.Size = UDim2.fromScale(0, 1); BarFill.BackgroundColor3 = Theme.Neon; BarFill.BorderSizePixel = 0; BarFill.Parent = BarBg; corner(BarFill, 3)

task.spawn(function()
    TweenService:Create(BarFill, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
    task.wait(1.6)
    TweenService:Create(SplashBox, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(SplashTitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    TweenService:Create(SplashSub, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    TweenService:Create(BarBg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(BarFill, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    SplashGui:Destroy()
    
    Screen.Enabled = true
    Window.Size = UDim2.fromOffset(0, 0)
    task.wait(0.1)
    TweenService:Create(Window, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(580, 420)}):Play()
    
    task.wait(0.4)
    SelectTab(1)
print("[HANX HUB] Loaded.")

task.spawn(function()
    task.wait(2)

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "HANX HUB",
            Text = "Successfully Injected!",
            Duration = 15
        })
    end)
end)
end)
