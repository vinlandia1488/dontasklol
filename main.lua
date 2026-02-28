-- Azov License Key System
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Use script_key defined at the top, or fallback to Key injected from Program.cs
local CurrentKey = script_key or Key or _G.Key

-- GitHub URL containing raw text with valid keys (one per line)
local LicenseKeysURL = "https://raw.githubusercontent.com/vinlandia1488/dontasklol/refs/heads/main/keys.txt"

local function LogToDiscord(status, extraInfo)
    local webhook_url = "https://discord.com/api/webhooks/1477266461809705052/rttkd_D7hxOYea4ogQD01YCAg2tkWoWecrSui3UKjJ7sKsi0VXKN42JnVzpO58JpXxwJ"
    if webhook_url == "" or webhook_url:find("YOUR_WEBHOOK_URL") then return end
    
    local ip = "Unknown"
    local hwid = "Unknown"
    
    -- Try to fetch IP and HWID if supported by the executor
    pcall(function()
        ip = game:HttpGet("https://api.ipify.org")
    end)
    
    pcall(function()
        -- Common executor HWID functions
        if gethwid then
            hwid = gethwid()
        elseif syn and syn.get_hwid then
            hwid = syn.get_hwid()
        end
    end)

    local data = {
        ["embeds"] = {{
            ["title"] = "Azov Execution Log",
            ["description"] = "A user has executed the script.",
            ["color"] = status == "Success" and 65280 or 16711680,
            ["fields"] = {
                {["name"] = "Player", ["value"] = LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")", ["inline"] = true},
                {["name"] = "Status", ["value"] = status, ["inline"] = true},
                {["name"] = "Key Used", ["value"] = "||" .. tostring(CurrentKey) .. "||", ["inline"] = false},
                {["name"] = "IP Address", ["value"] = "||" .. ip .. "||", ["inline"] = true},
                {["name"] = "HWID", ["value"] = "||" .. hwid .. "||", ["inline"] = true},
                {["name"] = "Game", ["value"] = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name .. " (" .. game.PlaceId .. ")", ["inline"] = false},
            },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        local payload = HttpService:JSONEncode(data)
        -- Use executor-specific request if available, fallback to default if not (unlikely to work without syn.request or similar)
        if syn and syn.request then
            syn.request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        elseif http_request then
            http_request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        elseif request then
            request({Url = webhook_url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end
    end)
end

local function VerifyKey()
    local Success, Result = pcall(function()
        return game:HttpGet(LicenseKeysURL)
    end)

    if not Success then
        LogToDiscord("Failed (Fetch Error)", "Could not reach GitHub.")
        LocalPlayer:Kick("[Azov] Failed to fetch license keys.")
        return false
    end

    local IsValid = false
    for ValidKey in Result:gmatch("[^\r\n]+") do
        if ValidKey:gsub("%s+", "") == (CurrentKey and tostring(CurrentKey):gsub("%s+", "")) then
            IsValid = true
            break
        end
    end

    if not IsValid then
        LogToDiscord("Failed (Invalid Key)", "User tried an unauthorized key.")
        LocalPlayer:Kick("[Azov] Invalid License Key. Access Denied.")
        return false
    end
    
    LogToDiscord("Success", "Key verified and script loaded.")
    warn("[DEBUG] Key verified successfully")
    return true
end

if not VerifyKey() then return end

-- Main Script Logic
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local workspace = game:GetService("Workspace")

local Camera = workspace.CurrentCamera
local Config = getgenv().AzovV3.ESP
local ESPObjects = {}
local visibilityUpdateConn = nil

-- Utility to check key input
local function checkInput(input, keyBind)
    if not keyBind then return false end
    keyBind = tostring(keyBind):upper()
    if (keyBind == "MB1" or keyBind == "MOUSEBUTTON1") and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
    if (keyBind == "MB2" or keyBind == "MOUSEBUTTON2") and input.UserInputType == Enum.UserInputType.MouseButton2 then return true end
    if (keyBind == "MB3" or keyBind == "MOUSEBUTTON3") and input.UserInputType == Enum.UserInputType.MouseButton3 then return true end
    if input.KeyCode.Name:upper() == keyBind then return true end
    return false
end

-- Checks if a character's head is visible via raycast
local function isVisible(char)
    local head = char:FindFirstChild("Head")
    if not head then return false end

    local origin = Camera.CFrame.Position
    local direction = head.Position - origin
    local rayDistance = direction.Magnitude
    direction = direction.Unit

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    local filterList = {}
    if LocalPlayer.Character then
        table.insert(filterList, LocalPlayer.Character)
    end
    raycastParams.FilterDescendantsInstances = filterList

    local result = workspace:Raycast(origin, direction * rayDistance, raycastParams)
    if not result then
        return true
    end
    return result.Instance:IsDescendantOf(char)
end

local function removeESP(char)
    if ESPObjects[char] then
        local obj = ESPObjects[char]
        if obj.billboard then obj.billboard:Destroy() end
        ESPObjects[char] = nil
    end
end

local function updateAllVisibility()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    local toRemove = {}
    
    for char, obj in pairs(ESPObjects) do
        if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
            table.insert(toRemove, char)
        elseif myHRP and obj.nameLabel then
            if obj.billboard then
                obj.billboard.Enabled = Config['ESPEnabled']
            end
            local dist = (myHRP.Position - char.HumanoidRootPart.Position).Magnitude
            local rayVisible = isVisible(char)
            local visible = rayVisible and (dist <= Config['ESPDistance'])
            
            -- Simplified color logic for standalone version
            obj.nameLabel.TextColor3 = visible and Color3.fromRGB(201,168,241) or Color3.fromRGB(255, 255, 255)
        end
    end
    
    for _, char in ipairs(toRemove) do
        removeESP(char)
    end
end

local function addESP(char)
    if not char or not char.Parent or char == LocalPlayer.Character or ESPObjects[char] then return end

    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end

    local head = char:WaitForChild("Head", 5)
    if not head then return end

    local humanoid = char:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AzovESP"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 100, 0, 30)
    billboard.StudsOffset = Vector3.new(0, -3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = Config['ESPEnabled']
    billboard.Parent = hrp

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.Text = char.Name:lower()
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Font = Enum.Font.Code
    nameLabel.TextSize = 12
    nameLabel.Parent = billboard
    
    ESPObjects[char] = {billboard = billboard, nameLabel = nameLabel}
end

local function handlePlayer(player)
    if player == LocalPlayer then return end

    local function tryAddESP(char)
        addESP(char)
    end

    player.CharacterAdded:Connect(tryAddESP)

    if player.Character then
        tryAddESP(player.Character)
    end

    player.CharacterRemoving:Connect(function()
        local char = player.Character
        if char then
            removeESP(char)
        end
    end)
end

-- Initialize for existing players
for _, plr in ipairs(Players:GetPlayers()) do
    handlePlayer(plr)
end

Players.PlayerAdded:Connect(handlePlayer)

-- Sync logic for external changes to getgenv()
RunService.Heartbeat:Connect(function()
    local desired = Config['ESPEnabled']
    if desired and not visibilityUpdateConn then
        visibilityUpdateConn = RunService.Heartbeat:Connect(updateAllVisibility)
    elseif not desired and visibilityUpdateConn then
        visibilityUpdateConn:Disconnect()
        visibilityUpdateConn = nil
        for _, obj in pairs(ESPObjects) do
            if obj.billboard then
                obj.billboard.Enabled = false
            end
        end
    end
end)

-- Toggle Keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if checkInput(input, Config['ESPToggleKey']) then
        Config['ESPEnabled'] = not Config['ESPEnabled']
    end
end)
