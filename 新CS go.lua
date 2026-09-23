-- =========================================================================
-- [ MEMESENSE - 完整构建 | 彩虹方块 + 弹道追踪 + 手雷ESP + 武器ESP ]
-- [ BloxStrike 版本 | 作者 Axiom ]
-- =========================================================================

local MaterialLimits = {
    [Enum.Material.Asphalt] = 0.25,
    [Enum.Material.Basalt] = 0.25,
    [Enum.Material.Brick] = 0.25,
    [Enum.Material.Cobblestone] = 0.25,
    [Enum.Material.Concrete] = 0.25,
    [Enum.Material.CrackedLava] = 0.25,
    [Enum.Material.DiamondPlate] = 0.25,
    [Enum.Material.Foil] = 0.25,
    [Enum.Material.Glacier] = 0.25,
    [Enum.Material.Granite] = 0.25,
    [Enum.Material.Grass] = 0.25,
    [Enum.Material.Ground] = 0.25,
    [Enum.Material.Ice] = 0.25,
    [Enum.Material.LeafyGrass] = 0.25,
    [Enum.Material.Limestone] = 0.25,
    [Enum.Material.Marble] = 0.25,
    [Enum.Material.Metal] = 0.25,
    [Enum.Material.Mud] = 0.25,
    [Enum.Material.Pavement] = 0.25,
    [Enum.Material.Rock] = 0.25,
    [Enum.Material.Salt] = 0.25,
    [Enum.Material.Sand] = 0.25,
    [Enum.Material.Sandstone] = 0.25,
    [Enum.Material.Slate] = 0.25,
    [Enum.Material.Snow] = 0.25,
    [Enum.Material.ForceField] = 0.25,
    [Enum.Material.Neon] = 0.25,
    [Enum.Material.CorrodedMetal] = 0.25,
    [Enum.Material.Pebble] = 0.25,
    [Enum.Material.CeramicTiles] = 0.25,
    [Enum.Material.Plaster] = 0.25,
    [Enum.Material.Plastic] = 7,
    [Enum.Material.SmoothPlastic] = 7,
    [Enum.Material.Wood] = 7,
    [Enum.Material.WoodPlanks] = 7,
    [Enum.Material.Cardboard] = 7,
    [Enum.Material.Glass] = 100,
    [Enum.Material.Fabric] = 100
}

local MaterialVariantLimits = {
    ["IndoorWall"] = 0.25,
    ["Sandy Brick"] = 0.25
}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
-- =========================================================================
-- [ 穿透系统 ]
-- =========================================================================

local function GetPenetrationStats(origin, direction, maxPen, ignoreList, targetRoot)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.CollisionGroup = "Bullet"
    local filter = ignoreList or {LP.Character, Camera}
    params.FilterDescendantsInstances = filter
    local currentOrigin = origin
    local currentDir = direction
    local accMat = {}
    local accVar = {}
    local stats = {
        TotalThickness = 0,
        MaterialStats = {},
        Success = false,
        FailReason = "达到最大步数",
        EndPos = Vector3.zero
    }

    local backParams = RaycastParams.new()
    backParams.FilterType = Enum.RaycastFilterType.Include
    backParams.CollisionGroup = "Bullet"

    for i = 1, 100 do
        if not currentOrigin or not currentDir then break end
        local result = Workspace:Raycast(currentOrigin, currentDir * 1000, params)
        if not result then
            if not targetRoot then
                stats.Success = true
                stats.EndPos = currentOrigin + (currentDir * 1000)
            else
                stats.FailReason = "虚空 (未命中)"
            end
            break
        end
        if not result.Instance or not result.Instance.Parent then
            stats.FailReason = "实例已销毁"
            break
        end
        if targetRoot and result.Instance:IsDescendantOf(targetRoot) then
            stats.Success = true
            stats.EndPos = result.Position
            stats.FailReason = "命中"
            return stats
        end
        table.insert(filter, result.Instance)
        params.FilterDescendantsInstances = filter
        local enterPos = result.Position
        local fakeEnd = enterPos + (currentDir * 1000)
        backParams.FilterDescendantsInstances = {result.Instance}
        local backRes = Workspace:Raycast(fakeEnd, enterPos - fakeEnd, backParams)
        local thickness = 0.5
        local limit = 0.25
        local matName = result.Instance.Material.Name
        if not backRes then
            thickness = 5
            stats.FailReason = "无限/阻挡"
        else
            thickness = (enterPos - backRes.Position).Magnitude
            local variant = backRes.Instance.MaterialVariant
            if variant ~= "" and MaterialVariantLimits[variant] then
                matName = variant
                limit = MaterialVariantLimits[variant]
                accVar[variant] = (accVar[variant] or 0) + thickness
                if accVar[variant] > limit + maxPen then
                    stats.FailReason = string.format("变体: %s (%.1f > %.1f)", variant, accVar[variant], limit + maxPen)
                    stats.MaterialStats = {Type = "变体", Name = variant, Thickness = accVar[variant], Limit = limit + maxPen}
                    return stats
                end
            else
                local mat = backRes.Material
                matName = mat.Name
                limit = MaterialLimits[mat] or 0.25
                accMat[mat] = (accMat[mat] or 0) + thickness
                if accMat[mat] > limit + maxPen then
                    stats.FailReason = string.format("%s (%.1f / %.1f)", matName, accMat[mat], limit + maxPen)
                    stats.MaterialStats = {Type = "材质", Name = matName, Thickness = accMat[mat], Limit = limit + maxPen}
                    return stats
                end
            end
            currentOrigin = backRes.Position
        end
        stats.TotalThickness = stats.TotalThickness + thickness
    end
    return stats
end
-- =========================================================================
-- [ 数学 & 连跳辅助 ]
-- =========================================================================

local function GetMoveDirection()
    local Direction = Vector3.zero
    local LookVector = Camera.CFrame.LookVector
    local RightVector = Camera.CFrame.RightVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then Direction += LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then Direction -= LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then Direction -= RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then Direction += RightVector end
    return Vector3.new(Direction.X, 0, Direction.Z).Unit
end

local charfolder = Workspace:WaitForChild("Characters", 10)

local function get_player_team(player)
    if not player then return nil end
    if player.Team then return player.Team.Name end
    return nil
end

local function IsValidTarget(character, teamCheckEnabled)
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
    local targetPlayer = Players:GetPlayerFromCharacter(character)
    if not targetPlayer or targetPlayer == LP then return false end
    if teamCheckEnabled then
        if LP.Team and targetPlayer.Team then
            if LP.Team == targetPlayer.Team then return false end
        end
        if LP.Character and LP.Character.Parent and character.Parent then
            if LP.Character.Parent == character.Parent and character.Parent.Name ~= "Characters" then
                return false
            end
        end
    end
    return true
end
-- =========================================================================
-- [ 库初始化 ]
-- =========================================================================

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

Library.Font = Enum.Font.Roboto

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title = '<font color="#ff0000"><b>MEME</b></font><font color="#ffffff"><b>SENSE</b></font>',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
    Size = UDim2.new(0, 650, 0, 520)
})

local Tabs = {
    Combat = Window:AddTab('战斗', 'swords'),
    Weapons = Window:AddTab('武器', 'crosshair'),
    Visuals = Window:AddTab('视觉', 'eye'),
    World = Window:AddTab('世界', 'globe'),
    Misc = Window:AddTab('杂项', 'activity'),
    SkinChanger = Window:AddTab('皮肤切换', 'paintbrush'),
    Settings = Window:AddTab('设置', 'settings'),
}
-- =========================================================================
-- [ 设置选项卡 ]
-- =========================================================================

local SettingsGroup = Tabs.Settings:AddLeftGroupbox("界面设置", "settings")

SettingsGroup:AddLabel("菜单快捷键"):AddKeyPicker("MenuKeybind", {
    Text = "菜单快捷键",
    Default = "RightShift",
    Mode = "Toggle",
    Callback = function(v) Library:Toggle() end
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        local keybind = Options.MenuKeybind
        if keybind then
            local currentVal = keybind.Value
            local isCtrlKey = (currentVal == "LeftControl" or currentVal == "RightControl" or currentVal == "LCtrl" or currentVal == "RCtrl")
            if isCtrlKey then
                local keyCode = input.KeyCode
                if (currentVal == "LeftControl" or currentVal == "LCtrl") and keyCode == Enum.KeyCode.LeftControl then
                    Library:Toggle()
                elseif (currentVal == "RightControl" or currentVal == "RCtrl") and keyCode == Enum.KeyCode.RightControl then
                    Library:Toggle()
                end
            end
        end
    end
end)
-- =========================================================================
-- [ 杂项选项卡 - 移动 ]
-- =========================================================================

local MiscBox = Tabs.Misc:AddLeftGroupbox("移动", "activity")

MiscBox:AddToggle("AutoBhop", { Text = "自动连跳", Default = false })
MiscBox:AddSlider("BhopSpeed", { Text = "连跳速度", Default = 18, Min = 5, Max = 30, Rounding = 1, Suffix = "速度" })
MiscBox:AddToggle("NoFallDamage", { Text = "无摔落伤害", Default = false })

RunService.Heartbeat:Connect(function()
    pcall(function()
        local Character = LP.Character
        if not Character then return end
        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character:FindFirstChild("Humanoid")
        if not RootPart or not Humanoid then return end

        if Toggles.AutoBhop and Toggles.AutoBhop.Value then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                local RayParams = RaycastParams.new()
                RayParams.FilterDescendantsInstances = {Character}
                RayParams.FilterType = Enum.RaycastFilterType.Exclude
                local GroundCheck = Workspace:Raycast(RootPart.Position, Vector3.new(0, -4, 0), RayParams)
                if GroundCheck then Humanoid.Jump = true end
            end
            local Success, Result = pcall(function() return GetMoveDirection() end)
            if Success and Result.Magnitude > 0 then
                local currentBhopSpeed = math.clamp(Options.BhopSpeed and Options.BhopSpeed.Value or 18, 5, 30)
                local Direction = Result * currentBhopSpeed
                local Velocity = RootPart.AssemblyLinearVelocity
                local NewX = Velocity.X + (Direction.X - Velocity.X) * 0.2
                local NewZ = Velocity.Z + (Direction.Z - Velocity.Z) * 0.2
                RootPart.AssemblyLinearVelocity = Vector3.new(NewX, Velocity.Y, NewZ)
            end
        end
    end)
end)

RunService.Heartbeat:Connect(function()
    pcall(function()
        if Toggles.NoFallDamage and Toggles.NoFallDamage.Value then
            local character = LP.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    pcall(function()
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    end)
                end
            end
        end
    end)
end)
-- =========================================================================
-- [ 世界选项卡设置 ]
-- =========================================================================

local WorldBox = Tabs.World:AddLeftGroupbox("世界", "globe")
local WeaponVisualBox = Tabs.World:AddRightGroupbox("武器视觉", "activity")

-- =========================================================================
-- [ 武器视觉 - 弹道追踪 ]
-- =========================================================================

WeaponVisualBox:AddToggle("BulletTracers", {
    Text = "子弹弹道追踪",
    Default = false,
}):AddColorPicker("BulletTracersColor", {
    Default = Color3.fromRGB(0, 170, 255),
    Title = "追踪颜色",
})

WeaponVisualBox:AddDropdown("TracerStyle", {
    Text = "追踪样式",
    Values = {"方块", "圆柱体 (Obelius)"},
    Default = "方块",
})

WeaponVisualBox:AddToggle("TracerRainbow", {
    Text = "追踪彩虹模式",
    Default = false,
})

WeaponVisualBox:AddSlider("TracerTime", {
    Text = "追踪显示时间",
    Default = 2,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Suffix = "秒"
})

WeaponVisualBox:AddToggle("BulletImpacts", {
    Text = "子弹弹着点",
    Default = false,
}):AddColorPicker("BulletImpactsColor", {
    Default = Color3.fromRGB(255, 0, 0),
    Title = "弹着点颜色",
})
-- =========================================================================
-- [ 手雷ESP - 仅追踪 (无警告框) ]
-- =========================================================================

local GrenadeVisualBox = Tabs.Visuals:AddRightGroupbox("手雷ESP", "activity")

GrenadeVisualBox:AddToggle("GrenadeTracers", {
    Text = "手雷弹道追踪",
    Default = false,
}):AddColorPicker("GrenadeTracerColor", {
    Default = Color3.fromRGB(255, 100, 0),
    Title = "追踪颜色",
})

GrenadeVisualBox:AddToggle("MolotovZoneESP", {
    Text = "燃烧瓶区域ESP",
    Default = false,
}):AddColorPicker("GrenadeZoneColor", {
    Default = Color3.fromRGB(255, 60, 0),
    Title = "区域颜色",
})

GrenadeVisualBox:AddToggle("SmokeZoneESP", {
    Text = "烟雾区域ESP",
    Default = false,
}):AddColorPicker("SmokeZoneColor", {
    Default = Color3.fromRGB(180, 180, 180),
    Title = "烟雾颜色",
})
-- =========================================================================
-- [ 自定义手部位置 ]
-- =========================================================================

local CustomHandsBox = Tabs.World:AddRightGroupbox("自定义手部位置", "crosshair")

CustomHandsBox:AddToggle("CustomHandsEnabled", { Text = "启用", Default = false })
CustomHandsBox:AddSlider("HandsX", { Text = "X轴", Default = 0.2, Min = -2, Max = 2, Rounding = 3, Suffix = "单位" })
CustomHandsBox:AddSlider("HandsY", { Text = "Y轴", Default = -0.155, Min = -2, Max = 2, Rounding = 3, Suffix = "单位" })
CustomHandsBox:AddSlider("HandsZ", { Text = "Z轴", Default = 0.075, Min = -2, Max = 2, Rounding = 3, Suffix = "单位" })

RunService.RenderStepped:Connect(function()
    pcall(function()
        if not Toggles.CustomHandsEnabled or not Toggles.CustomHandsEnabled.Value then return end
        local xOffset = Options.HandsX and Options.HandsX.Value or 0.2
        local yOffset = Options.HandsY and Options.HandsY.Value or -0.155
        local zOffset = Options.HandsZ and Options.HandsZ.Value or 0.075
        for _, child in ipairs(Camera:GetChildren()) do
            if child:IsA("Model") then
                local statsFolder = child:FindFirstChild("Stats")
                if statsFolder then
                    local defaultVal = statsFolder:FindFirstChild("Default")
                    if defaultVal and defaultVal:IsA("Vector3Value") then
                        defaultVal.Value = Vector3.new(xOffset, yOffset, zOffset)
                    end
                end
            end
        end
    end)
end)
-- =========================================================================
-- [ 武器透视 (Chams) ]
-- =========================================================================

local WeaponChamsBox = Tabs.World:AddRightGroupbox("武器透视", "eye")

WeaponChamsBox:AddToggle("WeaponChamsEnabled", {
    Text = "启用武器透视",
    Default = false,
}):AddColorPicker("WeaponChamsColor", {
    Default = Color3.fromRGB(0, 150, 255),
    Title = "透视颜色",
})

WeaponChamsBox:AddDropdown("WeaponChamsMode", {
    Text = "透视材质/类型",
    Values = {"玻璃", "力场", "金属", "高亮", "霓虹"},
    Default = "玻璃",
})

WeaponChamsBox:AddSlider("GlassTransparency", { Text = "玻璃透明度", Default = 0.4, Min = 0, Max = 1, Rounding = 2 })
WeaponChamsBox:AddSlider("MetalReflectance", { Text = "金属反射率", Default = 1.0, Min = 0, Max = 1, Rounding = 1 })

local activeNeonHighlights = {}

RunService.RenderStepped:Connect(function()
    pcall(function()
        local chamsEnabled = Toggles.WeaponChamsEnabled and Toggles.WeaponChamsEnabled.Value
        local chamsMode = Options.WeaponChamsMode and Options.WeaponChamsMode.Value or "玻璃"
        local chamsColor = Options.WeaponChamsColor and Options.WeaponChamsColor.Value or Color3.fromRGB(0, 150, 255)

        local weaponModel = nil
        for _, child in ipairs(Camera:GetChildren()) do
            if child:IsA("Model") and child.Name ~= "Viewmodel" and not child.Name:lower():find("light") then
                local w = child:FindFirstChild("Weapon") or child
                if w:IsA("Model") and w.Name ~= "Viewmodel" and not w.Name:lower():find("light") then
                    weaponModel = w
                    break
                end
            end
        end

        if not chamsEnabled or not weaponModel then
            for _, h in pairs(activeNeonHighlights) do
                if h and h.Parent then h:Destroy() end
            end
            activeNeonHighlights = {}
            if not chamsEnabled or not weaponModel then return end
        end

        local currentNeonParts = {}

        for _, part in ipairs(weaponModel:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "Hitbox" and part.Name ~= "HumanoidRootPart" then
                if part.Name == "ViewmodelLight" or part:FindFirstAncestor("ViewmodelLight") or part:FindFirstAncestor("Viewmodel") then
                    continue
                end
                pcall(function()
                    if chamsMode == "高亮" then
                        currentNeonParts[part] = true
                        local h = part:FindFirstChild("WeaponChamsHighlight")
                        if not h then
                            h = Instance.new("Highlight")
                            h.Name = "WeaponChamsHighlight"
                            h.Adornee = part
                            h.Parent = part
                            h.FillTransparency = 0
                            h.OutlineTransparency = 1
                            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            table.insert(activeNeonHighlights, h)
                        end
                        h.FillColor = chamsColor
                    else
                        local h = part:FindFirstChild("WeaponChamsHighlight")
                        if h then h:Destroy() end
                        if chamsMode ~= "霓虹" then
                            for _, v in ipairs(part:GetChildren()) do
                                if v:IsA("SurfaceAppearance") or v:IsA("Texture") or v:IsA("Decal") then v:Destroy() end
                            end
                        end
                        if chamsMode == "玻璃" then
                            part.Material = Enum.Material.Glass
                            part.Color = chamsColor
                            part.Transparency = Options.GlassTransparency and Options.GlassTransparency.Value or 0.4
                        elseif chamsMode == "力场" then
                            part.Material = Enum.Material.ForceField
                            part.Color = chamsColor
                            part.Transparency = 0
                        elseif chamsMode == "金属" then
                            part.Material = Enum.Material.Metal
                            part.Color = chamsColor
                            part.Reflectance = Options.MetalReflectance and Options.MetalReflectance.Value or 1.0
                            part.Transparency = 0
                        elseif chamsMode == "霓虹" then
                            part.Material = Enum.Material.Neon
                            part.Color = chamsColor
                            part.Transparency = 0
                            for _, v in ipairs(part:GetChildren()) do
                                if v:IsA("SurfaceAppearance") or v:IsA("Texture") or v:IsA("Decal") then v:Destroy() end
                            end
                        end
                    end
                end)
            end
        end

        if chamsMode == "高亮" then
            for i = #activeNeonHighlights, 1, -1 do
                local h = activeNeonHighlights[i]
                if not h or not h.Parent or not currentNeonParts[h.Adornee] then
                    if h then h:Destroy() end
                    table.remove(activeNeonHighlights, i)
                end
            end
        end
    end)
end)
-- =========================================================================
-- [ 战斗选项卡 - MEMESENSE 模式 ]
-- =========================================================================

local CubeCombatBox = Tabs.Combat:AddLeftGroupbox("Memesense 模式", "crosshair")

CubeCombatBox:AddToggle("MemesenseMainToggle", {
    Text = "Memesense 模式",
    Default = false,
}):AddKeyPicker("MemesenseKeybind", {
    Text = "Memesense 模式快捷键",
    Default = "None",
    Mode = "Toggle",
})

local MemesenseDepBox = CubeCombatBox:AddDependencyBox()

MemesenseDepBox:AddToggle("CubeAimbotEnabled", { Text = "启用方块智能自瞄", Default = false })
MemesenseDepBox:AddToggle("CubeVisibleCheck", { Text = "启用可见性检查", Default = false })

MemesenseDepBox:AddDropdown("CubeHitPart", {
    Text = "目标命中部位选择",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Default = "Head",
})

MemesenseDepBox:AddDivider()

MemesenseDepBox:AddToggle("CubeTriggerbot", { Text = "启用扳机机器人", Default = false })
MemesenseDepBox:AddSlider("CubeTriggerbotDelay", { Text = "扳机延迟", Default = 0.01, Min = 0, Max = 1, Rounding = 3 })

MemesenseDepBox:AddDivider()

MemesenseDepBox:AddToggle("BulletImpactV1Enabled", {
    Text = "方块检查器",
    Default = false,
}):AddColorPicker("BulletImpactV1Color", {
    Default = Color3.fromRGB(255, 0, 0),
    Title = "方块检查器颜色",
})

MemesenseDepBox:AddToggle("BulletImpactV1Rainbow", {
    Text = "方块检查器彩虹模式",
    Default = false,
})

MemesenseDepBox:AddSlider("BulletImpactV1Size", {
    Text = "弹着点大小",
    Default = 1.5,
    Min = 0.5,
    Max = 4,
    Rounding = 1,
    Suffix = "单位"
})

MemesenseDepBox:AddSlider("BulletImpactV1Dist", {
    Text = "最大射线距离",
    Default = 20,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Suffix = "米"
})

MemesenseDepBox:AddDivider()

MemesenseDepBox:AddToggle("ShowTargetPlayer", { Text = "显示目标玩家", Default = false })

MemesenseDepBox:AddDropdown("ShowTargetMode", {
    Text = "目标显示模式",
    Values = {"线条", "准星"},
    Default = "准星",
})

MemesenseDepBox:AddLabel("线条颜色"):AddColorPicker("ShowTargetLineColor", {
    Default = Color3.fromRGB(0, 255, 255),
    Title = "线条颜色",
})

MemesenseDepBox:AddLabel("准星颜色"):AddColorPicker("ShowTargetCrosshairColor", {
    Default = Color3.fromRGB(0, 255, 255),
    Title = "准星颜色",
})

CubeCombatBox:AddToggle("ShowPenetration", { Text = "显示穿透", Default = false })

MemesenseDepBox:SetupDependencies({ {Toggles.MemesenseMainToggle, true} })
-- =========================================================================
-- [ 穿透可视化器 ]
-- =========================================================================

task.spawn(function()
    local PenText = Drawing.new("Text")
    PenText.Visible = false
    PenText.Center = true
    PenText.Size = 18
    PenText.Font = 2
    PenText.Color = Color3.fromRGB(0, 255, 0)
    PenText.Outline = true

    local penParams = RaycastParams.new()
    penParams.FilterType = Enum.RaycastFilterType.Exclude
    penParams.CollisionGroup = "Bullet"

    RunService.RenderStepped:Connect(function()
        local show = Toggles.ShowPenetration and Toggles.ShowPenetration.Value
        local cam = Workspace.CurrentCamera
        if show and cam then
            PenText.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2 - 70)
            local ignore = {LP.Character, cam, Workspace:FindFirstChild("BacktrackChams")}
            penParams.FilterDescendantsInstances = ignore
            local res = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1000, penParams)
            if res then
                local stats = GetPenetrationStats(cam.CFrame.Position, cam.CFrame.LookVector, 4, {LP.Character, cam}, nil)
                if stats.Success then
                    PenText.Visible = true
                    PenText.Text = string.format("穿墙: 是\n(%.1f 单位)", stats.TotalThickness or 0)
                    PenText.Color = Color3.fromRGB(0, 255, 0)
                else
                    PenText.Visible = true
                    PenText.Text = "穿墙: 否"
                    PenText.Color = Color3.fromRGB(255, 0, 0)
                end
            else
                PenText.Visible = false
            end
        else
            PenText.Visible = false
        end
    end)
end)
-- =========================================================================
-- [ 命中音效 ]
-- =========================================================================

local HitSoundBox = Tabs.World:AddLeftGroupbox("命中音效", "volume-2")

HitSoundBox:AddToggle("HitSoundEnabled", { Text = "启用命中音效", Default = false })
HitSoundBox:AddToggle("CustomHitSoundToggle", { Text = "启用自定义命中音效", Default = false })
HitSoundBox:AddSlider("HitSoundVolume", { Text = "命中音效音量", Default = 1, Min = 0.1, Max = 5, Rounding = 1, Suffix = "倍" })

local HitSoundPresets = {
    ["Neverlose"] = "rbxassetid://139452805868562",
    ["Skeet"] = "rbxassetid://83717596220569",
    ["Bell"] = "rbxassetid://96481309571950",
    ["Bell2"] = "rbxassetid://124010691633262",
    ["Bubble"] = "rbxassetid://104824514322839",
    ["Rust"] = "rbxassetid://1255040462",
    ["Agro1"] = "rbxassetid://132463144859699",
    ["Agro2"] = "rbxassetid://102651850556408",
    ["Coins"] = "rbxassetid://5613553529",
    ["Schaater"] = "rbxassetid://17405655409",
    ["Pick"] = "rbxassetid://8616930816"
}

HitSoundBox:AddDropdown("HitSoundPreset", {
    Text = "命中音效预设",
    Values = {"Neverlose", "Skeet", "Bell", "Bell2", "Bubble", "Rust", "Agro1", "Agro2", "Coins", "Schaater", "Pick"},
    Default = "Neverlose",
})

HitSoundBox:AddInput("CustomHitSoundID", {
    Text = "自定义音效ID",
    Default = "",
    Placeholder = "纯数字ID 或 rbxassetid://...",
})

local function PlayHitSound()
    pcall(function()
        if not Toggles.HitSoundEnabled.Value then return end
        local soundId = ""
        if Toggles.CustomHitSoundToggle and Toggles.CustomHitSoundToggle.Value then
            local customInput = Options.CustomHitSoundID and Options.CustomHitSoundID.Value
            if customInput and customInput ~= "" then
                if not customInput:find("rbxassetid://") then
                    local cleanId = customInput:gsub("%D", "")
                    if cleanId ~= "" then soundId = "rbxassetid://" .. cleanId end
                else
                    soundId = customInput
                end
            end
        end
        if soundId == "" then
            soundId = HitSoundPresets[Options.HitSoundPreset.Value] or "rbxassetid://139452805868562"
        end
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = Options.HitSoundVolume and Options.HitSoundVolume.Value or 1
        sound.Parent = SoundService
        sound:Play()
        task.spawn(function()
            sound.Ended:Wait()
            sound:Destroy()
        end)
    end)
end
-- =========================================================================
-- [ 自定义相机 ]
-- =========================================================================

local CustomCameraBox = Tabs.World:AddRightGroupbox("自定义相机", "video")

CustomCameraBox:AddToggle("CustomFovToggle", {
    Text = "自定义视场角",
    Default = false,
}):AddKeyPicker("CustomFovKey", { Text = "自定义视场角快捷键", Default = "One", Mode = "Always" })

CustomCameraBox:AddSlider("FovAmount", { Text = "视场角数值", Default = 90, Min = 70, Max = 120, Rounding = 0, Suffix = "度" })

CustomCameraBox:AddToggle("ThirdPerson", {
    Text = "第三人称相机",
    Default = false,
    Callback = function(Value)
        if Value then
            LP.CameraMode = Enum.CameraMode.Classic
            LP.CameraMaxZoomDistance = Options.ThirdPersonDist and Options.ThirdPersonDist.Value or 10
            LP.CameraMinZoomDistance = Options.ThirdPersonDist and Options.ThirdPersonDist.Value or 10
        else
            LP.CameraMode = Enum.CameraMode.LockFirstPerson
            LP.CameraMaxZoomDistance = 0.5
            LP.CameraMinZoomDistance = 0.5
        end
    end
})

CustomCameraBox:AddSlider("ThirdPersonDist", {
    Text = "第三人称距离",
    Default = 10,
    Min = 5,
    Max = 50,
    Rounding = 1,
    Suffix = "单位",
    Callback = function(Value)
        if Toggles.ThirdPerson and Toggles.ThirdPerson.Value then
            LP.CameraMaxZoomDistance = Value
            LP.CameraMinZoomDistance = Value
        end
    end
})
-- =========================================================================
-- [ 自定义瞄准镜 ]
-- =========================================================================

local CustomScopeBox = Tabs.World:AddRightGroupbox("自定义瞄准镜", "crosshair")

CustomScopeBox:AddToggle("CustomScopeFov", { Text = "自定义瞄准镜视场角", Default = false })
CustomScopeBox:AddSlider("ScopeFovValue", { Text = "瞄准镜视场角", Default = 70, Min = 10, Max = 100, Rounding = 1, Suffix = "度" })
CustomScopeBox:AddToggle("RemoveScope", { Text = "移除瞄准镜", Default = false })
CustomScopeBox:AddDivider()

CustomScopeBox:AddToggle("CustomScopeCrosshair", {
    Text = "瞄准镜准星",
    Default = false,
}):AddColorPicker("ScopeCrosshairColor", { Default = Color3.fromRGB(255, 255, 255), Title = "准星颜色" })

CustomScopeBox:AddSlider("ScopeCrosshairThickness", { Text = "准星粗细", Default = 2, Min = 1, Max = 10, Rounding = 1, Suffix = "像素" })
CustomScopeBox:AddSlider("ScopeCrosshairLengthLR", { Text = "左右长度", Default = 150, Min = 0, Max = 1000, Rounding = 0, Suffix = "像素" })
CustomScopeBox:AddSlider("ScopeCrosshairLengthTB", { Text = "上下长度", Default = 100, Min = 0, Max = 1000, Rounding = 0, Suffix = "像素" })
-- =========================================================================
-- [ 命中标记 ]
-- =========================================================================

local HitMarkerBox = Tabs.World:AddLeftGroupbox("命中标记", "crosshair")

HitMarkerBox:AddToggle("HitMarkerEnabled", {
    Text = "启用命中标记",
    Default = false,
}):AddColorPicker("HitMarkerColor", { Default = Color3.fromRGB(255, 255, 255), Title = "命中标记颜色" })

HitMarkerBox:AddToggle("HitMarkerRainbow", { Text = "彩虹模式", Default = false })
HitMarkerBox:AddSlider("HitMarkerDuration", { Text = "显示持续时间", Default = 2, Min = 0.5, Max = 5, Rounding = 1, Suffix = "秒" })
HitMarkerBox:AddSlider("HitMarkerSpinSpeed", { Text = "旋转速度", Default = 720, Min = 0, Max = 1440, Rounding = 0, Suffix = "度/秒" })
HitMarkerBox:AddSlider("HitMarkerSize", { Text = "大小", Default = 25, Min = 5, Max = 50, Rounding = 0, Suffix = "像素" })
HitMarkerBox:AddSlider("HitMarkerThickness", { Text = "粗细", Default = 2, Min = 1, Max = 6, Rounding = 1, Suffix = "像素" })

local TriggerHitMarkerEvent = nil

task.spawn(function()
    local activeHitMarkers = {}

    TriggerHitMarkerEvent = function(hitPos)
        if not Toggles.HitMarkerEnabled or not Toggles.HitMarkerEnabled.Value then return end
        local dur = Options.HitMarkerDuration and Options.HitMarkerDuration.Value or 2
        local thick = Options.HitMarkerThickness and Options.HitMarkerThickness.Value or 2
        local lines = {}
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Thickness = thick
            line.Transparency = 1
            line.Visible = false
            lines[i] = line
        end
        table.insert(activeHitMarkers, {
            lines = lines,
            worldPos = hitPos,
            spawnTick = tick(),
            expireTick = tick() + dur
        })
    end

    RunService.RenderStepped:Connect(function()
        pcall(function()
            local currentTick = tick()
            local enabled = Toggles.HitMarkerEnabled and Toggles.HitMarkerEnabled.Value
            local col = Options.HitMarkerColor and Options.HitMarkerColor.Value or Color3.fromRGB(255, 255, 255)
            if Toggles.HitMarkerRainbow and Toggles.HitMarkerRainbow.Value then
                col = Color3.fromHSV((currentTick % 5) / 5, 1, 1)
            end
            local baseSize = Options.HitMarkerSize and Options.HitMarkerSize.Value or 25
            local spinSpeed = Options.HitMarkerSpinSpeed and Options.HitMarkerSpinSpeed.Value or 720
            local pulseFactor = 1 + 0.35 * math.sin(currentTick * math.pi)
            local currentSize = baseSize * pulseFactor
            local gap = 6 * pulseFactor

            for i = #activeHitMarkers, 1, -1 do
                local data = activeHitMarkers[i]
                if not enabled or currentTick > data.expireTick then
                    for _, line in ipairs(data.lines) do pcall(function() line:Remove() end) end
                    table.remove(activeHitMarkers, i)
                else
                    local screenPos, onScreen = Camera:WorldToViewportPoint(data.worldPos)
                    if onScreen then
                        local center = Vector2.new(screenPos.X, screenPos.Y)
                        local lifetime = currentTick - data.spawnTick
                        local currentAngle = math.rad((lifetime * spinSpeed) % 360)
                        local baseAngles = {0, 90, 180, 270}
                        for j = 1, 4 do
                            local line = data.lines[j]
                            line.Color = col
                            line.Thickness = Options.HitMarkerThickness and Options.HitMarkerThickness.Value or 2
                            local totalAngle = currentAngle + math.rad(baseAngles[j])
                            local cosA = math.cos(totalAngle)
                            local sinA = math.sin(totalAngle)
                            line.From = center + Vector2.new(cosA * gap, sinA * gap)
                            line.To = center + Vector2.new(cosA * (gap + currentSize), sinA * (gap + currentSize))
                            line.Visible = true
                        end
                    else
                        for _, line in ipairs(data.lines) do line.Visible = false end
                    end
                end
            end
        end)
    end)
end)
-- =========================================================================
-- [ 瞄准镜准星 GUI ]
-- =========================================================================

task.spawn(function()
    local CoreGui = game:GetService("CoreGui")
    local crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "BloxStrike_GdcScopeCrosshair"
    crosshairGui.ResetOnSpawn = false
    pcall(function() crosshairGui.Parent = CoreGui end)

    local container = Instance.new("Frame", crosshairGui)
    container.BackgroundTransparency = 1
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.Size = UDim2.new(0, 0, 0, 0)

    local leftLine = Instance.new("Frame", container)
    leftLine.AnchorPoint = Vector2.new(1, 0.5)
    leftLine.BorderSizePixel = 0

    local rightLine = Instance.new("Frame", container)
    rightLine.AnchorPoint = Vector2.new(0, 0.5)
    rightLine.BorderSizePixel = 0

    local topLine = Instance.new("Frame", container)
    topLine.AnchorPoint = Vector2.new(0.5, 1)
    topLine.BorderSizePixel = 0

    local bottomLine = Instance.new("Frame", container)
    bottomLine.AnchorPoint = Vector2.new(0.5, 0)
    bottomLine.BorderSizePixel = 0

    RunService.RenderStepped:Connect(function()
        pcall(function()
            local isScoped = false
            local playerGui = LP:FindFirstChild("PlayerGui")
            if playerGui then
                local s, scope = pcall(function() return playerGui.MainGui.Gameplay.Middle.SniperScope end)
                if s and scope and scope.Visible then isScoped = true end
            end
            local enabled = Toggles.CustomScopeCrosshair and Toggles.CustomScopeCrosshair.Value and isScoped
            container.Visible = enabled
            if enabled then
                local col = Options.ScopeCrosshairColor and Options.ScopeCrosshairColor.Value or Color3.fromRGB(255, 255, 255)
                leftLine.BackgroundColor3 = col
                rightLine.BackgroundColor3 = col
                topLine.BackgroundColor3 = col
                bottomLine.BackgroundColor3 = col
                local t = Options.ScopeCrosshairThickness and Options.ScopeCrosshairThickness.Value or 2
                local lenLR = Options.ScopeCrosshairLengthLR and Options.ScopeCrosshairLengthLR.Value or 150
                local lenTB = Options.ScopeCrosshairLengthTB and Options.ScopeCrosshairLengthTB.Value or 100
                leftLine.Size = UDim2.new(0, lenLR, 0, t)
                leftLine.Position = UDim2.new(0, 0, 0, 0)
                rightLine.Size = UDim2.new(0, lenLR, 0, t)
                rightLine.Position = UDim2.new(0, 0, 0, 0)
                topLine.Size = UDim2.new(0, t, 0, lenTB)
                topLine.Position = UDim2.new(0, 0, 0, 0)
                bottomLine.Size = UDim2.new(0, t, 0, lenTB)
                bottomLine.Position = UDim2.new(0, 0, 0, 0)
            end
        end)
    end)
end)
-- =========================================================================
-- [ 移除瞄准镜 ]
-- =========================================================================

task.spawn(function()
    local CachedSniperScope = nil
    RunService.RenderStepped:Connect(function()
        if CachedSniperScope and not CachedSniperScope.Parent then CachedSniperScope = nil end
        if not CachedSniperScope then
            local playerGui = LP:FindFirstChild("PlayerGui")
            if playerGui then
                local s, scope = pcall(function() return playerGui.MainGui.Gameplay.Middle.SniperScope end)
                if s and scope then CachedSniperScope = scope end
            end
        end
        local scopeFrame = CachedSniperScope
        if not Toggles.RemoveScope or not Toggles.RemoveScope.Value then
            if scopeFrame then
                if scopeFrame.Size ~= UDim2.new(1, 0, 1, 0) then scopeFrame.Size = UDim2.new(1, 0, 1, 0) end
            end
            return
        end
        if scopeFrame then
            if scopeFrame.Visible == true then
                scopeFrame.Size = UDim2.new(0, 0, 0, 0)
            else
                if scopeFrame.Size ~= UDim2.new(1, 0, 1, 0) then scopeFrame.Size = UDim2.new(1, 0, 1, 0) end
            end
        end
    end)
end)
-- =========================================================================
-- [ 自定义瞄准镜视场角 ]
-- =========================================================================

task.spawn(function()
    RunService.RenderStepped:Connect(function()
        pcall(function()
            if Toggles.CustomScopeFov and Toggles.CustomScopeFov.Value then
                local cam = Workspace.CurrentCamera
                if cam then
                    local playerGui = LP:FindFirstChild("PlayerGui")
                    if playerGui then
                        local scope = playerGui:FindFirstChild("MainGui") and
                            playerGui.MainGui:FindFirstChild("Gameplay") and
                            playerGui.MainGui.Gameplay:FindFirstChild("Middle") and
                            playerGui.MainGui.Gameplay.Middle:FindFirstChild("SniperScope")
                        if scope and scope.Visible and Options.ScopeFovValue then
                            cam.FieldOfView = Options.ScopeFovValue.Value
                        end
                    end
                end
            end
        end)
    end)
end)
-- =========================================================================
-- [ 第三人称元表钩子 ]
-- =========================================================================

task.spawn(function()
    if getrawmetatable and setreadonly then
        local mt = getrawmetatable(game)
        local oldNewIndex = mt.__newindex
        setreadonly(mt, false)
        mt.__newindex = newcclosure(function(self, key, value)
            if self == LP and Toggles.ThirdPerson and Toggles.ThirdPerson.Value then
                if key == "CameraMode" then
                    return oldNewIndex(self, key, Enum.CameraMode.Classic)
                elseif key == "CameraMaxZoomDistance" then
                    return oldNewIndex(self, key, Options.ThirdPersonDist and Options.ThirdPersonDist.Value or 10)
                elseif key == "CameraMinZoomDistance" then
                    return oldNewIndex(self, key, Options.ThirdPersonDist and Options.ThirdPersonDist.Value or 10)
                end
            end
            return oldNewIndex(self, key, value)
        end)
        setreadonly(mt, true)
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        if Toggles.CustomFovToggle and Toggles.CustomFovToggle.Value then
            local keypicker = Options.CustomFovKey
            local active = true
            if keypicker and keypicker.Value ~= "Always" and keypicker.Value ~= "One" then
                active = keypicker:GetState()
            end
            if active then
                local cam = Workspace.CurrentCamera
                if cam then cam.FieldOfView = Options.FovAmount.Value or 90 end
            end
        end
        if Toggles.ThirdPerson and Toggles.ThirdPerson.Value then
            local clampedDist = math.clamp(Options.ThirdPersonDist and Options.ThirdPersonDist.Value or 10, 5, 50)
            LP.CameraMode = Enum.CameraMode.Classic
            LP.CameraMaxZoomDistance = clampedDist
            LP.CameraMinZoomDistance = clampedDist
        end
    end)
end)
-- =========================================================================
-- [ 天空盒系统 ]
-- =========================================================================

local skyboxtable = {
    ["夜晚"] = {
        SkyboxBk = "rbxassetid://1514717643", SkyboxDn = "rbxassetid://1514716936",
        SkyboxFt = "rbxassetid://1514715910", SkyboxLf = "rbxassetid://1514714945",
        SkyboxRt = "rbxassetid://1514714011", SkyboxUp = "rbxassetid://1514713374"
    },
    ["海洋日落"] = {
        SkyboxBk = "rbxassetid://17525686840", SkyboxDn = "rbxassetid://17525678473",
        SkyboxFt = "rbxassetid://17525684686", SkyboxLf = "rbxassetid://17525680663",
        SkyboxRt = "rbxassetid://17525682665", SkyboxUp = "rbxassetid://17525674545"
    },
    ["我的夏日车"] = {
        SkyboxBk = "rbxassetid://16648590964", SkyboxDn = "rbxassetid://16648617436",
        SkyboxFt = "rbxassetid://16648595424", SkyboxLf = "rbxassetid://16648566370",
        SkyboxRt = "rbxassetid://16648577071", SkyboxUp = "rbxassetid://16648598180"
    },
    ["标准"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=91458024",
        SkyboxDn = "http://www.roblox.com/asset/?id=91457980",
        SkyboxFt = "http://www.roblox.com/asset/?id=91458024",
        SkyboxLf = "http://www.roblox.com/asset/?id=91458024",
        SkyboxRt = "http://www.roblox.com/asset/?id=91458024",
        SkyboxUp = "http://www.roblox.com/asset/?id=91458002"
    },
    ["我的世界"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=8735166756",
        SkyboxDn = "http://www.roblox.com/asset/?id=8735166707",
        SkyboxFt = "http://www.roblox.com/asset/?id=8735231668",
        SkyboxLf = "http://www.roblox.com/asset/?id=8735166755",
        SkyboxRt = "http://www.roblox.com/asset/?id=8735166751",
        SkyboxUp = "http://www.roblox.com/asset/?id=8735166729"
    },
    ["海绵宝宝"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=277099484",
        SkyboxDn = "http://www.roblox.com/asset/?id=277099500",
        SkyboxFt = "http://www.roblox.com/asset/?id=277099554",
        SkyboxLf = "http://www.roblox.com/asset/?id=277099531",
        SkyboxRt = "http://www.roblox.com/asset/?id=277099589",
        SkyboxUp = "http://www.roblox.com/asset/?id=277101591"
    },
    ["深空"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=159248188",
        SkyboxDn = "http://www.roblox.com/asset/?id=159248183",
        SkyboxFt = "http://www.roblox.com/asset/?id=159248187",
        SkyboxLf = "http://www.roblox.com/asset/?id=159248173",
        SkyboxRt = "http://www.roblox.com/asset/?id=159248192",
        SkyboxUp = "http://www.roblox.com/asset/?id=159248176"
    },
    ["多云天空"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=252760981",
        SkyboxDn = "http://www.roblox.com/asset/?id=252763035",
        SkyboxFt = "http://www.roblox.com/asset/?id=252761439",
        SkyboxLf = "http://www.roblox.com/asset/?id=252760980",
        SkyboxRt = "http://www.roblox.com/asset/?id=252760986",
        SkyboxUp = "http://www.roblox.com/asset/?id=252762652"
    },
    ["复古"] = {
        SkyboxBk = "rbxasset://sky/null_plainsky512_bk.jpg",
        SkyboxDn = "rbxasset://sky/null_plainsky512_dn.jpg",
        SkyboxFt = "rbxasset://sky/null_plainsky512_ft.jpg",
        SkyboxLf = "rbxasset://sky/null_plainsky512_lf.jpg",
        SkyboxRt = "rbxasset://sky/null_plainsky512_rt.jpg",
        SkyboxUp = "rbxasset://sky/null_plainsky512_up.jpg"
    },
    ["城市"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=9134792889",
        SkyboxDn = "http://www.roblox.com/asset/?id=9134791975",
        SkyboxFt = "http://www.roblox.com/asset/?id=9134793457",
        SkyboxLf = "http://www.roblox.com/asset/?id=9134791234",
        SkyboxRt = "http://www.roblox.com/asset/?id=9134790419",
        SkyboxUp = "http://www.roblox.com/asset/?id=9134791633"
    },
    ["紫色星云"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=15983968922",
        SkyboxDn = "http://www.roblox.com/asset/?id=15983966825",
        SkyboxFt = "http://www.roblox.com/asset/?id=15983965025",
        SkyboxLf = "http://www.roblox.com/asset/?id=15983967420",
        SkyboxRt = "http://www.roblox.com/asset/?id=15983966246",
        SkyboxUp = "http://www.roblox.com/asset/?id=15983964246"
    },
    ["粉色天空"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=7890140060",
        SkyboxDn = "http://www.roblox.com/asset/?id=7890140060",
        SkyboxFt = "http://www.roblox.com/asset/?id=7890140060",
        SkyboxLf = "http://www.roblox.com/asset/?id=7890140060",
        SkyboxRt = "http://www.roblox.com/asset/?id=7890140060",
        SkyboxUp = "http://www.roblox.com/asset/?id=7890140060"
    }
}

local skyNames = {}
for k, _ in pairs(skyboxtable) do table.insert(skyNames, k) end
table.sort(skyNames)

local function UpdateSkybox(name)
    local data = skyboxtable[name]
    if not data then return end
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") or v:IsA("Clouds") then v:Destroy() end
    end
    local sky = Lighting:FindFirstChild("Memesense_Sky")
    if not sky then
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("Sky") then v:Destroy() end
        end
        sky = Instance.new("Sky")
        sky.Name = "Memesense_Sky"
        sky.Parent = Lighting
    end
    sky.SkyboxBk = data.SkyboxBk
    sky.SkyboxDn = data.SkyboxDn
    sky.SkyboxFt = data.SkyboxFt
    sky.SkyboxLf = data.SkyboxLf
    sky.SkyboxRt = data.SkyboxRt
    sky.SkyboxUp = data.SkyboxUp
    sky.SunTextureId = ""
    sky.MoonTextureId = ""
    sky.StarCount = 0
end
-- =========================================================================
-- [ 天气系统 ]
-- =========================================================================

local WeatherPart = nil
local GroundPart = nil

local function UpdateWeather(wType)
    if WeatherPart then WeatherPart:Destroy() WeatherPart = nil end
    if GroundPart then GroundPart:Destroy() GroundPart = nil end
    for _, v in pairs(Workspace:GetChildren()) do
        if v.Name == "Memesense_RainDrop" then v:Destroy() end
    end
    if wType == "无" then return end

    WeatherPart = Instance.new("Part")
    WeatherPart.Name = "Memesense_Weather_Sky"
    WeatherPart.Size = Vector3.new(100, 1, 100)
    WeatherPart.Transparency = 1
    WeatherPart.Anchored = true
    WeatherPart.CanCollide = false
    WeatherPart.Parent = Workspace.CurrentCamera
    local SkyEmitter = Instance.new("ParticleEmitter")
    SkyEmitter.Parent = WeatherPart
    SkyEmitter.EmissionDirection = Enum.NormalId.Bottom
    SkyEmitter.Enabled = true

    GroundPart = Instance.new("Part")
    GroundPart.Name = "Memesense_Weather_Ground"
    GroundPart.Size = Vector3.new(50, 1, 50)
    GroundPart.Transparency = 1
    GroundPart.Anchored = true
    GroundPart.CanCollide = false
    GroundPart.Parent = Workspace.CurrentCamera
    local GroundEmitter = Instance.new("ParticleEmitter")
    GroundEmitter.Parent = GroundPart
    GroundEmitter.Enabled = false

    if wType == "雨" then
        SkyEmitter.Texture = "rbxassetid://241868005"
        SkyEmitter.Rate = 10000
        SkyEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        SkyEmitter.LightEmission = 0.2
        SkyEmitter.Transparency = NumberSequence.new(0)
        SkyEmitter.Size = NumberSequence.new(3, 6)
        SkyEmitter.Lifetime = NumberRange.new(2, 2.5)
        SkyEmitter.Speed = NumberRange.new(80, 100)
        SkyEmitter.SpreadAngle = Vector2.new(0, 0)
        SkyEmitter.Acceleration = Vector3.new(0, -50, 0)
        SkyEmitter.Orientation = Enum.ParticleOrientation.FacingCamera
    elseif wType == "雪" then
        SkyEmitter.Texture = "rbxassetid://99851851"
        SkyEmitter.Rate = 200
        SkyEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        SkyEmitter.Size = NumberSequence.new(0.25, 0.35)
        SkyEmitter.Speed = NumberRange.new(30, 30)
        SkyEmitter.Lifetime = NumberRange.new(5, 10)
        SkyEmitter.Acceleration = Vector3.new(0, 0, 0)
        SkyEmitter.SpreadAngle = Vector2.new(50, 50)
        SkyEmitter.LightEmission = 0.5
        SkyEmitter.Rotation = NumberRange.new(0, 0)
        SkyEmitter.RotSpeed = NumberRange.new(0, 0)
    elseif wType == "地狱火" then
        SkyEmitter.Texture = "rbxassetid://242205518"
        SkyEmitter.Rate = 400
        SkyEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0), Color3.fromRGB(150, 0, 0))
        SkyEmitter.Size = NumberSequence.new(2, 4)
        SkyEmitter.Speed = NumberRange.new(40, 60)
        SkyEmitter.Lifetime = NumberRange.new(2, 3)
        SkyEmitter.Acceleration = Vector3.new(0, -10, 0)
        SkyEmitter.RotSpeed = NumberRange.new(50, 100)
    end
end
-- =========================================================================
-- [ 光照系统 ]
-- =========================================================================

local DefaultLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows
}

local function UpdateLighting()
    if Toggles.EnableTime and Toggles.EnableTime.Value then
        Lighting.ClockTime = Options.WorldClockTime.Value
    else
        Lighting.ClockTime = DefaultLighting.ClockTime
    end
    if Toggles.EnableBrightness and Toggles.EnableBrightness.Value then
        Lighting.Brightness = Options.WorldBrightness.Value
    else
        Lighting.Brightness = DefaultLighting.Brightness
    end
    if Toggles.EnableColors and Toggles.EnableColors.Value then
        Lighting.Ambient = Options.WorldAmbient.Value
        Lighting.OutdoorAmbient = Options.WorldOutdoorAmbient.Value
    else
        Lighting.Ambient = DefaultLighting.Ambient
        Lighting.OutdoorAmbient = DefaultLighting.OutdoorAmbient
    end
end

WorldBox:AddToggle("EnableSkybox", {
    Text = "启用天空盒",
    Default = false,
    Callback = function(v)
        if v then
            if Toggles.Atmosphere and Toggles.Atmosphere.Value then Toggles.Atmosphere:SetValue(false) end
            UpdateSkybox(Options.SkyboxPreset.Value)
        end
    end
})

WorldBox:AddDropdown("SkyboxPreset", {
    Text = "天空盒预设",
    Values = skyNames,
    Default = "夜晚",
    Callback = function(v) if Toggles.EnableSkybox.Value then UpdateSkybox(v) end end
})

WorldBox:AddDropdown("WeatherType", {
    Text = "天气",
    Values = {"无", "雨", "雪", "地狱火"},
    Default = "无",
    Callback = function(v) UpdateWeather(v) end
})

WorldBox:AddToggle("EnableTime", { Text = "启用时间", Default = false, Callback = function(_) UpdateLighting() end })
WorldBox:AddSlider("WorldClockTime", { Text = "时钟时间", Default = 12, Min = 0, Max = 24, Rounding = 1, Suffix = "时", Callback = function(_) UpdateLighting() end })
WorldBox:AddToggle("EnableBrightness", { Text = "启用亮度", Default = false, Callback = function(_) UpdateLighting() end })
WorldBox:AddSlider("WorldBrightness", { Text = "亮度", Default = 2, Min = 0, Max = 10, Rounding = 1, Suffix = "倍", Callback = function(_) UpdateLighting() end })
WorldBox:AddToggle("EnableColors", { Text = "启用颜色", Default = false, Callback = function(_) UpdateLighting() end })

WorldBox:AddLabel("环境光颜色"):AddColorPicker("WorldAmbient", {
    Default = Color3.fromRGB(127, 127, 127),
    Title = "环境光颜色",
    Callback = function(_) UpdateLighting() end
})

WorldBox:AddLabel("室外光颜色"):AddColorPicker("WorldOutdoorAmbient", {
    Default = Color3.fromRGB(127, 127, 127),
    Title = "室外光颜色",
    Callback = function(_) UpdateLighting() end
})

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if Toggles.EnableSkybox and Toggles.EnableSkybox.Value then
                UpdateSkybox(Options.SkyboxPreset.Value)
            end
            UpdateLighting()
        end)
    end
end)

RunService.RenderStepped:Connect(function()
    if not Workspace.CurrentCamera then return end
    local CamCF = Workspace.CurrentCamera.CFrame
    if WeatherPart then WeatherPart.CFrame = CamCF * CFrame.new(0, 30, 0) end
end)
-- =========================================================================
-- [ 皮肤切换系统 ]
-- =========================================================================

local RS = ReplicatedStorage

local G = {
    knifeChangerSupported = true,
    executor = (identifyexecutor and identifyexecutor()) or "Unknown",
    inspectWarningShown = false
}

if string.find(G.executor, "RonixExploit", 1, true) or string.find(G.executor, "Xeno", 1, true) or string.find(G.executor, "Solara", 1, true) then
    G.knifeChangerSupported = false
end

local SD = {SkinsRoot = nil, SkinSelections = {}, GloveSelections = {}, GloveFolders = {}}

pcall(function()
    SD.SkinsRoot = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Skins")
end)

if SD.SkinsRoot then
    pcall(function()
        for _, wf in ipairs(SD.SkinsRoot:GetChildren()) do
            local skins = {}
            for _, sf in ipairs(wf:GetChildren()) do skins[#skins + 1] = sf.Name end
            table.sort(skins)
            SD.SkinSelections[wf.Name] = skins
        end
        for _, folder in ipairs(SD.SkinsRoot:GetChildren()) do
            if (folder.Name:match("Glove") or folder.Name:match("Gloves") or folder.Name == "Hand Wraps")
               and not (folder.Name:match("T Glove") or folder.Name:match("CT Glove") or folder.Name:match("T Gloves") or folder.Name:match("CT Gloves")) then
                SD.GloveFolders[#SD.GloveFolders + 1] = folder
            end
        end
    end)
end

for _, gf in ipairs(SD.GloveFolders) do
    local skins = {"默认"}
    for _, skin in ipairs(gf:GetChildren()) do skins[#skins + 1] = skin.Name end
    SD.GloveSelections[gf.Name] = skins
end

local Config = {
    SkinChanger = {Enabled = false, Skins = {}},
    KnifeChanger = {Enabled = false, Model = "Skeleton Knife"},
    GloveChanger = {Enabled = false, Gloves = {}, Model = "Sports Gloves", Skin = "默认"},
}

for w, s in pairs(SD.SkinSelections) do Config.SkinChanger.Skins[w] = s[1] or "默认" end
for _, gf in ipairs(SD.GloveFolders) do Config.GloveChanger.Gloves[gf.Name] = "默认" end

local Checkifbaseknife = {"CT Knife", "T Knife", "Knife"}
local function Checkknife(w)
    if not w then return false end
    for _, k in ipairs(Checkifbaseknife) do if w == k then return true end end
    return false
end

local SafeRequire = function(module)
    if not module then return nil end
    local success, result = pcall(function() return require(module) end)
    if success and result and type(result) == "table" then return result end
    return nil
end

local Router
pcall(function()
    local module = RS:FindFirstChild("Database") and RS.Database:FindFirstChild("Security") and RS.Database.Security:FindFirstChild("Router")
    if module then Router = SafeRequire(module) end
end)
local SkinsBox = Tabs.SkinChanger:AddLeftGroupbox("武器皮肤", "palette")
local GlovesBox = Tabs.SkinChanger:AddRightGroupbox("手套切换", "hand")
local KnifeBox = Tabs.SkinChanger:AddRightGroupbox("刀具切换", "sword")

SkinsBox:AddToggle("EnableSkins", {
    Text = "启用武器皮肤",
    Default = false,
    Callback = function(v) Config.SkinChanger.Enabled = v end
})

local KM = {"Karambit", "Butterfly Knife", "Flip Knife", "Gut Knife", "M9 Bayonet", "Skeleton Knife", "Stiletto Knife"}
local EW = {"Driver Gloves", "Sports Gloves", "Operator Gloves", "Hand Wraps"}

KnifeBox:AddToggle("KnifeChangerToggle", {
    Text = "启用刀具切换",
    Default = false,
    Callback = function(v) Config.KnifeChanger.Enabled = v end
})

KnifeBox:AddDropdown("KnifeModel", {
    Text = "刀具模型",
    Values = KM,
    Default = "Skeleton Knife",
    Callback = function(v) Config.KnifeChanger.Model = v end
})

for _, kn in ipairs(KM) do
    local ks = SD.SkinSelections[kn]
    if ks then
        KnifeBox:AddDropdown("KnifeSkin_" .. kn, {
            Text = kn .. " 皮肤",
            Values = ks,
            Default = 1,
            Callback = function(v) Config.SkinChanger.Skins[kn] = v end
        })
    end
end

GlovesBox:AddToggle("GloveChangerToggle", {
    Text = "启用手套切换",
    Default = false,
    Callback = function(v) Config.GloveChanger.Enabled = v end
})

local GM = {}
for k in pairs(SD.GloveSelections) do GM[#GM + 1] = k end
table.sort(GM)

GlovesBox:AddDropdown("GloveModel", {
    Text = "手套模型",
    Values = GM,
    Default = GM[1] or "Sports Gloves",
    Callback = function(v) Config.GloveChanger.Model = v end
})

for _, gFolder in ipairs(SD.GloveFolders) do
    local gName = gFolder.Name
    local gSkins = SD.GloveSelections[gName]
    if gSkins then
        GlovesBox:AddDropdown("GloveSkin_" .. gName, {
            Text = gName .. " 皮肤",
            Values = gSkins,
            Default = 1,
            Callback = function(v) Config.GloveChanger.Gloves[gName] = v end
        })
    end
end

for w, s in pairs(SD.SkinSelections) do
    if not table.find(KM, w) and not table.find(GM, w) and not table.find(EW, w) then
        SkinsBox:AddDropdown("Skin_" .. w, {
            Text = w,
            Values = s,
            Default = 1,
            Callback = function(v) Config.SkinChanger.Skins[w] = v end
        })
    end
end
local function InitKnifeChanger()
    pcall(function()
        local SM = RS:FindFirstChild("Database") and RS.Database:FindFirstChild("Components") and
            RS.Database.Components:FindFirstChild("Libraries") and
            RS.Database.Components.Libraries:FindFirstChild("Skins")
        local VM = RS:FindFirstChild("Classes") and RS.Classes:FindFirstChild("WeaponComponent") and
            RS.Classes.WeaponComponent:FindFirstChild("Classes") and
            RS.Classes.WeaponComponent.Classes:FindFirstChild("Viewmodel")
        if not SM or not VM then return end

        local Sk = SafeRequire(SM)
        local Vm = SafeRequire(VM)
        if not Sk or not Vm then return end

        local oGCM = Sk.GetCameraModel
        Sk.GetCameraModel = function(w, sk, ...)
            if Config.KnifeChanger.Enabled and w and Checkknife(w) then
                local newKnife = Config.KnifeChanger.Model
                local newSkin = Config.SkinChanger.Skins[newKnife] or "Vanilla"
                local success, result = pcall(oGCM, newKnife, newSkin, ...)
                if success and result then return result end
            end
            local success, result = pcall(oGCM, w, sk, ...)
            if success then return result end
            return nil
        end

        local oGChM = Sk.GetCharacterModel
        Sk.GetCharacterModel = function(w, sk, ...)
            if Config.KnifeChanger.Enabled and w and Checkknife(w) then
                local newKnife = Config.KnifeChanger.Model
                local newSkin = Config.SkinChanger.Skins[newKnife] or "Vanilla"
                local success, result = pcall(oGChM, newKnife, newSkin, ...)
                if success and result then return result end
            end
            local success, result = pcall(oGChM, w, sk, ...)
            if success then return result end
            return nil
        end

        local oVN = Vm.new
        Vm.new = function(vc, w, sk, ...)
            if Config.KnifeChanger.Enabled and w and Checkknife(w) then
                local newKnife = Config.KnifeChanger.Model
                local newSkin = Config.SkinChanger.Skins[newKnife] or "Vanilla"
                local success, result = pcall(oVN, vc, newKnife, newSkin, ...)
                if success and result then return result end
            end
            local success, result = pcall(oVN, vc, w, sk, ...)
            if success then return result end
            return nil
        end

        if Sk.GetGloves then
            local oGG = Sk.GetGloves
            Sk.GetGloves = function(g, sk)
                if Config.GloveChanger.Enabled and Config.GloveChanger.Model then
                    local gModel = Config.GloveChanger.Model
                    local ts = Config.GloveChanger.Gloves[gModel] or "默认"
                    local success, result = pcall(oGG, gModel, ts)
                    if success and result then return result end
                end
                local success, result = pcall(oGG, g, sk)
                if success then return result end
                return nil
            end
        end
    end)
end

if G.knifeChangerSupported then InitKnifeChanger() end
local function UpdateInventoryNames()
    local invGui = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("MainGui")
    if not invGui then return end
    local gameplay = invGui:FindFirstChild("Gameplay")
    if not gameplay then return end
    local bottom = gameplay:FindFirstChild("Bottom")
    if not bottom then return end
    local inv = bottom:FindFirstChild("Inventory")
    if not inv then return end
    local meleeSlot = inv:FindFirstChild("Melee")
    if meleeSlot and Config.KnifeChanger.Enabled then
        local weapon = meleeSlot:FindFirstChild("Weapon")
        if weapon then
            local weaponName = weapon:FindFirstChild("WeaponName")
            if weaponName and weaponName:IsA("TextLabel") then
                local knifeModel = Config.KnifeChanger.Model
                local sel = Config.SkinChanger.Skins[knifeModel]
                local star = utf8.char(9733)
                if sel and sel ~= "默认" then
                    weaponName.Text = star .. " " .. knifeModel .. " | " .. sel
                else
                    weaponName.Text = star .. " " .. knifeModel
                end
            end
        end
    end
end

local function GetWeaponModel()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    for _, ch in pairs(cam:GetChildren()) do
        if ch:IsA("Model") and ch.Name ~= "Arms" and ch.Name ~= "Arms1" and ch.Name ~= "Arms2" and ch.Name ~= "Viewmodel" then
            return ch
        end
    end
    return nil
end

local function ApplySkin()
    if not SD.SkinsRoot then return end
    local wm = GetWeaponModel()
    if not wm then return end
    local own = wm.Name
    local ewn = own
    local ca = false
    if Checkknife(own) then
        if Config.KnifeChanger.Enabled then ewn = Config.KnifeChanger.Model ca = true end
    else
        if Config.SkinChanger.Enabled then ca = true end
    end
    if not ca then return end
    local sel = Config.SkinChanger.Skins[ewn]
    if not sel or sel == "默认" then return end
    local wsf = SD.SkinsRoot:FindFirstChild(ewn)
    if not wsf then return end
    local sf = wsf:FindFirstChild(sel)
    if not sf then return end
    local cf = sf:FindFirstChild("Camera")
    if not cf then return end
    local fn = cf:FindFirstChild("Factory New")
    if not fn then return end
    for _, sa in pairs(fn:GetChildren()) do
        if sa:IsA("SurfaceAppearance") then
            local pt = wm:FindFirstChild(sa.Name, true)
            if pt and (pt:IsA("BasePart") or pt:IsA("MeshPart")) then
                for _, old in pairs(pt:GetChildren()) do
                    if old:IsA("SurfaceAppearance") then old:Destroy() end
                end
                sa:Clone().Parent = pt
            end
        end
    end
    UpdateInventoryNames()
end

local function ApplyGloves()
    if not Config.GloveChanger.Enabled then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local am
    for _, ch in ipairs(cam:GetChildren()) do
        if ch:IsA("Model") and (ch.Name:match("Arms") or ch:FindFirstChild("Right Arm")) then
            am = ch
            break
        end
    end
    if not am then return end
    local la = am:FindFirstChild("Left Arm")
    local ra = am:FindFirstChild("Right Arm")
    if not la or not ra then return end
    local lg = la:FindFirstChild("Glove")
    local rg = ra:FindFirstChild("Glove")
    if not lg or not rg then return end
    for _, old in pairs(lg:GetChildren()) do if old:IsA("SurfaceAppearance") then old:Destroy() end end
    for _, old in pairs(rg:GetChildren()) do if old:IsA("SurfaceAppearance") then old:Destroy() end end
    local selectedModel = Config.GloveChanger.Model
    if not selectedModel then return end
    local sel = Config.GloveChanger.Gloves[selectedModel]
    if not sel or sel == "默认" then return end
    if not SD.SkinsRoot then return end
    local gloveSkinFolder = SD.SkinsRoot:FindFirstChild(selectedModel)
    if not gloveSkinFolder then return end
    local skinVariant = gloveSkinFolder:FindFirstChild(sel)
    if not skinVariant then return end
    local cameraFolder = skinVariant:FindFirstChild("Camera")
    if not cameraFolder then return end
    local factoryNew = cameraFolder:FindFirstChild("Factory New")
    if not factoryNew then return end
    for _, sa in pairs(factoryNew:GetChildren()) do
        if sa:IsA("SurfaceAppearance") then
            sa:Clone().Parent = lg
            sa:Clone().Parent = rg
        end
    end
end

task.spawn(function()
    while true do
        pcall(function()
            if Config.SkinChanger.Enabled or Config.KnifeChanger.Enabled then ApplySkin() end
            if Config.GloveChanger.Enabled then ApplyGloves() end
        end)
        task.wait(0.5)
    end
end)
task.spawn(function()
    local lastShot = 0
    while true do
        task.wait(0.008)
        pcall(function()
            if not (Toggles.Ragebot and Toggles.Ragebot.Value) then return end

            -- 自动获取武器如果为空或已更换
            if not Weapon or not pcall(function() return Weapon.IsEquipped end) then
                if getCurrentEquipped then
                    Weapon = getEquipped()
                end
            end

            if not Weapon then return end
            if not Weapon.IsEquipped then return end

            local rounds = pcall(function() return Weapon.Rounds end) and Weapon.Rounds or 0
            if rounds <= 0 then return end

            if not RageTarget or not RageTarget.Parent then return end

            -- 检查目标是否存活
            local char = RageTarget:FindFirstAncestorOfClass("Model")
            if not char then return end
            if char:GetAttribute("Dead") or char:GetAttribute("Invincible") then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then return end

            -- 如果启用了可见性检查
            if Toggles.RagebotVisibleCheck and Toggles.RagebotVisibleCheck.Value then
                local _, onScreen = Camera:WorldToViewportPoint(RageTarget.Position)
                if not onScreen then return end
            end

            -- 如果启用了穿墙检查
            if Toggles.RagebotWallCheck and Toggles.RagebotWallCheck.Value then
                if not isVisible(RageTarget) then return end
            end

            local delay = Options.RageDelay and Options.RageDelay.Value or 0.02
            local now = tick()
            if now - lastShot < delay then return end
            lastShot = now

            Weapon:shoot()
        end)
    end
end)
-- =========================================================================
-- [ 武器选项卡 ]
-- =========================================================================

local WeaponModsBox = Tabs.Weapons:AddLeftGroupbox("武器修改", "wrench")
local GernadesBox = Tabs.Weapons:AddRightGroupbox("手雷", "bomb")

GernadesBox:AddToggle("Antiflashbang", {
    Text = "启用无闪光弹",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function",
    DisabledTooltip = "此功能在你的执行器上不可用。",
})

GernadesBox:AddToggle("Antismoke", {
    Text = "启用无烟雾",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function",
    DisabledTooltip = "此功能在你的执行器上不可用。",
})

WeaponModsBox:AddToggle("Firerate", {
    Text = "启用射速修改",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function",
    DisabledTooltip = "此功能在你的执行器上不可用。",
})

WeaponModsBox:AddSlider("FirerateSlider", { Text = "射速", Default = 0.01, Min = 0, Max = 1, Rounding = 3 })

WeaponModsBox:AddToggle("NoRecoil", {
    Text = "启用无后坐力",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function",
    DisabledTooltip = "此功能在你的执行器上不可用。",
})

WeaponModsBox:AddToggle("NoSpread", {
    Text = "启用无扩散",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function",
    DisabledTooltip = "此功能在你的执行器上不可用。",
})
-- =========================================================================
-- [ 战斗选项卡 - 暴力 + 狂暴 ]
-- =========================================================================

local CombatBlatantBox = Tabs.Combat:AddRightGroupbox("暴力", "zap")
local RageBlatantBox = Tabs.Combat:AddRightGroupbox("狂暴", "flame")

CombatBlatantBox:AddToggle("SilentAim", {
    Text = "启用静默瞄准",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function",
    DisabledTooltip = "此功能在你的执行器上不可用。",
})

local BlatantDependencyBox = CombatBlatantBox:AddDependencyBox()

BlatantDependencyBox:AddToggle("SilentWallbang", { Text = "穿墙", Default = false })

BlatantDependencyBox:AddToggle("SilentUseFovCircle", {
    Text = "使用视场角圆圈",
    Default = false,
}):AddColorPicker("SilentFovColor", { Default = Color3.fromRGB(255, 0, 0), Title = "静默视场角颜色" })

BlatantDependencyBox:AddSlider("SilentFovCircleRadius", { Text = "视场角半径", Default = 50, Min = 0, Max = 300, Rounding = 0 })

BlatantDependencyBox:AddDropdown("SilentHitPart", {
    Text = "命中部位选择",
    Values = {
        "HumanoidRootPart", "Head", "LeftLowerArm", "LowerTorso", "RightHand",
        "RightLowerArm", "LeftFoot", "LeftHand", "RightFoot", "RightLowerLeg",
        "LeftLowerLeg", "RightUpperArm", "LeftUpperArm", "UpperTorso", "RightUpperLeg", "LeftUpperLeg"
    },
    Default = "Head",
    Multi = false,
})

BlatantDependencyBox:AddToggle("SilentTeamCheck", { Text = "启用队伍检查", Default = true })
BlatantDependencyBox:SetupDependencies({ {Toggles.SilentAim, true} })

RageBlatantBox:AddToggle("Ragebot", {
    Text = "启用狂暴机器人",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function",
    DisabledTooltip = "此功能在你的执行器上不可用。",
})

local RageDependencyBox = RageBlatantBox:AddDependencyBox()

RageDependencyBox:AddSlider("RageDelay", { Text = "延迟", Default = 0.01, Min = 0, Max = 1, Rounding = 3 })

RageDependencyBox:AddDropdown("RageHitPart", {
    Text = "头部 / 命中部位选择",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Default = "Head",
})

RageDependencyBox:AddToggle("RagebotVisibleCheck", { Text = "启用可见性检查", Default = true })
RageDependencyBox:AddToggle("RagebotTeamCheck", { Text = "启用队伍检查", Default = true })
RageDependencyBox:AddToggle("RagebotWallCheck", { Text = "启用穿墙检查", Default = false })
RageDependencyBox:SetupDependencies({ {Toggles.Ragebot, true} })
-- ── 优先目标 ───────────────────────────────────────────────────────
RageDependencyBox:AddDivider()

local priorityTargetName = nil

local function refreshPriorityList()
    local names = {"[ 自动 ]"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local pt = get_player_team(p)
            local lt = get_player_team(LP)
            -- 如果队伍未确定 — 仍然显示玩家
            if pt == nil or lt == nil or pt ~= lt then
                table.insert(names, p.Name)
            end
        end
    end
    return names
end

RageDependencyBox:AddDropdown("RagePriorityTarget", {
    Text    = "优先目标",
    Values  = refreshPriorityList(),
    Default = "[ 自动 ]",
    Callback = function(v)
        priorityTargetName = (v == "[ 自动 ]") and nil or v
    end
})

RageDependencyBox:AddButton("刷新列表", function()
    Options.RagePriorityTarget:SetValues(refreshPriorityList())
    Options.RagePriorityTarget:SetValue("[ 自动 ]")
    priorityTargetName = nil
end)
-- =========================================================================
-- [ 视觉选项卡 - ESP系统 ] v5.7 (属性血量 + 血条渐变)
-- =========================================================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LP = Players.LocalPlayer

local VisualsESPBox = Tabs.Visuals:AddLeftGroupbox("ESP", "eye")

VisualsESPBox:AddToggle("ESPEnabled",   { Text = "启用ESP", Default = false })
VisualsESPBox:AddToggle("ESPTeamCheck", { Text = "队伍检查", Default = true })

VisualsESPBox:AddDropdown("ESPBoxType", {
    Text    = "方框ESP",
    Values  = {"2D方框","3D方框","角落方框","禁用"},
    Default = "2D方框",
})

VisualsESPBox:AddLabel("方框颜色 A"):AddColorPicker("ESPBoxColorA", { Default = Color3.fromRGB(255,255,255), Title = "方框颜色 A" })
VisualsESPBox:AddLabel("方框颜色 B"):AddColorPicker("ESPBoxColorB", { Default = Color3.fromRGB(0,200,255),   Title = "方框颜色 B" })

VisualsESPBox:AddToggle("ESPBoxFillGradient", { Text = "填充渐变", Default = false })
VisualsESPBox:AddLabel("填充颜色 "):AddColorPicker("ESPFillColorA", { Default = Color3.fromRGB(255,50,50),  Title = "填充颜色 A" })
VisualsESPBox:AddLabel("填充颜色 "):AddColorPicker("ESPFillColorB", { Default = Color3.fromRGB(50,50,255),  Title = "填充颜色 B" })
VisualsESPBox:AddToggle("ESPBoxFillRotation", { Text = "填充旋转", Default = false })
VisualsESPBox:AddSlider("ESPBoxRotationSpeed", { Text = "旋转速度", Min = 0.1, Max = 10, Default = 2, Rounding = 1 })

VisualsESPBox:AddToggle("ESPName", { Text = "名称ESP", Default = false })
VisualsESPBox:AddLabel("名称颜色"):AddColorPicker("ESPNameColor", { Default = Color3.new(1,1,1), Title = "名称颜色" })

VisualsESPBox:AddToggle("ESPHealth", { Text = "血条", Default = false })
VisualsESPBox:AddLabel("血量顶部颜色"):AddColorPicker("ESPHealthTopColor",       { Default = Color3.fromRGB(0,255,0),   Title = "血量顶部"    })
VisualsESPBox:AddLabel("血量底部颜色"):AddColorPicker("ESPHealthBottomColor", { Default = Color3.fromRGB(255,0,0),   Title = "血量底部" })

VisualsESPBox:AddToggle("ESPHealthText", { Text = "血量文字", Default = false })
VisualsESPBox:AddLabel("血量文字颜色"):AddColorPicker("ESPHealthTextColor",  { Default = Color3.new(1,1,1), Title = "血量文字颜色" })

VisualsESPBox:AddToggle("ESPDistance", { Text = "距离ESP", Default = false })
VisualsESPBox:AddLabel("距离颜色"):AddColorPicker("ESPDistanceColor",  { Default = Color3.new(1,1,1), Title = "距离颜色" })

VisualsESPBox:AddToggle("ESPWeapon", { Text = "显示武器名称", Default = false })
    :AddColorPicker("ESPWeaponColor", { Default = Color3.new(1,1,1), Title = "武器颜色" })

VisualsESPBox:AddToggle("ESPTracer", { Text = "追踪线ESP", Default = false })
VisualsESPBox:AddLabel("追踪线颜色"):AddColorPicker("ESPTracerColor",  { Default = Color3.new(1,1,1)             })
VisualsESPBox:AddLabel("追踪线颜色 "):AddColorPicker("ESPTracerColorB", { Default = Color3.fromRGB(255,0,128)     })
VisualsESPBox:AddDropdown("ESPTracerOrigin", {
    Text = "追踪线起点", Values = {"底部","顶部","中心","鼠标"}, Default = "底部",
})

VisualsESPBox:AddToggle("ESPSkeleton", { Text = "骨骼ESP", Default = false })
VisualsESPBox:AddLabel("骨骼颜色"):AddColorPicker("ESPSkeletonColorA", { Default = Color3.new(1,1,1),         Title = "骨骼 A" })
VisualsESPBox:AddLabel("骨骼颜色 "):AddColorPicker("ESPSkeletonColorB", { Default = Color3.fromRGB(0,255,255), Title = "骨骼 B" })

VisualsESPBox:AddToggle("ESPCircularTarget", { Text = "圆形目标", Default = false })
VisualsESPBox:AddLabel("圆形目标颜色"):AddColorPicker("ESPCircularTargetColor", { Default = Color3.fromRGB(255,200,0), Title = "圆形目标颜色" })
-- =========================================================================
-- [ 防弹背心细节队伍检查逻辑 ]
-- =========================================================================

local function hasVestDetails(character)
    if not character then return false end
    local armor = character:FindFirstChild("CharacterArmor")
    if armor and armor:FindFirstChild("VestDetails") then
        return true
    end
    return false
end

local function isCharacterAlly(targetChar)
    if not LP.Character then return false end
    local myHasVest = hasVestDetails(LP.Character)
    local targetHasVest = hasVestDetails(targetChar)
    
    if not myHasVest then
        return not targetHasVest
    else
        return targetHasVest
    end
end

local DEFAULT_ESP_COLOR = Color3.new(1,1,1)
getgenv().esplib_get_color = function(character) return DEFAULT_ESP_COLOR end

local function lerpColor(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t, a.G+(b.G-a.G)*t, a.B+(b.B-a.B)*t)
end

local _rotAngle = 0 

getgenv().esplib = {
    box = {
        enabled=false, type="2D",
        colorA=Color3.new(1,1,1), colorB=Color3.fromRGB(0,200,255),
        outline=Color3.new(0,0,0),
        fillGradient=false,
        fillColorA=Color3.fromRGB(255,50,50), fillColorB=Color3.fromRGB(50,50,255),
        fillRotation=false, rotationSpeed=2,
    },
    healthbar  = { enabled=false, topColor=Color3.fromRGB(0,255,0), bottomColor=Color3.fromRGB(255,0,0) },
    healthtext = { enabled=false, color=Color3.new(1,1,1), size=12 },
    name       = { enabled=false, fill=Color3.new(1,1,1), size=13 },
    distance   = { enabled=false, color=Color3.new(1,1,1), size=13 },
    tracer     = { enabled=false, fillA=Color3.new(1,1,1), fillB=Color3.fromRGB(255,0,128), outline=Color3.new(0,0,0), from="bottom" },
    skeleton   = { enabled=false, colorA=Color3.new(1,1,1), colorB=Color3.fromRGB(0,255,255), thickness=2 },
    weapon     = { enabled=false, fill=Color3.new(1,1,1), size=13 },
    circulartarget = { enabled=false, color=Color3.fromRGB(255,200,0) },
}

local esplib       = getgenv().esplib
local espinstances = {}
getgenv().esplib_instances = espinstances
local espfunctions = {}

local abs    = math.abs
local huge   = math.huge
local floor  = math.floor
local clamp  = math.clamp
local sin    = math.sin
local cos    = math.cos
local pi     = math.pi
local pi2    = pi * 2

local SKELETON_BONES_R6 = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}
local SKELETON_BONES_R15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local AABB_CORNER_SIGNS = {
    {0,0,0},{1,0,0},{0,1,0},{1,1,0},{0,0,1},{1,0,1},{0,1,1},{1,1,1},
}
local BOX_3D_EDGES = {
    {1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8},
}

local WorldToViewportPoint = Camera.WorldToViewportPoint
local boxCfg        = esplib.box
local healthCfg     = esplib.healthbar
local healthTextCfg = esplib.healthtext
local nameCfg       = esplib.name
local distCfg       = esplib.distance
local tracerCfg     = esplib.tracer
local skeletonCfg   = esplib.skeleton
local weaponCfg     = esplib.weapon
local circularTargetCfg = esplib.circulartarget

local BASE_DIST = 20
local BASE_W    = 86
local BASE_H    = 155
local partHalfExtentCache = setmetatable({},{__mode="k"})

local function get_part_half_extent(part)
    local c = partHalfExtentCache[part]
    if not c then
        local s=part.Size; c={hx=s.X*.5,hy=s.Y*.5,hz=s.Z*.5}; partHalfExtentCache[part]=c
    end
    return c.hx,c.hy,c.hz
end

local function compute_world_aabb(parts)
    local x0,y0,z0= huge, huge, huge
    local x1,y1,z1=-huge,-huge,-huge
    for i=1,#parts do
        local p=parts[i]
        local hx,hy,hz=get_part_half_extent(p)
        local px,py,pz,r00,r01,r02,r10,r11,r12,r20,r21,r22=p.CFrame:GetComponents()
        local ex=abs(r00)*hx+abs(r01)*hy+abs(r02)*hz
        local ey=abs(r10)*hx+abs(r11)*hy+abs(r12)*hz
        local ez=abs(r20)*hx+abs(r21)*hy+abs(r22)*hz
        if px-ex<x0 then x0=px-ex end; if py-ey<y0 then y0=py-ey end; if pz-ez<z0 then z0=pz-ez end
        if px+ex>x1 then x1=px+ex end; if py+ey>y1 then y1=py+ey end; if pz+ez>z1 then z1=pz+ez end
    end
    if x0==huge then return nil end
    return x0,y0,z0,x1,y1,z1
end

local function project_fixed_box(x0,y0,z0,x1,y1,z1)
    local cx=(x0+x1)*.5; local cy=(y0+y1)*.5; local cz=(z0+z1)*.5
    local sp,vis=WorldToViewportPoint(Camera,Vector3.new(cx,cy,cz))
    if not vis and sp.Z <= 0 then return nil,nil,false end
    local depth=sp.Z
    if depth<=0 then depth = 0.1 end
    local scale=BASE_DIST/depth
    local w=BASE_W*scale
    local h=BASE_H*scale
    local sx,sy=sp.X,sp.Y
    return Vector2.new(sx-w*.5,sy-h*.5), Vector2.new(sx+w*.5,sy+h*.5), true
end

local function project_aabb_corners_3d(x0,y0,z0,x1,y1,z1)
    local sc={}; local on=false
    for i=1,8 do
        local s=AABB_CORNER_SIGNS[i]
        local wx=s[1]==0 and x0 or x1; local wy=s[2]==0 and y0 or y1; local wz=s[3]==0 and z0 or z1
        local pos,vis=WorldToViewportPoint(Camera,Vector3.new(wx,wy,wz))
        sc[i]=Vector2.new(pos.X,pos.Y); if vis then on=true end
    end
    return sc,on
end

local function ensure_character_parts(instance,data)
    if data.partlist then return data.partlist end
    local list={}; local idx=setmetatable({},{__mode="k"})
    local function add(p)
        if p:IsA("BasePart") and not idx[p] then
            list[#list+1]=p; idx[p]=#list
            local c=p:GetPropertyChangedSignal("Size"):Connect(function() partHalfExtentCache[p]=nil end)
            data.sizeConns=data.sizeConns or {}; data.sizeConns[p]=c
        end
    end
    local function rem(p)
        local i=idx[p]; if not i then return end
        local last=#list; local lp=list[last]
        list[i]=lp; idx[lp]=i; list[last]=nil; idx[p]=nil
        if data.sizeConns and data.sizeConns[p] then data.sizeConns[p]:Disconnect(); data.sizeConns[p]=nil end
    end
    if instance:IsA("Model") then
        for _,p in next,instance:GetDescendants() do add(p) end
        data.partConnAdd=instance.DescendantAdded:Connect(add)
        data.partConnRemove=instance.DescendantRemoving:Connect(rem)
    elseif instance:IsA("BasePart") then add(instance) end
    data.partlist=list; return list
end
-- =========================================================================
-- [ 填充渐变 ] 
-- =========================================================================

local MAX_FILL_LINES = 400 

local function setupFillLines()
    local lines = {}
    for i = 1, MAX_FILL_LINES do
        local l = Drawing.new("Line")
        l.Thickness = 4.0
        l.Transparency = 0.3
        l.Visible = false
        lines[i] = l
    end
    return lines
end

local function drawFillGradient360(fillLines, x, y, w, h, colorA, colorB, angle)
    local dx = cos(angle)
    local dy = sin(angle)
    local cx = x + w * 0.5
    local cy = y + h * 0.5
    local maxDot = math.max((abs(dx) * w + abs(dy) * h) * 0.5, 1)

    local targetRows = math.clamp(math.floor(h * 0.8), 15, MAX_FILL_LINES)
    local rowH = h / targetRows

    for i = 1, targetRows do
        local py = y + (i - 0.5) * rowH
        local dotL = ((x     - cx) * dx + (py - cy) * dy) / maxDot
        local dotR = ((x + w - cx) * dx + (py - cy) * dy) / maxDot
        local tL = clamp(dotL * 0.5 + 0.5, 0, 1)
        local tR = clamp(dotR * 0.5 + 0.5, 0, 1)
        
        local line = fillLines[i]
        line.Color = lerpColor(colorA, colorB, (tL + tR) * 0.5)
        line.Thickness = math.clamp(rowH + 1.5, 2, 8) 
        line.From  = Vector2.new(x + 1, py)
        line.To    = Vector2.new(x + w - 1, py)
        line.Visible = true
    end
    for i = targetRows + 1, #fillLines do 
        fillLines[i].Visible = false 
    end
end

local GRAD_STEPS = 4
local function drawBoxOutlineGradient(box, x, y, w, h, colorA, colorB, rotOff)
    local grad=box.grad_lines; local idx=0
    local sides={{x,y,x+w,y},{x+w,y,x+w,y+h},{x+w,y+h,x,y+h},{x,y+h,x,y}}
    for si=1,4 do
        local s=sides[si]; local x1,y1,x2,y2=s[1],s[2],s[3],s[4]
        for step=0,GRAD_STEPS-1 do
            idx=idx+1
            local tA=step/GRAD_STEPS; local tB=(step+1)/GRAD_STEPS
            local tMid=(((si-1)/4)+(tA/4)+rotOff)%1
            local col=lerpColor(colorA,colorB,tMid)
            local line=grad[idx]
            if line then
                line.From=Vector2.new(x1+(x2-x1)*tA,y1+(y2-y1)*tA)
                line.To  =Vector2.new(x1+(x2-x1)*tB,y1+(y2-y1)*tB)
                line.Color=col; line.Visible=true
            end
        end
    end
    for i=idx+1,#grad do grad[i].Visible=false end
end

local function hideBox(box)
    box.outline.Visible=false; box.fill.Visible=false
    for _,l in ipairs(box.grad_lines)      do l.Visible=false end
    for _,l in ipairs(box.fill_grad_lines)  do l.Visible=false end
    for _,l in ipairs(box.corner_fill)     do l.Visible=false end
    for _,l in ipairs(box.corner_outline)   do l.Visible=false end
    for _,l in ipairs(box.box_3d_lines)    do l.Visible=false end
end
-- =========================================================================
-- [ 绘图工厂 ]
-- =========================================================================

function espfunctions.add_box(instance)
    if not instance or (espinstances[instance] and espinstances[instance].box) then return end
    local function mkLine(th) local l=Drawing.new("Line"); l.Thickness=th; l.Transparency=1; l.Visible=false; return l end
    local function mkSq(th,f) local s=Drawing.new("Square"); s.Thickness=th; s.Filled=f; s.Transparency=1; s.Visible=false; return s end
    local box={}
    box.outline=mkSq(3,false); box.fill=mkSq(1,false)
    box.grad_lines={}; for i=1,16 do box.grad_lines[i]=mkLine(1) end
    box.fill_grad_lines = setupFillLines()
    box.corner_fill={}; box.corner_outline={}
    for i=1,8 do box.corner_fill[i]=mkLine(1); box.corner_outline[i]=mkLine(3) end
    box.box_3d_lines={}; for i=1,12 do box.box_3d_lines[i]=mkLine(2) end
    espinstances[instance]=espinstances[instance] or {}
    espinstances[instance].box=box
end

-- 创建血条渐变线条 (12段平滑填充)
local MAX_HP_SEGMENTS = 12

function espfunctions.add_healthbar(instance)
    if not instance or (espinstances[instance] and espinstances[instance].healthbar) then return end
    local bg = Drawing.new("Square")
    bg.Thickness = 1
    bg.Filled = true
    bg.Color = Color3.new(0, 0, 0)
    bg.Transparency = 0.5
    bg.Visible = false

    local segs = {}
    for i = 1, MAX_HP_SEGMENTS do
        local l = Drawing.new("Line")
        l.Thickness = 3
        l.Transparency = 1
        l.Visible = false
        segs[i] = l
    end

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].healthbar = { background = bg, segments = segs }
end

function espfunctions.add_healthtext(instance)
    if not instance or (espinstances[instance] and espinstances[instance].healthtext) then return end
    local t = Drawing.new("Text")
    t.Center = false
    t.Outline = true
    t.Font = 1
    t.Transparency = 1
    t.Visible = false
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].healthtext = t
end

function espfunctions.add_name(instance)
    if not instance or (espinstances[instance] and espinstances[instance].name) then return end
    local t=Drawing.new("Text"); t.Center=true; t.Outline=true; t.Font=1; t.Transparency=1
    espinstances[instance]=espinstances[instance] or {}; espinstances[instance].name=t
end

function espfunctions.add_distance(instance)
    if not instance or (espinstances[instance] and espinstances[instance].distance) then return end
    local t=Drawing.new("Text"); t.Center=true; t.Outline=true; t.Font=1; t.Transparency=1
    espinstances[instance]=espinstances[instance] or {}; espinstances[instance].distance=t
end

function espfunctions.add_tracer(instance)
    if not instance or (espinstances[instance] and espinstances[instance].tracer) then return end
    local o=Drawing.new("Line"); o.Thickness=3; o.Transparency=1
    local f=Drawing.new("Line"); f.Thickness=1; f.Transparency=1
    espinstances[instance]=espinstances[instance] or {}; espinstances[instance].tracer={outline=o,fill=f}
end

function espfunctions.add_skeleton(instance,options)
    if not instance or (espinstances[instance] and espinstances[instance].skeleton) then return end
    options=options or {}
    local isR15=instance:FindFirstChild("UpperTorso")~=nil
    local bones=isR15 and SKELETON_BONES_R15 or SKELETON_BONES_R6
    local lines={}; local bp={}
    for i=1,#bones do
        local l=Drawing.new("Line"); l.Thickness=options.thickness or 2; l.Transparency=1; l.Visible=false; lines[i]=l
        bp[i]={instance:FindFirstChild(bones[i][1]),instance:FindFirstChild(bones[i][2])}
    end
    espinstances[instance]=espinstances[instance] or {}
    espinstances[instance].skeleton={lines=lines,bone_parts=bp,screenCache={}}
end

function espfunctions.add_weapon(instance)
    if not instance or (espinstances[instance] and espinstances[instance].weapon) then return end
    local t=Drawing.new("Text"); t.Center=true; t.Outline=true; t.Font=1; t.Transparency=1; t.Visible=false
    espinstances[instance]=espinstances[instance] or {}; espinstances[instance].weapon=t
end

function espfunctions.add_circulartarget(instance)
    if not instance or (espinstances[instance] and espinstances[instance].circulartarget) then return end
    local SEGS=32; local lines={}
    for i=1,SEGS do local l=Drawing.new("Line"); l.Thickness=1.5; l.Transparency=1; l.Visible=false; lines[i]=l end
    
    local TRAIL_SEGS = 25
    local trailLines = {}
    local neonGlowLines = {}
    for i = 1, TRAIL_SEGS do 
        local l = Drawing.new("Line")
        l.Thickness = 2.5
        l.Transparency = 0.4
        l.Visible = false
        trailLines[i] = l

        local glow = Drawing.new("Line")
        glow.Thickness = 5.0
        glow.Transparency = 0.15
        glow.Visible = false
        neonGlowLines[i] = glow
    end
    
    espinstances[instance]=espinstances[instance] or {}
    espinstances[instance].circulartarget={
        lines = lines, 
        trailLines = trailLines, 
        neonGlowLines = neonGlowLines, 
        segments = SEGS, 
        alpha = 0, 
        movingUp = true, 
        trailHistory = {}
    }
end
local function hide_all(data)
    if data.box      then hideBox(data.box) end
    if data.healthbar then 
        data.healthbar.background.Visible=false
        for _,seg in ipairs(data.healthbar.segments) do seg.Visible=false end
    end
    if data.healthtext then data.healthtext.Visible=false end
    if data.name      then data.name.Visible=false end
    if data.distance  then data.distance.Visible=false end
    if data.tracer    then data.tracer.outline.Visible=false; data.tracer.fill.Visible=false end
    if data.skeleton  then for _,l in ipairs(data.skeleton.lines) do l.Visible=false end end
    if data.weapon    then data.weapon.Visible=false end
    if data.circulartarget then 
        for _,l in ipairs(data.circulartarget.lines) do l.Visible=false end 
        for _,l in ipairs(data.circulartarget.trailLines) do l.Visible=false end
        for _,l in ipairs(data.circulartarget.neonGlowLines) do l.Visible=false end
    end
end

local function cleanup_instance(instance,data)
    pcall(function()
        if data.box then
            data.box.outline:Remove(); data.box.fill:Remove()
            for _,l in next,data.box.grad_lines      do l:Remove() end
            for _,l in next,data.box.fill_grad_lines  do l:Remove() end
            for _,l in next,data.box.corner_fill      do l:Remove() end
            for _,l in next,data.box.corner_outline   do l:Remove() end
            for _,l in next,data.box.box_3d_lines     do l:Remove() end
        end
        if data.healthbar  then 
            data.healthbar.background:Remove()
            for _,seg in ipairs(data.healthbar.segments) do seg:Remove() end
        end
        if data.healthtext then data.healthtext:Remove() end
        if data.name       then data.name:Remove() end
        if data.distance   then data.distance:Remove() end
        if data.tracer     then data.tracer.outline:Remove(); data.tracer.fill:Remove() end
        if data.skeleton   then for _,l in next,data.skeleton.lines do l:Remove() end end
        if data.weapon     then data.weapon:Remove() end
        if data.circulartarget then 
            for _,l in ipairs(data.circulartarget.lines) do l:Remove() end 
            for _,l in ipairs(data.circulartarget.trailLines) do l:Remove() end
            for _,l in ipairs(data.circulartarget.neonGlowLines) do l:Remove() end
        end
        if data.partConnAdd    then data.partConnAdd:Disconnect() end
        if data.partConnRemove then data.partConnRemove:Disconnect() end
        if data.sizeConns then for _,c in next,data.sizeConns do c:Disconnect() end end
    end)
end

local weaponAttrCache={}; local weaponNameCache={}
local function GetWeaponName(player)
    if not player then return "无" end
    local attr=player:GetAttribute("CurrentEquipped")
    if attr~=weaponAttrCache[player] then
        weaponAttrCache[player]=attr
        if attr then
            local ok,dec=pcall(function() return game:GetService("HttpService"):JSONDecode(attr) end)
            weaponNameCache[player]=(ok and dec and dec.Name) or "无"
        else weaponNameCache[player]="无" end
    end
    return weaponNameCache[player] or "无"
end

local function get_cached_screen_pos(cache,part)
    local c=cache[part]; if c then return c[1],c[2] end
    local pos,vis=WorldToViewportPoint(Camera,part.Position)
    local sp=Vector2.new(pos.X,pos.Y); cache[part]={sp,vis}; return sp,vis
end
-- =========================================================================
-- [ 渲染循环 ]
-- =========================================================================

RunService.RenderStepped:Connect(function(dt)
    if boxCfg.fillRotation then
        _rotAngle = (_rotAngle + dt * (boxCfg.rotationSpeed or 2)) % pi2
    end

    local camPos          = Camera.CFrame.Position
    local vp              = Camera.ViewportSize
    local teamCheck       = Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value
    local rotOff1         = _rotAngle / pi2

    for instance,data in next,espinstances do
        if not instance or not instance.Parent then
            cleanup_instance(instance,data); espinstances[instance]=nil; continue
        end
        
        if instance == LP.Character then
            hide_all(data); continue
        end

        if instance:IsA("Model") and not instance.PrimaryPart then 
            local head = instance:FindFirstChild("Head")
            local torso = instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChild("Torso") or instance:FindFirstChild("UpperTorso")
            if head then instance.PrimaryPart = head elseif torso then instance.PrimaryPart = torso end
        end

        if teamCheck and isCharacterAlly(instance) then
            hide_all(data); continue
        end

        local healthAttr = instance:GetAttribute("Health")
        local maxHealthAttr = instance:GetAttribute("MaxHealth") or 100
        local isDeadAttr = instance:GetAttribute("Dead")

        if isDeadAttr == true or (healthAttr and healthAttr <= 0) then 
            hide_all(data)
            continue 
        end

        local needBox    = boxCfg.enabled      and data.box      ~=nil
        local needHp     = healthCfg.enabled   and data.healthbar~=nil
        local needHpTxt  = healthTextCfg.enabled and data.healthtext~=nil
        local needName   = nameCfg.enabled     and data.name     ~=nil
        local needDist   = distCfg.enabled     and data.distance ~=nil
        local needTracer = tracerCfg.enabled   and data.tracer   ~=nil
        local needSkel   = skeletonCfg.enabled and data.skeleton ~=nil
        local needWep    = weaponCfg.enabled   and data.weapon   ~=nil
        local needCirc   = circularTargetCfg.enabled and data.circulartarget ~=nil

        if data.box      and not needBox    then hideBox(data.box) end
        if data.healthbar and not needHp    then 
            data.healthbar.background.Visible=false
            for _,seg in ipairs(data.healthbar.segments) do seg.Visible=false end
        end
        if data.healthtext and not needHpTxt then data.healthtext.Visible=false end
        if data.name     and not needName   then data.name.Visible=false end
        if data.distance and not needDist   then data.distance.Visible=false end
        if data.tracer   and not needTracer then data.tracer.outline.Visible=false; data.tracer.fill.Visible=false end
        if data.skeleton and not needSkel   then for _,l in ipairs(data.skeleton.lines) do l.Visible=false end end
        if data.weapon   and not needWep    then data.weapon.Visible=false end
        if data.circulartarget then 
            if not needCirc then 
                for _,l in ipairs(data.circulartarget.lines) do l.Visible=false end 
                for _,l in ipairs(data.circulartarget.trailLines) do l.Visible=false end
                for _,l in ipairs(data.circulartarget.neonGlowLines) do l.Visible=false end
            end
        end

        if not(needBox or needHp or needHpTxt or needName or needDist or needTracer or needSkel or needWep or needCirc) then continue end

        local parts=ensure_character_parts(instance,data)
        local min2,max2,onscreen=nil,nil,false
        local c3d,on3d=nil,false

        local x0,y0,z0,x1,y1,z1=compute_world_aabb(parts)
        if x0 then
            min2,max2,onscreen=project_fixed_box(x0,y0,z0,x1,y1,z1)
            if needBox and boxCfg.type=="3D" then
                c3d,on3d=project_aabb_corners_3d(x0,y0,z0,x1,y1,z1)
            end
        end
                -- ── 方框 ──────────────────────────────────────────────────────────
        if data.box then
            if needBox and onscreen and min2 and max2 then
                local x,y = min2.X,min2.Y
                local w   = max2.X-min2.X
                local h   = max2.Y-min2.Y
                local cA  = boxCfg.colorA; local cB=boxCfg.colorB
                local fA  = boxCfg.fillColorA; local fB=boxCfg.fillColorB

                if boxCfg.type=="2D" then
                    if boxCfg.fillGradient then
                        drawFillGradient360(data.box.fill_grad_lines, x, y, w, h, fA, fB, _rotAngle)
                    else
                        for _,l in ipairs(data.box.fill_grad_lines) do l.Visible=false end
                    end
                    drawBoxOutlineGradient(data.box, x, y, w, h, cA, cB, rotOff1)
                    data.box.outline.Visible=false; data.box.fill.Visible=false
                    for _,l in ipairs(data.box.corner_fill)   do l.Visible=false end
                    for _,l in ipairs(data.box.corner_outline) do l.Visible=false end
                    for _,l in ipairs(data.box.box_3d_lines)   do l.Visible=false end

                elseif boxCfg.type=="角落" then
                    for _,l in ipairs(data.box.grad_lines) do l.Visible=false end
                    data.box.outline.Visible=false; data.box.fill.Visible=false
                    if boxCfg.fillGradient then
                        drawFillGradient360(data.box.fill_grad_lines, x, y, w, h, fA, fB, _rotAngle)
                    else for _,l in ipairs(data.box.fill_grad_lines) do l.Visible=false end end
                    
                    local len=math.min(w,h)*.25
                    local corners={
                        {Vector2.new(x,y),     Vector2.new(x+len,y)  },
                        {Vector2.new(x,y),     Vector2.new(x,y+len)  },
                        {Vector2.new(x+w-len,y),Vector2.new(x+w,y)   },
                        {Vector2.new(x+w,y),   Vector2.new(x+w,y+len)},
                        {Vector2.new(x,y+h),   Vector2.new(x+len,y+h)},
                        {Vector2.new(x,y+h-len),Vector2.new(x,y+h)   },
                        {Vector2.new(x+w-len,y+h),Vector2.new(x+w,y+h)},
                        {Vector2.new(x+w,y+h-len),Vector2.new(x+w,y+h)},
                    }
                    for i=1,8 do
                        local t=(i-1)/8; local col=lerpColor(cA,cB,t)
                        data.box.corner_outline[i].From=corners[i][1]; data.box.corner_outline[i].To=corners[i][2]
                        data.box.corner_outline[i].Color=boxCfg.outline; data.box.corner_outline[i].Visible=true
                        data.box.corner_fill[i].From=corners[i][1]; data.box.corner_fill[i].To=corners[i][2]
                        data.box.corner_fill[i].Color=col; data.box.corner_fill[i].Visible=true
                    end
                    for _,l in ipairs(data.box.box_3d_lines) do l.Visible=false end

                elseif boxCfg.type=="3D" then
                    for _,l in ipairs(data.box.fill_grad_lines) do l.Visible=false end
                    for _,l in ipairs(data.box.grad_lines)      do l.Visible=false end
                    data.box.outline.Visible=false; data.box.fill.Visible=false
                    for _,l in ipairs(data.box.corner_fill)   do l.Visible=false end
                    for _,l in ipairs(data.box.corner_outline) do l.Visible=false end
                    if c3d and #c3d==8 then
                        for i=1,12 do
                            local e=BOX_3D_EDGES[i]
                            data.box.box_3d_lines[i].From=c3d[e[1]]; data.box.box_3d_lines[i].To=c3d[e[2]]
                            data.box.box_3d_lines[i].Color=lerpColor(cA,cB,(i-1)/12)
                            data.box.box_3d_lines[i].Visible=on3d
                        end
                    else for _,l in ipairs(data.box.box_3d_lines) do l.Visible=false end end
                end
            else hideBox(data.box) end
        end

        -- ── 血条 (渐变) ──────────────────
        if data.healthbar then
            local bg = data.healthbar.background
            local segs = data.healthbar.segments
            if needHp and onscreen and min2 and max2 and healthAttr then
                local x = min2.X - 6
                local y = min2.Y
                local w = 3
                local h = max2.Y - min2.Y
                
                local maxHp = maxHealthAttr > 0 and maxHealthAttr or 100
                local hpFraction = clamp(healthAttr / maxHp, 0, 1)
                
                bg.Position = Vector2.new(x - 1, y - 1)
                bg.Size = Vector2.new(w + 2, h + 2)
                bg.Visible = true

                local barHeight = h * hpFraction
                local startY = y + (h - barHeight)
                
                local activeSegCount = math.clamp(math.floor(MAX_HP_SEGMENTS * hpFraction), 1, MAX_HP_SEGMENTS)
                local segH = barHeight / activeSegCount

                for i = 1, MAX_HP_SEGMENTS do
                    local segLine = segs[i]
                    if i <= activeSegCount then
                        local segmentFraction = (i - 0.5) / MAX_HP_SEGMENTS
                        -- 在顶部颜色和底部颜色之间渐变
                        segLine.Color = lerpColor(healthCfg.bottomColor, healthCfg.topColor, segmentFraction)
                        
                        local py1 = startY + (i - 1) * segH
                        local py2 = startY + i * segH
                        
                        segLine.From = Vector2.new(x + w * 0.5, py1)
                        segLine.To = Vector2.new(x + w * 0.5, py2)
                        segLine.Thickness = w
                        segLine.Visible = true
                    else
                        segLine.Visible = false
                    end
                end
            else
                bg.Visible = false
                for _,seg in ipairs(segs) do seg.Visible = false end
            end
        end

        -- ── 血量文字 ──────────────────────────────────────────────────
        if data.healthtext then
            if needHpTxt and onscreen and min2 and max2 and healthAttr then
                local currentHp = math.floor(healthAttr + 0.5)
                local maxHp = maxHealthAttr > 0 and maxHealthAttr or 100
                
                data.healthtext.Text = tostring(currentHp)
                data.healthtext.Size = healthTextCfg.size
                data.healthtext.Color = healthTextCfg.color
                
                local textX = max2.X + 4
                local textY = min2.Y + (max2.Y - min2.Y) * (1 - (healthAttr / maxHp)) - 4
                data.healthtext.Position = Vector2.new(textX, textY)
                data.healthtext.Visible = true
            else
                data.healthtext.Visible = false
            end
        end

        -- ── 名称 ─────────────────────────────────────────────────────────
        if data.name then
            if needName and onscreen and min2 and max2 then
                data.name.Text=instance.Name; data.name.Size=nameCfg.size; data.name.Color=nameCfg.fill
                data.name.Position=Vector2.new((min2.X+max2.X)*.5,min2.Y-15); data.name.Visible=true
            else data.name.Visible=false end
        end

        -- ── 距离 ─────────────────────────────────────────────────────
        if data.distance then
            if needDist and onscreen and min2 and max2 then
                local dist=999
                if instance:IsA("Model") and instance.PrimaryPart then dist=(camPos-instance.PrimaryPart.Position).Magnitude
                elseif instance:IsA("BasePart") then dist=(camPos-instance.Position).Magnitude end
                data.distance.Text=tostring(floor(dist)).."米"; data.distance.Size=distCfg.size
                data.distance.Color=distCfg.color
                data.distance.Position=Vector2.new((min2.X+max2.X)*.5,max2.Y+2); data.distance.Visible=true
            else data.distance.Visible=false end
        end

        -- ── 武器 ───────────────────────────────────────────────────────
        if data.weapon then
            if needWep and onscreen and min2 and max2 then
                if not data.player then data.player=Players:GetPlayerFromCharacter(instance) end
                local wn=data.player and GetWeaponName(data.player) or "无"
                data.weapon.Text="["..wn.."]"; data.weapon.Size=weaponCfg.size or 13
                data.weapon.Color=weaponCfg.fill
                data.weapon.Position=Vector2.new((min2.X+max2.X)*.5,max2.Y+15)
                data.weapon.Center=true; data.weapon.Visible=true
            else data.weapon.Visible=false end
        end

        -- ── 追踪线 ───────────────────────────────────────────────────────
        if data.tracer then
            if needTracer and onscreen and min2 and max2 then
                local from_pos
                if tracerCfg.from=="mouse" then local ml=UserInputService:GetMouseLocation(); from_pos=Vector2.new(ml.X,ml.Y)
                elseif tracerCfg.from=="top" then from_pos=Vector2.new(vp.X/2,0)
                elseif tracerCfg.from=="center" then from_pos=Vector2.new(vp.X/2,vp.Y/2)
                else from_pos=Vector2.new(vp.X/2,vp.Y) end
                local to_pos=(min2+max2)/2
                local dist=0
                if instance:IsA("Model") and instance.PrimaryPart then dist=clamp((camPos-instance.PrimaryPart.Position).Magnitude/200,0,1) end
                local col=lerpColor(tracerCfg.fillA,tracerCfg.fillB,dist)
                data.tracer.outline.From=from_pos; data.tracer.outline.To=to_pos; data.tracer.outline.Color=tracerCfg.outline; data.tracer.outline.Visible=true
                data.tracer.fill.From=from_pos; data.tracer.fill.To=to_pos; data.tracer.fill.Color=col; data.tracer.fill.Visible=true
            else data.tracer.outline.Visible=false; data.tracer.fill.Visible=false end
        end

        -- ── 骨骼 ─────────────────────────────────────────────────────
        if data.skeleton then
            if needSkel then
                local bp=data.skeleton.bone_parts; local lines=data.skeleton.lines; local sc=data.skeleton.screenCache
                for k in next,sc do sc[k]=nil end
                local anyDrawn = false
                for i=1,#bp do
                    local pair=bp[i]; local pA,pB=pair[1],pair[2]; local line=lines[i]
                    if pA and pB and pA.Parent and pB.Parent then
                        local posA,vA=get_cached_screen_pos(sc,pA); local posB,vB=get_cached_screen_pos(sc,pB)
                        if vA or vB then
                            line.From=posA; line.To=posB
                            line.Color=lerpColor(skeletonCfg.colorA,skeletonCfg.colorB,(i-1)/#bp)
                            line.Thickness=skeletonCfg.thickness; line.Visible=true
                            anyDrawn = true
                        else line.Visible=false end
                    else line.Visible=false end
                end
                if not anyDrawn then for _,l in ipairs(lines) do l.Visible=false end end
            else for _,l in ipairs(data.skeleton.lines) do l.Visible=false end end
        end

        -- ── 圆形目标 ──────────────────────────────────────────────
        if data.circulartarget then
            local ct = data.circulartarget
            local head = instance:FindFirstChild("Head")
            local root = instance:IsA("Model") and instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") or head
            
            if needCirc and head and root then
                local speed = 2.0 
                if ct.movingUp then
                    ct.alpha = ct.alpha + dt * speed
                    if ct.alpha >= 1 then ct.alpha = 1; ct.movingUp = false end
                else
                    ct.alpha = ct.alpha - dt * speed
                    if ct.alpha <= 0 then ct.alpha = 0; ct.movingUp = true end
                end

                local footPos = root.Position - Vector3.new(0, (root.Size.Y * 0.8) + 1.2, 0)
                local headPos = head.Position + Vector3.new(0, 0.3, 0)
                local currentWorldPos = footPos:Lerp(headPos, ct.alpha)
                
                table.insert(ct.trailHistory, 1, currentWorldPos)
                if #ct.trailHistory > #ct.trailLines then table.remove(ct.trailHistory) end

                for i = 1, #ct.trailLines do
                    local trailLine = ct.trailLines[i]
                    local glowLine = ct.neonGlowLines[i]
                    local p1 = ct.trailHistory[i]
                    local p2 = ct.trailHistory[i + 1]
                    
                    if p1 and p2 then
                        local s1, v1 = WorldToViewportPoint(Camera, p1)
                        local s2, v2 = WorldToViewportPoint(Camera, p2)
                        if v1 or v2 then
                            local fadeFactor = clamp(1 - (i / #ct.trailLines), 0.05, 1)
                            
                            glowLine.From = Vector2.new(s1.X, s1.Y)
                            glowLine.To = Vector2.new(s2.X, s2.Y)
                            glowLine.Color = circularTargetCfg.color
                            glowLine.Transparency = fadeFactor * 0.35
                            glowLine.Visible = true

                            trailLine.From = Vector2.new(s1.X, s1.Y)
                            trailLine.To = Vector2.new(s2.X, s2.Y)
                            trailLine.Color = circularTargetCfg.color
                            trailLine.Transparency = fadeFactor * 0.85
                            trailLine.Visible = true
                        else
                            trailLine.Visible = false; glowLine.Visible = false
                        end
                    else
                        trailLine.Visible = false; glowLine.Visible = false
                    end
                end

                local R = 2.2
                local SEGS = ct.segments
                local col = circularTargetCfg.color
                for i = 1, SEGS do
                    local aA = pi2 * ((i - 1) / SEGS)
                    local aB = pi2 * (i / SEGS)
                    local wA = currentWorldPos + Vector3.new(cos(aA) * R, 0, sin(aA) * R)
                    local wB = currentWorldPos + Vector3.new(cos(aB) * R, 0, sin(aB) * R)
                    local sA, vA = WorldToViewportPoint(Camera, wA)
                    local sB, vB = WorldToViewportPoint(Camera, wB)
                    local line = ct.lines[i]
                    if vA or vB then
                        line.From = Vector2.new(sA.X, sA.Y)
                        line.To = Vector2.new(sB.X, sB.Y)
                        line.Color = col
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                end
            else
                for _,l in ipairs(ct.lines) do l.Visible=false end
                for _,l in ipairs(ct.trailLines) do l.Visible=false end
                for _,l in ipairs(ct.neonGlowLines) do l.Visible=false end
            end
        end
    end
end)

for k,v in next,espfunctions do esplib[k]=v end
-- =========================================================================
-- [ 设置同步 ]
-- =========================================================================

local function updateESPSettings()
    local bt=Options.ESPBoxType.Value
    if bt=="禁用" then esplib.box.enabled=false
    else esplib.box.enabled=Toggles.ESPEnabled.Value; esplib.box.type=bt:gsub("方框","") end
    esplib.box.colorA        = Options.ESPBoxColorA.Value
    esplib.box.colorB        = Options.ESPBoxColorB.Value
    esplib.box.fillGradient  = Toggles.ESPBoxFillGradient.Value
    esplib.box.fillColorA    = Options.ESPFillColorA.Value
    esplib.box.fillColorB    = Options.ESPFillColorB.Value
    esplib.box.fillRotation  = Toggles.ESPBoxFillRotation.Value
    esplib.box.rotationSpeed = Options.ESPBoxRotationSpeed.Value
    esplib.name.enabled      = Toggles.ESPEnabled.Value and Toggles.ESPName.Value
    esplib.name.fill         = Options.ESPNameColor.Value
    esplib.healthbar.enabled     = Toggles.ESPEnabled.Value and Toggles.ESPHealth.Value
    esplib.healthbar.topColor    = Options.ESPHealthTopColor.Value
    esplib.healthbar.bottomColor = Options.ESPHealthBottomColor.Value
    esplib.healthtext.enabled    = Toggles.ESPEnabled.Value and Toggles.ESPHealthText.Value
    esplib.healthtext.color      = Options.ESPHealthTextColor.Value
    esplib.distance.enabled      = Toggles.ESPEnabled.Value and Toggles.ESPDistance.Value
    esplib.distance.color        = Options.ESPDistanceColor.Value
    esplib.tracer.enabled        = Toggles.ESPEnabled.Value and Toggles.ESPTracer.Value
    esplib.tracer.fillA          = Options.ESPTracerColor.Value
    esplib.tracer.fillB          = Options.ESPTracerColorB.Value
    esplib.tracer.from           = Options.ESPTracerOrigin.Value
    esplib.skeleton.enabled      = Toggles.ESPEnabled.Value and Toggles.ESPSkeleton.Value
    esplib.skeleton.colorA       = Options.ESPSkeletonColorA.Value
    esplib.skeleton.colorB       = Options.ESPSkeletonColorB.Value
    esplib.weapon.enabled        = Toggles.ESPEnabled.Value and Toggles.ESPWeapon.Value
    esplib.weapon.fill           = Options.ESPWeaponColor and Options.ESPWeaponColor.Value or Color3.new(1,1,1)
    esplib.circulartarget.enabled = Toggles.ESPEnabled.Value and Toggles.ESPCircularTarget.Value
    esplib.circulartarget.color   = Options.ESPCircularTargetColor.Value
end

-- =========================================================================
-- [ 动态角色文件夹扫描器 ]
-- =========================================================================

local espCharacters={}

local function addEspToCharacter(character)
    if not character or espCharacters[character] then return end
    if character == LP.Character then return end
    
    esplib.add_box(character)
    esplib.add_name(character)
    esplib.add_healthbar(character)
    esplib.add_healthtext(character)
    esplib.add_distance(character)
    esplib.add_tracer(character)
    esplib.add_skeleton(character, {thickness=2})
    esplib.add_weapon(character)
    esplib.add_circulartarget(character)
    
    espCharacters[character]=true
end

local function removeEspFromCharacter(character)
    if character then
        if espinstances[character] then
            cleanup_instance(character, espinstances[character])
            espinstances[character] = nil
        end
        espCharacters[character]=nil
    end
end

local charactersFolder = Workspace:WaitForChild("Characters", 5)

local function scanCharactersFolder()
    if not charactersFolder then return end
    
    local function processContainer(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") then
                if child:GetAttribute("Health") ~= nil or child:FindFirstChild("Head") then
                    addEspToCharacter(child)
                end
                processContainer(child)
            end
        end
    end
    
    processContainer(charactersFolder)
end

scanCharactersFolder()

if charactersFolder then
    charactersFolder.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Model") then
            task.wait(0.1)
            if descendant:GetAttribute("Health") ~= nil or descendant:FindFirstChild("Head") then
                addEspToCharacter(descendant)
            end
        end
    end)

    charactersFolder.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("Model") then
            removeEspFromCharacter(descendant)
        end
    end)
end

local function refreshAllCharacters()
    for c in next,espCharacters do removeEspFromCharacter(c) end
    scanCharactersFolder()
end

local function onChange() updateESPSettings(); refreshAllCharacters() end
Toggles.ESPEnabled:OnChanged(onChange); Toggles.ESPTeamCheck:OnChanged(onChange)
Options.ESPBoxType:OnChanged(updateESPSettings)
Options.ESPBoxColorA:OnChanged(updateESPSettings); Options.ESPBoxColorB:OnChanged(updateESPSettings)
Toggles.ESPBoxFillGradient:OnChanged(updateESPSettings)
Options.ESPFillColorA:OnChanged(updateESPSettings); Options.ESPFillColorB:OnChanged(updateESPSettings)
Toggles.ESPBoxFillRotation:OnChanged(updateESPSettings); Options.ESPBoxRotationSpeed:OnChanged(updateESPSettings)
Toggles.ESPName:OnChanged(updateESPSettings); Options.ESPNameColor:OnChanged(updateESPSettings)
Toggles.ESPHealth:OnChanged(updateESPSettings)
Options.ESPHealthTopColor:OnChanged(updateESPSettings); Options.ESPHealthBottomColor:OnChanged(updateESPSettings)
Toggles.ESPHealthText:OnChanged(updateESPSettings)
Options.ESPHealthTextColor:OnChanged(updateESPSettings)
Toggles.ESPDistance:OnChanged(updateESPSettings)
Options.ESPDistanceColor:OnChanged(updateESPSettings)
Toggles.ESPTracer:OnChanged(updateESPSettings)
Options.ESPTracerColor:OnChanged(updateESPSettings); Options.ESPTracerColorB:OnChanged(updateESPSettings)
Options.ESPTracerOrigin:OnChanged(updateESPSettings)
Toggles.ESPSkeleton:OnChanged(updateESPSettings)
Options.ESPSkeletonColorA:OnChanged(updateESPSettings); Options.ESPSkeletonColorB:OnChanged(updateESPSettings)
Toggles.ESPWeapon:OnChanged(updateESPSettings)
if Options.ESPWeaponColor then Options.ESPWeaponColor:OnChanged(updateESPSettings) end
Toggles.ESPCircularTarget:OnChanged(updateESPSettings); Options.ESPCircularTargetColor:OnChanged(updateESPSettings)

updateESPSettings()

Players.PlayerRemoving:Connect(function(p)
    if priorityTargetName and p.Name == priorityTargetName then
        priorityTargetName = nil
        pcall(function()
            Options.RagePriorityTarget:SetValues(refreshPriorityList())
            Options.RagePriorityTarget:SetValue("[ 自动 ]")
        end)
    end
end)
-- =========================================================================
-- [ 视场角圆圈 ]
-- =========================================================================

local SilentFovCircle = Drawing.new("Circle")
SilentFovCircle.NumSides = 128
SilentFovCircle.Thickness = 1
SilentFovCircle.Filled = false
SilentFovCircle.Visible = false

local AimbotFovCircle = Drawing.new("Circle")
AimbotFovCircle.NumSides = 128
AimbotFovCircle.Thickness = 1
AimbotFovCircle.Filled = false
AimbotFovCircle.Visible = false

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            if not SilentFovCircle or not pcall(function() return SilentFovCircle.Visible end) then
                SilentFovCircle = Drawing.new("Circle")
                SilentFovCircle.NumSides = 128
                SilentFovCircle.Thickness = 1
                SilentFovCircle.Filled = false
            end
            if not AimbotFovCircle or not pcall(function() return AimbotFovCircle.Visible end) then
                AimbotFovCircle = Drawing.new("Circle")
                AimbotFovCircle.NumSides = 128
                AimbotFovCircle.Thickness = 1
                AimbotFovCircle.Filled = false
            end
        end)
    end
end)

-- =========================================================================
-- [ 目标系统 ]
-- =========================================================================

local SilentTarget = nil
local AimbotTarget = nil
local RageTarget = nil
local CubeSmartTarget = nil
local lockedTargetInstance = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local frameCounter = 0

local function isVisible(target)
    local ignoreList = {LP.Character}
    local myTeam = get_player_team(LP)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and get_player_team(p) == myTeam and p.Character then
            table.insert(ignoreList, p.Character)
        end
    end
    rayParams.FilterDescendantsInstances = ignoreList
    local origin = Workspace.CurrentCamera.CFrame.Position
    local direction = target.Position - origin
    local result = Workspace:Raycast(origin, direction, rayParams)
    if result then
        local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
        local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
        if hitPlayer and hitPlayer.Character == target.Parent then return true end
        return false
    end
    return true
end

local function getMemesenseActive()
    local memesenseActive = Toggles.MemesenseMainToggle and Toggles.MemesenseMainToggle.Value
    if Options.MemesenseKeybind then
        local kState = Options.MemesenseKeybind:GetState()
        if Options.MemesenseKeybind.Value ~= "None" and Options.MemesenseKeybind.Value ~= "Always" and Options.MemesenseKeybind.Value ~= "Toggle" then
            memesenseActive = kState
        end
    end
    return memesenseActive
end

local function isEnemy(char)
    if not char then return false end
    local lchar = LP.Character
    if not lchar then return false end
    local myHasVest = hasVestDetails(lchar)
    local targetHasVest = hasVestDetails(char)
    if myHasVest then return not targetHasVest
    else return targetHasVest end
end

local function FindAllTargets()
    local camera = Workspace.CurrentCamera
    local lchar = LP.Character
    if not lchar then return end
    local myTeam = get_player_team(LP)
    local screenCenter = camera.ViewportSize / 2
    local sDist, sClose = math.huge, nil
    local rDist, rClose = math.huge, nil
    local cDist, cClose = math.huge, nil
    local memesenseActive = getMemesenseActive()

    -- 直接扫描 Workspace.Characters
    local charsFolder = Workspace:FindFirstChild("Characters")
    if not charsFolder then return end

    local allChars = {}
    for _, obj in ipairs(charsFolder:GetDescendants()) do
        if obj:IsA("Model") then
            local head = obj:FindFirstChild("Head")
            local root = obj:FindFirstChild("HumanoidRootPart")
            if (head or root) and obj ~= lchar then
                -- 检查是否死亡
                local isDead = obj:GetAttribute("Dead")
                    or obj:GetAttribute("Invincible")
                local hp = obj:GetAttribute("Health")
                if not isDead and (hp == nil or hp > 0) then
                    table.insert(allChars, obj)
                end
            end
        end
    end

    -- 通过防弹背心细节判断敌人/盟友
    local function isEnemy(char)
        if not char then return false end
        -- 盟友与LP具有相同的VestDetails状态
        local myHasVest = hasVestDetails(lchar)
        local targetHasVest = hasVestDetails(char)
        if myHasVest then
            return not targetHasVest  -- 我们有背心 → 敌人没有
        else
            return targetHasVest      -- 我们没有背心 → 敌人有
        end
    end

    -- Memesense方块目标
    if memesenseActive then
        local chosenPartName = Options.CubeHitPart.Value or "Head"

        -- 检查锁定目标
        if lockedTargetInstance and lockedTargetInstance.Parent then
            local charModel = lockedTargetInstance.Parent
            local isDead = charModel:GetAttribute("Dead")
                or charModel:GetAttribute("Invincible")
            local hp = charModel:GetAttribute("Health")
            if isDead or (hp and hp <= 0) then
                lockedTargetInstance = nil
            elseif Toggles.CubeVisibleCheck and Toggles.CubeVisibleCheck.Value then
                if not isVisible(lockedTargetInstance) then
                    lockedTargetInstance = nil
                end
            end
        else
            lockedTargetInstance = nil
        end

        local bestTarget = lockedTargetInstance
        local bestDist = math.huge
        if lockedTargetInstance then
            local bp = lockedTargetInstance.Parent:FindFirstChild(chosenPartName) or lockedTargetInstance
            if bp then bestDist = (camera.CFrame.Position - bp.Position).Magnitude end
        end

        for _, char in ipairs(allChars) do
            if not isEnemy(char) then continue end
            local targetPart = char:FindFirstChild(chosenPartName)
                or char:FindFirstChild("Head")
                or char:FindFirstChild("HumanoidRootPart")
            if not targetPart then continue end

            local passVis = true
            if Toggles.CubeVisibleCheck and Toggles.CubeVisibleCheck.Value then
                if not isVisible(targetPart) then passVis = false end
            end
            if passVis then
                local dist = (camera.CFrame.Position - targetPart.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestTarget = targetPart
                end
            end
        end
        lockedTargetInstance = bestTarget
        cClose = bestTarget
    else
        lockedTargetInstance = nil
    end

    -- 狂暴机器人 + 静默瞄准
    for _, char in ipairs(allChars) do
        if not isEnemy(char) then continue end

        -- 狂暴机器人
        if Toggles.Ragebot and Toggles.Ragebot.Value then
            local rPart = char:FindFirstChild(Options.RageHitPart.Value)
                or char:FindFirstChild("Head")
                or char:FindFirstChild("HumanoidRootPart")
            if rPart then
                local _, rOnScreen = camera:WorldToViewportPoint(rPart.Position)
                local alive = true
                if Toggles.RagebotVisibleCheck and Toggles.RagebotVisibleCheck.Value and not rOnScreen then
                    alive = false
                end
                if alive and Toggles.RagebotWallCheck and Toggles.RagebotWallCheck.Value then
                    if not isVisible(rPart) then alive = false end
                end
                if alive then
                    local rd = (camera.CFrame.Position - rPart.Position).Magnitude
                    local p = Players:GetPlayerFromCharacter(char)
                    if priorityTargetName and p and p.Name == priorityTargetName then
                        rClose = rPart
                        rDist  = 0
                    else
                        if rd < rDist and rDist > 0 then
                            rDist  = rd
                            rClose = rPart
                        end
                    end
                end
            end
        end

        -- 静默瞄准
        if Toggles.SilentAim and Toggles.SilentAim.Value then
            local silentPartName = Options.SilentHitPart and Options.SilentHitPart.Value or "Head"
            local sPart = char:FindFirstChild(silentPartName)
                or char:FindFirstChild("Head")
                or char:FindFirstChild("HumanoidRootPart")
            if sPart then
                local sScreenPos, sOnScreen = camera:WorldToViewportPoint(sPart.Position)
                if sOnScreen then
                    local sd = (Vector2.new(sScreenPos.X, sScreenPos.Y) - screenCenter).Magnitude
                    local maxRadius = (Toggles.SilentUseFovCircle and Toggles.SilentUseFovCircle.Value)
                        and (Options.SilentFovCircleRadius and Options.SilentFovCircleRadius.Value or 50)
                        or 999999
                    if sd <= maxRadius then
                        local wallOk = (Toggles.SilentWallbang and Toggles.SilentWallbang.Value) or isVisible(sPart)
                        if wallOk and sd < sDist then
                            sDist = sd; sClose = sPart
                        end
                    end
                end
            end
        end
    end

    SilentTarget    = sClose
    RageTarget      = rClose
    CubeSmartTarget = cClose
end
-- =========================================================================
-- [ 显示目标系统 ]
-- =========================================================================

local ShowTargetHitMarkerLines = {}
for i = 1, 4 do
    local l = Drawing.new("Line")
    l.Thickness = 2
    l.Transparency = 1
    l.Visible = false
    ShowTargetHitMarkerLines[i] = l
end

local ShowTargetConnectorLine = Drawing.new("Line")
ShowTargetConnectorLine.Thickness = 1.5
ShowTargetConnectorLine.Transparency = 1
ShowTargetConnectorLine.Visible = false

RunService.RenderStepped:Connect(function()
    pcall(function()
        local cam = Workspace.CurrentCamera
        local memesenseActive = getMemesenseActive()
        local showTargetEnabled = memesenseActive and (Toggles.ShowTargetPlayer and Toggles.ShowTargetPlayer.Value)
        local targetMode = Options.ShowTargetMode and Options.ShowTargetMode.Value or "准星"
        local absoluteClosestPart = nil
        local minAbsoluteDist = math.huge
        local myTeam = get_player_team(LP)
        local chosenPartName = Options.CubeHitPart and Options.CubeHitPart.Value or "Head"

        if showTargetEnabled then
            for _, v in ipairs(Players:GetPlayers()) do
                if v ~= LP then
                    local char = v.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        local isDead = char:GetAttribute("Dead") or char:GetAttribute("Invincible") or (hum and hum.Health <= 0)
                        if not isDead then
                            local vTeam = get_player_team(v)
                            if myTeam ~= vTeam then
                                local pPart = char:FindFirstChild(chosenPartName) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                                if pPart then
                                    local dist = (cam.CFrame.Position - pPart.Position).Magnitude
                                    if dist < minAbsoluteDist then
                                        minAbsoluteDist = dist
                                        absoluteClosestPart = pPart
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local lineVisible = false
        local crosshairVisible = false

        if showTargetEnabled and absoluteClosestPart and absoluteClosestPart.Parent then
            local screenPos, onScreen = cam:WorldToViewportPoint(absoluteClosestPart.Position)
            local center = Vector2.new(screenPos.X, screenPos.Y)
            local currentTick = tick()

            if targetMode == "准星" then
                local crossCol = Options.ShowTargetCrosshairColor and Options.ShowTargetCrosshairColor.Value or Color3.fromRGB(0, 255, 255)
                local pulseFactor = 1 + 0.3 * math.sin(currentTick * math.pi * 2)
                local baseSize = 16 * pulseFactor
                local gap = 5 * pulseFactor
                local spinAngle = math.rad((currentTick * 180) % 360)
                local baseAngles = {0, math.pi/2, math.pi, (3*math.pi)/2}
                for j = 1, 4 do
                    local line = ShowTargetHitMarkerLines[j]
                    line.Color = crossCol
                    line.Thickness = 2
                    local totalAngle = spinAngle + baseAngles[j]
                    local cosA = math.cos(totalAngle)
                    local sinA = math.sin(totalAngle)
                    line.From = center + Vector2.new(cosA * gap, sinA * gap)
                    line.To = center + Vector2.new(cosA * (gap + baseSize), sinA * (gap + baseSize))
                    line.Visible = true
                end
                crosshairVisible = true
            elseif targetMode == "线条" then
                local lineCol = Options.ShowTargetLineColor and Options.ShowTargetLineColor.Value or Color3.fromRGB(0, 255, 255)
                local viewportCenter = cam.ViewportSize / 2
                ShowTargetConnectorLine.From = viewportCenter
                ShowTargetConnectorLine.To = center
                ShowTargetConnectorLine.Color = lineCol
                ShowTargetConnectorLine.Visible = true
                lineVisible = true
            end
        end

        if not crosshairVisible then
            for j = 1, 4 do ShowTargetHitMarkerLines[j].Visible = false end
        end
        if not lineVisible then ShowTargetConnectorLine.Visible = false end
        if not showTargetEnabled then
            for j = 1, 4 do ShowTargetHitMarkerLines[j].Visible = false end
            ShowTargetConnectorLine.Visible = false
        end
    end)
end)

-- =========================================================================
-- [ 主渲染循环 ]
-- =========================================================================

RunService.RenderStepped:Connect(function()
    frameCounter = frameCounter + 1
    local cam = Workspace.CurrentCamera
    local viewportCenter = cam.ViewportSize / 2

    pcall(function()
        SilentFovCircle.Position = viewportCenter
        SilentFovCircle.Radius = Options.SilentFovCircleRadius and Options.SilentFovCircleRadius.Value or 50
        SilentFovCircle.Color = Options.SilentFovColor and Options.SilentFovColor.Value or Color3.fromRGB(255, 0, 0)
        SilentFovCircle.Visible = Toggles.SilentAim and Toggles.SilentAim.Value and Toggles.SilentUseFovCircle and Toggles.SilentUseFovCircle.Value
        AimbotFovCircle.Position = viewportCenter
        AimbotFovCircle.Radius = Options.AimbotFovCircleRadius and Options.AimbotFovCircleRadius.Value or 50
        AimbotFovCircle.Color = Options.AimbotFovColor and Options.AimbotFovColor.Value or Color3.fromRGB(0, 255, 0)
        AimbotFovCircle.Visible = Toggles.Aimbot and Toggles.Aimbot.Value and Toggles.AimbotUseFovCircle and Toggles.AimbotUseFovCircle.Value
    end)

    if frameCounter % 2 == 0 then FindAllTargets() end

    local memesenseActive = getMemesenseActive()
    local targetToPull = nil

    if memesenseActive and CubeSmartTarget then
        targetToPull = CubeSmartTarget
    end

    if targetToPull and targetToPull.Parent then
        pcall(function()
            cam.CFrame = CFrame.new(cam.CFrame.Position, targetToPull.Position)
        end)
    end
end)

-- =========================================================================
-- [ 方块检查器 - 彩虹模式 ]
-- =========================================================================

local BulletImpactV1Part = Instance.new("Part")
BulletImpactV1Part.Name = "CubeChecker_Physical"
BulletImpactV1Part.Size = Vector3.new(1.5, 1.5, 0.01)
BulletImpactV1Part.Anchored = true
BulletImpactV1Part.CanCollide = false
BulletImpactV1Part.CanQuery = false
BulletImpactV1Part.CanTouch = false
BulletImpactV1Part.Material = Enum.Material.Neon
BulletImpactV1Part.Transparency = 0.98
BulletImpactV1Part.Parent = Workspace

local selectionBox = Instance.new("SelectionBox")
selectionBox.Adornee = BulletImpactV1Part
selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
selectionBox.LineThickness = 0.04
selectionBox.Transparency = 0.2
selectionBox.Parent = BulletImpactV1Part

local impactRayParams = RaycastParams.new()
impactRayParams.FilterType = Enum.RaycastFilterType.Exclude
impactRayParams.IgnoreWater = true

RunService.RenderStepped:Connect(function()
    pcall(function()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local memesenseActive = getMemesenseActive()
        local enabled = memesenseActive and (Toggles.BulletImpactV1Enabled and Toggles.BulletImpactV1Enabled.Value)
        BulletImpactV1Part.Parent = enabled and Workspace or nil

        if enabled then
            local sizeVal = Options.BulletImpactV1Size and Options.BulletImpactV1Size.Value or 1.5
            local maxDist = Options.BulletImpactV1Dist and Options.BulletImpactV1Dist.Value or 20
            BulletImpactV1Part.Size = Vector3.new(sizeVal, sizeVal, 0.01)

            local userColor = Options.BulletImpactV1Color and Options.BulletImpactV1Color.Value or Color3.fromRGB(255, 0, 0)

            if Toggles.BulletImpactV1Rainbow and Toggles.BulletImpactV1Rainbow.Value then
                local hue = (tick() % 5) / 5
                userColor = Color3.fromHSV(hue, 1, 1)
            end

            local origin = cam.CFrame.Position
            local direction = cam.CFrame.LookVector * maxDist
            impactRayParams.FilterDescendantsInstances = {LP.Character, BulletImpactV1Part}
            local result = Workspace:Raycast(origin, direction, impactRayParams)

            if result then
                BulletImpactV1Part.Parent = Workspace
                BulletImpactV1Part.CFrame = CFrame.lookAt(result.Position + (result.Normal * 0.02), result.Position + result.Normal)
                if CubeSmartTarget and memesenseActive and Toggles.CubeAimbotEnabled.Value then
                    BulletImpactV1Part.Color = Color3.fromRGB(0, 255, 0)
                    selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
                else
                    BulletImpactV1Part.Color = userColor
                    selectionBox.Color3 = userColor
                end
            else
                BulletImpactV1Part.Parent = nil
            end
        end
    end)
end)

         -- ╔══════════════════════════════════════════════════════╗
-- ║         手雷区域ESP  –  圆形版本 v4                  ║
-- ║  圆柱体轮廓，地形贴合，平滑淡出                      ║
-- ║  颜色与UI颜色选择器实时同步                          ║
-- ║  + 手雷图标 + 计时环                                 ║
-- ╚══════════════════════════════════════════════════════╝

if _G.BS_CircleZoneLoaded then
    warn("[区域ESP] 已在运行，跳过重复注入。")
    return
end
_G.BS_CircleZoneLoaded = true

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1)

if type(_G.Config) ~= "table" then _G.Config = {} end
_G.Config.SmokeZoneESP   = true
_G.Config.MolotovZoneESP = true

local function cfgDefault(k,v) if _G.Config[k]==nil then _G.Config[k]=v end end
cfgDefault("GrenadeESP",     false)
cfgDefault("GrenadeTracers", false)
cfgDefault("ColoredSmoke",   false)
cfgDefault("NoSmoke",        false)
cfgDefault("SmokeColor",     Color3.fromRGB(255, 0, 0))

-- ═══════════════════════════════════════════════════════
--  ★  设置  ★
-- ═══════════════════════════════════════════════════════

local SETTINGS = {
    Smoke = {
        RadiusTrim   = 0.0,
        HeightOffset = 0.3,
        Segments     = 40,
        Thickness    = 0.28,
    },
    Molotov = {
        RadiusTrim   = 4.5,
        HeightOffset = 0.3,
        Segments     = 40,
        Thickness    = 0.28,
    },
}

local FADE_IN_TIME    = 0.4
local FADE_OUT_TIME   = 0.6
local RECALC_INTERVAL = 0.05
local RAYCAST_DOWN    = 14

local function GetMolotovColor()
    if Options and Options.GrenadeZoneColor then
        return Options.GrenadeZoneColor.Value
    end
    return Color3.fromRGB(255, 60, 0)
end

local function GetSmokeColor()
    if Options and Options.SmokeZoneColor then
        return Options.SmokeZoneColor.Value
    end
    return Color3.fromRGB(180, 180, 180)
end

local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera

local ActiveZones       = {}
local DebrisConnections = {}

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function ComputeZoneBounds(parent)
    local sumX, sumZ = 0, 0
    local minY = math.huge
    local count = 0
    local parts = {}
    for _, v in ipairs(parent:GetChildren()) do
        if v:IsA("BasePart") then
            count = count + 1
            sumX  = sumX + v.Position.X
            sumZ  = sumZ + v.Position.Z
            local b = v.Position.Y - v.Size.Y * 0.5
            if b < minY then minY = b end
            table.insert(parts, v)
        end
    end
    if count == 0 then return nil, nil, false end
    local cx, cz = sumX/count, sumZ/count
    local maxR = 0
    for _, p in ipairs(parts) do
        local dx  = p.Position.X - cx
        local dz  = p.Position.Z - cz
        local ext = math.max(p.Size.X, p.Size.Z) * 0.5
        local r   = math.sqrt(dx*dx + dz*dz) + ext
        if r > maxR then maxR = r end
    end
    return Vector3.new(cx, minY, cz), math.max(maxR, 1.2), true
end

local function GetGroundY(x, baseY, z, excludeList)
    RayParams.FilterDescendantsInstances = excludeList or {}
    local result = workspace:Raycast(
        Vector3.new(x, baseY + 5, z),
        Vector3.new(0, -RAYCAST_DOWN, 0),
        RayParams
    )
    return result and result.Position.Y or baseY
end

local function MakeCylinder(col, thickness)
    local p = Instance.new("Part")
    p.Name         = "BS_RingSeg"
    p.Anchored     = true
    p.CanCollide   = false
    p.CanQuery     = false
    p.CastShadow   = false
    p.Material     = Enum.Material.Neon
    p.Color        = col
    p.Transparency = 1
    p.Shape        = Enum.PartType.Cylinder
    p.Size         = Vector3.new(thickness, thickness, thickness)
    p.Parent       = workspace
    return p
end

local function CreateZoneRing(parent, cfg, isMolotov)
    if ActiveZones[parent] then return end

    local segments  = cfg.Segments  or 40
    local thickness = cfg.Thickness or 0.28
    local initColor = isMolotov and GetMolotovColor() or GetSmokeColor()

    local cylinders = {}
    local allParts  = {}
    for i = 1, segments do
        local cyl = MakeCylinder(initColor, thickness)
        table.insert(cylinders, cyl)
        table.insert(allParts, cyl)
    end

    local record = {
        cylinders  = cylinders,
        allParts   = allParts,
        cfg        = cfg,
        isMolotov  = isMolotov,
        lastRecalc = 0,
        lastRadius = 1,
        alive      = true,
        fadingOut  = false,
        fadeAlpha  = 0,
    }
    ActiveZones[parent] = record

    local fadeInStart = tick()

    local function CurrentAlpha()
        if record.fadingOut then return record.fadeAlpha end
        return math.clamp((tick() - fadeInStart) / FADE_IN_TIME, 0, 1)
    end

    local function FadeOut()
        if record.fadingOut then return end
        record.fadingOut = true
        record.fadeAlpha = CurrentAlpha()
        local startTick  = tick()
        local startAlpha = record.fadeAlpha
        local conn
        conn = RunService.Heartbeat:Connect(function()
            local t = math.clamp((tick() - startTick) / FADE_OUT_TIME, 0, 1)
            record.fadeAlpha = startAlpha * (1 - t)
            local transp = 1 - record.fadeAlpha
            for _, cyl in ipairs(cylinders) do
                pcall(function() cyl.Transparency = transp end)
            end
            if t >= 1 then
                conn:Disconnect()
                record.alive = false
                for _, cyl in ipairs(cylinders) do
                    pcall(function() cyl:Destroy() end)
                end
                ActiveZones[parent] = nil
            end
        end)
    end

    parent.AncestryChanged:Connect(function(_, newParent)
        if newParent == nil then FadeOut() end
    end)

    local updateConn
    updateConn = RunService.Heartbeat:Connect(function()
        if not record.alive then updateConn:Disconnect() return end
        if not parent or not parent.Parent then
            updateConn:Disconnect()
            FadeOut()
            return
        end

        local now = tick()
        if now - record.lastRecalc < RECALC_INTERVAL then return end
        record.lastRecalc = now

        local center, radius, found = ComputeZoneBounds(parent)
        if not found then return end

        local trim     = cfg.RadiusTrim or 0
        local smoothed = record.lastRadius + (radius - record.lastRadius) * 0.25
        record.lastRadius = smoothed
        local finalR   = math.max(smoothed - trim, 0.8)

        local alpha  = CurrentAlpha()
        local transp = 1 - alpha
        local col    = record.isMolotov and GetMolotovColor() or GetSmokeColor()

        for i, cyl in ipairs(cylinders) do
            local angleA   = (2*math.pi) * ((i-1) / segments)
            local angleB   = (2*math.pi) * (i     / segments)
            local angleMid = (angleA + angleB) / 2

            local xA = center.X + math.cos(angleA)   * finalR
            local zA = center.Z + math.sin(angleA)   * finalR
            local xB = center.X + math.cos(angleB)   * finalR
            local zB = center.Z + math.sin(angleB)   * finalR
            local xM = center.X + math.cos(angleMid) * finalR
            local zM = center.Z + math.sin(angleMid) * finalR

            local yA = GetGroundY(xA, center.Y, zA, allParts) + (cfg.HeightOffset or 0.3)
            local yB = GetGroundY(xB, center.Y, zB, allParts) + (cfg.HeightOffset or 0.3)
            local yM = (yA + yB) * 0.5

            local posA = Vector3.new(xA, yA, zA)
            local posB = Vector3.new(xB, yB, zB)
            local mid  = Vector3.new(xM, yM, zM)
            local dir  = posB - posA
            local len  = dir.Magnitude
            if len < 0.001 then continue end

            local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.rad(90), 0)

            cyl.CFrame       = cf
            cyl.Size         = Vector3.new(len, thickness, thickness)
            cyl.Color        = col
            cyl.Transparency = transp
        end
    end)

    record.updateConn = updateConn
end

-- =========================================================================
-- [ 手雷区域扫描器 ]
-- =========================================================================

local function IsToggleOn(name)
    if Toggles and Toggles[name] then return Toggles[name].Value end
    return false
end

local ScannedObjects = {}

local function TryHandleObject(obj)
    if not obj or not obj.Parent then return end
    if ScannedObjects[obj] then return end

    local name = obj.Name:lower()

    local isMolotov = (
        name:find("firezone") or name:find("fire_zone") or
        name:find("molotov")  or name:find("voxelfire") or
        name:find("ignite")   or name:find("flamezone")  or
        name:find("firearea") or name:find("burnzone")
    )

    local isSmoke = (
        name:find("smokezone") or name:find("smoke_zone") or
        name:find("voxelsmoke") or name:find("smokearea") or
        name:find("gaszone")
    )

    if isMolotov and IsToggleOn("MolotovZoneESP") then
        ScannedObjects[obj] = true
        CreateZoneRing(obj, SETTINGS.Molotov, true)
        obj.AncestryChanged:Connect(function(_, p)
            if p == nil then ScannedObjects[obj] = nil end
        end)
    elseif isSmoke and IsToggleOn("SmokeZoneESP") then
        ScannedObjects[obj] = true
        CreateZoneRing(obj, SETTINGS.Smoke, false)
        obj.AncestryChanged:Connect(function(_, p)
            if p == nil then ScannedObjects[obj] = nil end
        end)
    end
end

local function ScanFolder(folder)
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        TryHandleObject(child)
        for _, sub in ipairs(child:GetChildren()) do
            TryHandleObject(sub)
        end
    end
    folder.ChildAdded:Connect(function(child)
        task.wait()
        TryHandleObject(child)
        child.ChildAdded:Connect(function(sub)
            task.wait()
            TryHandleObject(sub)
        end)
    end)
end

task.spawn(function()
    task.wait(1)
    ScanFolder(Workspace)
    local debris = Workspace:FindFirstChild("Debris")
    if debris then ScanFolder(debris) end
    local effects = Workspace:FindFirstChild("Effects")
    if effects then ScanFolder(effects) end
    local fx = Workspace:FindFirstChild("FX")
    if fx then ScanFolder(fx) end
    Workspace.ChildAdded:Connect(function(child)
        local n = child.Name:lower()
        if n == "debris" or n == "effects" or n == "fx" then
            ScanFolder(child)
        end
        task.wait()
        TryHandleObject(child)
        child.ChildAdded:Connect(function(sub)
            task.wait()
            TryHandleObject(sub)
        end)
    end)
    while task.wait(3) do
        for _, child in ipairs(Workspace:GetChildren()) do
            TryHandleObject(child)
            for _, sub in ipairs(child:GetChildren()) do
                TryHandleObject(sub)
            end
        end
    end
end)

local function VisualizeShrapnel(pos)
    if not _G.Config.GrenadeTracers then return end
    local lines = {}
    for i = 1, 16 do
        local line = Drawing.new("Line")
        line.Visible = true
        line.Color = Color3.fromRGB(255,100,0)
        line.Thickness = 2
        line.Transparency = 1
        local dir = Vector3.new(math.random()*2-1,math.random()*2-1,math.random()*2-1).Unit
        table.insert(lines, {obj=line, dir=dir})
    end
    task.spawn(function()
        local Cam = workspace.CurrentCamera
        local s = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local t = tick()-s
            if t > 0.8 then
                conn:Disconnect()
                for _,l in ipairs(lines) do l.obj:Remove() end
                return
            end
            local a = math.clamp(t/0.8,0,1)
            local e = (1-(1-a)^2)*12
            for _,l in ipairs(lines) do
                local wS = pos+l.dir*(e*0.2)
                local wE = pos+l.dir*e
                local sS,o1 = Cam:WorldToViewportPoint(wS)
                local sE,o2 = Cam:WorldToViewportPoint(wE)
                l.obj.Visible = o1 or o2
                if l.obj.Visible then
                    l.obj.From = Vector2.new(sS.X,sS.Y)
                    l.obj.To   = Vector2.new(sE.X,sE.Y)
                    l.obj.Transparency = 1-a
                end
            end
        end)
    end)
end

-- =========================================================================
-- [ 手雷飞行追踪 ]
-- =========================================================================

local GrenadeFlightTracers = {}

local function StartGrenadeFlightTracer(part)
    if not part or not part:IsA("BasePart") then return end
    if GrenadeFlightTracers[part] then return end

    local MAX_TRAIL = 30
    local history   = {}
    local lines     = {}

    for i = 1, MAX_TRAIL do
        local l = Drawing.new("Line")
        l.Visible      = false
        l.Thickness    = 2
        l.Transparency = 1
        lines[i] = l
    end

    GrenadeFlightTracers[part] = lines

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local enabled = Toggles and Toggles.GrenadeTracers and Toggles.GrenadeTracers.Value
        local col = Options and Options.GrenadeTracerColor and Options.GrenadeTracerColor.Value or Color3.fromRGB(255, 100, 0)

        if not part or not part.Parent then
            conn:Disconnect()
            GrenadeFlightTracers[part] = nil
            if #history > 0 then
                VisualizeShrapnel(history[1])
            end
            for _, l in ipairs(lines) do
                pcall(function() l:Remove() end)
            end
            return
        end

        if not enabled then
            for _, l in ipairs(lines) do l.Visible = false end
            return
        end

        table.insert(history, 1, part.Position)
        if #history > MAX_TRAIL + 1 then table.remove(history) end

        local cam = workspace.CurrentCamera
        for i = 1, MAX_TRAIL do
            local l  = lines[i]
            local p1 = history[i]
            local p2 = history[i + 1]
            if not p1 or not p2 then
                l.Visible = false
                continue
            end
            local s1, o1 = cam:WorldToViewportPoint(p1)
            local s2, o2 = cam:WorldToViewportPoint(p2)
            if (o1 or o2) and s1.Z > 0 and s2.Z > 0 then
                local fade = 1 - (i / MAX_TRAIL)
                l.From      = Vector2.new(s1.X, s1.Y)
                l.To        = Vector2.new(s2.X, s2.Y)
                l.Color     = col
                l.Thickness = math.max(2 * fade, 0.5)
                l.Transparency = 1 - fade
                l.Visible   = true
            else
                l.Visible = false
            end
        end
    end)
end

-- =========================================================================
-- [ 飞行手雷检测器 ]
-- =========================================================================

local TrackedGrenades = {}

local GRENADE_PATTERNS = {
    "grenade","flash","molotov","bang","frag",
    "he_","_he","throwable","projectile","nade",
    "incendiary","decoy","c4"
}

local GRENADE_BLACKLIST = {
    "gun","rifle","pistol","bullet","casing","debris",
    "light","muzzle","launch","effect","arm","leg",
    "torso","head","humanoid","mesh","handle",
    "constraint","weld","motor","zone","voxel"
}

local function isGrenadeObject(obj)
    if not obj:IsA("BasePart") and not obj:IsA("Model") then return false end
    local name = obj.Name:lower()
    for _, p in ipairs(GRENADE_BLACKLIST) do
        if name:find(p) then return false end
    end
    if #name > 20 and name:find("%-") then return true end
    for _, p in ipairs(GRENADE_PATTERNS) do
        if name:find(p) then return true end
    end
    return false
end

local function TryTrackGrenade(obj)
    if TrackedGrenades[obj] then return end

    local part = obj
    if obj:IsA("Model") then
        part = obj:FindFirstChild("Handle")
             or obj:FindFirstChildWhichIsA("BasePart")
    end
    if not part or not part:IsA("BasePart") then return end
    if part.Size.Magnitude > 8 then return end
    if Players:GetPlayerFromCharacter(obj) then return end
    if Players:GetPlayerFromCharacter(obj.Parent) then return end

    TrackedGrenades[obj] = true

    local cc
    cc = obj.AncestryChanged:Connect(function(_, p)
        if p == nil then
            TrackedGrenades[obj] = nil
            cc:Disconnect()
        end
    end)

    StartGrenadeFlightTracer(part)
end

local function ScanForGrenades(folder)
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        if isGrenadeObject(child) then TryTrackGrenade(child) end
        if child:IsA("Model") then
            for _, sub in ipairs(child:GetChildren()) do
                if isGrenadeObject(sub) then TryTrackGrenade(sub) end
            end
        end
    end
end

task.spawn(function()
    task.wait(0.5)
    ScanForGrenades(Workspace)

    local toWatch = {"Debris","Effects","FX","Projectiles","Grenades"}
    for _, fname in ipairs(toWatch) do
        local f = Workspace:FindFirstChild(fname)
        if f then
            ScanForGrenades(f)
            f.ChildAdded:Connect(function(child)
                task.wait()
                if isGrenadeObject(child) then TryTrackGrenade(child) end
            end)
        end
    end

    Workspace.ChildAdded:Connect(function(child)
        task.wait()
        if isGrenadeObject(child) then TryTrackGrenade(child) end
        local n = child.Name:lower()
        if n=="debris" or n=="effects" or n=="fx" or n=="projectiles" or n=="grenades" then
            ScanForGrenades(child)
            child.ChildAdded:Connect(function(sub)
                task.wait()
                if isGrenadeObject(sub) then TryTrackGrenade(sub) end
            end)
        end
        child.ChildAdded:Connect(function(sub)
            task.wait()
            if isGrenadeObject(sub) then TryTrackGrenade(sub) end
        end)
    end)
end)

-- =========================================================================
-- [ Chams V3 — 防弹背心细节队伍检查 + 可见/不可见高亮 ]
-- =========================================================================

task.spawn(function()
    repeat task.wait() until Tabs and Tabs.Visuals
    repeat task.wait() until Toggles and Options

    local ChamsGroupbox = Tabs.Visuals:AddRightGroupbox("透视")

    ChamsGroupbox:AddToggle("ChamsEnabled",   { Text = "启用",    Default = false })
    ChamsGroupbox:AddToggle("ChamsTeamCheck", { Text = "队伍检查",  Default = true  })

    ChamsGroupbox:AddDivider()

    ChamsGroupbox:AddLabel("可见")
    ChamsGroupbox:AddDropdown("ChamsMaterialVisible", {
        Text    = "可见材质",
        Values  = {"霓虹", "金属", "力场", "光滑塑料"},
        Default = "霓虹",
    })
    ChamsGroupbox:AddLabel("可见颜色"):AddColorPicker("ChamsColorVisible", {
        Default = Color3.fromRGB(0, 200, 0),
        Title   = "可见颜色",
    })
    ChamsGroupbox:AddSlider("ChamsAlphaVisible", {
        Text     = "可见填充透明度",
        Default  = 0.3,
        Min      = 0,
        Max      = 1,
        Rounding = 2,
    })
    ChamsGroupbox:AddSlider("ChamsOutlineAlphaVisible", {
        Text     = "可见轮廓透明度",
        Default  = 0,
        Min      = 0,
        Max      = 1,
        Rounding = 2,
    })

    ChamsGroupbox:AddDivider()

    ChamsGroupbox:AddLabel("不可见")
    ChamsGroupbox:AddDropdown("ChamsMaterialUnvisible", {
        Text    = "不可见材质",
        Values  = {"霓虹", "金属", "力场", "光滑塑料"},
        Default = "金属",
    })
    ChamsGroupbox:AddLabel("不可见颜色"):AddColorPicker("ChamsColorUnvisible", {
        Default = Color3.fromRGB(200, 0, 0),
        Title   = "不可见颜色",
    })
    ChamsGroupbox:AddSlider("ChamsAlphaUnvisible", {
        Text     = "不可见填充透明度",
        Default  = 0.3,
        Min      = 0,
        Max      = 1,
        Rounding = 2,
    })
    ChamsGroupbox:AddSlider("ChamsOutlineAlphaUnvisible", {
        Text     = "不可见轮廓透明度",
        Default  = 0,
        Min      = 0,
        Max      = 1,
        Rounding = 2,
    })

    local Players   = game:GetService("Players")
    local RunService= game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local LP        = Players.LocalPlayer

    local ESPFolder
    pcall(function()
        ESPFolder = Instance.new("Folder", game:GetService("CoreGui"))
        ESPFolder.Name = "Chams_Container"
    end)

    local Highlights = {}

    local function getMaterial(str)
        if str == "金属"          then return Enum.Material.Metal
        elseif str == "力场" then return Enum.Material.ForceField
        elseif str == "光滑塑料" then return Enum.Material.SmoothPlastic
        else return Enum.Material.Neon end
    end

    local function removeChams(char)
        if Highlights[char] then
            pcall(function() Highlights[char].visible:Destroy() end)
            pcall(function() Highlights[char].unvisible:Destroy() end)
            Highlights[char] = nil
        end
        if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            pcall(function()
                if obj:IsA("BasePart") and obj:GetAttribute("OrigMat") then
                    obj.Material = Enum.Material[obj:GetAttribute("OrigMat")]
                    obj.Color    = obj:GetAttribute("OrigColor") or obj.Color
                    obj:SetAttribute("OrigMat",   nil)
                    obj:SetAttribute("OrigColor", nil)
                end
            end)
        end
    end

    local function hasVestDetails(char)
        if not char then return false end
        local armor = char:FindFirstChild("CharacterArmor")
        if armor then
            return armor:FindFirstChild("VestDetails") ~= nil
        end
        return false
    end

    local function isTeammate(char)
        if not char then return false end
        local myChar = LP.Character
        if not myChar then return false end
        local myHasVest  = hasVestDetails(myChar)
        local hisHasVest = hasVestDetails(char)
        return myHasVest == hisHasVest
    end

    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude

    local function isVisible(char)
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        if not root then return false end
        local camPos = Workspace.CurrentCamera.CFrame.Position
        local dir    = root.Position - camPos
        RayParams.FilterDescendantsInstances = {LP.Character, char}
        local result = Workspace:Raycast(camPos, dir, RayParams)
        return result == nil
    end

    RunService.RenderStepped:Connect(function()
        local enabled     = Toggles.ChamsEnabled   and Toggles.ChamsEnabled.Value
        local teamCheckOn = Toggles.ChamsTeamCheck and Toggles.ChamsTeamCheck.Value

        local matVisible   = getMaterial(Options.ChamsMaterialVisible   and Options.ChamsMaterialVisible.Value   or "霓虹")
        local matUnvisible = getMaterial(Options.ChamsMaterialUnvisible and Options.ChamsMaterialUnvisible.Value or "金属")
        local colVisible   = Options.ChamsColorVisible   and Options.ChamsColorVisible.Value   or Color3.fromRGB(0,200,0)
        local colUnvisible = Options.ChamsColorUnvisible and Options.ChamsColorUnvisible.Value or Color3.fromRGB(200,0,0)

        local fillAlphaVis    = Options.ChamsAlphaVisible         and Options.ChamsAlphaVisible.Value         or 0.3
        local fillAlphaUnvis  = Options.ChamsAlphaUnvisible       and Options.ChamsAlphaUnvisible.Value       or 0.3
        local outAlphaVis     = Options.ChamsOutlineAlphaVisible   and Options.ChamsOutlineAlphaVisible.Value   or 0
        local outAlphaUnvis   = Options.ChamsOutlineAlphaUnvisible and Options.ChamsOutlineAlphaUnvisible.Value or 0

        local charactersFolder = Workspace:FindFirstChild("Characters")
        if not charactersFolder then return end

        local enemyChars = {}
        for _, obj in ipairs(charactersFolder:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") then
                local char = obj
                if char == LP.Character then continue end
                if teamCheckOn and isTeammate(char) then
                    removeChams(char)
                    continue
                end
                if not enabled then
                    removeChams(char)
                    continue
                end
                table.insert(enemyChars, char)
            end
        end

        for _, char in ipairs(enemyChars) do
            if not Highlights[char] then
                local hlVis = Instance.new("Highlight")
                hlVis.DepthMode           = Enum.HighlightDepthMode.Occluded
                hlVis.Parent              = ESPFolder

                local hlUnvis = Instance.new("Highlight")
                hlUnvis.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
                hlUnvis.Parent            = ESPFolder

                Highlights[char] = { visible = hlVis, unvisible = hlUnvis }

                char.AncestryChanged:Connect(function(_, newParent)
                    if newParent == nil then removeChams(char) end
                end)
            end

            local hl  = Highlights[char]
            local seen = isVisible(char)

            hl.visible.Adornee            = char
            hl.visible.FillColor          = colVisible
            hl.visible.OutlineColor       = colVisible
            hl.visible.FillTransparency   = fillAlphaVis
            hl.visible.OutlineTransparency= outAlphaVis
            hl.visible.Enabled            = seen

            hl.unvisible.Adornee            = char
            hl.unvisible.FillColor          = colUnvisible
            hl.unvisible.OutlineColor       = colUnvisible
            hl.unvisible.FillTransparency   = fillAlphaUnvis
            hl.unvisible.OutlineTransparency= outAlphaUnvis
            hl.unvisible.Enabled            = not seen

            local targetMat = seen and matVisible or matUnvisible
            local targetCol = seen and colVisible or colUnvisible

            for _, part in ipairs(char:GetDescendants()) do
                pcall(function()
                    if part:IsA("SurfaceAppearance") or part:IsA("Decal") or part:IsA("Texture") then
                        part:Destroy()
                    elseif part:IsA("MeshPart") and part.TextureID ~= "" then
                        part.TextureID = ""
                    elseif part:IsA("SpecialMesh") and part.TextureId ~= "" then
                        part.TextureId = ""
                    end
                    if part:IsA("BasePart") then
                        if not part:GetAttribute("OrigMat") then
                            part:SetAttribute("OrigMat",   part.Material.Name)
                            part:SetAttribute("OrigColor", part.Color)
                        end
                        part.Material = targetMat
                        part.Color    = targetCol
                    end
                end)
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            removeChams(player.Character)
        end
    end)
end)

-- =========================================================================
-- [ 瞬间换弹 ]
-- =========================================================================

task.spawn(function()
    local MiscWeaponBox = Tabs.Weapons:AddRightGroupbox("武器", "crosshair")

    MiscWeaponBox:AddToggle("InstantReload", {
        Text = "瞬间换弹",
        Default = false,
    })

    local RELOAD_ANIMS = {
        ["Reload"]       = true,
        ["ReloadStart"]  = true,
        ["ReloadAction"] = true,
        ["ReloadEnd"]    = true,
    }

    local RELOAD_SPEED = 199
    local reloadHooked = {}

    local function getWeaponObjectSafe()
        local ok, IC = pcall(function()
            return require(game:GetService("ReplicatedStorage").Controllers.InventoryController)
        end)
        if not ok or not IC then return nil end
        return IC.peekCurrentEquippedForMovement and IC.peekCurrentEquippedForMovement() or nil
    end

    local function hookAnimationReload(animModule)
        if not animModule or reloadHooked[animModule] then return end
        reloadHooked[animModule] = true

        pcall(function()
            local origPlay = animModule.play
            animModule.play = function(self_anim, animName, ...)
                local track = origPlay(self_anim, animName, ...)
                if track and RELOAD_ANIMS[animName] then
                    task.defer(function()
                        pcall(function()
                            if Toggles.InstantReload and Toggles.InstantReload.Value then
                                if track.IsPlaying then
                                    track:AdjustSpeed(RELOAD_SPEED)
                                end
                            end
                        end)
                    end)
                end
                return track
            end
        end)
    end

    local lastReloadWeapon = nil

    task.spawn(function()
        while task.wait(0.1) do
            pcall(function()
                local weapon = getWeaponObjectSafe()
                if not weapon then return end

                if weapon ~= lastReloadWeapon then
                    lastReloadWeapon = weapon
                    if weapon.Viewmodel and weapon.Viewmodel.Animation then
                        hookAnimationReload(weapon.Viewmodel.Animation)
                    end
                    if weapon.CharacterAnimator then
                        hookAnimationReload(weapon.CharacterAnimator)
                    end
                end

                if not (Toggles.InstantReload and Toggles.InstantReload.Value) then return end

                if weapon.IsReloading then
                    pcall(function()
                        if weapon.Viewmodel and weapon.Viewmodel.Animation and weapon.Viewmodel.Animation.Animations then
                            for name, track in pairs(weapon.Viewmodel.Animation.Animations) do
                                if RELOAD_ANIMS[name] and track.IsPlaying then
                                    track:AdjustSpeed(RELOAD_SPEED)
                                end
                            end
                        end
                        if weapon.CharacterAnimator and weapon.CharacterAnimator.Animations then
                            for name, track in pairs(weapon.CharacterAnimator.Animations) do
                                if RELOAD_ANIMS[name] and track.IsPlaying then
                                    track:AdjustSpeed(RELOAD_SPEED)
                                end
                            end
                        end
                    end)
                end
            end)
        end
    end)

    pcall(function()
        local IC = require(game:GetService("ReplicatedStorage").Controllers.InventoryController)
        if IC.OnInventoryItemEquipped then
            IC.OnInventoryItemEquipped:Connect(function(_, weapon)
                if not weapon then return end
                task.defer(function()
                    if weapon.Viewmodel and weapon.Viewmodel.Animation then
                        hookAnimationReload(weapon.Viewmodel.Animation)
                    end
                    if weapon.CharacterAnimator then
                        hookAnimationReload(weapon.CharacterAnimator)
                    end
                end)
            end)
        end
    end)
end)

-- =========================================================================
-- [ 设置最终化 ]
-- =========================================================================

SettingsGroup:AddButton("卸载菜单", function()
    Library:Unload()
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("memesensescript")
SaveManager:SetFolder("memesensescript/bloxstrike")
SaveManager:SetSubFolder("memesensescript")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

-- =========================================================================
-- [ MEMESENSE 完整构建结束 ]
-- =========================================================================