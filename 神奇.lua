local RS=game:GetService("ReplicatedStorage")
local mod=RS.System.CooldownUI
local ok,C=pcall(require,mod)
if ok and type(C)=="table" then
  local orig=C.Start
  C.Start=function(cfg)
    if type(cfg)=="table" then cfg.Duration=0 end
    return orig(cfg)
  end
  if C.ReduceAll then
    local r=C.ReduceAll
    C.ReduceAll=function(self,a) return r(self,1e9) end
  end
  print("无冷却已启用")
end