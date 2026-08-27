-- ===================== 服务加载 =====================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- ===================== WindUI 加载 =====================
local cloneref = (cloneref or clonereference or function(instance) return instance end)
local ReplicatedStorage_clone = cloneref(ReplicatedStorage)

local WindUI
do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)
    if ok then
        WindUI = result
    else
        if cloneref(RunService):IsStudio() then
            WindUI = require(cloneref(ReplicatedStorage_clone:WaitForChild("WindUI"):WaitForChild("Init")))
        else
            WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
        end
    end
end

-- ===================== 创建 WindUI 窗口 =====================
local Window = WindUI:CreateWindow({
    Title = "GOC 私人脚本",
    Folder = "GOC_Hub",
    Icon = "crown",
    NewElements = true,
    HideSearchBar = true,
    OpenButton = {
        Title = "🔱 GOC",
        CornerRadius = UDim.new(0, 12),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 1.0,
        Size = UDim2.new(0, 180, 0, 60),
        Color = ColorSequence.new(Color3.fromHex("#FFD700"), Color3.fromHex("#FF6B00")),
    },
    Topbar = {
        Height = 48,
        ButtonsType = "Mac",
    },
})

-- ===================== 颜色常量 =====================
local Gold = Color3.fromHex("#FFD700")
local Orange = Color3.fromHex("#FF8C00")
local Green = Color3.fromHex("#00E676")
local Red = Color3.fromHex("#FF3D3D")
local Purple = Color3.fromHex("#B388FF")
local Blue = Color3.fromHex("#448AFF")

-- ===================== 🏠 首页标签页 =====================
local HomeTab = Window:Tab({
    Title = "🏠 首页",
    Desc = "GOC 私人脚本中心",
    Icon = "home",
    IconColor = Gold,
    IconShape = "Square",
})

local HomeSection = HomeTab:Section({Title = "欢迎使用"})
HomeSection:Space({Columns = 1})
HomeSection:Section({Title = "⚜️ GOC 私人脚本 ⚜️", TextSize = 28, FontWeight = Enum.FontWeight.Bold})
HomeSection:Space()
HomeSection:Section({Title = "━━━━━━━━━━━━━━━━━━━━━━━━", TextSize = 12, TextTransparency = 0.5})
HomeSection:Space()
HomeSection:Section({Title = "🔰 功能导航", TextSize = 18, FontWeight = Enum.FontWeight.SemiBold})
HomeSection:Space()
HomeSection:Button({
    Title = "💰 自动刷钱控制",
    Description = "点击前往刷钱控制面板",
    Color = Green,
    Icon = "dollar-sign",
    Justify = "Left",
    Callback = function() print("[GOC] 请切换到'刷钱控制'标签页") end,
})
HomeSection:Space()
HomeSection:Button({
    Title = "🎵 音乐播放器",
    Description = "点击前往内置音乐库",
    Color = Purple,
    Icon = "music",
    Justify = "Left",
    Callback = function() print("[GOC] 请切换到'音乐播放器'标签页") end,
})
HomeSection:Space()
HomeSection:Section({Title = "━━━━━━━━━━━━━━━━━━━━━━━━", TextSize = 12, TextTransparency = 0.5})
HomeSection:Space()
HomeSection:Section({Title = "📋 脚本信息", TextSize = 16, FontWeight = Enum.FontWeight.SemiBold})
HomeSection:Space()
HomeSection:Section({
    Title = "🧑‍💻 作者：GOC\n📅 版本：v2.0.0\n🕹️ 类型：自动农场 + 音乐播放\n💎 专属私人脚本\n\n⚠️ 请勿外传，仅供个人使用",
    TextSize = 14,
    TextTransparency = 0.3,
})
HomeSection:Space()
HomeSection:Section({Title = "━━━━━━━━━━━━━━━━━━━━━━━━", TextSize = 12, TextTransparency = 0.5})
HomeSection:Space()
HomeSection:Section({Title = "🌟 状态总览", TextSize = 16, FontWeight = Enum.FontWeight.SemiBold})
HomeSection:Space()
local HomeStatusText = HomeSection:Section({
    Title = "自动刷钱：⚫ 未启动\n音乐播放：🎵 无",
    TextSize = 14,
    TextTransparency = 0.25,
})
HomeSection:Space()
HomeSection:Section({Title = "🔱 GOC Private Script © 2024 🔱", TextSize = 11, TextTransparency = 0.5})

-- ===================== 💰 刷钱控制标签页（无车辆版） =====================
local FarmTab = Window:Tab({
    Title = "💰 刷钱控制",
    Desc = "自动农场循环脚本",
    Icon = "play",
    IconColor = Green,
    IconShape = "Square",
})

local FarmSection = FarmTab:Section({Title = "⚙️ 刷钱脚本"})
FarmSection:Section({Title = "点击下方按钮，直接开始无限循环刷钱", TextSize = 14, FontWeight = Enum.FontWeight.Medium})
FarmSection:Space()

FarmSection:Button({
    Title = "🔥 开始刷钱（无限循环）",
    Description = "点击后执行刷钱脚本，不会停止",
    Color = Green,
    Justify = "Center",
    Callback = function()
        task.spawn(function()
            local char = player.Character or player.CharacterAdded:Wait()
            local hrp = char:WaitForChild("HumanoidRootPart")

            local pos1 = Vector3.new(6823.82, 17.58, 33.67)
            local pos2 = Vector3.new(6822.64, 17.63, 19.72)
            local pos3 = Vector3.new(6859.28, 17.58, -17.58)
            local pos4 = Vector3.new(6886.41, 17.38, 113.27)
            local pos4b = Vector3.new(39.27, 17.38, 137.08)
            local pos5 = Vector3.new(205.58, 17.40, -45.70)
            local pos6 = Vector3.new(64.16, 17.38, 101.49)
            local pos7 = Vector3.new(5064.40, 17.38, 149.43)
            local pos8 = Vector3.new(6883.75, 17.38, 126.79)
            local pos9 = Vector3.new(6810.84, 17.60, -36.79)

            local avacados = Workspace:WaitForChild("WorldBuyableItems"):WaitForChild("Crate Of Avacados")
            local diamondRing = Workspace:WaitForChild("WorldBuyableItems"):WaitForChild("Fake Diamond Ring")

            local buyRemote = ReplicatedStorage:WaitForChild("__remotes")
                :WaitForChild("WorldBuyableItemService")
                :WaitForChild("PurchaseWorldBuyableItem")

            local function noclip()
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide == true then
                        v.CanCollide = false
                    end
                end
            end

            local function smoothMove(targetPos, speed)
                speed = speed or 4
                local startPos = hrp.Position
                local distance = (targetPos - startPos).Magnitude
                local steps = math.floor(distance / speed)
                steps = math.max(steps, 10)
                for i = 1, steps do
                    local t = i / steps
                    hrp.CFrame = CFrame.new(startPos:Lerp(targetPos, t))
                    task.wait(0.02)
                end
                hrp.CFrame = CFrame.new(targetPos)
            end

            local function teleport(pos)
                hrp.CFrame = CFrame.new(pos)
            end

            local function sellItems()
                for _, v in pairs(Workspace:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Parent and v.Parent.Name:lower():find("sell") then
                        fireproximityprompt(v)
                        print("已触发售货，停留5秒...")
                        task.wait(5)
                        print("售货完成"