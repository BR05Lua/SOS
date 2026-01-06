local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

if RunService:IsServer() then
    return
end

local player = Players.LocalPlayer
if not player then
    return
end

local playerGui = player:WaitForChild("PlayerGui")

local LOADER_LOCK_NAME = "StepsLoader_Lock"
if playerGui:FindFirstChild(LOADER_LOCK_NAME) then
    return
end

local lock = Instance.new("BoolValue")
lock.Name = LOADER_LOCK_NAME
lock.Value = true
lock.Parent = playerGui

local function canRunStep(stepName)
    local markerName = "StepsLoader_Step_" .. tostring(stepName)

    if playerGui:FindFirstChild(markerName) then
        return false
    end

    local marker = Instance.new("BoolValue")
    marker.Name = markerName
    marker.Value = true
    marker.Parent = playerGui

    return true
end

local steps = {
    {
        name = "Main Menu",
        run = function()
            if not canRunStep("Main Menu") then
                return
            end

            loadstring(game:HttpGet("https://raw.githubusercontent.com/BR05Lua/SOS/refs/heads/main/SOSMenu.lua"))()
        end,
        delayAfter = 0.1,
    },
    {
        name = "Tag System",
        run = function()
            if not canRunStep("Tag System") then
                return
            end

            loadstring(game:HttpGet("https://raw.githubusercontent.com/BR05Lua/SOS/refs/heads/main/BR05TagSystem.lua"))()
        end,
        delayAfter = 0.1,
    },
    {
        name = "IY",
        run = function()
            if not canRunStep("IY") then
                return
            end

            loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        end,
        delayAfter = 0.1, -- optional, but consistent with the others
    },
}

for i, step in ipairs(steps) do
    local ok, err = pcall(step.run)
    if not ok then
        warn("Loader failed at index", i, step.name, err)
        break
    end

    if type(step.delayAfter) == "number" and step.delayAfter > 0 then
        task.wait(step.delayAfter)
    end
end

print("Fully Loaded.")
print("Thanks To Co Owner For Making The New Loadstring System.")
