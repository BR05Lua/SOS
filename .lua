local urls = {
    "https://raw.githubusercontent.com/user/script1.lua",
    "https://raw.githubusercontent.com/user/script2.lua",
    "https://raw.githubusercontent.com/user/script3.lua"
}

for _, url in ipairs(urls) do
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)

    if success then
        local func, err = loadstring(result)
        if func then
            pcall(func)
        else
            warn("Compile error:", err)
        end
    else
        warn("HTTP error:", result)
    end
end
