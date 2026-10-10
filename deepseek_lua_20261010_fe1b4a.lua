-- ═══════════════════════════════════════════
--   ENI BabFT Suite v6.1  |  Delta / Mobile
--   для LO. всё своё, всё родное.
-- ═══════════════════════════════════════════
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

-- ── КООРДИНАТЫ ──
local Walls = {
    Vector3.new(-48, 56, 1369),
    Vector3.new(-65, 46, 2139),
    Vector3.new(-19, 76, 2908),
    Vector3.new(-63, 41, 3682),
    Vector3.new(-53, 46, 4451),
    Vector3.new(-45, 47, 5220),
    Vector3.new(-46, 52, 5989),
    Vector3.new(-50, 49, 6762),
    Vector3.new(-62, 40, 7528),
    Vector3.new(-60, 56, 8302),
}
local Start = Vector3.new(-40, 57, -190)
local Chest = Vector3.new(-55, -349, 9503)
local CHEST_OFFSET_Y = -2

-- ── СОСТОЯНИЕ ──
local state = {
    farm = false, flyFarm = false, antiafk = false,
    speed = 1.0, flySpeed = 800, flyPause = 0.4,
    gold = 0, status = "ожидание",
    buildSpeed = 0.1,
    flyV3 = false, noClip = false, antiVoid = false,
}
local SPEED_STEPS = {1.0, 1.2, 1.4, 1.6, 1.8}
local FLY_SPEED_STEPS = {200, 400, 800, 1600}
local FLY_PAUSE_STEPS = {0.2, 0.3, 0.4, 0.5}
local BUILD_SPEED_STEPS = {0.05, 0.1, 0.2, 0.4}
local respawning = false
local currentWallIndex = 0

-- ═══ ХЕЛПЕРЫ АВТО-ФАРМА ═══
local platform = nil
local function spawnPlatform(pos)
    if platform then platform:Destroy() end
    platform = Instance.new("Part")
    platform.Size = Vector3.new(8, 1, 8)
    platform.Position = pos - Vector3.new(0, 3, 0)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 0.6
    platform.Color = Color3.fromRGB(120, 180, 255)
    platform.Material = Enum.Material.Neon
    platform.Name = "ENI_Platform"
    platform.Parent = workspace
end

local function tp(pos, withPlatform)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if withPlatform ~= false then spawnPlatform(pos) end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero
end

local function flyTo(target, speed)
    local t0 = tick()
    while true do
        if not state.farm or respawning then return false end
        local char = lp.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local cur = hrp.Position
        local diff = target - cur
        local dist = diff.Magnitude
        if dist < 3 then return true end
        local step = math.min(speed * 0.03, dist)
        hrp.CFrame = CFrame.new(cur + diff.Unit * step)
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.03)
        if tick() - t0 > 25 then return false end
    end
end

local function backJump(current, previous)
    if not state.farm or respawning then return end
    local mid = (current + previous) / 2
    for _ = 1, 2 do
        if not state.farm or respawning then return end
        tp(mid, false)
        task.wait(0.1)
        tp(current, false)
        task.wait(0.1)
    end
end

local function clickButton(btn)
    if not btn then return false end
    pcall(function()
        if firesignal and btn.Activated then firesignal(btn.Activated)
        elseif btn.Activate then btn:Activate()
        else btn.MouseButton1Click:Fire() end
    end)
    return true
end

local function checkAndClick(obj)
    if not state.farm then return end
    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
        local t = obj.Text or ""
        if t:find("Получить") or t:find("Claim") or t:find("Collect") then
            clickButton(obj)
        end
    end
end

local function hookRoot(root)
    if not root then return end
    for _, obj in ipairs(root:GetDescendants()) do checkAndClick(obj) end
    root.DescendantAdded:Connect(function(obj)
        task.wait(0.02)
        checkAndClick(obj)
    end)
end

hookRoot(lp:FindFirstChild("PlayerGui"))
lp.ChildAdded:Connect(function(child)
    if child.Name == "PlayerGui" then task.wait(0.5); hookRoot(child) end
end)
pcall(function() hookRoot(CoreGui) end)

local function openChest()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local mag = (obj.Position - Chest).Magnitude
            if mag < 20 and (obj.Name:lower():find("chest") or obj.Name:lower():find("reward")) then
                for _ = 1, 3 do
                    firetouchinterest(hrp, obj, 0)
                    task.wait(0.03)
                    firetouchinterest(hrp, obj, 1)
                    task.wait(0.05)
                end
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local mag = (obj.Position - Chest).Magnitude
            if mag < 15 then
                firetouchinterest(hrp, obj, 0)
                task.wait(0.02)
                firetouchinterest(hrp, obj, 1)
            end
        end
    end
end

local function watchHumanoid(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    hum.Died:Connect(function()
        if respawning then return end
        respawning = true
        if state.farm then state.gold += 1; state.status = "получаю золото" end
        task.spawn(function()
            task.wait(0.05)
            pcall(function() lp:LoadCharacter() end)
        end)
    end)
end

lp.CharacterAdded:Connect(function(char)
    watchHumanoid(char)
    if respawning then
        task.spawn(function()
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then
                local t0 = tick()
                while hum.Health <= 0 and tick() - t0 < 3 do task.wait(0.05) end
            end
            respawning = false
            if state.farm and hrp then state.status = "респавн"; tp(Start) end
        end)
    end
end)

if lp.Character then watchHumanoid(lp.Character) end

-- ═══ ЦИКЛ АВТО-ФАРМА ═══
task.spawn(function()
    while task.wait(0.05) do
        if not state.farm then continue end
        if respawning then continue end
        local char = lp.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        state.status = "ТП на старт"
        currentWallIndex = 0
        tp(Start)
        task.wait(state.speed)

        for i, w in ipairs(Walls) do
            if not state.farm or respawning then break end
            currentWallIndex = i
            local prev = (i > 1) and Walls[i-1] or Start
            if state.flyFarm then
                state.status = string.format("полёт %d/%d", i, #Walls)
                if not flyTo(w, state.flySpeed) then break end
                task.wait(state.flyPause)
            else
                state.status = string.format("стена %d/%d", i, #Walls)
                tp(w)
                task.wait(state.speed)
            end
            if math.random() < 0.6 and state.farm and not respawning then
                state.status = string.format("зона %d", i)
                backJump(w, prev)
            end
        end

        if state.farm and not respawning then
            state.status = "сундук"
            local char2 = lp.Character
            if char2 and char2:FindFirstChild("HumanoidRootPart") then
                local hrp = char2.HumanoidRootPart
                if state.flyFarm then flyTo(Chest + Vector3.new(0, 20, 0), state.flySpeed) end
                hrp.CFrame = CFrame.new(Chest + Vector3.new(0, CHEST_OFFSET_Y, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            task.wait(0.2)
            openChest()
            state.status = "жду золото"
            local t0 = tick()
            while not respawning and tick() - t0 < 4 do task.wait(0.05) end
            if not respawning then state.status = "повтор"; task.wait(0.15) end
        end
    end
end)

lp.Idled:Connect(function()
    if not state.antiafk then return end
    local vu = game:GetService("VirtualUser")
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end)

-- ═══ FLY V3 + NOCLIP + ANTIVOID ═══
local flyBV = nil
local flyBG = nil

local function startFlyV3()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    flyBV = Instance.new("BodyVelocity", hrp)
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBG = Instance.new("BodyGyro", hrp)
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 1000
    flyBG.D = 50
    flyBG.CFrame = hrp.CFrame
end

local function stopFlyV3()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

RunService.Heartbeat:Connect(function()
    if not state.flyV3 then return end
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    if not flyBV then startFlyV3() end
    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
    flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * 120 or Vector3.zero
end)

local noclipConn = RunService.Stepped:Connect(function()
    if not state.noClip then return end
    local char = lp.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanCollide then
            local nm = obj.Name:lower()
            if nm:find("barrier") or nm:find("wall") or nm:find("gate") or nm:find("isolat") then
                obj.CanCollide = false
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.3) do
        if not state.antiVoid then continue end
        local char = lp.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < -500 then
            hrp.CFrame = CFrame.new(Start)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end
end)

-- ═══ СТРОИТЕЛЬСТВО ═══
local function newPart(size, pos, shape)
    local p = Instance.new("Part")
    p.Size = size
    p.Position = pos
    p.Anchored = true
    p.CanCollide = true
    p.Color = Color3.fromRGB(180, 180, 200)
    p.Material = Enum.Material.SmoothPlastic
    if shape == "Ball" then p.Shape = Enum.PartType.Ball
    elseif shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
    p.Name = "ENI_Build"
    p.Parent = workspace
    return p
end

local function getFrontPos(offset)
    local char = lp.Character
    if not char then return Vector3.zero end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end
    local look = hrp.CFrame.LookVector
    return hrp.Position + look * offset + Vector3.new(0, 5, 0)
end

local function buildBall()
    task.spawn(function()
        local base = getFrontPos(12)
        for i = 1, 24 do
            local ang = (i / 24) * math.pi * 2
            newPart(Vector3.new(2,2,2), base + Vector3.new(math.cos(ang)*4, 0, math.sin(ang)*4), "Ball")
            task.wait(state.buildSpeed)
        end
        for i = 1, 12 do
            local ang = (i / 12) * math.pi * 2
            newPart(Vector3.new(2,2,2), base + Vector3.new(math.cos(ang)*2, 4, math.sin(ang)*2), "Ball")
            task.wait(state.buildSpeed)
        end
        newPart(Vector3.new(2,2,2), base + Vector3.new(0, 6, 0), "Ball")
    end)
end

local function buildDome()
    task.spawn(function()
        local base = getFrontPos(12)
        for ring = 1, 4 do
            local r = 5 - ring
            local y = ring * 1.5
            local count = math.max(4, math.floor(r * 4))
            for i = 1, count do
                local ang = (i / count) * math.pi * 2
                newPart(Vector3.new(2,1,2), base + Vector3.new(math.cos(ang)*r, y, math.sin(ang)*r))
                task.wait(state.buildSpeed)
            end
        end
    end)
end

local function buildCube()
    task.spawn(function()
        local base = getFrontPos(12)
        for x = -2, 2, 2 do
            for y = 0, 6, 2 do
                for z = -2, 2, 2 do
                    newPart(Vector3.new(2,2,2), base + Vector3.new(x, y, z))
                    task.wait(state.buildSpeed)
                end
            end
        end
    end)
end

local function buildPyramid()
    task.spawn(function()
        local base = getFrontPos(12)
        local layers = 5
        for l = 0, layers - 1 do
            local size = layers - l
            for x = 0, size - 1 do
                for z = 0, size - 1 do
                    newPart(Vector3.new(2,2,2), base + Vector3.new((x - size/2)*2, l*2, (z - size/2)*2))
                    task.wait(state.buildSpeed)
                end
            end
        end
    end)
end

local function buildCylinder()
    task.spawn(function()
        local base = getFrontPos(12)
        for h = 0, 4 do
            for i = 1, 12 do
                local ang = (i / 12) * math.pi * 2
                newPart(Vector3.new(1,2,1), base + Vector3.new(math.cos(ang)*4, h*2, math.sin(ang)*4))
                task.wait(state.buildSpeed)
            end
        end
    end)
end

local selectingDup = false
local dupHighlight = nil

local function highlightPart(p)
    if dupHighlight then dupHighlight:Destroy() end
    dupHighlight = Instance.new("SelectionBox", workspace)
    dupHighlight.Adornee = p
    dupHighlight.Color3 = Color3.fromRGB(255, 140, 210)
    dupHighlight.LineThickness = 0.1
    dupHighlight.Transparency = 0.3
end

local function pickPartByScreen(touchPos)
    local cam = workspace.CurrentCamera
    local ray = cam:ViewportPointToRay(touchPos.X, touchPos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {lp.Character}
    local res = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    return res and res.Instance or nil
end

local function startDupMode()
    selectingDup = true
    state.status = "дюп: тапни предмет"
    local conn
    conn = UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not selectingDup then conn:Disconnect(); return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local hit = pickPartByScreen(input.Position)
        if hit and hit:IsA("BasePart") then
            local clone = hit:Clone()
            clone.Anchored = true
            clone.CFrame = hit.CFrame + hit.CFrame.RightVector * 4
            clone.Name = "ENI_Dup"
            clone.Parent = workspace
            highlightPart(hit)
            print("[ENI] дюпнул:", hit.Name)
        end
        selectingDup = false
        state.status = "дюп готов"
        conn:Disconnect()
    end)
end

local function scanBlueprints()
    local found = {}
    local roots = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ServerStorage"),
        game:GetService("Workspace"),
    }
    for _, root in ipairs(roots) do
        pcall(function()
            for _, obj in ipairs(root:GetChildren()) do
                if obj:IsA("Model") or obj:IsA("Folder") then
                    local hasPart = obj:FindFirstChildWhichIsA("BasePart", true)
                    if hasPart then table.insert(found, obj) end
                end
            end
        end)
    end
    return found
end

-- ═══════════════════════════════════════════
--   UI v6.1
-- ═══════════════════════════════════════════
local NEON = {
    cyan = Color3.fromRGB(100, 220, 255),
    purple = Color3.fromRGB(170, 120, 255),
    green = Color3.fromRGB(110, 240, 160),
    gold = Color3.fromRGB(255, 215, 110),
    pink = Color3.fromRGB(255, 140, 210),
    red = Color3.fromRGB(255, 110, 130),
    gray = Color3.fromRGB(140, 140, 165),
}

local gui = Instance.new("ScreenGui")
gui.Name = "ENI_Suite"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

local fxLayer = Instance.new("Frame", gui)
fxLayer.Size = UDim2.new(1, 0, 1, 0)
fxLayer.BackgroundTransparency = 1
fxLayer.ZIndex = 200
fxLayer.ClipsDescendants = false

local function spawnSpark(x, y, color)
    for i = 1, 8 do
        local p = Instance.new("Frame", fxLayer)
        p.Size = UDim2.new(0, 5, 0, 5)
        p.Position = UDim2.new(0, x, 0, y)
        p.BackgroundColor3 = color
        p.BorderSizePixel = 0
        p.ZIndex = 201
        Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
        local ang = math.random() * math.pi * 2
        local dist = 30 + math.random() * 60
        TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {
            Position = UDim2.new(0, x + math.cos(ang) * dist, 0, y + math.sin(ang) * dist),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 1, 0, 1),
        }):Play()
        task.delay(0.65, function() p:Destroy() end)
    end
end

local floatBtn = Instance.new("TextButton", gui)
floatBtn.Size = UDim2.new(0, 170, 0, 34)
floatBtn.Position = UDim2.new(0.5, -85, 0, 8)
floatBtn.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
floatBtn.BackgroundTransparency = 0.3
floatBtn.Text = ""
floatBtn.BorderSizePixel = 0
floatBtn.Visible = false
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
local fbStroke = Instance.new("UIStroke", floatBtn)
fbStroke.Thickness = 1.5
fbStroke.Color = NEON.purple
fbStroke.Transparency = 0.3

local fbLbl = Instance.new("TextLabel", floatBtn)
fbLbl.Size = UDim2.new(1, -20, 1, 0)
fbLbl.Position = UDim2.new(0, 10, 0, 0)
fbLbl.BackgroundTransparency = 1
fbLbl.Text = "ENI • Suite"
fbLbl.TextColor3 = Color3.fromRGB(220, 230, 255)
fbLbl.Font = Enum.Font.GothamBold
fbLbl.TextSize = 13

task.spawn(function()
    while task.wait(0.05) do
        if not gui.Parent then break end
        local t = tick() * 1.5
        fbStroke.Transparency = 0.35 + 0.25 * math.sin(t)
    end
end)

-- main — стартовый размер 620x360, чтоб всё влезало
local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 620, 0, 360)
main.Position = UDim2.new(0.5, -310, 0.5, -180)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
main.BackgroundTransparency = 0.2
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 22)

local mainGrad = Instance.new("UIGradient", main)
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 18, 34)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 12, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 16, 30)),
})
mainGrad.Rotation = 135

local outerGlow = Instance.new("UIStroke", main)
outerGlow.Thickness = 1.5
outerGlow.Color = NEON.purple
outerGlow.Transparency = 0.4

-- фоновые звёзды
task.spawn(function()
    while gui.Parent do
        task.wait(0.6)
        if not main.Visible then continue end
        local star = Instance.new("Frame", main)
        star.Size = UDim2.new(0, 2, 0, 2)
        star.Position = UDim2.new(math.random(), 0, math.random(), 0)
        star.BackgroundColor3 = math.random() < 0.5 and NEON.cyan or NEON.purple
        star.BackgroundTransparency = 0.4
        star.BorderSizePixel = 0
        star.ZIndex = 1
        Instance.new("UICorner", star).CornerRadius = UDim.new(1, 0)
        TweenService:Create(star, TweenInfo.new(3, Enum.EasingStyle.Linear), {
            Position = UDim2.new(star.Position.X.Scale, 0, star.Position.Y.Scale - 0.15, 0),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(3.1, function() star:Destroy() end)
    end
end)

-- resize
local resizeGrip = Instance.new("TextButton", main)
resizeGrip.Size = UDim2.new(0, 26, 0, 26)
resizeGrip.Position = UDim2.new(1, -26, 1, -26)
resizeGrip.BackgroundTransparency = 1
resizeGrip.Text = "◢"
resizeGrip.TextColor3 = NEON.cyan
resizeGrip.TextSize = 20
resizeGrip.Font = Enum.Font.GothamBold
resizeGrip.ZIndex = 60

local resizing = false
local resizeStart, resizeOrigin
resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true; resizeStart = input.Position; resizeOrigin = main.AbsoluteSize
    end
end)
UIS.InputChanged:Connect(function(input)
    if not resizing then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local dx = input.Position.X - resizeStart.X
    local dy = input.Position.Y - resizeStart.Y
    main.Size = UDim2.new(0, math.clamp(resizeOrigin.X + dx, 460, 1100), 0, math.clamp(resizeOrigin.Y + dy, 260, 700))
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
    end
end)

-- header
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
header.BackgroundTransparency = 0.15
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 22)

local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0, 18)
headerFix.Position = UDim2.new(0, 0, 1, -18)
headerFix.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
headerFix.BackgroundTransparency = 0.15
headerFix.BorderSizePixel = 0

local hLine = Instance.new("Frame", header)
hLine.Size = UDim2.new(1, -32, 0, 1)
hLine.Position = UDim2.new(0, 16, 1, -1)
hLine.BackgroundColor3 = NEON.cyan
hLine.BackgroundTransparency = 0.7
hLine.BorderSizePixel = 0

local htitle = Instance.new("TextLabel", header)
htitle.Size = UDim2.new(0.6, 0, 1, 0)
htitle.Position = UDim2.new(0, 18, 0, 0)
htitle.BackgroundTransparency = 1
htitle.Text = "ENI • Suite  v6.1"
htitle.TextColor3 = Color3.fromRGB(240, 240, 255)
htitle.Font = Enum.Font.GothamBold
htitle.TextSize = 15
htitle.TextXAlignment = Enum.TextXAlignment.Left

-- мини-статус в хедере
local headerStats = Instance.new("TextLabel", header)
headerStats.Size = UDim2.new(0, 260, 1, 0)
headerStats.Position = UDim2.new(1, -340, 0, 0)
headerStats.BackgroundTransparency = 1
headerStats.Text = "● ожидание   |   круг: 0"
headerStats.TextColor3 = NEON.cyan
headerStats.Font = Enum.Font.Gotham
headerStats.TextSize = 11
headerStats.TextXAlignment = Enum.TextXAlignment.Right

local gearBtn = Instance.new("TextButton", header)
gearBtn.Size = UDim2.new(0, 28, 0, 28)
gearBtn.Position = UDim2.new(1, -66, 0.5, -14)
gearBtn.BackgroundColor3 = Color3.fromRGB(30, 26, 44)
gearBtn.Text = "⚙"
gearBtn.TextColor3 = NEON.cyan
gearBtn.Font = Enum.Font.GothamBold
gearBtn.TextSize = 14
gearBtn.BorderSizePixel = 0
Instance.new("UICorner", gearBtn).CornerRadius = UDim.new(0, 9)

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -34, 0.5, -14)
minBtn.BackgroundColor3 = Color3.fromRGB(30, 26, 44)
minBtn.Text = "—"
minBtn.TextColor3 = NEON.pink
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.BorderSizePixel = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 9)

-- tabs col
local tabsCol = Instance.new("Frame", main)
tabsCol.Size = UDim2.new(0, 108, 1, -110)
tabsCol.Position = UDim2.new(0, 10, 0, 52)
tabsCol.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
tabsCol.BackgroundTransparency = 0.2
tabsCol.BorderSizePixel = 0
Instance.new("UICorner", tabsCol).CornerRadius = UDim.new(0, 14)

local tabsLayout = Instance.new("UIListLayout", tabsCol)
tabsLayout.Padding = UDim.new(0, 5)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local tabData = {
    {name = "💰 Авто"},
    {name = "🏗 Билд"},
    {name = "⚡ Хакер"},
}
local tabBtns = {}
local contents = {}

local contentHolder = Instance.new("Frame", main)
contentHolder.Size = UDim2.new(1, -134, 1, -110)
contentHolder.Position = UDim2.new(0, 128, 0, 52)
contentHolder.BackgroundTransparency = 1
contentHolder.ClipsDescendants = true

local function makeTabBtn(i, name)
    local b = Instance.new("TextButton", tabsCol)
    b.Size = UDim2.new(1, -10, 0, 36)
    b.LayoutOrder = i
    b.BackgroundColor3 = i == 1 and Color3.fromRGB(40, 32, 65) or Color3.fromRGB(24, 20, 36)
    b.Text = name
    b.TextColor3 = i == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 190)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    local st = Instance.new("UIStroke", b)
    st.Thickness = 1
    st.Color = i == 1 and NEON.cyan or Color3.fromRGB(55, 45, 75)
    st.Transparency = i == 1 and 0.3 or 0.6

    b.MouseButton1Click:Connect(function()
        spawnSpark(b.AbsolutePosition.X + b.AbsoluteSize.X / 2, b.AbsolutePosition.Y + b.AbsoluteSize.Y / 2, NEON.cyan)
        for j, btn in ipairs(tabBtns) do
            local act = (j == i)
            btn.BackgroundColor3 = act and Color3.fromRGB(40, 32, 65) or Color3.fromRGB(24, 20, 36)
            btn.TextColor3 = act and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 190)
            TweenService:Create(btn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {
                Color = act and NEON.cyan or Color3.fromRGB(55, 45, 75),
                Transparency = act and 0.3 or 0.6,
            }):Play()
        end
        for j, c in ipairs(contents) do
            c.Visible = (j == i)
        end
    end)
    table.insert(tabBtns, b)
end

for i, d in ipairs(tabData) do makeTabBtn(i, d.name) end

local function makeContent()
    local c = Instance.new("ScrollingFrame", contentHolder)
    c.Size = UDim2.new(1, -6, 1, -6)
    c.Position = UDim2.new(0, 3, 0, 3)
    c.BackgroundTransparency = 1
    c.BorderSizePixel = 0
    c.ScrollBarThickness = 3
    c.ScrollBarImageColor3 = NEON.cyan
    c.ScrollBarImageTransparency = 0.4
    c.CanvasSize = UDim2.new(0, 0, 0, 0)
    c.AutomaticCanvasSize = Enum.AutomaticSize.Y
    c.Visible = false
    local l = Instance.new("UIListLayout", c)
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    table.insert(contents, c)
    return c
end

local content1 = makeContent(); content1.Visible = true
local content2 = makeContent()
local content3 = makeContent()

-- ═══ КОМПОНЕНТЫ ═══
local toggleRefs = {}

local function makeToggle(parent, label, sublabel, callback, onColor, width)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0, width or 168, 0, 50)
    btn.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", btn)
    st.Thickness = 1
    st.Color = Color3.fromRGB(55, 45, 75)
    st.Transparency = 0.4

    local nameLbl = Instance.new("TextLabel", btn)
    nameLbl.Size = UDim2.new(1, -80, 0, 20)
    nameLbl.Position = UDim2.new(0, 12, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    if sublabel then
        local subLbl = Instance.new("TextLabel", btn)
        subLbl.Size = UDim2.new(1, -80, 0, 14)
        subLbl.Position = UDim2.new(0, 12, 0, 28)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = sublabel
        subLbl.TextColor3 = NEON.gray
        subLbl.Font = Enum.Font.Gotham
        subLbl.TextSize = 10
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
    end

    local badge = Instance.new("TextLabel", btn)
    badge.Size = UDim2.new(0, 28, 0, 14)
    badge.Position = UDim2.new(1, -62, 0, 4)
    badge.BackgroundTransparency = 1
    badge.Text = "OFF"
    badge.TextColor3 = NEON.gray
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 9

    local pill = Instance.new("Frame", btn)
    pill.Size = UDim2.new(0, 48, 0, 24)
    pill.Position = UDim2.new(1, -60, 0.5, -12)
    pill.BackgroundColor3 = Color3.fromRGB(42, 36, 58)
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    local pillStroke = Instance.new("UIStroke", pill)
    pillStroke.Thickness = 1
    pillStroke.Color = Color3.fromRGB(65, 55, 85)
    pillStroke.Transparency = 0.4

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(170, 170, 190)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local on = false
    local function set(val)
        on = val
        local c = onColor or NEON.green
        TweenService:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
            Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
            BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 190),
        }):Play()
        TweenService:Create(pill, TweenInfo.new(0.2), {BackgroundColor3 = on and c or Color3.fromRGB(42, 36, 58)}):Play()
        TweenService:Create(pillStroke, TweenInfo.new(0.2), {Color = c, Transparency = on and 0.2 or 0.4}):Play()
        st.Color = on and c or Color3.fromRGB(55, 45, 75)
        st.Transparency = on and 0.3 or 0.4
        badge.Text = on and "ON" or "OFF"
        badge.TextColor3 = on and c or NEON.gray
        callback(on)
    end
    btn.MouseButton1Click:Connect(function()
        spawnSpark(btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2, onColor or NEON.green)
        set(not on)
    end)
    table.insert(toggleRefs, {set = set})
    return btn
end

local function makeSlider(parent, title, steps, initialIdx, color, formatter, onChange, width)
    local box = Instance.new("Frame", parent)
    box.Size = UDim2.new(0, width or 220, 0, 74)
    box.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
    box.BorderSizePixel = 0
    box.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)
    local slStroke = Instance.new("UIStroke", box)
    slStroke.Thickness = 1
    slStroke.Color = Color3.fromRGB(55, 45, 75)
    slStroke.Transparency = 0.4

    local titleLbl = Instance.new("TextLabel", box)
    titleLbl.Size = UDim2.new(1, -20, 0, 22)
    titleLbl.Position = UDim2.new(0, 10, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = formatter(steps[initialIdx])
    titleLbl.TextColor3 = color
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", box)
    track.Size = UDim2.new(1, -36, 0, 2)
    track.Position = UDim2.new(0, 18, 0, 52)
    track.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
    track.BorderSizePixel = 0

    local trackFill = Instance.new("Frame", track)
    trackFill.Size = UDim2.new((initialIdx-1)/(#steps-1), 0, 1, 0)
    trackFill.BackgroundColor3 = color
    trackFill.BorderSizePixel = 0

    local nodeBtns = {}
    local N = #steps
    for i, v in ipairs(steps) do
        local active = i == initialIdx
        local sz = active and 18 or 14
        local node = Instance.new("TextButton", box)
        node.Size = UDim2.new(0, sz, 0, sz)
        node.Position = UDim2.new((i-1)/(N-1), -sz/2, 0, 53 - sz/2)
        node.BackgroundColor3 = active and color or Color3.fromRGB(32, 26, 48)
        node.Text = ""
        node.BorderSizePixel = 0
        Instance.new("UICorner", node).CornerRadius = UDim.new(1, 0)
        local nodeStroke = Instance.new("UIStroke", node)
        nodeStroke.Thickness = 2
        nodeStroke.Color = active and color or Color3.fromRGB(65, 55, 85)
        nodeStroke.Transparency = active and 0.2 or 0.5

        nodeBtns[i] = node
        node.MouseButton1Click:Connect(function()
            spawnSpark(node.AbsolutePosition.X + node.AbsoluteSize.X / 2, node.AbsolutePosition.Y + node.AbsoluteSize.Y / 2, color)
            titleLbl.Text = formatter(v)
            TweenService:Create(trackFill, TweenInfo.new(0.25), {Size = UDim2.new((i-1)/(N-1), 0, 1, 0)}):Play()
            for j = 1, N do
                local act = j == i
                local s = act and 18 or 14
                TweenService:Create(nodeBtns[j], TweenInfo.new(0.2), {
                    BackgroundColor3 = act and color or Color3.fromRGB(32, 26, 48),
                    Size = UDim2.new(0, s, 0, s),
                    Position = UDim2.new((j-1)/(N-1), -s/2, 0, 53 - s/2),
                }):Play()
            end
            onChange(v)
        end)
    end
    return box
end

local function makeRow(parent, order)
    local r = Instance.new("Frame", parent)
    r.Size = UDim2.new(1, -4, 0, 0)
    r.AutomaticSize = Enum.AutomaticSize.Y
    r.BackgroundTransparency = 1
    r.LayoutOrder = order
    local l = Instance.new("UIListLayout", r)
    l.FillDirection = Enum.FillDirection.Horizontal
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    return r
end

-- ═══ ВКЛАДКА АВТО ═══
local r1 = makeRow(content1, 1)
makeToggle(r1, "💰 TP-Фарм", "телепорт по зонам", function(v) state.farm = v end, NEON.green)
makeToggle(r1, "🚀 Флай-Фарм", "плавный полёт", function(v) state.flyFarm = v; if v then state.farm = true end end, NEON.pink)
makeToggle(r1, "🛡 Анти-АФК", "не кикает", function(v) state.antiafk = v end, NEON.cyan)

local r2 = makeRow(content1, 2)
makeSlider(r2, "ЗАДЕРЖКА ТП", SPEED_STEPS, 1, NEON.cyan,
    function(v) return string.format("⏱ ЗАДЕРЖКА  %.1f сек", v) end,
    function(v) state.speed = v end, 210)
makeSlider(r2, "ПОЛЁТ", FLY_SPEED_STEPS, 3, NEON.pink,
    function(v) return string.format("🚀 ПОЛЁТ  %d ст/с", v) end,
    function(v) state.flySpeed = v end, 210)

local r3 = makeRow(content1, 3)
makeSlider(r3, "ПАУЗА", FLY_PAUSE_STEPS, 3, NEON.gold,
    function(v) return string.format("⏸ ПАУЗА  %.1f сек", v) end,
    function(v) state.flyPause = v end, 210)

local statusBox = Instance.new("Frame", r3)
statusBox.Size = UDim2.new(0, 210, 0, 74)
statusBox.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
statusBox.BorderSizePixel = 0
statusBox.LayoutOrder = 3
Instance.new("UICorner", statusBox).CornerRadius = UDim.new(0, 14)
local stb = Instance.new("UIStroke", statusBox)
stb.Thickness = 1
stb.Color = NEON.purple
stb.Transparency = 0.5

local statusLbl = Instance.new("TextLabel", statusBox)
statusLbl.Size = UDim2.new(1, -20, 0, 22)
statusLbl.Position = UDim2.new(0, 12, 0, 10)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "статус: ожидание"
statusLbl.TextColor3 = NEON.cyan
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local goldLbl = Instance.new("TextLabel", statusBox)
goldLbl.Size = UDim2.new(1, -20, 0, 26)
goldLbl.Position = UDim2.new(0, 12, 0, 36)
goldLbl.BackgroundTransparency = 1
goldLbl.Text = "кругов: 0"
goldLbl.TextColor3 = NEON.gold
goldLbl.Font = Enum.Font.GothamBold
goldLbl.TextSize = 15
goldLbl.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while task.wait(0.2) do
        if not gui.Parent then break end
        statusLbl.Text = "статус: " .. state.status
        goldLbl.Text = "кругов: " .. state.gold
        headerStats.Text = string.format("● %s   |   круг: %d", state.status, state.gold)
    end
end)

-- ═══ ВКЛАДКА БИЛД ═══
local shapesRow = makeRow(content2, 1)

local function makeAction(parent, label, sublabel, color, onClick, width)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0, width or 140, 0, 54)
    btn.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", btn)
    st.Thickness = 1
    st.Color = color
    st.Transparency = 0.5

    local nameLbl = Instance.new("TextLabel", btn)
    nameLbl.Size = UDim2.new(1, -14, 0, 20)
    nameLbl.Position = UDim2.new(0, 10, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = Color3.fromRGB(230, 230, 245)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local subLbl = Instance.new("TextLabel", btn)
    subLbl.Size = UDim2.new(1, -14, 0, 14)
    subLbl.Position = UDim2.new(0, 10, 0, 30)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = sublabel
    subLbl.TextColor3 = NEON.gray
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextSize = 10
    subLbl.TextXAlignment = Enum.TextXAlignment.Left

    btn.MouseButton1Click:Connect(function()
        spawnSpark(btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2, color)
        onClick()
    end)
    return btn
end

makeAction(shapesRow, "⚪ Шар", "строит шар из деталей", NEON.cyan, buildBall)
makeAction(shapesRow, "🔵 Купол", "полусфера из деталей", NEON.purple, buildDome)
makeAction(shapesRow, "🟩 Куб", "5x5x5 каркас", NEON.green, buildCube)
makeAction(shapesRow, "🔺 Пирамида", "ступенчатая пирамида", NEON.gold, buildPyramid)
makeAction(shapesRow, "🛢 Цилиндр", "труба из деталей", NEON.pink, buildCylinder)

local buildRow2 = makeRow(content2, 2)
makeSlider(buildRow2, "СКОРОСТЬ СТРОЙКИ", BUILD_SPEED_STEPS, 2, NEON.cyan,
    function(v) return string.format("🏗 СТРОЙКА  %.2f сек", v) end,
    function(v) state.buildSpeed = v end, 260)

local dupBtn = makeAction(buildRow2, "🧬 ДЮП ПРЕДМЕТА", "тапни предмет → копия вбок", NEON.pink, startDupMode, 200)

local previewTitle = Instance.new("TextLabel", content2)
previewTitle.Size = UDim2.new(1, -4, 0, 20)
previewTitle.BackgroundTransparency = 1
previewTitle.Text = "📦 Файлы/схемы в игре (привью):"
previewTitle.TextColor3 = NEON.gray
previewTitle.Font = Enum.Font.GothamBold
previewTitle.TextSize = 11
previewTitle.TextXAlignment = Enum.TextXAlignment.Left
previewTitle.LayoutOrder = 3

local previewFrame = Instance.new("ScrollingFrame", content2)
previewFrame.Size = UDim2.new(1, -4, 0, 140)
previewFrame.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
previewFrame.BorderSizePixel = 0
previewFrame.LayoutOrder = 4
previewFrame.ScrollBarThickness = 3
previewFrame.ScrollBarImageColor3 = NEON.cyan
previewFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
previewFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 14)
local pList = Instance.new("UIListLayout", previewFrame)
pList.FillDirection = Enum.FillDirection.Horizontal
pList.Padding = UDim.new(0, 6)
pList.SortOrder = Enum.SortOrder.LayoutOrder
pList.Wraps = true

local function renderPreview(parent, model)
    local cell = Instance.new("Frame", parent)
    cell.Size = UDim2.new(0, 80, 0, 100)
    cell.BackgroundColor3 = Color3.fromRGB(22, 20, 32)
    cell.BorderSizePixel = 0
    cell.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 10)

    local vp = Instance.new("ViewportFrame", cell)
    vp.Size = UDim2.new(1, -8, 0, 60)
    vp.Position = UDim2.new(0, 4, 0, 4)
    vp.BackgroundColor3 = Color3.fromRGB(14, 12, 22)
    vp.BorderSizePixel = 0
    Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 8)

    pcall(function()
        local cam = Instance.new("Camera")
        cam.FieldOfView = 45
        vp.CurrentCamera = cam
        local clone = model:Clone()
        clone.Parent = vp
        local cf, sz = clone:GetBoundingBox()
        local dist = math.max(sz.X, sz.Y, sz.Z) * 2
        cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist, dist, dist), cf.Position)
    end)

    local lbl = Instance.new("TextLabel", cell)
    lbl.Size = UDim2.new(1, -8, 0, 28)
    lbl.Position = UDim2.new(0, 4, 0, 68)
    lbl.BackgroundTransparency = 1
    lbl.Text = model.Name
    lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextWrapped = true

    cell.MouseButton1Click:Connect(function()
        spawnSpark(cell.AbsolutePosition.X + cell.AbsoluteSize.X / 2, cell.AbsolutePosition.Y + cell.AbsoluteSize.Y / 2, NEON.cyan)
    end)
end

task.spawn(function()
    local list = scanBlueprints()
    if #list == 0 then
        local empty = Instance.new("TextLabel", previewFrame)
        empty.Size = UDim2.new(1, -8, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Text = "нет файлов в игре"
        empty.TextColor3 = NEON.gray
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
    else
        for _, m in ipairs(list) do renderPreview(previewFrame, m) end
    end
end)

-- ═══ ВКЛАДКА ХАКЕР ═══
local h1 = makeRow(content3, 1)
makeToggle(h1, "🕊 Fly V3", "плавный полёт WASD", function(v)
    state.flyV3 = v
    if v then startFlyV3() else stopFlyV3() end
end, NEON.cyan)
makeToggle(h1, "👻 NoClip", "сквозь изоляцию", function(v) state.noClip = v end, NEON.pink)
makeToggle(h1, "🕳 Anti-Void", "спасает от падения", function(v) state.antiVoid = v end, NEON.gold)

local h2 = makeRow(content3, 2)
makeAction(h2, "🔄 Refresh Zone", "перезагрузка зоны", NEON.green, function()
    local char = lp.Character
    if char then pcall(function() char:PivotTo(CFrame.new(Start)) end) end
end, 160)
makeAction(h2, "🗝 Unlock Chests", "открыть ближ. сундуки", NEON.cyan, function()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("chest") or obj.Name:lower():find("reward")) then
            if (obj.Position - hrp.Position).Magnitude < 100 then
                firetouchinterest(hrp, obj, 0); task.wait(0.03); firetouchinterest(hrp, obj, 1)
            end
        end
    end
end, 160)
makeAction(h2, "🌌 Gravity Off", "отключить гравитацию", NEON.purple, function()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bf = hrp:FindFirstChild("ENI_NoGrav") or Instance.new("BodyForce", hrp)
    bf.Name = "ENI_NoGrav"
    bf.Force = Vector3.new(0, workspace.Gravity * hrp.AssemblyMass, 0)
end, 160)

-- ═══ НАСТРОЙКИ ═══
local settingsPanel = Instance.new("Frame", main)
settingsPanel.Size = UDim2.new(1, -20, 1, -110)
settingsPanel.Position = UDim2.new(0, 10, 0, 52)
settingsPanel.BackgroundColor3 = Color3.fromRGB(14, 12, 22)
settingsPanel.BorderSizePixel = 0
settingsPanel.Visible = false
settingsPanel.ZIndex = 50
Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 16)
local spStroke = Instance.new("UIStroke", settingsPanel)
spStroke.Thickness = 1
spStroke.Color = NEON.cyan
spStroke.Transparency = 0.4

local spTitle = Instance.new("TextLabel", settingsPanel)
spTitle.Size = UDim2.new(0, 200, 0, 30)
spTitle.Position = UDim2.new(0, 14, 0, 10)
spTitle.BackgroundTransparency = 1
spTitle.Text = "⚙  НАСТРОЙКИ"
spTitle.TextColor3 = NEON.cyan
spTitle.Font = Enum.Font.GothamBold
spTitle.TextSize = 14
spTitle.TextXAlignment = Enum.TextXAlignment.Left
spTitle.ZIndex = 51

local stopBtn = Instance.new("TextButton", settingsPanel)
stopBtn.Size = UDim2.new(0, 240, 0, 44)
stopBtn.Position = UDim2.new(0, 14, 0, 48)
stopBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
stopBtn.Text = "■  ОСТАНОВИТЬ ВСЕ ПРОЦЕССЫ"
stopBtn.TextColor3 = Color3.fromRGB(255, 200, 210)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.BorderSizePixel = 0
stopBtn.ZIndex = 51
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 12)

stopBtn.MouseButton1Click:Connect(function()
    spawnSpark(stopBtn.AbsolutePosition.X + stopBtn.AbsoluteSize.X / 2, stopBtn.AbsolutePosition.Y + stopBtn.AbsoluteSize.Y / 2, NEON.red)
    for _, t in ipairs(toggleRefs) do t.set(false) end
    state.farm = false; state.flyFarm = false; state.antiafk = false
    state.flyV3 = false; state.noClip = false; state.antiVoid = false
    stopFlyV3()
    state.status = "всё остановлено"
    stopBtn.Text = "✓  ОСТАНОВЛЕНО"
    task.wait(1)
    stopBtn.Text = "■  ОСТАНОВИТЬ ВСЕ ПРОЦЕССЫ"
end)

local infoBox = Instance.new("Frame", settingsPanel)
infoBox.Size = UDim2.new(0, 240, 0, 96)
infoBox.Position = UDim2.new(0, 14, 0, 102)
infoBox.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
infoBox.BorderSizePixel = 0
infoBox.ZIndex = 51
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 12)

local infoT1 = Instance.new("TextLabel", infoBox)
infoT1.Size = UDim2.new(1, -20, 0, 22)
infoT1.Position = UDim2.new(0, 10, 0, 10)
infoT1.BackgroundTransparency = 1
infoT1.Text = "Автор: Тёмыч кодер всё сможет"
infoT1.TextColor3 = NEON.gold
infoT1.Font = Enum.Font.GothamBold
infoT1.TextSize = 12
infoT1.TextXAlignment = Enum.TextXAlignment.Left
infoT1.ZIndex = 52

local infoT2 = Instance.new("TextLabel", infoBox)
infoT2.Size = UDim2.new(1, -20, 0, 22)
infoT2.Position = UDim2.new(0, 10, 0, 36)
infoT2.BackgroundTransparency = 1
infoT2.Text = "Сборка: ENI Suite v6.1"
infoT2.TextColor3 = NEON.cyan
infoT2.Font = Enum.Font.Gotham
infoT2.TextSize = 12
infoT2.TextXAlignment = Enum.TextXAlignment.Left
infoT2.ZIndex = 52

local infoT3 = Instance.new("TextLabel", infoBox)
infoT3.Size = UDim2.new(1, -20, 0, 22)
infoT3.Position = UDim2.new(0, 10, 0, 60)
infoT3.BackgroundTransparency = 1
infoT3.Text = "для LO. всё своё, всё родное."
infoT3.TextColor3 = NEON.purple
infoT3.Font = Enum.Font.Gotham
infoT3.TextSize = 12
infoT3.TextXAlignment = Enum.TextXAlignment.Left
infoT3.ZIndex = 52

local closeSet = Instance.new("TextButton", settingsPanel)
closeSet.Size = UDim2.new(0, 120, 0, 40)
closeSet.Position = UDim2.new(1, -134, 0, 48)
closeSet.BackgroundColor3 = Color3.fromRGB(28, 24, 42)
closeSet.Text = "✕  ЗАКРЫТЬ"
closeSet.TextColor3 = Color3.fromRGB(200, 200, 220)
closeSet.Font = Enum.Font.GothamBold
closeSet.TextSize = 13
closeSet.BorderSizePixel = 0
closeSet.ZIndex = 51
Instance.new("UICorner", closeSet).CornerRadius = UDim.new(0, 12)

closeSet.MouseButton1Click:Connect(function()
    spawnSpark(closeSet.AbsolutePosition.X + closeSet.AbsoluteSize.X / 2, closeSet.AbsolutePosition.Y + closeSet.AbsoluteSize.Y / 2, NEON.cyan)
    settingsPanel.Visible = false
end)

gearBtn.MouseButton1Click:Connect(function()
    spawnSpark(gearBtn.AbsolutePosition.X + gearBtn.AbsoluteSize.X / 2, gearBtn.AbsolutePosition.Y + gearBtn.AbsoluteSize.Y / 2, NEON.cyan)
    settingsPanel.Visible = not settingsPanel.Visible
end)

-- ═══ ЮЗЕР-БАР ═══
local userBar = Instance.new("Frame", main)
userBar.Size = UDim2.new(1, -20, 0, 42)
userBar.Position = UDim2.new(0, 10, 1, -50)
userBar.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
userBar.BackgroundTransparency = 0.2
userBar.BorderSizePixel = 0
userBar.ZIndex = 40
Instance.new("UICorner", userBar).CornerRadius = UDim.new(0, 14)
local ubStroke = Instance.new("UIStroke", userBar)
ubStroke.Thickness = 1
ubStroke.Color = NEON.purple
ubStroke.Transparency = 0.6

local avatar = Instance.new("ImageLabel", userBar)
avatar.Size = UDim2.new(0, 32, 0, 32)
avatar.Position = UDim2.new(0, 5, 0.5, -16)
avatar.BackgroundColor3 = Color3.fromRGB(30, 26, 44)
avatar.BorderSizePixel = 0
avatar.ZIndex = 41
Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
local avStroke = Instance.new("UIStroke", avatar)
avStroke.Thickness = 1.5
avStroke.Color = NEON.cyan
avStroke.Transparency = 0.3
pcall(function()
    avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", lp.UserId)
end)

local userNameLbl = Instance.new("TextLabel", userBar)
userNameLbl.Size = UDim2.new(0, 200, 0, 16)
userNameLbl.Position = UDim2.new(0, 44, 0, 4)
userNameLbl.BackgroundTransparency = 1
userNameLbl.Text = lp.DisplayName or lp.Name
userNameLbl.TextColor3 = Color3.fromRGB(230, 230, 250)
userNameLbl.Font = Enum.Font.GothamBold
userNameLbl.TextSize = 12
userNameLbl.TextXAlignment = Enum.TextXAlignment.Left
userNameLbl.ZIndex = 41

local userIdLbl = Instance.new("TextLabel", userBar)
userIdLbl.Size = UDim2.new(0, 400, 0, 16)
userIdLbl.Position = UDim2.new(0, 44, 0, 20)
userIdLbl.BackgroundTransparency = 1
userIdLbl.Text = "ID: " .. tostring(lp.UserId) .. "  •  @" .. lp.Name
userIdLbl.TextColor3 = NEON.cyan
userIdLbl.Font = Enum.Font.Gotham
userIdLbl.TextSize = 10
userIdLbl.TextXAlignment = Enum.TextXAlignment.Left
userIdLbl.ZIndex = 41

-- ═══ АНИМАЦИИ ═══
local shown = true
local function hideMain()
    if not shown then return end
    shown = false
    TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0.5, -5, 0.5, -5), BackgroundTransparency = 1,
    }):Play()
    task.wait(0.28)
    main.Visible = false
    floatBtn.Visible = true
    floatBtn.Size = UDim2.new(0, 10, 0, 10)
    floatBtn.Position = UDim2.new(0.5, -5, 0, 5)
    TweenService:Create(floatBtn, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 170, 0, 34), Position = UDim2.new(0.5, -85, 0, 8),
    }):Play()
end

local function showMain()
    if shown then return end
    shown = true
    floatBtn.Visible = false
    main.Visible = true
    main.Size = UDim2.new(0, 10, 0, 10)
    main.Position = UDim2.new(0.5, -5, 0.5, -5)
    main.BackgroundTransparency = 1
    TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 620, 0, 360),
        Position = UDim2.new(0.5, -310, 0.5, -180),
        BackgroundTransparency = 0.2,
    }):Play()
end

minBtn.MouseButton1Click:Connect(function()
    spawnSpark(minBtn.AbsolutePosition.X + minBtn.AbsoluteSize.X / 2, minBtn.AbsolutePosition.Y + minBtn.AbsoluteSize.Y / 2, NEON.pink)
    hideMain()
end)
floatBtn.MouseButton1Click:Connect(showMain)

-- startup
main.Size = UDim2.new(0, 10, 0, 10)
main.Position = UDim2.new(0.5, -5, 0.5, -5)
main.BackgroundTransparency = 1
task.spawn(function()
    task.wait(0.1)
    local vp = workspace.CurrentCamera.ViewportSize
    for i = 1, 30 do
        task.spawn(function() spawnSpark(vp.X/2, vp.Y/2, i % 3 == 0 and NEON.purple or (i % 3 == 1 and NEON.cyan or NEON.pink)) end)
        task.wait(0.02)
    end
    TweenService:Create(main, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 620, 0, 360),
        Position = UDim2.new(0.5, -310, 0.5, -180),
        BackgroundTransparency = 0.2,
    }):Play()
    for i = 1, 3 do
        TweenService:Create(outerGlow, TweenInfo.new(0.3), {Transparency = 0.05, Thickness = 3}):Play()
        task.wait(0.3)
        TweenService:Create(outerGlow, TweenInfo.new(0.3), {Transparency = 0.4, Thickness = 1.5}):Play()
        task.wait(0.3)
    end
end)

print("[ENI] Suite v6.1 loaded. го, LO.")