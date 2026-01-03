loadstring(game:HttpGet("https://raw.githubusercontent.com/BR05Lua/SOS/refs/heads/main/Security/BR05"))()
    end,
    function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/BR05Lua/SOS/refs/heads/main/SOSMenu.lua"))()
    end,
    function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/BR05Lua/SOS/refs/heads/main/BR05TagSystem.lua"))()
    end
}

for i, loader in ipairs(loaders) do
    local success, err = pcall(loader)
    if not success then
        warn("Loader failed at index", i, err)
        break
    end
end
