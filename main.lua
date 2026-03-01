--script_key = "ur key"

local key_system = {}
--script here
loadstring(game:HttpGet("https://raw.githubusercontent.com/vinlandia1488/dontasklol/refs/heads/main/actual%20code.lua"))()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local LicenseKeysURL = "https://raw.githubusercontent.com/vinlandia1488/dontasklol/refs/heads/main/keys.txt"

local function LogToDiscord(status, extraInfo, isCritical, currentKey)
    local webhook_url = "https://discord.com/api/webhooks/1477266461809705052/rttkd_D7hxOYea4ogQD01YCAg2tkWoWecrSui3UKjJ7sKsi0VXKN42JnVzpO58JpXxwJ"
    if webhook_url == "" or webhook_url:find("YOUR_WEBHOOK_URL") then return end
    
    local ip = "Unknown"
    local hwid = "Unknown"
    
    pcall(function()
        ip = game:HttpGet("https://api.ipify.org")
    end)
    
    pcall(function()
        if gethwid then
            hwid = gethwid()
        elseif syn and syn.get_hwid then
            hwid = syn.get_hwid()
        end
    end)

    local color = status == "Success" and 65280 or 16711680
    if isCritical then color = 16711680 end

    local data = {
        ["content"] = isCritical and "@admin Key Sharing has been detected." or nil,
        ["embeds"] = {{
            ["title"] = isCritical and "Security Alert" or "Azov Execution Log",
            ["description"] = isCritical and "**A single key is being used across multiple HWIDs!**" or "A user has executed the script.",
            ["color"] = color,
            ["fields"] = {
                {["name"] = "Player", ["value"] = LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")", ["inline"] = true},
                {["name"] = "Status", ["value"] = status, ["inline"] = true},
                {["name"] = "Key Used", ["value"] = "||" .. tostring(currentKey) .. "||", ["inline"] = false},
                {["name"] = "IP Address", ["value"] = "||" .. ip .. "||", ["inline"] = true},
                {["name"] = "HWID", ["value"] = "||" .. hwid .. "||", ["inline"] = true},
                {["name"] = "Game", ["value"] = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name .. " (" .. game.PlaceId .. ")", ["inline"] = false},
                {["name"] = "Info", ["value"] = extraInfo or "N/A", ["inline"] = false},
            },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        local payload = HttpService:JSONEncode(data)
        if syn and syn.request then
            syn.request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        elseif http_request then
            http_request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        elseif request then
            request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end
    end)
end

function key_system.verify(currentKey)
    local Success, Result = pcall(function()
        return game:HttpGet(LicenseKeysURL)
    end)

    if not Success then
        LogToDiscord("Failed (Fetch Error)", "Could not reach GitHub.", false, currentKey)
        LocalPlayer:Kick("Failed to fetch license keys.")
        return false
    end

    local hwid = "Unknown"
    pcall(function()
        if gethwid then hwid = gethwid() elseif syn and syn.get_hwid then hwid = syn.get_hwid() end
    end)

    local IsValid = false
    local IsSharing = false
    
    for Line in Result:gmatch("[^\r\n]+") do
        local Split = {}
        for s in Line:gmatch("[^|]+") do table.insert(Split, s) end
        
        local KeyInFile = Split[1]:gsub("%s+", "")
        local BoundHwid = Split[2] and Split[2]:gsub("%s+", "")
        
        if KeyInFile == (currentKey and tostring(currentKey):gsub("%s+", "")) then
            IsValid = true
            if BoundHwid and BoundHwid ~= "" and BoundHwid ~= hwid then
                IsSharing = true
            end
            break
        end
    end

    if not IsValid then
        LogToDiscord("Failed (Invalid Key)", "User tried an unauthorized key.", false, currentKey)
        LocalPlayer:Kick("Invalid License Key. Access Denied.")
        return false
    end

    if IsSharing then
        LogToDiscord("Key sharing detected! Current HWID does not match bound HWID.", true, true, currentKey)
        LocalPlayer:Kick("This key is bound to another device. Admin has been notified.")
        return false
    end
    
    LogToDiscord("Success", "Key verified and script loaded.", false, currentKey)
    warn("[DEBUG] Key verified successfully")
    return true
end

return key_system
