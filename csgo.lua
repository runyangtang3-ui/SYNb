-- // Services \\
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CameraController = require(ReplicatedStorage.Controllers.CameraController)
local CharacterAnimator = require(ReplicatedStorage.Classes.WeaponComponent.Classes.CharacterAnimator)
local ViewmodelAnimator = require(ReplicatedStorage.Classes.WeaponComponent.Classes.Viewmodel.Classes.Animation)

-- // No recoil camera effects (强制覆盖所有可能的后坐力函数) \\
local function disableRecoilFunctions(module)
    if not module then return end
    local funcsToDisable = {
        "weaponKick",
        "setWeaponRecoil",
        "applyRecoil",
        "updateRecoil",
        "playRecoil",
        "recoil",
        "kick",
        "cameraShake",
        "setRecoil",
        "addRecoil"
    }
    for _, funcName in ipairs(funcsToDisable) do
        pcall(function()
            if type(module[funcName]) == "function" then
                module[funcName] = function() end
            end
        end)
    end
end
disableRecoilFunctions(CameraController)
disableRecoilFunctions(CharacterAnimator)
disableRecoilFunctions(ViewmodelAnimator)

-- // Bullet logic \\
local Bullet = require(ReplicatedStorage.Components.Weapon.Classes.Bullet)

-- // No Spread (覆盖所有扩散计算函数) \\
local spreadFuncsToZero = {
    "getTrueSpread",
    "getBaseSpread",
    "getSpreadForConfig",
    "getSpread",
    "getCurrentSpread",
    "calculateSpread"
}
for _, funcName in ipairs(spreadFuncsToZero) do
    pcall(function()
        if type(Bullet[funcName]) == "function" then
            Bullet[funcName] = function() return 0 end
        end
    end)
end

-- // Spoofing (彻底控制 Spread 对象，创建前后都强制归零) \\
local OldCreate = Bullet.create
Bullet.create = function(self, aimingOptions, isAiming)
    -- 创建前强制归零
    if self.Spread then
        pcall(function()
            self.Spread:setPosition(0)
            self.Spread:setGoal(0)
            self.Spread:setValue(0)
            self.Spread:set(0)
            self.Spread.Value = 0
        end)
    end

    local result = OldCreate(self, aimingOptions, isAiming)

    -- 创建后再次强制归零，防止内部逻辑重置
    if self.Spread then
        pcall(function()
            self.Spread:setPosition(0)
            self.Spread:setGoal(0)
            self.Spread:setValue(0)
            self.Spread:set(0)
            self.Spread.Value = 0
        end)
    end

    -- 如果返回的对象有 Spread 属性，也一并处理
    if type(result) == "table" and result.Spread then
        pcall(function()
            result.Spread:setPosition(0)
            result.Spread:setGoal(0)
            result.Spread:setValue(0)
            result.Spread:set(0)
            result.Spread.Value = 0
        end)
    end

    return result
end

-- // 可选：运行时持续清除所有 Spread 实例 (轻量级循环) \\
-- 启用后可以防止任何漏网的扩散设置，但会有轻微性能消耗
local RunService = cloneref(game:GetService("RunService"))
if RunService.Heartbeat then
    RunService.Heartbeat:Connect(function()
        -- 扫描所有可能存在的 Spread 对象并归零（实际游戏中可根据需要调整范围）
        -- 由于全局扫描成本较高，这里只对当前活跃的武器相关对象处理
        -- 简单实现：遍历所有玩家角色，找到武器组件并设置其 Spread 为零
        -- 注意：这只是一个示例，具体依赖游戏结构，可注释掉以节省性能
        --[[
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            local character = player.Character
            if character then
                local weapon = character:FindFirstChildOfClass("Tool") or character:FindFirstChild("Weapon")
                if weapon and weapon:FindFirstChild("Spread") then
                    weapon.Spread:setPosition(0)
                    weapon.Spread:setGoal(0)
                    weapon.Spread:setValue(0)
                end
            end
        end
        ]]
    end)
end