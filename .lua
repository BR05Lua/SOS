local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Prevent running on the server
if RunService:IsServer() then
    return
end

-- Ensure LocalPlayer is available
local player = Players.LocalPlayer
if not player then
    repeat task.wait() until Players.LocalPlayer
    player = Players.LocalPlayer
end

-- Ensure PlayerGui is available
local playerGui = player:WaitForChild("PlayerGui")

-- Lock to prevent multiple loader instances
local LOADER_LOCK_NAME = "StepsLoader_Lock"
if playerGui:FindFirstChild(LOADER_LOCK_NAME) then
    warn("[StepsLoader] Already running, aborting duplicate execution.")
    return
end

local lock = Instance.new("BoolValue")
lock.Name = LOADER_LOCK_NAME
lock.Value = true
lock.Parent = playerGui

-- Prevents duplicate step execution
local function canRunStep(stepName)
    local markerName = "StepsLoader_Step_" .. tostring(stepName)
    if playerGui:FindFirstChild(markerName) then
        warn("[StepsLoader] Skipping already executed step:", stepName)
        return false
    end

    local marker = Instance.new("BoolValue")
    marker.Name = markerName
    marker.Value = true
    marker.Parent = playerGui
    return true
end

-- Safe HTTP loader function
local function safeLoad(url)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if success and type(result) == "string" and result ~= "" then
        local f, err = loadstring(result)
        if f then
            local ok, execErr = pcall(f)
            if not ok then
                warn("[StepsLoader] Execution failed:", execErr)
            end
        else
            warn("[StepsLoader] Loadstring error:", err)
        end
    else
        warn("[StepsLoader] Failed to fetch from:", url)
    end
end

-- Define your loading steps here
local steps = {
    {
        name = "Main Menu",
        run = function()
            if not canRunStep("Main Menu") then return end
            safeLoad("https://raw.githubusercontent.com/BR05Lua/soshud-host/refs/heads/main/public/SOSMenu.lua?token=GHSAT0AAAAAADSQKI4X5FJX35N4Q4P7R5KQ2K4QCAA") -- Add your loadstring URL here
        end,
        delayAfter = 0.1,
    },
    {
        name = "Tag System",
        run = function()
            if not canRunStep("Tag System") then return end
            safeLoad("https://raw.githubusercontent.com/BR05Lua/soshud-host/refs/heads/main/public/BR05TagSystem.lua?token=GHSAT0AAAAAADSQKI4XZCIQRUGSPD4ZWCSQ2K4QBMA") -- Add your loadstring URL here
        end,
        delayAfter = 0.1,
    },
    {
        name = "IY",
        run = function()
            if not canRunStep("IY") then return end
            safeLoad("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source") -- Add your loadstring URL here
        end,
        delayAfter = 0.1,
    },
}

-- Execute each step safely
for i, step in ipairs(steps) do
    local ok, err = pcall(step.run)
    if not ok then
        warn("[StepsLoader] Failed at step:", i, step.name, err)
    end

    if type(step.delayAfter) == "number" and step.delayAfter > 0 then
        task.wait(step.delayAfter)
    end
end

print("[StepsLoader] Fully Loaded.")
print("[StepsLoader] Thanks To Co Owner For Making The New Loadstring System.")
