--[[
    Azov V3 - Key System Module
    HOW TO USE:
    1. Host this file on GitHub (raw link).
    2. Reference the link in main.lua using loadstring.
    3. Ensure you have your keys.txt file hosted as well.
]]



    -- [[ console & log management ]]
    if AzovV3['Global']['CleanLogs'] then
        task.spawn(function()
            while AzovV3['Global']['CleanLogs'] do
                pcall(function()
                    game:GetService("LogService"):ClearOutput()
                end)
                pcall(function()
                    if clearconsole then clearconsole() end
                    if rconsoleclear then rconsoleclear() end
                end)
                task.wait(10) -- clear every 10 seconds to keep it clean
            end
        end)
    end

    -- [[ main variables & setup ]]

    local Players           = game:GetService("Players")
    local UserInputService  = game:GetService("UserInputService")
    local RunService        = game:GetService("RunService")
    local Stats             = game:GetService("Stats")
    local GuiService        = game:GetService("GuiService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local LocalPlayer       = Players.LocalPlayer
    local Mouse             = LocalPlayer:GetMouse()
    local Camera            = workspace.CurrentCamera

    local function checkInput(input, keyBind)
        if not keyBind then return false end
        keyBind = tostring(keyBind):upper()
        
        if (keyBind == "MB1" or keyBind == "MOUSEBUTTON1") and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
        if (keyBind == "MB2" or keyBind == "MOUSEBUTTON2") and input.UserInputType == Enum.UserInputType.MouseButton2 then return true end
        if (keyBind == "MB3" or keyBind == "MOUSEBUTTON3") and input.UserInputType == Enum.UserInputType.MouseButton3 then return true end
        
        if input.KeyCode.Name:upper() == keyBind then return true end
        return false
    end

    local SilentAimActive   = true
    local SpeedEnabled      = false
    local CamlockActive     = false 
    local TriggerBotActive  = AzovV3['Camera Aimbot']['TriggerBot']['Enabled']
    local LockedTarget      = nil
    local ManualTarget      = nil
    local ManualTargetPlayer = nil
    local ForceHitTargetPlayer = nil
    local AntiLockActive    = AzovV3['AntiLock']['AntiLockEnabled'] -- anti-lock toggle state

    local BodyParts = {
        "Head",
        "HumanoidRootPart",
        "UpperTorso",
        "LowerTorso",
        "LeftTorso",
        "RightTorso",
        "LeftUpperArm",
        "LeftLowerArm",
        "LeftHand",
        "RightUpperArm",
        "RightLowerArm",
        "RightHand",
        "LeftUpperLeg",
        "LeftLowerLeg",
        "LeftFoot",
        "RightUpperLeg",
        "RightLowerLeg",
        "RightFoot"
    }

    local PartOffsets = {
        Head = Vector3.new(0, 0.3, 0),  
        HumanoidRootPart = Vector3.new(0, 0, 0),
        UpperTorso = Vector3.new(0, 0.2, 0),
        LowerTorso = Vector3.new(0, 0, 0),
        LeftTorso = Vector3.new(-0.8, 0, 0),
        RightTorso = Vector3.new(0.8, 0, 0),
        LeftUpperArm = Vector3.new(0, 0.2, 0),  
        LeftLowerArm = Vector3.new(0, -0.1, 0),  
        LeftHand = Vector3.new(0, -0.2, 0),  
        RightUpperArm = Vector3.new(0, 0.2, 0),  
        RightLowerArm = Vector3.new(0, -0.1, 0),
        RightHand = Vector3.new(0, -0.2, 0),
        LeftUpperLeg = Vector3.new(0, -0.3, 0),  
        LeftLowerLeg = Vector3.new(0, -0.4, 0),  
        LeftFoot = Vector3.new(0, -0.5, 0),  
        RightUpperLeg = Vector3.new(0, -0.3, 0),
        RightLowerLeg = Vector3.new(0, -0.4, 0),
        RightFoot = Vector3.new(0, -0.5, 0)
    }

    local fovCircle = Drawing.new("Circle")
    fovCircle.Thickness     = 2
    fovCircle.NumSides      = 1000  
    fovCircle.Radius        = AzovV3['Silent Aimbot']['DefaultFOV']
    fovCircle.Filled        = false
    fovCircle.Visible       = AzovV3['Silent Aimbot']['FOV_VISIBLE']
    fovCircle.ZIndex        = 999
    fovCircle.Transparency  = 0.85
    fovCircle.Color         = AzovV3['Silent Aimbot']['FOV_COLOR_ON']

    RunService.RenderStepped:Connect(function()
        local insetY = GuiService:GetGuiInset().Y
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + insetY)
        
        local weaponConfig = AzovV3['Silent Aimbot']['WeaponConfigurations']
        if weaponConfig and weaponConfig['Enabled'] then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                local toolName = tool.Name:gsub("%[", ""):gsub("%]", "")
                local specificFOV = weaponConfig[toolName]
                if specificFOV then
                    fovCircle.Radius = specificFOV
                else
                    fovCircle.Radius = AzovV3['Silent Aimbot']['DefaultFOV']
                end
            else
                fovCircle.Radius = AzovV3['Silent Aimbot']['DefaultFOV']
            end
        else
            fovCircle.Radius = AzovV3['Silent Aimbot']['DefaultFOV']
        end
    end)

    local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local args = {...}
        local method = getnamecallmethod and getnamecallmethod() or ""
        if method == "FireServer" and AzovV3['Exploits'] and AzovV3['Exploits']['Gun TP'] and AzovV3['Exploits']['Gun TP']['Enabled'] then
            local rname = tostring(self.Name or ""):lower()
            if rname:find("main") or rname:find("gun") or rname:find("shoot") or rname:find("fire") or rname:find("projectile") then
                local bestTarget = TargetCache and TargetCache.Target
                local bestPart = TargetCache and TargetCache.Part
                if bestTarget and bestPart then
                    local hrp = bestTarget:FindFirstChild("HumanoidRootPart")
                    local basePos = getPartWorldPos(bestTarget, TargetCache.PartName) or bestPart.Position
                    local adjustedVel = hrp and getAdjustedVelocity(hrp, TargetCache.Distance, true) or Vector3.new(0,0,0)
                    local predValue
                    if AzovV3['Silent Aimbot']['AutoPrediction'] then
                        predValue = calculateDynamicPrediction(bestTarget, TargetCache.Distance or 0)
                    elseif AzovV3['Silent Aimbot']['PingPrediction'] then
                        predValue = currentPred
                    else
                        predValue = AzovV3['Silent Aimbot']['ManualPrediction']
                    end
                    local predictedPos = basePos + (adjustedVel * predValue) - Vector3.new(0, 0.4, 0)
                    for i,v in ipairs(args) do
                        local tv = typeof(v)
                        if tv == "Vector3" then
                            args[i] = predictedPos
                        elseif tv == "CFrame" then
                            args[i] = CFrame.new(predictedPos)
                        end
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if checkInput(input, AzovV3['Silent Aimbot']['ToggleKey']) then
            if AzovV3['Silent Aimbot']['ToggleMode'] == "Toggle" then
                SilentAimActive = not SilentAimActive
                fovCircle.Color = SilentAimActive and AzovV3['Silent Aimbot']['FOV_COLOR_ON'] or AzovV3['Silent Aimbot']['FOV_COLOR_OFF']
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        -- hold logic removed
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if checkInput(input, AzovV3['Camera Aimbot']['ToggleKey']) then
            if AzovV3['Camera Aimbot']['CamlockMode'] == "Toggle" then
                CamlockActive = not CamlockActive
                if not CamlockActive then
                    LockedTarget = nil  
                end
            else -- hold mode
                CamlockActive = true
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if AzovV3['Camera Aimbot']['CamlockMode'] == "Hold" and checkInput(input, AzovV3['Camera Aimbot']['ToggleKey']) then
            CamlockActive = false
            LockedTarget = nil
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if checkInput(input, AzovV3['Speed Modifications']['SpeedToggleKey']) then
            SpeedEnabled = not SpeedEnabled
        end
    end)

    if AzovV3['Camera Aimbot']['TriggerBot']['UseToggleKey'] then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if checkInput(input, AzovV3['Camera Aimbot']['TriggerBot']['ToggleKey']) then
                TriggerBotActive = not TriggerBotActive
            end
        end)
    end

    -- anti-lock update
    RunService.RenderStepped:Connect(function()
        AntiLockActive = AzovV3['AntiLock']['AntiLockEnabled']
    end)

    -- super jump hold
    local holdingSuperJump = false
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode.Name:lower() == AzovV3['Speed Modifications']['SuperJumpHoldKey']:lower() then
            holdingSuperJump = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode.Name:lower() == AzovV3['Speed Modifications']['SuperJumpHoldKey']:lower() then
            holdingSuperJump = false
        end
    end)

    

    -- speed/jump logic
    RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return end
        
        -- ensure usejumppower is true so jumppower property works
        if hum.UseJumpPower == false then
            hum.UseJumpPower = true
        end

        if SpeedEnabled then
            hum.WalkSpeed = AzovV3['Speed Modifications']['BoostWalkSpeed']
        end
        
        if holdingSuperJump then
            hum.JumpPower = AzovV3['Speed Modifications']['SuperJumpPower']
        end

        -- low health boost modifier
        local lowHealth = AzovV3['Speed Modifications']['Modifiers']['LowHealthBoost']
        if lowHealth['Enabled'] and hum.Health > 0 and hum.Health <= lowHealth['HealthThreshold'] then
            hum.WalkSpeed = hum.WalkSpeed + lowHealth['BoostAmount']
        end
    end)

    local RapidFireActive = AzovV3['Rapid Fire']['RapidFireEnabled']
    local isRapidFiring = false
    -- removed hrp teleport on shoot feature: no state needed here

    local function getCurrentGun()
        local char = LocalPlayer.Character
        if not char then return nil end
        for _, tool in next, char:GetChildren() do
            if tool:IsA("Tool") and tool:FindFirstChild("Ammo") then
                return tool
            end
        end
        return nil
    end

    if AzovV3['Rapid Fire']['UseRapidToggleKey'] then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if checkInput(input, AzovV3['Rapid Fire']['RapidFireToggleKey']) then
                RapidFireActive = not RapidFireActive
                if not RapidFireActive then
                    isRapidFiring = false
                end
            end
        end)
    end

    UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local gun = getCurrentGun()
            if RapidFireActive and gun and not isRapidFiring then
                isRapidFiring = true
                spawn(function()
                    while isRapidFiring do
                        gun:Activate()
                        task.wait(math.max(AzovV3['Rapid Fire']['Delay'] or 0.01, 0.01))
                    end
                end)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isRapidFiring = false
        end
    end)

    local function getPing()
        local success, pingStr = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
        end)
        if success and pingStr then
            local split = pingStr:split(" ")
            if split[1] then
                return math.floor(tonumber(split[1]) or 0 + 0.5)
            end
        end
        return 0
    end

    local function getAdjustedVelocity(part, distance, isSilent)
        if not part then return Vector3.new(0,0,0) end
        local velocity = part.AssemblyLinearVelocity
        
        -- apply y axis control
        local ySettings = isSilent and AzovV3['Silent Aimbot']['Y Axis Control'] or AzovV3['Camera Aimbot']['Y Axis Control']
        if ySettings then
            if ySettings['YOverride']['Enabled'] then
                velocity = Vector3.new(velocity.X, ySettings['YOverride']['Value'], velocity.Z)
            elseif ySettings['ClampY']['Enabled'] then
                local minY = ySettings['ClampY']['MinY']
                local maxY = ySettings['ClampY']['MaxY']
                
                if ySettings['ClampY']['Dynamic'] and distance then
                    local scale = math.clamp(1 - (distance / 500), 0.5, 1)
                    minY = minY * scale
                    maxY = maxY * scale
                end
                
                local clampedY = math.clamp(velocity.Y, minY, maxY)
                velocity = Vector3.new(velocity.X, clampedY, velocity.Z)
            end
        end
        
        return velocity
    end

local originalC0 = nil
local lastJoint = nil
local armOrbitAngle = 0

RunService.RenderStepped:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then 
        if lastJoint and originalC0 then
            lastJoint.C0 = originalC0
            lastJoint = nil
            originalC0 = nil
        end
        return 
    end
    
    local tool = char:FindFirstChildOfClass("Tool")
    local myHead = char:FindFirstChild("Head")
    
    if not (AzovV3['Exploits'] and AzovV3['Exploits']['Gun TP'] and AzovV3['Exploits']['Gun TP']['Enabled']) then
        if lastJoint and originalC0 then
            lastJoint.C0 = originalC0
            lastJoint = nil
            originalC0 = nil
        end
        
        return
    end
    
    local settings = AzovV3['Exploits']['Gun TP']
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    local arm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
    local joint = nil
    
    if torso and arm then
        joint = arm:FindFirstChild("Right Shoulder") or torso:FindFirstChild("Right Shoulder") or arm:FindFirstChild("RightWrist")
    end
    
    -- reset if tool unequipped or joint changed
    if not tool or not joint then
        if lastJoint and originalC0 then
            lastJoint.C0 = originalC0
            lastJoint = nil
            originalC0 = nil
        end
        
        return
    end
    
    if joint ~= lastJoint then
        if lastJoint and originalC0 then lastJoint.C0 = originalC0 end
        lastJoint = joint
        if not originalC0 then
            originalC0 = joint.C0
        end
    end
    
    if originalC0 then
        joint.C0 = originalC0
    end
    
    return
end)

    local function calculateDynamicPrediction(target, distance)
        if not target then return 0 end
        local settings = AzovV3['Silent Aimbot']['AutoPredSettings']
        local basePred = settings['BasePrediction']
        
        local distPred = distance * settings['DistanceMultiplier']
        
        local hrp = target:FindFirstChild("HumanoidRootPart")
        local velocity = hrp and hrp.AssemblyLinearVelocity or Vector3.new(0,0,0)
        local speed = velocity.Magnitude
        local speedPred = speed * settings['SpeedMultiplier']
        
        local finalPred = basePred + distPred + speedPred
        
        local hum = target:FindFirstChild("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then
            finalPred = finalPred + settings['AirPrediction']
        end
        
        finalPred = math.clamp(
            finalPred, 
            settings['MinPredictionFloor'], 
            settings['MaxPredictionCap']
        )

        return finalPred
    end

    local currentPred = AzovV3['Silent Aimbot']['ManualPrediction']

    spawn(function()
        local lastNotify = 0
        while true do
            local ping = getPing()

            if AzovV3['Silent Aimbot']['PingPrediction'] then
                for _, r in ipairs(AzovV3['Silent Aimbot']['PredictionRanges']) do
                    if ping >= r[1] then
                        currentPred = r[2]
                        break
                    end
                end
            end

            if AzovV3['Silent Aimbot']['ShowPingNotifier'] and tick() - lastNotify > 6.5 then
                local modeText = AzovV3['Silent Aimbot']['AutoPrediction'] and "Auto" or (AzovV3['Silent Aimbot']['PingPrediction'] and "Ping" or "Manual")
                game.StarterGui:SetCore("SendNotification", {
                    Title = "Prediction",
                    Text = "Mode: "..modeText.."\nPing: " .. ping .. "ms\nPred: " .. string.format("%.4f", currentPred),
                    Duration = 4
                })
                lastNotify = tick()
            end

            task.wait(0.5)
        end
    end)

    local function isVisible(targetPos, targetChar)
        local char = LocalPlayer.Character
        if not char then return true end -- default to visible if we can't check
        
        local rayOrigin = Camera.CFrame.Position
        local rayDirection = targetPos - rayOrigin
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
        return not rayResult or (rayResult.Instance and rayResult.Instance:IsDescendantOf(targetChar))
    end

    local function getRealPart(char, partName)
        if partName == "LeftTorso" or partName == "RightTorso" then
            return char:FindFirstChild("UpperTorso")
        end
        return char:FindFirstChild(partName)
    end

    local function getPartWorldPos(char, partName)
        local part = getRealPart(char, partName)
        if not part then return nil end
        local offset = PartOffsets[partName] or Vector3.new(0, 0, 0)
        return part.CFrame * offset
    end

    local function getScaledWorldPos(char)
        -- rewrite: targeting the absolute closest body part to the cursor
        local insetY = GuiService:GetGuiInset().Y
        local mousePos = Vector2.new(Mouse.X, Mouse.Y + insetY)
        
        local bestPart = nil
        local bestDist = 9e9
        
        for _, partName in ipairs(BodyParts) do
            local part = getRealPart(char, partName)
            if part then
                local targetPos = getPartWorldPos(char, partName)
                local screenPos3D, onScreen = Camera:WorldToViewportPoint(targetPos)
                
                if onScreen then
                    local screenPos = Vector2.new(screenPos3D.X, screenPos3D.Y)
                    local dist = (mousePos - screenPos).Magnitude
                    
                    if dist < bestDist then
                        bestDist = dist
                        bestPart = part
                    end
                end
            end
        end
        
        -- if no part found on screen, fallback to hrp
        if not bestPart then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            return hrp and hrp.Position or Vector3.new(0,0,0)
        end
        
        -- return the center of the closest part
        return bestPart.Position
    end

    local function findBestTarget(useClosestPart, targetPart, useWallCheck, radius, maxDist, forcedTarget)
        radius = radius or fovCircle.Radius
        maxDist = maxDist or AzovV3['Silent Aimbot']['MaxTargetDistance']
        local bestTarget = nil
        local bestPart = nil
        local bestPartName = nil
        local bestScreenDist = 9e9
        local closestPlayerDist = 9999
        local bestTargetVisible = false
        local insetY = GuiService:GetGuiInset().Y
        local mousePos = Vector2.new(Mouse.X, Mouse.Y + insetY)

        for _, plr in pairs(Players:GetPlayers()) do
            if forcedTarget and plr.Character ~= forcedTarget then continue end
            if plr == LocalPlayer or table.find(AzovV3["Global"]['IgnorePlayers'], plr.Name) then continue end
            local char = plr.Character
            if not char then continue end
            local hum = char:FindFirstChild("Humanoid")
            if not hum then
                if not (forcedTarget and plr.Character == forcedTarget) then
                    continue
                end
            elseif hum.Health <= 0 then
                if not (forcedTarget and plr.Character == forcedTarget) then
                    continue
                end
            end

            if AzovV3["Checks"]['KnockedCheck'] then
                local bodyEffects = char:FindFirstChild("BodyEffects")
                if bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value then
                    continue
                end
            end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            local rootPos = hrp.Position
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local distToMe = myRoot and (rootPos - myRoot.Position).Magnitude or 9999
        local maxDist = AzovV3['Silent Aimbot']['MaxTargetDistance']
        
        if not (AzovV3['Exploits'] and AzovV3['Exploits']['Gun TP'] and AzovV3['Exploits']['Gun TP']['Enabled']) and maxDist > 0 and distToMe > maxDist then continue end

            local bestPartForThisPlayer = nil
            local bestPartNameForThisPlayer = nil
            local bestDistForThisPlayer = 9e9
            local bestScreenPosForThisPlayer = nil
            local playerPartVisible = false

            if useClosestPart then
                for _, partName in ipairs(BodyParts) do
                    local part = getRealPart(char, partName)
                    if part then
                        local targetPos = getPartWorldPos(char, partName)
                        local screenPos3D, onScreen = Camera:WorldToViewportPoint(targetPos)
                        if onScreen or (forcedTarget and AzovV3['Silent Aimbot']['OffscreenTargeting']) then
                            local visible = isVisible(targetPos, char)
                            if not (AzovV3['Exploits'] and AzovV3['Exploits']['Gun TP'] and AzovV3['Exploits']['Gun TP']['Enabled']) and useWallCheck and not visible then
                                if not forcedTarget then
                                    continue
                                end
                            end
                            local screenPos = Vector2.new(screenPos3D.X, screenPos3D.Y)
                            local mag = (mousePos - screenPos).Magnitude
                            if mag < bestDistForThisPlayer then
                                bestDistForThisPlayer = mag
                                bestPartForThisPlayer = part
                                bestPartNameForThisPlayer = partName
                                bestScreenPosForThisPlayer = screenPos
                                playerPartVisible = visible
                            end
                        end
                    end
                end
            else
                local part = getRealPart(char, targetPart)
                local targetPos
                if part then
                    targetPos = getPartWorldPos(char, targetPart)
                else
                    part = hrp
                    targetPos = hrp.Position
                end
                local partName = targetPart
                
                local screenPos3D, onScreen = Camera:WorldToViewportPoint(targetPos)
                if onScreen or (forcedTarget and AzovV3['Silent Aimbot']['OffscreenTargeting']) then
                    local visible = isVisible(targetPos, char)
                    if not (AzovV3['Exploits'] and AzovV3['Exploits']['Gun TP'] and AzovV3['Exploits']['Gun TP']['Enabled']) and useWallCheck and not visible then
                        if not forcedTarget then
                            
                        else
                            bestDistForThisPlayer = (mousePos - Vector2.new(screenPos3D.X, screenPos3D.Y)).Magnitude
                            bestPartForThisPlayer = part
                            bestPartNameForThisPlayer = partName
                            bestScreenPosForThisPlayer = Vector2.new(screenPos3D.X, screenPos3D.Y)
                            playerPartVisible = visible
                        end
                    else
                        bestDistForThisPlayer = (mousePos - Vector2.new(screenPos3D.X, screenPos3D.Y)).Magnitude
                        bestPartForThisPlayer = part
                        bestPartNameForThisPlayer = partName
                        bestScreenPosForThisPlayer = Vector2.new(screenPos3D.X, screenPos3D.Y)
                        playerPartVisible = visible
                    end
                end
            end

            if bestPartForThisPlayer and (bestDistForThisPlayer <= radius or (forcedTarget and AzovV3['Silent Aimbot']['OffscreenTargeting'])) then
                if bestDistForThisPlayer < bestScreenDist then
                    bestScreenDist = bestDistForThisPlayer
                    bestTarget = char
                    bestPart = bestPartForThisPlayer
                    bestPartName = bestPartNameForThisPlayer
                    closestPlayerDist = distToMe
                    bestTargetVisible = playerPartVisible
                end
            end
        end

        return bestTarget, bestPart, bestPartName, closestPlayerDist, bestTargetVisible
    end

    local TargetCache = {
        Target = nil,
        Part = nil,
        PartName = nil,
        Distance = nil,
        IsVisible = false
    }

    RunService.RenderStepped:Connect(function()
        local silentAimEnabled = SilentAimActive or AzovV3['Silent Aimbot']['ToggleMode'] == "Always"
        if not silentAimEnabled and not TriggerBotActive and not AzovV3['Silent Aimbot']['TracerEnabled'] then 
            TargetCache.Target = nil
            return 
        end

        local targetToUse = nil
        if AzovV3['Silent Aimbot']['TargetingMode'] == "Manual" then
            local charToUse = nil
            if ManualTargetPlayer and ManualTargetPlayer.Character then
                charToUse = ManualTargetPlayer.Character
                ManualTarget = charToUse
            elseif ManualTarget and ManualTarget.Parent then
                charToUse = ManualTarget
            end
            if charToUse then
                targetToUse = charToUse
            else
                TargetCache.Target = nil
                TargetCache.Part = nil
                TargetCache.PartName = nil
                TargetCache.Distance = nil
                TargetCache.IsVisible = false
                return
            end
        end
        
        -- search with max possible fov (silent aim) to cover all features
        local bestTarget, bestPart, bestPartName, closestPlayerDist, isVisibleFlag = findBestTarget(
            AzovV3['Closest Point']['ClosestPartEnabled'], 
            AzovV3['Targeting']['TargetPart'], 
            targetToUse and AzovV3["Checks"]['ManualTargetWallCheck'] or AzovV3["Checks"]['WallCheck'], 
            nil, -- use default/max fov
            nil, -- use default max dist
            targetToUse
        )
        
        TargetCache.Target = bestTarget
        TargetCache.Part = bestPart
        TargetCache.PartName = bestPartName
        TargetCache.Distance = closestPlayerDist
        TargetCache.IsVisible = isVisibleFlag
    end)

    local oldIndex; oldIndex = hookmetamethod(game, "__index", function(self, idx)
        local silentAimEnabled = SilentAimActive or AzovV3['Silent Aimbot']['ToggleMode'] == "Always"
        if self == Mouse and (idx == "Hit" or (idx == "Target" and game.PlaceId == 2788229376)) then
            local forceHitCfg = AzovV3['Exploits'] and AzovV3['Exploits']['Force Hit']
            if forceHitCfg and forceHitCfg['Enabled'] and ForceHitTargetPlayer then
                local wc = forceHitCfg['WeaponConfigurations']
                if wc and wc['Enabled'] then
                    local charLocal = LocalPlayer.Character
                    local heldTool = charLocal and charLocal:FindFirstChildOfClass("Tool")
                    if not heldTool then
                        return oldIndex(self, idx)
                    end
                    local toolName = heldTool.Name:gsub("%[",""):gsub("%]","")
                    local cfg = wc[toolName]
                    if not (cfg and cfg['Enabled']) then
                        return oldIndex(self, idx)
                    end
                end
                local char = ForceHitTargetPlayer.Character
                if char then
                    local partName = forceHitCfg['TargetPart'] or "Head"
                    local part = char:FindFirstChild(partName)
                    if part then
                        return CFrame.new(part.Position)
                    end
                end
            end
            if silentAimEnabled then
                local bestTarget = TargetCache.Target
                local bestPart = TargetCache.Part
                local isScaled = AzovV3['Closest Point']['ClosestPartMode'] == "Scaled"
                
                if bestTarget and bestPart then
        local wallCheckEnabled = ManualTarget and AzovV3["Checks"]['ManualTargetWallCheck'] or AzovV3["Checks"]['WallCheck']
        if not (AzovV3['Exploits'] and AzovV3['Exploits']['Gun TP'] and AzovV3['Exploits']['Gun TP']['Enabled']) and wallCheckEnabled and not TargetCache.IsVisible then
            return oldIndex(self, idx)
        end

                    local hrp = bestTarget:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local targetPos
                        if isScaled then
                            targetPos = getScaledWorldPos(bestTarget)
                        else
                            targetPos = getPartWorldPos(bestTarget, TargetCache.PartName) or bestPart.Position
                        end
                        
                        local adjustedVel = getAdjustedVelocity(hrp, TargetCache.Distance, true)
                        local predictedPos
                        
                        if not AzovV3['Silent Aimbot']['AutoPrediction'] and not AzovV3['Silent Aimbot']['PingPrediction'] and AzovV3['Silent Aimbot']['ManualPredictionMode'] == "Advanced" then
                            local adv = AzovV3['Silent Aimbot']['AdvancedManualPrediction']
                            predictedPos = targetPos + Vector3.new(
                                adjustedVel.X * adv.X,
                                adjustedVel.Y * adv.Y,
                                adjustedVel.Z * adv.Z
                            ) - Vector3.new(0, 0.4, 0)
                        else
                            local predValue
                            if AzovV3['Silent Aimbot']['AutoPrediction'] then
                                predValue = calculateDynamicPrediction(bestTarget, TargetCache.Distance)
                            elseif AzovV3['Silent Aimbot']['PingPrediction'] then
                                predValue = currentPred
                            else
                                predValue = AzovV3['Silent Aimbot']['ManualPrediction']
                            end
                            predictedPos = targetPos + (adjustedVel * predValue) - Vector3.new(0, 0.4, 0)
                        end
                        
                        local antiCurve = AzovV3['Silent Aimbot']['AntiCurve']
                        if antiCurve and antiCurve['Enabled'] then
                            local deg = tonumber(antiCurve['Angle']) or 0
                            if deg ~= 0 then
                                local angle = math.rad(deg)
                                local origin = Camera.CFrame.Position
                                local dist = (predictedPos - origin).Magnitude
                                local direction = (predictedPos - origin).Unit
                                local basis = CFrame.new(Vector3.zero, direction)
                                local rotatedDirection = (basis * CFrame.Angles(-angle, 0, 0)).LookVector
                                local finalPos = origin + (rotatedDirection * dist)
                                return CFrame.new(finalPos)
                            end
                        end
                        
                        return CFrame.new(predictedPos)
                    end
                end
            end
        end

        return oldIndex(self, idx)
    end)

    local Tracer
    local ForceHitTracer = Drawing.new("Line")
    ForceHitTracer.Visible = false

    if AzovV3['Silent Aimbot']['TracerEnabled'] then
        Tracer = Drawing.new("Line")
        Tracer.Visible = true
        Tracer.Thickness = AzovV3['Silent Aimbot']['TracerThickness']

        RunService.RenderStepped:Connect(function()
            if not AzovV3['Silent Aimbot']['TracerEnabled'] then
                Tracer.Visible = false
                return
            end
            Tracer.Color = SilentAimActive and AzovV3['Silent Aimbot']['TracerColorOn'] or AzovV3['Silent Aimbot']['TracerColorOff']
            
            local bestTarget = TargetCache.Target
            local bestPart = TargetCache.Part
            local isScaled = AzovV3['Closest Point']['ClosestPartMode'] == "Scaled"
            
            if bestTarget and bestPart then
                local targetPos
                if isScaled then
                    local hrp = bestTarget:FindFirstChild("HumanoidRootPart")
                    if not hrp then
                        Tracer.Visible = false
                        return
                    end
                    targetPos = hrp.Position
                else
                    targetPos = getPartWorldPos(bestTarget, TargetCache.PartName) or bestPart.Position
                end
                local screenPos3D, onScreen = Camera:WorldToViewportPoint(targetPos)
                local mousePos = UserInputService:GetMouseLocation()
                
                if onScreen then
                    Tracer.From = mousePos
                    Tracer.To = Vector2.new(screenPos3D.X, screenPos3D.Y)
                    Tracer.Visible = true
                elseif AzovV3['Silent Aimbot']['OffscreenTargeting'] then
                    local relative = Camera.CFrame:PointToObjectSpace(targetPos)
                    local dir = Vector2.new(relative.X, -relative.Y).Unit
                    Tracer.From = mousePos
                    Tracer.To = mousePos + dir * 10000
                    Tracer.Visible = true
                else
                    Tracer.Visible = false
                end
            else
                Tracer.Visible = false
            end
        end)
    end

    RunService.RenderStepped:Connect(function()
        local fhCfg = AzovV3['Exploits'] and AzovV3['Exploits']['Force Hit']
        local tracerCfg = fhCfg and fhCfg['Tracer']
        if not (fhCfg and fhCfg['Enabled'] and tracerCfg and tracerCfg['Enabled']) then
            ForceHitTracer.Visible = false
            return
        end
        if fhCfg['SyncManualTarget'] then
            ForceHitTracer.Visible = false
            return
        end
        if not ForceHitTargetPlayer then
            ForceHitTracer.Visible = false
            return
        end
        local char = ForceHitTargetPlayer.Character
        if not char then
            ForceHitTracer.Visible = false
            return
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            ForceHitTracer.Visible = false
            return
        end
        local targetPos = hrp.Position
        local screenPos3D, onScreen = Camera:WorldToViewportPoint(targetPos)
        local viewport = Camera.ViewportSize
        local fromPos = Vector2.new(viewport.X / 2, 0)
        if onScreen then
            ForceHitTracer.From = fromPos
            ForceHitTracer.To = Vector2.new(screenPos3D.X, screenPos3D.Y)
        else
            local relative = Camera.CFrame:PointToObjectSpace(targetPos)
            local dir = Vector2.new(relative.X, -relative.Y)
            local mag = dir.Magnitude
            if mag == 0 or mag ~= mag then
                ForceHitTracer.Visible = false
                return
            end
            dir = dir / mag
            ForceHitTracer.From = fromPos
            ForceHitTracer.To = fromPos + dir * 10000
        end
        ForceHitTracer.Color = tracerCfg['Color'] or Color3.fromRGB(201,168,241)
        ForceHitTracer.Thickness = tracerCfg['Thickness'] or 0.5
        ForceHitTracer.Visible = true
    end)

    local EasingFunctions = {
        Linear = function(t) return t end,
        QuadIn = function(t) return t * t end,
        QuadOut = function(t) return t * (2 - t) end,
        CubicIn = function(t) return t * t * t end,
        CubicOut = function(t) return 1 - ((1 - t) * (1 - t) * (1 - t)) end,
    }

    RunService.RenderStepped:Connect(function(delta)
        if not CamlockActive then return end

        if not LockedTarget then
            local bestTarget, bestPart, bestPartName, closestPlayerDist, _ = findBestTarget(AzovV3['Closest Point']['CamlockClosestPartEnabled'], AzovV3['Targeting']['CamlockTargetPart'], AzovV3["Checks"]['CamlockWallCheck'])
            if bestTarget then
                LockedTarget = {
                    Character = bestTarget,
                    PartName = bestPartName,
                    Distance = closestPlayerDist
                }
            else
                return
            end
        end

        local targetChar = LockedTarget.Character
        if not targetChar or not targetChar:FindFirstChild("Humanoid") or targetChar.Humanoid.Health <= 0 then
            LockedTarget = nil
            CamlockActive = false  
            return
        end

        if AzovV3["Checks"]['KnockedCheck'] then
            local bodyEffects = targetChar:FindFirstChild("BodyEffects")
            if bodyEffects and bodyEffects:FindFirstChild("K.O") and bodyEffects["K.O"].Value then
                LockedTarget = nil
                CamlockActive = false  
                return
            end
        end

        local hrp = targetChar:FindFirstChild("HumanoidRootPart")
        if not hrp then
            LockedTarget = nil
            CamlockActive = false  
            return
        end

        local partName = LockedTarget.PartName
        local part = getRealPart(targetChar, partName)
        if not part then
            LockedTarget = nil
            CamlockActive = false  
            return
        end

        local targetPos = getPartWorldPos(targetChar, partName) or part.Position
        local adjustedVel = getAdjustedVelocity(hrp, LockedTarget.Distance, false)
        local predictedPos

        if not AzovV3['Silent Aimbot']['AutoPrediction'] and not AzovV3['Silent Aimbot']['PingPrediction'] and AzovV3['Silent Aimbot']['ManualPredictionMode'] == "Advanced" then
            local adv = AzovV3['Silent Aimbot']['AdvancedManualPrediction']
            predictedPos = targetPos + Vector3.new(
                adjustedVel.X * adv.X,
                adjustedVel.Y * adv.Y,
                adjustedVel.Z * adv.Z
            ) - Vector3.new(0, 0.4, 0)
        else
            local predValue = AzovV3['Camera Aimbot']['CamlockPrediction']  
            if AzovV3['Silent Aimbot']['AutoPrediction'] then
                predValue = calculateDynamicPrediction(targetChar, LockedTarget.Distance)
            elseif AzovV3['Silent Aimbot']['PingPrediction'] then
                predValue = currentPred
            end
            predictedPos = targetPos + (adjustedVel * predValue) - Vector3.new(0, 0.4, 0)
        end
        
        -- Humanizer
        local humanizer = AzovV3['Camera Aimbot']['Humanizer']
        if humanizer and humanizer['Enabled'] then
            local style = humanizer['Style']
            if style == "Jitter" then
                local intensity = humanizer['JitterIntensity']
                predictedPos = predictedPos + Vector3.new(
                    math.random(-intensity * 10, intensity * 10) / 100,
                    math.random(-intensity * 10, intensity * 10) / 100,
                    math.random(-intensity * 10, intensity * 10) / 100
                )
            elseif style == "Sway" then
                local intensity = humanizer['SwayIntensity']
                local speed = humanizer['SwaySpeed']
                local t = tick()
                predictedPos = predictedPos + Vector3.new(
                    math.sin(t * speed) * intensity / 10,
                    math.cos(t * speed) * intensity / 10,
                    0
                )
            end
        end

        if AzovV3["Checks"]['CamlockWallCheck'] and not isVisible(predictedPos, targetChar) then
            return
        end

        local targetCFrame = CFrame.new(Camera.CFrame.Position, predictedPos)

        local easingFunc = EasingFunctions[AzovV3['Camera Aimbot']['CamlockEasingStyle']] or EasingFunctions.Linear
        local smoothVal = AzovV3['Camera Aimbot']['CamlockSmoothness'] or 1
        if smoothVal < 1 then smoothVal = 1 end
        
        local rawAlpha = 1 / smoothVal
        local easedAlpha = easingFunc(rawAlpha)
        
        easedAlpha = math.clamp(easedAlpha * delta * 60, 0, 1)  

        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, easedAlpha)
    end)

    local AntiViewerRunning = false
    local function StartAntiViewer()
        if AntiViewerRunning then return end
        AntiViewerRunning = true
        task.spawn(function()
            local mouse = LocalPlayer:GetMouse()
            while AzovV3['Anti Ban']['AntiViewerEnabled'] do
                local players = Players:GetPlayers()
                local closestPlayer = nil
                local closestDistance = math.huge
                
                for _, player in ipairs(players) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local playerPosition = player.Character.HumanoidRootPart.Position
                        local viewportPosition, onScreen = Camera:WorldToViewportPoint(playerPosition)
                        if onScreen then
                            local mousePos = UserInputService:GetMouseLocation()
                            local distance = (mousePos - Vector2.new(viewportPosition.X, viewportPosition.Y)).Magnitude
                            if distance < closestDistance then
                                closestPlayer = player
                                closestDistance = distance
                            end
                        end
                    end
                end
                
                -- This function currently does not apply any actual redirection logic, 
                -- but we fixed the loop and player list update to prevent errors.
                
                task.wait(0.1)
            end
            AntiViewerRunning = false
        end)
    end
    if AzovV3['Anti Ban']['AntiViewerEnabled'] then
        StartAntiViewer()
    end

    local function IsTouchingWall(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local rayDirections = {
            hrp.CFrame.RightVector * 2,   
            -hrp.CFrame.RightVector * 2,  
            hrp.CFrame.LookVector * 2,    
            -hrp.CFrame.LookVector * 2    
        }

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        for _, dir in ipairs(rayDirections) do
            local rayResult = workspace:Raycast(hrp.Position, dir, rayParams)
            if rayResult then
                return true
            end
        end
        return false
    end

    UserInputService.JumpRequest:Connect(function()
        if not AzovV3['Speed Modifications']['WallJumpEnabled'] then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        if hum:GetState() == Enum.HumanoidStateType.Freefall and IsTouchingWall(char) then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z) + Vector3.new(0, 50, 0)
            hum:ChangeState(Enum.HumanoidStateType.Jumping)  
        end
    end)

    local lastFire = 0
    RunService.RenderStepped:Connect(function()
        if TriggerBotActive then
            local currentTime = tick()
            if currentTime - lastFire >= AzovV3['Camera Aimbot']['TriggerBot']['Delay'] then
                local bestTarget = TargetCache.Target
                if bestTarget and TargetCache.Part then
                    -- check world distance
                    local maxDist = AzovV3['Camera Aimbot']['TriggerBot']['MaxDistance']
                    if maxDist > 0 and TargetCache.Distance > maxDist then return end

                    -- check fov (screen distance)
                    local partPos = TargetCache.Part.Position
                    local screenPos, onScreen = Camera:WorldToViewportPoint(partPos)
                    if onScreen then
                        local mousePos = UserInputService:GetMouseLocation()
                        local screenDist = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                        
                        if screenDist <= AzovV3['Camera Aimbot']['TriggerBot']['FOV'] then
                            pcall(function()
                                mouse1press()
                                task.wait(0.01)
                                mouse1release()
                            end)
                            lastFire = currentTime
                        end
                    end
                end
            end
        end
    end)

    -- esp variables
    local ESPObjects = {}
    local visibilityUpdateConn = nil
    local ESPActive = AzovV3['ESP']['ESPEnabled']

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

    local function updateAllVisibility()
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        
        local toRemove = {}
        
        for char, obj in pairs(ESPObjects) do
            if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
                table.insert(toRemove, char)
            elseif myHRP and obj.nameLabel then
                if obj.billboard then
                    obj.billboard.Enabled = ESPActive
                end
                local dist = (myHRP.Position - char.HumanoidRootPart.Position).Magnitude
                local rayVisible = isVisible(char)
                local visible = rayVisible and (dist <= AzovV3['ESP']['ESPDistance'])
                local isTargeted = false
                if AzovV3['Silent Aimbot']['TargetingMode'] == "Manual" then
                    local pl = Players:GetPlayerFromCharacter(char)
                    if ManualTargetPlayer and pl == ManualTargetPlayer then
                        isTargeted = true
                    end
                else
                    if TargetCache and TargetCache.Target == char then
                        isTargeted = true
                    end
                end
                if isTargeted then
                    obj.nameLabel.TextColor3 = AzovV3['ESP']['TargetedColor'] or Color3.fromRGB(255, 85, 85)
                else
                    obj.nameLabel.TextColor3 = visible and Color3.fromRGB(201,168,241) or Color3.fromRGB(255, 255, 255)
                end
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
        billboard.Size = UDim2.new(0, 100, 0, 30) -- smaller size
        billboard.StudsOffset = Vector3.new(0, -3, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = ESPActive
        billboard.Parent = hrp

        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Size = UDim2.new(1, 0, 1, 0)
        nameLabel.Text = char.Name:lower() -- looks cleaner/edgier
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextStrokeTransparency = 0.5
        nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameLabel.Font = Enum.Font.Code -- monospaced, clean look
        nameLabel.TextSize = 12 -- smaller text
        nameLabel.Parent = billboard
        
        ESPObjects[char] = {billboard = billboard, nameLabel = nameLabel}
    end

    local function removeESP(char)
        if ESPObjects[char] then
            local obj = ESPObjects[char]
            if obj.billboard then obj.billboard:Destroy() end
            ESPObjects[char] = nil
        end
    end

    -- player tracking (fixed: conditional add, proper removing)
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

    for _, plr in ipairs(Players:GetPlayers()) do
        handlePlayer(plr)
    end

    Players.PlayerAdded:Connect(handlePlayer)

    if ESPActive then
        visibilityUpdateConn = RunService.Heartbeat:Connect(updateAllVisibility)
    end

    local espStateSyncConn = RunService.Heartbeat:Connect(function()
        local desired = AzovV3['ESP']['ESPEnabled']
        if desired == false and ESPActive == true then
            ESPActive = false
            for char, obj in pairs(ESPObjects) do
                if obj.billboard then
                    obj.billboard.Enabled = false
                end
            end
            if visibilityUpdateConn then
                visibilityUpdateConn:Disconnect()
                visibilityUpdateConn = nil
            end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if checkInput(input, AzovV3['ESP']['ESPToggleKey']) then
            if not AzovV3['ESP']['ESPEnabled'] and not ESPActive then
                return
            end
            ESPActive = not ESPActive
            for char, obj in pairs(ESPObjects) do
                if obj.billboard then
                    obj.billboard.Enabled = ESPActive
                end
            end
            if ESPActive then
                if visibilityUpdateConn then visibilityUpdateConn:Disconnect() end
                visibilityUpdateConn = RunService.Heartbeat:Connect(updateAllVisibility)
            else
                if visibilityUpdateConn then
                    visibilityUpdateConn:Disconnect()
                    visibilityUpdateConn = nil
                end
            end
        end
    end)

    -- anti-lock implementation
    RunService.Heartbeat:Connect(function()
        if AntiLockActive then
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local vel = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(0, AzovV3['AntiLock']['AntiLockAmount'], 0)
            RunService.RenderStepped:Wait()
            hrp.AssemblyLinearVelocity = vel
        end
    end)

    local function deepMerge(target, source)
        for key, value in pairs(source) do
            if typeof(value) == "table" and typeof(target[key]) == "table" then
                deepMerge(target[key], value)
            else
                target[key] = value
            end
        end
    end

    local function applyRuntimeChanges()
        local silentAimEnabled = SilentAimActive or AzovV3['Silent Aimbot']['ToggleMode'] == "Always"
        fovCircle.Radius = AzovV3['Silent Aimbot']['DefaultFOV']
        fovCircle.Visible = AzovV3['Silent Aimbot']['FOV_VISIBLE']
        fovCircle.Color = silentAimEnabled and AzovV3['Silent Aimbot']['FOV_COLOR_ON'] or AzovV3['Silent Aimbot']['FOV_COLOR_OFF']
        local desiredESP = AzovV3['ESP']['ESPEnabled']
        if desiredESP == false and ESPActive == true then
            ESPActive = false
            for char, obj in pairs(ESPObjects) do
                if obj.billboard then
                    obj.billboard.Enabled = false
                end
            end
            if visibilityUpdateConn then
                visibilityUpdateConn:Disconnect()
                visibilityUpdateConn = nil
            end
        end
        
        if Tracer then
            Tracer.Thickness = AzovV3['Silent Aimbot']['TracerThickness']
        end
        if AzovV3['Silent Aimbot']['TracerEnabled'] and not Tracer then
            Tracer = Drawing.new("Line")
            Tracer.Visible = true
            Tracer.Thickness = AzovV3['Silent Aimbot']['TracerThickness']
            RunService.RenderStepped:Connect(function()
                if not AzovV3['Silent Aimbot']['TracerEnabled'] then
                    Tracer.Visible = false
                    return
                end
                local currentSilentAimEnabled = SilentAimActive or AzovV3['Silent Aimbot']['ToggleMode'] == "Always"
                Tracer.Color = currentSilentAimEnabled and AzovV3['Silent Aimbot']['TracerColorOn'] or AzovV3['Silent Aimbot']['TracerColorOff']
                
                local bestTarget = TargetCache.Target
                local bestPart = TargetCache.Part
                
                local isScaled = AzovV3['Closest Point']['ClosestPartMode'] == "Scaled"
                
                if bestTarget and (bestPart or isScaled) then
                    local targetPos
                    if isScaled then
                        local hrp = bestTarget:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            targetPos = hrp.Position
                        else
                            targetPos = getPartWorldPos(bestTarget, TargetCache.PartName) or (bestPart and bestPart.Position)
                        end
                    else
                        targetPos = getPartWorldPos(bestTarget, TargetCache.PartName) or bestPart.Position
                    end
                    local screenPos3D, onScreen = Camera:WorldToViewportPoint(targetPos)
                    local mousePos = UserInputService:GetMouseLocation()
                    
                    if onScreen then
                        Tracer.From = mousePos
                        Tracer.To = Vector2.new(screenPos3D.X, screenPos3D.Y)
                        Tracer.Visible = true
                    elseif AzovV3['Silent Aimbot']['OffscreenTargeting'] then
                        local relative = Camera.CFrame:PointToObjectSpace(targetPos)
                        local dir = Vector2.new(relative.X, -relative.Y).Unit
                        Tracer.From = mousePos
                        Tracer.To = mousePos + dir * 10000
                        Tracer.Visible = true
                    else
                        Tracer.Visible = false
                    end
                else
                    Tracer.Visible = false
                end
            end)
        end
        if AzovV3['Anti Ban']['AntiViewerEnabled'] then
            StartAntiViewer()
        end
    end

    local oldNewIndex; oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
        return oldNewIndex(self, key, value)
    end)

    local oldIndex; oldIndex = hookmetamethod(game, "__index", function(self, key)
        return oldIndex(self, key)
    end)

    local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
            -- remote handling
        end
        return oldNamecall(self, ...)
    end)

    -- chat command system
    LocalPlayer.Chatted:Connect(function(msg)
        -- [[ Dynamic Settings Editor ]]
        if msg:sub(1, 5):lower() == "!set " then
            local content = msg:sub(6)
            local path, valueStr
            
            -- Try "path=value" format first
            local eqPos = content:find("=")
            if eqPos then
                path = content:sub(1, eqPos - 1)
                valueStr = content:sub(eqPos + 1)
            else
                -- Fallback to "path value"
                local lastSpace = 0
                for i = #content, 1, -1 do
                    if content:sub(i, i) == " " then
                        lastSpace = i
                        break
                    end
                end
                
                if lastSpace > 0 then
                    path = content:sub(1, lastSpace - 1)
                    valueStr = content:sub(lastSpace + 1)
                end
            end
            
            if path and valueStr then
                -- Trim spaces
                path = path:match("^%s*(.-)%s*$")
                valueStr = valueStr:match("^%s*(.-)%s*$")
                
                -- Traverse path
                local keys = path:split(".")
                local current = AzovV3
                local parent = nil
                local lastKey = nil
                
                for i, key in ipairs(keys) do
                    local found = false
                    if type(current) == "table" then
                        -- Exact match
                        if current[key] ~= nil then
                            parent = current
                            lastKey = key
                            current = current[key]
                            found = true
                        else
                            -- Case-insensitive search
                            for k, v in pairs(current) do
                                if type(k) == "string" and k:lower() == key:lower() then
                                    parent = current
                                    lastKey = k
                                    current = v
                                    found = true
                                    break
                                end
                            end
                        end
                    end
                    if not found then
                        parent = nil
                        break
                    end
                end
                
                if parent and lastKey and parent[lastKey] ~= nil then
                    -- Parse value
                    local val = valueStr
                    if val:lower() == "true" then val = true
                    elseif val:lower() == "false" then val = false
                    elseif tonumber(val) then val = tonumber(val)
                    elseif val:sub(1,1) == '"' and val:sub(-1,-1) == '"' then
                        val = val:sub(2, -2)
                    elseif val:sub(1,1) == "'" and val:sub(-1,-1) == "'" then
                        val = val:sub(2, -2)
                    end
                    
                    parent[lastKey] = val
                    
                    if AzovV3['Notifications']['CommandNotify'] then
                        game.StarterGui:SetCore("SendNotification", {
                            Title = "Setting Updated",
                            Text = lastKey .. " -> " .. tostring(val),
                            Duration = 3
                        })
                    end
                    
                    applyRuntimeChanges()
                end
            end
            return
        end

        local cmdConfig = AzovV3['ChatCommands'][msg]
        if cmdConfig then
            for section, values in pairs(cmdConfig) do
                if AzovV3[section] then
                    deepMerge(AzovV3[section], values)
                end
            end
            -- optional: notify the user (toggleable)
            if AzovV3['Notifications']['CommandNotify'] then
                game.StarterGui:SetCore("SendNotification", {
                    Title = "Config Updated",
                    Text = "Applied config for " .. msg,
                    Duration = 3
                })
            end
            applyRuntimeChanges()
        end
    end)

    -- panic button
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if checkInput(input, AzovV3['Global']['PanicKey']) then
            SilentAimActive = false
            CamlockActive = false
            LockedTarget = nil
            SpeedEnabled = false
            TriggerBotActive = false
            AntiLockActive = false
            ESPActive = false

            -- hide fov circle
            fovCircle.Visible = false
            fovCircle.Radius = AzovV3['Silent Aimbot']['DefaultFOV']
            fovCircle.Color = AzovV3['Silent Aimbot']['FOV_COLOR_OFF']
            AzovV3['Silent Aimbot']['FOV_VISIBLE'] = false

            -- hide tracer if exists
            if Tracer then
                Tracer.Visible = false
                AzovV3['Silent Aimbot']['TracerEnabled'] = false
            end

            -- disable esp
            for char, obj in pairs(ESPObjects) do
                if obj.billboard then
                    obj.billboard.Enabled = false
                end
            end
            if visibilityUpdateConn then
                visibilityUpdateConn:Disconnect()
                visibilityUpdateConn = nil
            end

            -- force normal speeds
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum.WalkSpeed = 16
                    hum.JumpPower = 50
                end
            end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if checkInput(input, AzovV3['Silent Aimbot']['ManualTargetKey']) then
            -- old method: try mouse.target first
            local target = Mouse.Target
            if target and target.Parent and target.Parent:FindFirstChild("Humanoid") then
                -- if we clicked a different target, select them. if same, toggle off?
                -- usually clicking a player explicitly means "select this one".
                -- so we'll just set it.
                local plr = Players:GetPlayerFromCharacter(target.Parent)
                if ManualTargetPlayer and plr == ManualTargetPlayer then
                    ManualTarget = nil
                    ManualTargetPlayer = nil
                else
                    ManualTarget = target.Parent
                    ManualTargetPlayer = plr
                end
            else
                -- fallback: find best target with large radius (effectively infinite)
                local bestTarget, _, _, _, _ = findBestTarget(true, "Head", AzovV3['Checks']['ManualTargetWallCheck'], 20000, 20000)
                if bestTarget then
                    local plr = Players:GetPlayerFromCharacter(bestTarget)
                    if ManualTargetPlayer and plr == ManualTargetPlayer then
                        ManualTarget = nil
                        ManualTargetPlayer = nil
                    else
                        ManualTarget = bestTarget
                        ManualTargetPlayer = plr
                    end
                else
                    ManualTarget = nil
                    ManualTargetPlayer = nil
                end
            local fhCfg = AzovV3['Exploits'] and AzovV3['Exploits']['Force Hit']
            if fhCfg and fhCfg['Enabled'] and fhCfg['SyncManualTarget'] then
                ForceHitTargetPlayer = ManualTargetPlayer or nil
            end
            end
        end
    end)

    local function getClosestForceHitCharacter()
        local mousePos = UserInputService:GetMouseLocation()
        local closestPlayer = nil
        local closestDist = math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local char = plr.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                if root and humanoid and humanoid.Health > 0 then
                    local knocked = false
                    if AzovV3['Checks']['KnockedCheck'] then
                        local bodyEffects = char:FindFirstChild("BodyEffects")
                        if bodyEffects then
                            local ko = bodyEffects:FindFirstChild("K.O") or bodyEffects:FindFirstChild("KO")
                            if ko and ko.Value then
                                knocked = true
                            end
                        end
                        if char:GetAttribute("Knocked") or char:GetAttribute("Downed") then
                            knocked = true
                        end
                    end
                    if not knocked then
                        local screenPos3D, onScreen = Camera:WorldToViewportPoint(root.Position)
                        if onScreen then
                            local screenPos = Vector2.new(screenPos3D.X, screenPos3D.Y)
                            local dist = (screenPos - mousePos).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closestPlayer = plr
                            end
                        end
                    end
                end
            end
        end
        return closestPlayer
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        local fhCfg = AzovV3['Exploits'] and AzovV3['Exploits']['Force Hit']
        if not (fhCfg and fhCfg['Enabled']) then return end
        if fhCfg['SyncManualTarget'] then return end
        if not checkInput(input, fhCfg['Keybind']) then return end
        local newPlr = getClosestForceHitCharacter()
        if ForceHitTargetPlayer and (not newPlr or newPlr == ForceHitTargetPlayer) then
            ForceHitTargetPlayer = nil
        else
            ForceHitTargetPlayer = newPlr
        end
    end)

    -- Force Hit bullet teleport (tool grip method)
    local ForceHitCharAddedConn, ForceHitCharRemovedConn, ForceHitToolActivatedConn

    local function forceHitCFrameToOffset(origin, target)
        local actual_origin = origin * CFrame.new(0, -1, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0)
        return actual_origin:ToObjectSpace(target):Inverse()
    end

    local function forceHitTeleportBullet(tool)
        local fhCfg = AzovV3['Exploits'] and AzovV3['Exploits']['Force Hit']
        if not (fhCfg and fhCfg['Enabled']) then return end
        local wc = fhCfg['WeaponConfigurations']
        if wc and wc['Enabled'] then
            local char = LocalPlayer.Character
            local heldTool = char and char:FindFirstChildOfClass("Tool")
            if not heldTool then return end
            local toolName = heldTool.Name:gsub("%[",""):gsub("%]","")
            local cfg = wc[toolName]
            if not (cfg and cfg['Enabled']) then
                return
            end
        end
        if not ForceHitTargetPlayer then return end
        local targetChar = ForceHitTargetPlayer.Character
        if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then return end

        local char = LocalPlayer.Character
        if not char then return end
        local originPart = char:FindFirstChild("HumanoidRootPart")
        local targetPart = targetChar.HumanoidRootPart
        if not (originPart and targetPart) then return end

        local rightHand = char:FindFirstChild("RightHand")
        if not rightHand then return end

        local originalGrip = tool.Grip
        tool.Parent = LocalPlayer.Backpack
        tool.Grip = forceHitCFrameToOffset(rightHand.CFrame, targetPart.CFrame)
        tool.Parent = char
        RunService.RenderStepped:Wait()
        tool.Parent = LocalPlayer.Backpack
        tool.Grip = originalGrip
        tool.Parent = char
    end

    local function setupForceHitCharacter(char)
        if ForceHitCharAddedConn then ForceHitCharAddedConn:Disconnect() end
        if ForceHitCharRemovedConn then ForceHitCharRemovedConn:Disconnect() end
        if ForceHitToolActivatedConn then ForceHitToolActivatedConn:Disconnect() end

        ForceHitCharAddedConn = char.ChildAdded:Connect(function(tool)
            if tool:IsA("Tool") then
                if getconnections then
                    for _, conn in ipairs(getconnections(tool:GetPropertyChangedSignal("Grip"))) do
                        conn:Disable()
                    end
                end
                if ForceHitToolActivatedConn then ForceHitToolActivatedConn:Disconnect() end
                ForceHitToolActivatedConn = tool.Activated:Connect(function()
                    forceHitTeleportBullet(tool)
                end)
            end
        end)

        ForceHitCharRemovedConn = char.ChildRemoved:Connect(function()
            if ForceHitToolActivatedConn then
                ForceHitToolActivatedConn:Disconnect()
                ForceHitToolActivatedConn = nil
            end
        end)
    end

    local currentFHChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    setupForceHitCharacter(currentFHChar)

    LocalPlayer.CharacterAdded:Connect(function(char)
        setupForceHitCharacter(char)
    end)

    LocalPlayer.CharacterRemoving:Connect(function()
        if ForceHitCharAddedConn then ForceHitCharAddedConn:Disconnect() end
        if ForceHitCharRemovedConn then ForceHitCharRemovedConn:Disconnect() end
        if ForceHitToolActivatedConn then ForceHitToolActivatedConn:Disconnect() end
    end)

    -- [[ Hitbox Expander ]]
    local HitboxVisuals = {}
    local OriginalProperties = {}

    local function restorePart(part)
        if OriginalProperties[part] then
            local props = OriginalProperties[part]
            part.Size = props.Size
            part.Transparency = props.Transparency
            part.CanCollide = props.CanCollide
            part.Color = props.Color
            part.Material = props.Material
            OriginalProperties[part] = nil
        end
        if HitboxVisuals[part] then
            HitboxVisuals[part]:Destroy()
            HitboxVisuals[part] = nil
        end
    end

    RunService.RenderStepped:Connect(function()
        local settings = AzovV3['Hitbox Expander']
        if not settings['Enabled'] then 
            -- Cleanup all when disabled
            for part, _ in pairs(OriginalProperties) do
                restorePart(part)
            end
            return 
        end

        local targetPartName = settings['Part'] or "HumanoidRootPart"
        local baseSize = settings['HitboxSize'] or 2
        local transparency = settings['Transparency'] or 0.9
        local visualize = settings['Visualize']
        local boxColor = settings['BoxColor'] or Color3.fromRGB(120, 0, 255)
        local cornerColor = settings['CornerColor'] or Color3.fromRGB(200, 100, 255)
        
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        
        local currentParts = {}

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or table.find(AzovV3["Global"]['IgnorePlayers'], plr.Name) then continue end
            
            local char = plr.Character
            if not char then continue end
            
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            
            -- Knocked Check
            if AzovV3['Checks']['KnockedCheck'] then
                if char:FindFirstChild("BodyEffects") then
                    local ko = char.BodyEffects:FindFirstChild("K.O") or char.BodyEffects:FindFirstChild("KO")
                    if ko and ko.Value then continue end
                end
                if char:GetAttribute("Knocked") or char:GetAttribute("Downed") then continue end
            end
            
            local targetPart = char:FindFirstChild(targetPartName)
            if targetPart and targetPart:IsA("BasePart") then
                currentParts[targetPart] = true
                
                -- Store original properties if not already stored
                if not OriginalProperties[targetPart] then
                    OriginalProperties[targetPart] = {
                        Size = targetPart.Size,
                        Transparency = targetPart.Transparency,
                        CanCollide = targetPart.CanCollide,
                        Color = targetPart.Color,
                        Material = targetPart.Material
                    }
                end

                local finalSize = Vector3.new(baseSize, baseSize, baseSize)
                
                -- Velocity-based expansion
                if rangeMod and rangeMod['Enabled'] and myHRP then
                    local dist = (myHRP.Position - targetPart.Position).Magnitude
                    if dist <= (rangeMod['EffectiveRange'] or 300) then
                        local velocity = targetPart.AssemblyLinearVelocity
                        local prediction = rangeMod['Prediction'] or 0.15
                        if velocity == velocity then
                            finalSize = finalSize + (Vector3.new(math.abs(velocity.X), math.abs(velocity.Y), math.abs(velocity.Z)) * prediction)
                        end
                    end
                end
                
                -- Apply Physical Changes
                targetPart.CanCollide = false
                targetPart.Size = finalSize
                
                -- Visual Handling
                if visualize then
                    -- Make the actual part invisible so the "Big Head" isn't blocky
                    targetPart.Transparency = 1 
                    
                    local visualFolder = HitboxVisuals[targetPart]
                    if not visualFolder then
                        visualFolder = Instance.new("Folder")
                        visualFolder.Name = "HitboxVisual_" .. plr.Name
                        visualFolder.Parent = game:GetService("CoreGui")
                        
                        -- Selection Box (Edges)
                        local box = Instance.new("SelectionBox")
                        box.Name = "Outline"
                        box.Adornee = targetPart
                        box.Color3 = boxColor
                        box.LineThickness = 0.01
                        box.SurfaceTransparency = 1
                        box.Parent = visualFolder
                        
                        -- Corner Ridges
                        local cornerFolder = Instance.new("Folder")
                        cornerFolder.Name = "Corners"
                        cornerFolder.Parent = visualFolder

                        local offsets = {
                            Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
                            Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1)
                        }

                        for i, offset in ipairs(offsets) do
                            local corner = Instance.new("BoxHandleAdornment")
                            corner.Name = "Corner" .. i
                            corner.Adornee = targetPart
                            corner.Size = Vector3.new(0.15, 0.15, 0.15)
                            corner.Color3 = cornerColor
                            corner.Transparency = 0.1
                            corner.AlwaysOnTop = true
                            corner.ZIndex = 5
                            corner.Parent = cornerFolder
                        end

                        HitboxVisuals[targetPart] = visualFolder
                    end
                    
                    -- Update colors and corner positions
                    local b = visualFolder:FindFirstChild("Outline")
                    if b then b.Color3 = boxColor end
                    
                    local cFolder = visualFolder:FindFirstChild("Corners")
                    if cFolder then
                        local size = targetPart.Size
                        local cornerIdx = 1
                        local offsets = {
                            Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
                            Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1)
                        }
                        for _, corner in ipairs(cFolder:GetChildren()) do
                            local offset = offsets[cornerIdx]
                            if offset then
                                corner.CFrame = CFrame.new((size / 2) * offset)
                                corner.Color3 = cornerColor
                            end
                            cornerIdx = cornerIdx + 1
                        end
                    end
                else
                    -- Restore transparency if visual turned off but expander still on
                    if OriginalProperties[targetPart] then
                        targetPart.Transparency = OriginalProperties[targetPart].Transparency
                    end
                    if HitboxVisuals[targetPart] then
                        HitboxVisuals[targetPart]:Destroy()
                        HitboxVisuals[targetPart] = nil
                    end
                end
            end
        end

        -- Cleanup for players who left, died, or are no longer targeted
        for part, _ in pairs(OriginalProperties) do
            if not currentParts[part] then
                restorePart(part)
            end
        end
    end)


    local LPH_NO_VIRTUALIZE = function(f) return f end

    local originalRandom = math.random
    originalRandom = hookfunction(math.random, LPH_NO_VIRTUALIZE(function(...)
        local args = { ... }
        if checkcaller() then return originalRandom(...) end

        -- infinite range logic
        local isSpreadCall = false
        if #args == 0 then
            isSpreadCall = true
        elseif #args == 2 and type(args[1]) == "number" and type(args[2]) == "number" then
            local a, b = args[1], args[2]
            if (a == -0.1 and b == 0.05) or
            (a >= -0.15 and a <= -0.05 and b >= 0.03 and b <= 0.07) then
                isSpreadCall = true
            end
        elseif #args == 1 and type(args[1]) == "number" then
            local a = args[1]
            if a == -0.1 or a == -0.05 or (a >= -0.15 and a <= -0.03) then
                isSpreadCall = true
            end
        end

        if not isSpreadCall then return originalRandom(...) end

        local spreadMods = AzovV3 and AzovV3['Gun Spread Modifications']
        if not spreadMods or not spreadMods.Enabled then return originalRandom(...) end

        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local tool = character:FindFirstChildOfClass("Tool")
        local toolName = tool and tool.Name or ""
        toolName = toolName:gsub("%[", ""):gsub("%]", "")

        local weaponConfig = spreadMods[toolName]
        if not weaponConfig then return originalRandom(...) end

        local multiplier = 1
        if spreadMods.Mode == "Randomized" then
            local min = math.clamp(tonumber(weaponConfig.Min) or 0, 0, 1)
            local max = math.clamp(tonumber(weaponConfig.Max) or 1, 0, 1)
            if min > max then min, max = max, min end
            local rand = originalRandom()
            multiplier = min + (rand * (max - min))
        else
            multiplier = math.clamp(tonumber(weaponConfig.Fixed) or 1, 0, 1)
        end

        local originalValue = originalRandom(...)
        return originalValue * multiplier
    end))

    -- [[ inventory sorter ]]
    local function sortInventory()
        if not AzovV3['inventory sorter']['enabled'] then return end
        
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return end
        
        local slots = AzovV3['inventory sorter']['slots']
        if not slots or #slots == 0 then return end

        local tools = {}
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(tools, tool)
            end
        end

        if #tools == 0 then 
            return 
        end

        local ordered = {}

        local function takeTool(matchFn)
            for i, tool in ipairs(tools) do
                if matchFn(tool) then
                    table.insert(ordered, tool)
                    table.remove(tools, i)
                    return
                end
            end
        end

        for i = 1, #slots do
            local raw = slots[i]
            local slotName = raw and tostring(raw):lower() or ""
            if slotName ~= "" then
                takeTool(function(t) return t.Name:lower() == slotName end)
                takeTool(function(t) return t.Name:lower():find(slotName, 1, true) ~= nil end)
            end
        end

        for _, tool in ipairs(tools) do
            table.insert(ordered, tool)
        end

        local temp = Instance.new("Folder")
        for _, tool in ipairs(ordered) do
            tool.Parent = temp
        end
        for _, tool in ipairs(ordered) do
            tool.Parent = backpack
        end
        temp:Destroy()
    end

    -- trigger on spawn/death (characteradded)
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        -- wait for tools to load into backpack
        local backpack = LocalPlayer:WaitForChild("Backpack", 10)
        if backpack then
            -- wait until at least one tool exists or timeout
            local start = tick()
            while #backpack:GetChildren() == 0 and tick() - start < 5 do
                task.wait(0.5)
            end
            task.wait(1.5) -- extra buffer for tool initialization
            sortInventory()
        end
    end)

    -- initial run
    if LocalPlayer.Character then
        task.spawn(function()
            task.wait(1.5)
            sortInventory()
        end)
    end

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local cfg = AzovV3['inventory sorter']
        if not cfg or not cfg['enabled'] then return end
        local hotkey = cfg['key']
        if hotkey and checkInput(input, hotkey) then
            sortInventory()
        end
    end)

    local KnifeSkinData = {}

    local KnifeSkins = {
        ["Golden Age Tanto"] = {soundid = "rbxassetid://5917819099", animationid = "rbxassetid://13473404819", positionoffset = Vector3.new(0, -0.20, -1.2), rotationoffset = Vector3.new(90, 263.7, 180)},
        ["GPO-Knife"] = {soundid = "rbxassetid://4604390759", animationid = "rbxassetid://14014278925", positionoffset = Vector3.new(0.00, -0.32, -1.07), rotationoffset = Vector3.new(90, -97.4, 90)},
        ["GPO-Knife Prestige"] = {soundid = "rbxassetid://4604390759", animationid = "rbxassetid://14014278925", positionoffset = Vector3.new(0.00, -0.32, -1.07), rotationoffset = Vector3.new(90, -97.4, 90)},
        ["Heaven"] = {soundid = "rbxassetid://14489860007", animationid = "rbxassetid://14500266726", positionoffset = Vector3.new(-0.02, -0.82, 0.20), rotationoffset = Vector3.new(64.42, 3.79, 0.00)},
        ["Love Kukri"] = {soundid = "", animationid = "", positionoffset = Vector3.new(-0.14, 0.14, -1.62), rotationoffset = Vector3.new(-90.00, 180.00, -4.97), particle = true, textureid = "rbxassetid://12124159284"},
        ["Purple Dagger"] = {soundid = "rbxassetid://17822743153", animationid = "rbxassetid://17824999722", positionoffset = Vector3.new(-0.13, -0.24, -1.80), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
        ["Blue Dagger"] = {soundid = "rbxassetid://17822737046", animationid = "rbxassetid://17824995184", positionoffset = Vector3.new(-0.13, -0.24, -1.80), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
        ["Green Dagger"] = {soundid = "rbxassetid://17822741762", animationid = "rbxassetid://17825004320", positionoffset = Vector3.new(-0.13, -0.24, -1.07), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
        ["Red Dagger"] = {soundid = "rbxassetid://17822952417", animationid = "rbxassetid://17825008844", positionoffset = Vector3.new(-0.13, -0.24, -1.07), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
        ["Portal"] = {soundid = "rbxassetid://16058846352", animationid = "rbxassetid://16058633881", positionoffset = Vector3.new(-0.13, -0.35, -0.57), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
        ["Emerald Butterfly"] = {soundid = "rbxassetid://14931902491", animationid = "rbxassetid://14918231706", positionoffset = Vector3.new(-0.02, -0.30, -0.65), rotationoffset = Vector3.new(180.00, 90.95, 180.00)},
        ["Boy"] = {soundid = "rbxassetid://18765078331", animationid = "rbxassetid://18789158908", positionoffset = Vector3.new(-0.02, -0.09, -0.73), rotationoffset = Vector3.new(89.05, -88.11, 180.00)},
        ["Girl"] = {soundid = "rbxassetid://18765078331", animationid = "rbxassetid://18789162944", positionoffset = Vector3.new(-0.02, -0.16, -0.73), rotationoffset = Vector3.new(89.05, -88.11, 180.00)},
        ["Dragon"] = {soundid = "rbxassetid://14217789230", animationid = "rbxassetid://14217804400", positionoffset = Vector3.new(-0.02, -0.32, -0.98), rotationoffset = Vector3.new(89.05, 90.95, 180.00)},
        ["Void"] = {soundid = "rbxassetid://14756591763", animationid = "rbxassetid://14774699952", positionoffset = Vector3.new(-0.02, -0.22, -0.85), rotationoffset = Vector3.new(180.00, 90.95, 180.00)},
        ["Wild West"] = {soundid = "rbxassetid://16058689026", animationid = "rbxassetid://16058148839", positionoffset = Vector3.new(-0.02, -0.24, -1.15), rotationoffset = Vector3.new(-91.89, 90.95, 180.00)},
        ["Iced Out"] = {soundid = "rbxassetid://14924261405", animationid = "rbxassetid://18465353361", positionoffset = Vector3.new(0.02, -0.08, 0.99), rotationoffset = Vector3.new(180.00, -90.95, -180.00)},
        ["Reptile"] = {soundid = "rbxassetid://18765103349", animationid = "rbxassetid://18788955930", positionoffset = Vector3.new(-0.03, -0.06, -0.92), rotationoffset = Vector3.new(168.63, 90.00, -180.00)},
        ["Emerald"] = {soundid = "", animationid = "", positionoffset = Vector3.new(-0.03, -0.06, -0.92), rotationoffset = Vector3.new(168.63, 90.00, 108.00)},
        ["Ribbon"] = {soundid = "rbxassetid://130974579277249", animationid = "rbxassetid://124102609796063", positionoffset = Vector3.new(0.02, -0.25, -0.05), rotationoffset = Vector3.new(90.00, 0.00, 180.00)},
    }

    local function clearGunMesh(tool, exclude)
        local children = tool:GetChildren()
        for i = 1, #children do
            local v = children[i]
            if v:IsA("MeshPart") and v ~= exclude then
                v:Destroy()
            end
        end
    end

    local function applyGunSkin(tool, name)
        local orig = tool:FindFirstChildOfClass("MeshPart")
        if not orig then return end

        local skinmodules = ReplicatedStorage:FindFirstChild("SkinModules")
        if not skinmodules then return end

        local ok, skinmodulesreq = pcall(function()
            return require(skinmodules)
        end)
        if not ok or not skinmodulesreq then return end

        local info = skinmodulesreq[tool.Name] and skinmodulesreq[tool.Name][name]
        if not info then return end

        clearGunMesh(tool, orig)

        local skinpart = info.TextureID
        if typeof(skinpart) == "Instance" then
            local clone = skinpart:Clone()
            clone.Parent = tool
            clone.CFrame = orig.CFrame
            clone.Name = "CurrentSkin"

            local w = Instance.new("Weld")
            w.Part0 = clone
            w.Part1 = orig
            w.C0 = info.CFrame:Inverse()
            w.Parent = clone

            orig.Transparency = 1
        else
            orig.TextureID = skinpart
            orig.Transparency = 0
        end

        local handle = tool:FindFirstChild("Handle")
        if not handle then return end

        local shoot = handle:FindFirstChild("ShootSound")
        if shoot then
            local skinassets = ReplicatedStorage:FindFirstChild("SkinAssets")
            if skinassets then
                local gunsounds = skinassets:FindFirstChild("GunShootSounds")
                if gunsounds then
                    local sounds = gunsounds:FindFirstChild(tool.Name)
                    local obj = sounds and sounds:FindFirstChild(name)
                    if obj then
                        shoot.SoundId = obj.Value
                    end
                end
            end
        end

        local skinassets = ReplicatedStorage:FindFirstChild("SkinAssets")
        if skinassets then
            local particlefolder = skinassets:FindFirstChild("GunHandleParticle")
            if particlefolder then
                local particlesource = particlefolder:FindFirstChild(name)
                if particlesource then
                    local pe = particlesource:FindFirstChild("ParticleEmitter")
                    if pe then
                        for _, existing in ipairs(handle:GetChildren()) do
                            if existing:IsA("ParticleEmitter") then
                                existing:Destroy()
                            end
                        end
                        pe:Clone().Parent = handle
                    end
                end
            end
        end

        handle:SetAttribute("SkinName", name)
    end

    local function clearKnife(tool)
        local data = KnifeSkinData[tool]
        if data then
            if data.track then
                data.track:Stop()
                data.track:Destroy()
                data.track = nil
            end
            if data.welds then
                for _, w in ipairs(data.welds) do
                    if w then w:Destroy() end
                end
            end
            if data.sounds then
                for _, s in ipairs(data.sounds) do
                    if s and s.Parent then s:Destroy() end
                end
            end
        end

        local mesh = tool:FindFirstChild("Default")
        if mesh then
            local children = mesh:GetChildren()
            for i = 1, #children do
                local v = children[i]
                if v.Name == "Handle.R" or v:IsA("Model") or (v:IsA("BasePart") and v.Name ~= "Default") then
                    v:Destroy()
                end
            end
            mesh.Transparency = 0
        end

        KnifeSkinData[tool] = nil
    end

    local function applyKnifeSkin(char, tool, skin)
        local skinconfig = KnifeSkins[skin]
        if not skinconfig then return end

        local hum = char:FindFirstChild("Humanoid")
        local rhand = char:FindFirstChild("RightHand")
        if not hum or not rhand then return end

        clearKnife(tool)
        KnifeSkinData[tool] = {track = nil, welds = {}, sounds = {}}
        local data = KnifeSkinData[tool]

        local mesh = tool:FindFirstChild("Default")
        if not mesh then return end
        mesh.Transparency = 1

        local skinmodules = ReplicatedStorage:FindFirstChild("SkinModules")
        if not skinmodules then return end
        local knives = skinmodules:FindFirstChild("Knives")
        if not knives then return end

        local skinmodel = knives:FindFirstChild(skin)
        if not skinmodel then return end
        local clone = skinmodel:Clone()
        clone.Name = skin

        local handr = Instance.new("Part")
        handr.Name = "Handle.R"
        handr.Transparency = 1
        handr.CanCollide = false
        handr.Anchored = false
        handr.Size = Vector3.new(0.001, 0.001, 0.001)
        handr.Massless = true
        handr.Parent = mesh

        local m6d = Instance.new("Motor6D")
        m6d.Name = "Handle.R"
        m6d.Part0 = rhand
        m6d.Part1 = handr
        m6d.Parent = handr

        local offset = CFrame.new(skinconfig.positionoffset) * CFrame.Angles(math.rad(skinconfig.rotationoffset.X), math.rad(skinconfig.rotationoffset.Y), math.rad(skinconfig.rotationoffset.Z))

        if clone:IsA("Model") then
            if not clone.PrimaryPart then
                local children = clone:GetChildren()
                for i = 1, #children do
                    local c = children[i]
                    if c:IsA("BasePart") then
                        clone.PrimaryPart = c
                        break
                    end
                end
            end
            if clone.PrimaryPart then
                local descendants = clone:GetDescendants()
                for i = 1, #descendants do
                    local p = descendants[i]
                    if p:IsA("BasePart") then
                        p.CanCollide = false
                        p.Massless = true
                        p.Anchored = false
                        local w = Instance.new("Weld")
                        w.Part0 = handr
                        w.Part1 = p
                        w.C0 = offset
                        w.C1 = p.CFrame:ToObjectSpace(clone.PrimaryPart.CFrame)
                        w.Parent = p
                        table.insert(data.welds, w)
                    end
                end
            end
            clone.Parent = mesh
        elseif clone:IsA("BasePart") then
            clone.CanCollide = false
            clone.Massless = true
            clone.Anchored = false

            if clone:IsA("MeshPart") and skinconfig.textureid then
                clone.TextureID = skinconfig.textureid
            end

            if skinconfig.particle then
                local skinassets = ReplicatedStorage:FindFirstChild("SkinAssets")
                if skinassets then
                    local particlefolder = skinassets:FindFirstChild("GunHandleParticle")
                    if particlefolder then
                        local particlesource = particlefolder:FindFirstChild(skin)
                        if particlesource then
                            local pe = particlesource:FindFirstChild("ParticleEmitter")
                            if pe then
                                pe:Clone().Parent = clone
                            end
                        end
                    end
                end
            end

            clone.Parent = mesh
            local w = Instance.new("Weld")
            w.Part0 = handr
            w.Part1 = clone
            w.C0 = offset
            w.Parent = clone
            table.insert(data.welds, w)
        end

        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        if skinconfig.animationid and skinconfig.animationid ~= "" then
            local anim = Instance.new("Animation")
            anim.AnimationId = skinconfig.animationid
            local track = animator:LoadAnimation(anim)
            track.Looped = false
            track:Play()
            data.track = track
            anim:Destroy()
            track.Ended:Once(function()
                if data.track == track then
                    data.track = nil
                end
                track:Destroy()
            end)
        end
        if skinconfig.soundid and skinconfig.soundid ~= "" then
            local snd = Instance.new("Sound")
            snd.SoundId = skinconfig.soundid
            snd.Parent = workspace
            snd:Play()
            table.insert(data.sounds, snd)
            snd.Ended:Connect(function()
                snd:Destroy()
            end)
        end

        tool:SetAttribute("CurrentKnifeSkin", skin)
    end

    local RegisteredSkinTools = {}

    local function setupSkinTool(tool)
        if not tool:IsA("Tool") then return end
        if RegisteredSkinTools[tool] then return end
        RegisteredSkinTools[tool] = true

        tool.Equipped:Connect(function()
            local skinCfg = AzovV3['Skins']
            if not skinCfg or not skinCfg['Enabled'] then return end

            local char = tool.Parent
            if char ~= LocalPlayer.Character then return end

            local skin = skinCfg['Options'][tool.Name]
            if not skin or skin == "" then return end

            if tool.Name == "[Knife]" then
                applyKnifeSkin(char, tool, skin)
            else
                applyGunSkin(tool, skin)
            end
        end)

        tool.Unequipped:Connect(function()
            if tool.Name == "[Knife]" then
                local data = KnifeSkinData[tool]
                if not data then return end
                if data.welds then
                    for _, w in ipairs(data.welds) do
                        if w then w:Destroy() end
                    end
                    data.welds = {}
                end
                if data.sounds then
                    for _, s in ipairs(data.sounds) do
                        if s and s.Parent then s:Destroy() end
                    end
                    data.sounds = {}
                end
                local mesh = tool:FindFirstChild("Default")
                if mesh then
                    local children = mesh:GetChildren()
                    for i = 1, #children do
                        local v = children[i]
                        if v.Name == "Handle.R" or v:IsA("Model") or (v:IsA("MeshPart") and v.Name ~= "Default") then
                            v:Destroy()
                        end
                    end
                    mesh.Transparency = 0
                end
            end
        end)

        if tool.Parent == LocalPlayer.Character then
            local skinCfg = AzovV3['Skins']
            if not skinCfg or not skinCfg['Enabled'] then return end

            local skin = skinCfg['Options'][tool.Name]
            if skin and skin ~= "" then
                if tool.Name == "[Knife]" then
                    task.spawn(function()
                        applyKnifeSkin(LocalPlayer.Character, tool, skin)
                    end)
                else
                    task.spawn(function()
                        applyGunSkin(tool, skin)
                    end)
                end
            end
        end
    end

    local function watchSkinChar(char)
        if not char then return end
        local children = char:GetChildren()
        for i = 1, #children do
            local v = children[i]
            if v:IsA("Tool") then
                setupSkinTool(v)
            end
        end
        char.ChildAdded:Connect(function(v)
            if v:IsA("Tool") then
                setupSkinTool(v)
            end
        end)
    end

    if LocalPlayer.Character then
        watchSkinChar(LocalPlayer.Character)
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        watchSkinChar(char)
    end)

    local backpacktools = LocalPlayer.Backpack:GetChildren()
    for i = 1, #backpacktools do
        local v = backpacktools[i]
        if v:IsA("Tool") then
            setupSkinTool(v)
        end
    end

    LocalPlayer.Backpack.ChildAdded:Connect(function(v)
        if v:IsA("Tool") then
            setupSkinTool(v)
        end
    end)


local key_system = {}

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
