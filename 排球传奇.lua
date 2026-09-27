-- ============================================
-- ★ 红星 hx 中心 —— 测试脚本 + 排球传奇范围增大
-- ============================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- 加载 Obsidian
local ObsidianRepo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
loadstring(game:HttpGet(ObsidianRepo .. "Library.lua"))()
local Library = getgenv().Library or getgenv().ObsidianLibrary
if not Library then warn("[Grief] Library = nil"); return end

-- 创建窗口（标题和 Footer 留空，我们自己贴）
local Window = Library:CreateWindow({
    Title = "",
    Footer = "",
    Center = true,
    AutoShow = true,
    NotifySide = "Right",
})

-- ============================================
-- 红白标题：★ 红星 hx 中心
-- ============================================
local function getWindowHolder()
    return Window.Holder or Window.MainFrame
end

local function buildColoredTitle(parent, position, size)
    local frame = Instance.new("Frame")
    frame.Name = "GriefColoredTitle"
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Position = position
    frame.Size = size
    frame.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 0)
    layout.Parent = frame

    local function mk(text, color, order, fontSize)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.BorderSizePixel = 0
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = fontSize or 20
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        lbl.Size = UDim2.new(0, 0, 1, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.X
        lbl.LayoutOrder = order
        lbl.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Parent = lbl
        return lbl
    end

    mk("★ ", Color3.fromRGB(255, 200, 0), 0, 20)
    mk("红星 ", Color3.fromRGB(255, 0, 0), 1, 20)
    mk("h", Color3.fromRGB(255, 0, 0), 2, 20)
    mk("x 中心", Color3.fromRGB(255, 255, 255), 3, 20)

    return frame
end

task.spawn(function()
    task.wait(1.5)

    local holder = getWindowHolder()
    if not holder then
        warn("[Grief] 找不到 Window.Holder")
        return
    end

    local titleLabel
    local footerLabel
    for _, d in ipairs(holder:GetDescendants()) do
        if d:IsA("TextLabel") then
            if d.Name == "Title" then titleLabel = d end
            if d.Name == "Footer" then footerLabel = d end
        end
    end

    if not titleLabel then
        local topY = math.huge
        for _, d in ipairs(holder:GetDescendants()) do
            if d:IsA("TextLabel") and d.AbsoluteSize.Y >= 16 and d.AbsoluteSize.Y <= 40 then
                if d.AbsolutePosition.Y < topY and d.AbsolutePosition.Y >= 0 then
                    topY = d.AbsolutePosition.Y
                    titleLabel = d
                end
            end
        end
    end

    if titleLabel then
        titleLabel.Text = ""
        titleLabel.TextTransparency = 1
        buildColoredTitle(titleLabel.Parent, titleLabel.Position, titleLabel.Size)
    end

    if footerLabel then
        footerLabel.Text = ""
        footerLabel.TextTransparency = 1
        buildColoredTitle(footerLabel.Parent, footerLabel.Position, footerLabel.Size)
    end

    print("[Grief] 标题已上色")
end)

-- ============================================
-- UI
-- ============================================
local Tabs = {
    Main = Window:AddTab("Main", "box"),
    Settings = Window:AddTab("UI Settings", "settings"),
}

-- ============================================
-- 排球传奇范围增大（可滑动 0 ~ 50）
-- ============================================
local VolleyballHitbox = {
    radius = 12,
    color = Color3.fromRGB(0, 255, 255),
    thickness = 2.5,
    transparency = 0.25,
    balls = {},
    renderConn = nil,
    addedConn = nil,
    removedConn = nil,
}

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Vector2New = Vector2.new

local function refreshAllHitboxSize()
    local d2 = VolleyballHitbox.radius * 2
    for _, data in pairs(VolleyballHitbox.balls) do
        if data.box and data.box.Parent then
            data.box.Size = Vector3.new(d2, d2, d2)
        end
    end
end

local function addBall(ball)
    if not ball:IsA("Model") or not ball:IsDescendantOf(workspace) then return end
    local root = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart", true)
    if not root or VolleyballHitbox.balls[ball] then return end

    local d2 = VolleyballHitbox.radius * 2

    local box = Instance.new("Part")
    box.Shape = Enum.PartType.Ball
    box.Size = Vector3.new(d2, d2, d2)
    box.CFrame = root.CFrame
    box.Transparency = 1
    box.CanCollide = false
    box.CanTouch = false
    box.CanQuery = true
    box.Anchored = true
    box.CastShadow = false
    box.Massless = true
    box.Parent = ball

    local ring = Drawing.new("Circle")
    ring.Color = VolleyballHitbox.color
    ring.Filled = false
    ring.NumSides = 128
    ring.Thickness = VolleyballHitbox.thickness
    ring.Transparency = VolleyballHitbox.transparency
    ring.Visible = false

    VolleyballHitbox.balls[ball] = { box = box, ring = ring }
end

local function killBall(ball)
    local d = VolleyballHitbox.balls[ball]
    if not d then return end
    pcall(function()
        if d.box then d.box:Destroy() end
        if d.ring then d.ring:Destroy() end
    end)
    VolleyballHitbox.balls[ball] = nil
end

local function startHitbox()
    if VolleyballHitbox.renderConn then return end

    VolleyballHitbox.addedConn = CollectionService:GetInstanceAddedSignal("Ball"):Connect(addBall)
    VolleyballHitbox.removedConn = CollectionService:GetInstanceRemovedSignal("Ball"):Connect(killBall)

    VolleyballHitbox.renderConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local radius = VolleyballHitbox.radius
        for ball, d in pairs(VolleyballHitbox.balls) do
            local root = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart", true)
            if not root or not ball.Parent then
                killBall(ball)
            else
                d.box.CFrame = root.CFrame

                local pos, on = cam:WorldToViewportPoint(root.Position)
                if on and pos.Z > 0 and radius > 0 then
                    local edge = cam:WorldToViewportPoint(root.Position + cam.CFrame.RightVector * radius)
                    local r = math.abs(edge.X - pos.X)
                    if r ~= r or r <= 0 then
                        d.ring.Visible = false
                    else
                        d.ring.Position = Vector2New(pos.X, pos.Y)
                        d.ring.Radius = r
                        d.ring.Visible = true
                    end
                else
                    d.ring.Visible = false
                end
            end
        end
    end)

    for _, ball in ipairs(CollectionService:GetTagged("Ball")) do
        addBall(ball)
    end
end

local function stopHitbox()
    if VolleyballHitbox.renderConn then
        VolleyballHitbox.renderConn:Disconnect()
        VolleyballHitbox.renderConn = nil
    end
    if VolleyballHitbox.addedConn then
        VolleyballHitbox.addedConn:Disconnect()
        VolleyballHitbox.addedConn = nil
    end
    if VolleyballHitbox.removedConn then
        VolleyballHitbox.removedConn:Disconnect()
        VolleyballHitbox.removedConn = nil
    end
    for ball, _ in pairs(VolleyballHitbox.balls) do
        killBall(ball)
    end
    VolleyballHitbox.balls = {}
end

-- ============================================
-- ★ 落地点显示（绿色方框 + 连线）
-- ============================================
local LandingMarker = {
    enabled = false,
    balls = {},         -- [ball] = { box = Part, line = Drawing.Line }
    conn = nil,
    addedConn = nil,
    removedConn = nil,
    color = Color3.fromRGB(0, 255, 0),   -- 绿色
    boxSize = 3,                          -- 方框边长
    boxThickness = 0.15,                  -- 方框厚度
    transparency = 0.3,
}

-- 射线检测，找到球正下方的地面位置
local function raycastGround(origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { workspace.CurrentCamera }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
    if result then
        return result.Position, result.Normal
    end
    -- 没打到就用球的正下方（-50 高度）作为兜底
    return Vector3.new(origin.X, origin.Y - 50, origin.Z), Vector3.new(0, 1, 0)
end

-- 创建一个空心方框（由 4 条细长 Part 组成的方形边框）
local function createBoxFrame(parent, size, thickness, color, transparency)
    local frame = Instance.new("Model")
    frame.Name = "LandingBoxFrame"
    frame.Parent = parent

    local half = size / 2
    local t = thickness

    -- 4 条边：前后左右
    local function makeBar(name, cf, sz)
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Massless = true
        p.Material = Enum.Material.Neon
        p.Color = color
        p.Transparency = transparency
        p.Size = sz
        p.CFrame = cf
        p.Parent = frame
        return p
    end

    -- 前边 (Z-)
    makeBar("Front", CFrame.new(0, 0, -half), Vector3.new(size, t, t))
    -- 后边 (Z+)
    makeBar("Back",  CFrame.new(0, 0,  half), Vector3.new(size, t, t))
    -- 左边 (X-)
    makeBar("Left",  CFrame.new(-half, 0, 0), Vector3.new(t, t, size))
    -- 右边 (X+)
    makeBar("Right", CFrame.new( half, 0, 0), Vector3.new(t, t, size))

    return frame
end

local function addLandingBall(ball)
    if not ball:IsA("Model") or not ball:IsDescendantOf(workspace) then return end
    local root = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart", true)
    if not root or LandingMarker.balls[ball] then return end

    -- 绿色方框
    local frame = createBoxFrame(ball, LandingMarker.boxSize, LandingMarker.boxThickness,
        LandingMarker.color, LandingMarker.transparency)
    frame:PivotTo(root.CFrame)

    -- 连线
    local line = Drawing.new("Line")
    line.Color = LandingMarker.color
    line.Thickness = 2
    line.Transparency = 0.6
    line.Visible = false

    LandingMarker.balls[ball] = { frame = frame, line = line }
end

local function killLandingBall(ball)
    local d = LandingMarker.balls[ball]
    if not d then return end
    pcall(function()
        if d.frame then d.frame:Destroy() end
        if d.line then d.line:Destroy() end
    end)
    LandingMarker.balls[ball] = nil
end

local function startLanding()
    if LandingMarker.conn then return end

    LandingMarker.addedConn = CollectionService:GetInstanceAddedSignal("Ball"):Connect(function(b)
        if LandingMarker.enabled then addLandingBall(b) end
    end)
    LandingMarker.removedConn = CollectionService:GetInstanceRemovedSignal("Ball"):Connect(killLandingBall)

    LandingMarker.conn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        for ball, d in pairs(LandingMarker.balls) do
            local root = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart", true)
            if not root or not ball.Parent or not d.frame or not d.frame.Parent then
                killLandingBall(ball)
            else
                -- 计算正下方地面位置
                local groundPos = raycastGround(root.Position)

                -- 方框贴到地面（略微抬高 0.1 避免穿模）
                d.frame:PivotTo(CFrame.new(groundPos + Vector3.new(0, 0.1, 0)))

                -- 更新连线：球心 -> 地面
                local p1, on1 = cam:WorldToViewportPoint(root.Position)
                local p2, on2 = cam:WorldToViewportPoint(groundPos)
                if on1 and on2 and p1.Z > 0 and p2.Z > 0 then
                    d.line.From = Vector2New(p1.X, p1.Y)
                    d.line.To   = Vector2New(p2.X, p2.Y)
                    d.line.Visible = true
                else
                    d.line.Visible = false
                end
            end
        end
    end)

    for _, ball in ipairs(CollectionService:GetTagged("Ball")) do
        addLandingBall(ball)
    end
end

local function stopLanding()
    if LandingMarker.conn then
        LandingMarker.conn:Disconnect()
        LandingMarker.conn = nil
    end
    if LandingMarker.addedConn then
        LandingMarker.addedConn:Disconnect()
        LandingMarker.addedConn = nil
    end
    if LandingMarker.removedConn then
        LandingMarker.removedConn:Disconnect()
        LandingMarker.removedConn = nil
    end
    for ball, _ in pairs(LandingMarker.balls) do
        killLandingBall(ball)
    end
    LandingMarker.balls = {}
end

-- ============================================
-- 排球传奇 UI
-- ============================================
local vbBox = Tabs.Main:AddLeftGroupbox("排球传奇 · 范围增大")

vbBox:AddLabel("范围可调 0 ~ 50（建议别开满很容易被挂DC ）")

vbBox:AddSlider("VBRadius", {
    Text = "范围半径",
    Default = 12,
    Min = 0,
    Max = 50,
    Rounding = 1,
    Compact = false,
    Callback = function(val)
        VolleyballHitbox.radius = val
        refreshAllHitboxSize()
    end,
})

vbBox:AddToggle("VBEnabled", {
    Text = "启用范围增大",
    Default = false,
    Callback = function(val)
        if val then
            startHitbox()
            Library:Notify({ Title = "排球传奇", Description = "范围增大已开启（半径 " .. VolleyballHitbox.radius .. "）", Time = 2 })
        else
            stopHitbox()
            Library:Notify({ Title = "排球传奇", Description = "范围增大已关闭", Time = 2 })
        end
    end,
})

-- ★ 落地点显示
local landingBox = Tabs.Main:AddLeftGroupbox("排球传奇 · 落地点显示")

landingBox:AddLabel("绿色方框 = 球落地点，连线指示球")

landingBox:AddToggle("VBLanding", {
    Text = "显示落地点",
    Default = false,
    Callback = function(val)
        LandingMarker.enabled = val
        if val then
            startLanding()
            Library:Notify({ Title = "落地点显示", Description = "已开启", Time = 2 })
        else
            stopLanding()
            Library:Notify({ Title = "落地点显示", Description = "已关闭", Time = 2 })
        end
    end,
})

-- ============================================
-- 菜单键
-- ============================================
Tabs.Settings:AddLeftGroupbox("菜单"):AddLabel("菜单按键"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "菜单按键",
})
Library.ToggleKeybind = Options.MenuKeybind

print("[Grief] 加载完成 ✓")