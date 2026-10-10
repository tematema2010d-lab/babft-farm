-- ═══════════════════════════════════════════
--   ENI BabFT Suite v8.1 «Winter»  |  Delta / Android
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
    Vector3.new(-48, 56, 1369), Vector3.new(-65, 46, 2139), Vector3.new(-19, 76, 2908),
    Vector3.new(-63, 41, 3682), Vector3.new(-53, 46, 4451), Vector3.new(-45, 47, 5220),
    Vector3.new(-46, 52, 5989), Vector3.new(-50, 49, 6762), Vector3.new(-62, 40, 7528),
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
    flyV3 = false, noClip = false,
}
local SPEED_STEPS = {1.0, 1.2, 1.4, 1.6, 1.8}
local FLY_SPEED_STEPS = {200, 400, 800, 1600}
local FLY_PAUSE_STEPS = {0.2, 0.3, 0.4, 0.5}
local respawning = false

-- ═══ АВТО-ФАРМ ═══
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
        local diff = target - hrp.Position
        local dist = diff.Magnitude
        if dist < 3 then return true end
        local step = math.min(speed * 0.03, dist)
        hrp.CFrame = CFrame.new(hrp.Position + diff.Unit * step)
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
        tp(mid, false); task.wait(0.1)
        tp(current, false); task.wait(0.1)
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
        task.wait(0.02); checkAndClick(obj)
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
                    firetouchinterest(hrp, obj, 0); task.wait(0.03)
                    firetouchinterest(hrp, obj, 1); task.wait(0.05)
                end
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local mag = (obj.Position - Chest).Magnitude
            if mag < 15 then
                firetouchinterest(hrp, obj, 0); task.wait(0.02)
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

task.spawn(function()
    while task.wait(0.05) do
        if not state.farm then continue end
        if respawning then continue end
        local char = lp.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        state.status = "ТП на старт"
        tp(Start)
        task.wait(state.speed)

        for i, w in ipairs(Walls) do
            if not state.farm or respawning then break end
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

-- ═══ FLY V3 (BodyVelocity) ═══
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
    flyBV.Name = "ENI_FlyBV"
    flyBG = Instance.new("BodyGyro", hrp)
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 3000
    flyBG.D = 200
    flyBG.CFrame = hrp.CFrame
    flyBG.Name = "ENI_FlyBG"
end

local function stopFlyV3()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

RunService.RenderStepped:Connect(function()
    if not state.flyV3 then return end
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    if not flyBV then startFlyV3() end
    if not flyBV then return end
    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
    flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * 100 or Vector3.zero
    flyBG.CFrame = cam.CFrame
end)

-- ENI Winter v8.2 | для LO
-- Полная версия — тот же v8.1, но NoClip-кэш переделан.

-- ═══ NOCLIP (патч v8.2, без лагов) ═══
local cachedParts = {}
task.spawn(function()
    while task.wait(2) do
        if not state.noClip then
            cachedParts = {}
            continue
        end
        local char = lp.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local newCache = {}
        local root = workspace:FindFirstChild("Boat") or workspace
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("BasePart") and obj.CanCollide then
                local d = (obj.Position - hrp.Position).Magnitude
                if d < 80 then
                    local nm = obj.Name:lower()
                    if nm:find("barrier") or nm:find("wall") or nm:find("gate") or nm:find("isolat") or nm:find("door") then
                        table.insert(newCache, obj)
                    end
                end
            end
        end
        cachedParts = newCache
    end
end)

RunService.Stepped:Connect(function()
    if not state.noClip then return end
    local char = lp.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
    for _, obj in ipairs(cachedParts) do
        if obj.Parent and obj.CanCollide then obj.CanCollide = false end
    end
end)

-- ═══════════════════════════════════════════
--   UI v8.1 «Winter» — 2 вкладки
-- ═══════════════════════════════════════════
local C = {
    ice        = Color3.fromRGB(180, 230, 255),
    iceDeep    = Color3.fromRGB(90, 150, 200),
    snow       = Color3.fromRGB(240, 248, 255),
    frost      = Color3.fromRGB(200, 220, 240),
    dark       = Color3.fromRGB(12, 18, 30),
    darkMild   = Color3.fromRGB(20, 30, 48),
    glassBlue  = Color3.fromRGB(70, 130, 190),
    aurora     = Color3.fromRGB(140, 220, 255),
    gold       = Color3.fromRGB(255, 220, 130),
    gray       = Color3.fromRGB(150, 165, 190),
}

local gui = Instance.new("ScreenGui")
gui.Name = "ENI_Winter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

-- снег поверх экрана
local snowLayer = Instance.new("Frame", gui)
snowLayer.Size = UDim2.new(1, 0, 1, 0)
snowLayer.BackgroundTransparency = 1
snowLayer.ZIndex = 199
snowLayer.ClipsDescendants = false

task.spawn(function()
    while gui.Parent do
        task.wait(0.35)
        local snow = Instance.new("Frame", snowLayer)
        local sz = math.random(2, 5)
        snow.Size = UDim2.new(0, sz, 0, sz)
        snow.Position = UDim2.new(math.random(), 0, -0.05, 0)
        snow.BackgroundColor3 = C.snow
        snow.BackgroundTransparency = math.random(30, 60) / 100
        snow.BorderSizePixel = 0
        snow.ZIndex = 199
        Instance.new("UICorner", snow).CornerRadius = UDim.new(1, 0)
        local drift = (math.random() - 0.5) * 0.1
        local dur = math.random(6, 12)
        TweenService:Create(snow, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
            Position = UDim2.new(snow.Position.X.Scale + drift, 0, 1.05, 0),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(dur + 0.1, function() snow:Destroy() end)
    end
end)

-- float
local floatBtn = Instance.new("TextButton", gui)
floatBtn.Size = UDim2.new(0, 170, 0, 34)
floatBtn.Position = UDim2.new(0.5, -85, 0, 8)
floatBtn.BackgroundColor3 = C.darkMild
floatBtn.BackgroundTransparency = 0.25
floatBtn.Text = ""
floatBtn.BorderSizePixel = 0
floatBtn.Visible = false
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
local fbStroke = Instance.new("UIStroke", floatBtn)
fbStroke.Thickness = 1.5; fbStroke.Color = C.ice; fbStroke.Transparency = 0.3

local fbLbl = Instance.new("TextLabel", floatBtn)
fbLbl.Size = UDim2.new(1, -20, 1, 0)
fbLbl.Position = UDim2.new(0, 10, 0, 0)
fbLbl.BackgroundTransparency = 1
fbLbl.Text = "❄ ENI • Winter"
fbLbl.TextColor3 = C.snow
fbLbl.Font = Enum.Font.GothamBold
fbLbl.TextSize = 13

task.spawn(function()
    while task.wait(0.05) do
        if not gui.Parent then break end
        fbStroke.Transparency = 0.35 + 0.25 * math.sin(tick() * 1.5)
    end
end)

-- main
local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 640, 0, 380)
main.Position = UDim2.new(0.5, -320, 0.5, -190)
main.BackgroundColor3 = C.dark
main.BackgroundTransparency = 0.15
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 22)

local mainGrad = Instance.new("UIGradient", main)
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 40, 65)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 20, 34)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 44, 70)),
})
mainGrad.Rotation = 135

local outerGlow = Instance.new("UIStroke", main)
outerGlow.Thickness = 1.5; outerGlow.Color = C.ice; outerGlow.Transparency = 0.35

local iceEdge = Instance.new("Frame", main)
iceEdge.Size = UDim2.new(1, -20, 0, 3)
iceEdge.Position = UDim2.new(0, 10, 0, 0)
iceEdge.BackgroundColor3 = C.ice
iceEdge.BackgroundTransparency = 0.4
iceEdge.BorderSizePixel = 0
Instance.new("UICorner", iceEdge).CornerRadius = UDim.new(1, 0)

-- снежинки-иконки внутри окна
task.spawn(function()
    while gui.Parent do
        task.wait(1.2)
        if not main.Visible then continue end
        local flake = Instance.new("TextLabel", main)
        flake.Size = UDim2.new(0, 18, 0, 18)
        flake.Position = UDim2.new(math.random(), 0, math.random(), 0)
        flake.BackgroundTransparency = 1
        flake.Text = "❄"
        flake.TextColor3 = C.ice
        flake.TextTransparency = 0.7
        flake.Font = Enum.Font.GothamBold
        flake.TextSize = math.random(10, 18)
        flake.Rotation = math.random(0, 360)
        flake.ZIndex = 2
        TweenService:Create(flake, TweenInfo.new(4, Enum.EasingStyle.Linear), {
            Position = UDim2.new(flake.Position.X.Scale, 0, flake.Position.Y.Scale + 0.2, 0),
            TextTransparency = 1,
            Rotation = flake.Rotation + 180,
        }):Play()
        task.delay(4.1, function() flake:Destroy() end)
    end
end)

-- resize
local resizeGrip = Instance.new("TextButton", main)
resizeGrip.Size = UDim2.new(0, 26, 0, 26)
resizeGrip.Position = UDim2.new(1, -26, 1, -26)
resizeGrip.BackgroundTransparency = 1
resizeGrip.Text = "❅"
resizeGrip.TextColor3 = C.ice
resizeGrip.TextSize = 18
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
    main.Size = UDim2.new(0, math.clamp(resizeOrigin.X + dx, 480, 1100), 0, math.clamp(resizeOrigin.Y + dy, 280, 700))
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
    end
end)

-- header
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = C.darkMild
header.BackgroundTransparency = 0.2
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 22)

local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0, 18)
headerFix.Position = UDim2.new(0, 0, 1, -18)
headerFix.BackgroundColor3 = C.darkMild
headerFix.BackgroundTransparency = 0.2
headerFix.BorderSizePixel = 0

local hLine = Instance.new("Frame", header)
hLine.Size = UDim2.new(1, -32, 0, 1)
hLine.Position = UDim2.new(0, 16, 1, -1)
hLine.BackgroundColor3 = C.ice
hLine.BackgroundTransparency = 0.6
hLine.BorderSizePixel = 0

local htitle = Instance.new("TextLabel", header)
htitle.Size = UDim2.new(0.6, 0, 1, 0)
htitle.Position = UDim2.new(0, 18, 0, 0)
htitle.BackgroundTransparency = 1
htitle.Text = "❄ ENI • Winter  v8.1"
htitle.TextColor3 = C.snow
htitle.Font = Enum.Font.GothamBold
htitle.TextSize = 15
htitle.TextXAlignment = Enum.TextXAlignment.Left

local headerStats = Instance.new("TextLabel", header)
headerStats.Size = UDim2.new(0, 300, 1, 0)
headerStats.Position = UDim2.new(1, -380, 0, 0)
headerStats.BackgroundTransparency = 1
headerStats.Text = "● ожидание   |   круг: 0"
headerStats.TextColor3 = C.ice
headerStats.Font = Enum.Font.Gotham
headerStats.TextSize = 11
headerStats.TextXAlignment = Enum.TextXAlignment.Right

local gearBtn = Instance.new("TextButton", header)
gearBtn.Size = UDim2.new(0, 28, 0, 28)
gearBtn.Position = UDim2.new(1, -66, 0.5, -14)
gearBtn.BackgroundColor3 = C.dark
gearBtn.Text = "⚙"
gearBtn.TextColor3 = C.ice
gearBtn.Font = Enum.Font.GothamBold
gearBtn.TextSize = 14
gearBtn.BorderSizePixel = 0
Instance.new("UICorner", gearBtn).CornerRadius = UDim.new(0, 9)

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -34, 0.5, -14)
minBtn.BackgroundColor3 = C.dark
minBtn.Text = "—"
minBtn.TextColor3 = C.ice
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.BorderSizePixel = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 9)

-- tabs (2 вкладки)
local tabsCol = Instance.new("Frame", main)
tabsCol.Size = UDim2.new(0, 112, 1, -110)
tabsCol.Position = UDim2.new(0, 10, 0, 54)
tabsCol.BackgroundColor3 = C.darkMild
tabsCol.BackgroundTransparency = 0.25
tabsCol.BorderSizePixel = 0
Instance.new("UICorner", tabsCol).CornerRadius = UDim.new(0, 14)

local tabsLayout = Instance.new("UIListLayout", tabsCol)
tabsLayout.Padding = UDim.new(0, 5)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local tabData = {
    {name = "❄ Авто"},
    {name = "⚡ Хакер"},
}
local tabBtns = {}
local contents = {}

local contentHolder = Instance.new("Frame", main)
contentHolder.Size = UDim2.new(1, -140, 1, -110)
contentHolder.Position = UDim2.new(0, 132, 0, 54)
contentHolder.BackgroundTransparency = 1
contentHolder.ClipsDescendants = true

local function makeTabBtn(i, name)
    local b = Instance.new("TextButton", tabsCol)
    b.Size = UDim2.new(1, -10, 0, 34)
    b.LayoutOrder = i
    b.BackgroundColor3 = i == 1 and C.glassBlue or C.dark
    b.Text = name
    b.TextColor3 = i == 1 and C.snow or C.gray
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    local st = Instance.new("UIStroke", b)
    st.Thickness = 1; st.Color = i == 1 and C.ice or Color3.fromRGB(50, 70, 90); st.Transparency = 0.4

    b.MouseButton1Click:Connect(function()
        for j, btn in ipairs(tabBtns) do
            local act = (j == i)
            btn.BackgroundColor3 = act and C.glassBlue or C.dark
            btn.TextColor3 = act and C.snow or C.gray
        end
        for j, c in ipairs(contents) do c.Visible = (j == i) end
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
    c.ScrollBarThickness = 4
    c.ScrollBarImageColor3 = C.ice
    c.ScrollBarImageTransparency = 0.3
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

-- components
local toggleRefs = {}

local function makeToggle(parent, label, sublabel, callback, onColor, width)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0, width or 180, 0, 52)
    btn.BackgroundColor3 = C.darkMild
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", btn)
    st.Thickness = 1; st.Color = Color3.fromRGB(60, 80, 105); st.Transparency = 0.4

    local nameLbl = Instance.new("TextLabel", btn)
    nameLbl.Size = UDim2.new(1, -80, 0, 20)
    nameLbl.Position = UDim2.new(0, 12, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = C.frost
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    if sublabel then
        local subLbl = Instance.new("TextLabel", btn)
        subLbl.Size = UDim2.new(1, -80, 0, 14)
        subLbl.Position = UDim2.new(0, 12, 0, 30)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = sublabel
        subLbl.TextColor3 = C.gray
        subLbl.Font = Enum.Font.Gotham
        subLbl.TextSize = 10
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
    end

    local badge = Instance.new("TextLabel", btn)
    badge.Size = UDim2.new(0, 28, 0, 14)
    badge.Position = UDim2.new(1, -62, 0, 4)
    badge.BackgroundTransparency = 1
    badge.Text = "OFF"
    badge.TextColor3 = C.gray
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 9

    local pill = Instance.new("Frame", btn)
    pill.Size = UDim2.new(0, 48, 0, 24)
    pill.Position = UDim2.new(1, -60, 0.5, -12)
    pill.BackgroundColor3 = C.dark
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    local pillStroke = Instance.new("UIStroke", pill)
    pillStroke.Thickness = 1; pillStroke.Color = Color3.fromRGB(70, 90, 115); pillStroke.Transparency = 0.4

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = C.frost
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local on = false
    local function set(val)
        on = val
        local c = onColor or C.aurora
        TweenService:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
            Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
            BackgroundColor3 = on and C.snow or C.frost,
        }):Play()
        TweenService:Create(pill, TweenInfo.new(0.2), {BackgroundColor3 = on and c or C.dark}):Play()
        TweenService:Create(pillStroke, TweenInfo.new(0.2), {Color = c, Transparency = on and 0.15 or 0.4}):Play()
        st.Color = on and c or Color3.fromRGB(60, 80, 105)
        st.Transparency = on and 0.2 or 0.4
        badge.Text = on and "ON" or "OFF"
        badge.TextColor3 = on and c or C.gray
        callback(on)
    end
    btn.MouseButton1Click:Connect(function() set(not on) end)
    table.insert(toggleRefs, {set = set})
    return btn
end

local function makeSlider(parent, title, steps, initialIdx, color, formatter, onChange, width)
    local box = Instance.new("Frame", parent)
    box.Size = UDim2.new(0, width or 220, 0, 74)
    box.BackgroundColor3 = C.darkMild
    box.BorderSizePixel = 0
    box.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)
    local slStroke = Instance.new("UIStroke", box)
    slStroke.Thickness = 1; slStroke.Color = Color3.fromRGB(60, 80, 105); slStroke.Transparency = 0.4

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
    track.BackgroundColor3 = C.dark
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
        node.BackgroundColor3 = active and color or C.dark
        node.Text = ""
        node.BorderSizePixel = 0
        Instance.new("UICorner", node).CornerRadius = UDim.new(1, 0)
        local nodeStroke = Instance.new("UIStroke", node)
        nodeStroke.Thickness = 2; nodeStroke.Color = active and color or Color3.fromRGB(70, 90, 115); nodeStroke.Transparency = active and 0.15 or 0.5

        nodeBtns[i] = node
        node.MouseButton1Click:Connect(function()
            titleLbl.Text = formatter(v)
            TweenService:Create(trackFill, TweenInfo.new(0.25), {Size = UDim2.new((i-1)/(N-1), 0, 1, 0)}):Play()
            for j = 1, N do
                local act = j == i
                local s = act and 18 or 14
                TweenService:Create(nodeBtns[j], TweenInfo.new(0.2), {
                    BackgroundColor3 = act and color or C.dark,
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
makeToggle(r1, "❄ TP-Фарм", "телепорт по зонам", function(v) state.farm = v end, C.aurora)
makeToggle(r1, "🌨 Флай-Фарм", "плавный полёт", function(v) state.flyFarm = v; if v then state.farm = true end end, C.ice)
makeToggle(r1, "🛡 Анти-АФК", "не кикает", function(v) state.antiafk = v end, C.aurora)

local r2 = makeRow(content1, 2)
makeSlider(r2, "ЗАДЕРЖКА ТП", SPEED_STEPS, 1, C.ice,
    function(v) return string.format("⏱ ЗАДЕРЖКА  %.1f сек", v) end,
    function(v) state.speed = v end, 210)
makeSlider(r2, "ПОЛЁТ", FLY_SPEED_STEPS, 3, C.aurora,
    function(v) return string.format("🌨 ПОЛЁТ  %d ст/с", v) end,
    function(v) state.flySpeed = v end, 210)

local r3 = makeRow(content1, 3)
makeSlider(r3, "ПАУЗА", FLY_PAUSE_STEPS, 3, C.gold,
    function(v) return string.format("⏸ ПАУЗА  %.1f сек", v) end,
    function(v) state.flyPause = v end, 210)

local statusBox = Instance.new("Frame", r3)
statusBox.Size = UDim2.new(0, 210, 0, 74)
statusBox.BackgroundColor3 = C.darkMild
statusBox.BorderSizePixel = 0
statusBox.LayoutOrder = 3
Instance.new("UICorner", statusBox).CornerRadius = UDim.new(0, 14)
local stb = Instance.new("UIStroke", statusBox)
stb.Thickness = 1; stb.Color = C.ice; stb.Transparency = 0.5

local statusLbl = Instance.new("TextLabel", statusBox)
statusLbl.Size = UDim2.new(1, -20, 0, 22)
statusLbl.Position = UDim2.new(0, 12, 0, 10)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "статус: ожидание"
statusLbl.TextColor3 = C.ice
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local goldLbl = Instance.new("TextLabel", statusBox)
goldLbl.Size = UDim2.new(1, -20, 0, 26)
goldLbl.Position = UDim2.new(0, 12, 0, 36)
goldLbl.BackgroundTransparency = 1
goldLbl.Text = "кругов: 0"
goldLbl.TextColor3 = C.gold
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

-- ═══ ВКЛАДКА ХАКЕР ═══
local h1 = makeRow(content2, 1)
makeToggle(h1, "🕊 Fly V3", "плавный полёт WASD", function(v)
    state.flyV3 = v
    if v then startFlyV3() else stopFlyV3() end
end, C.aurora)
makeToggle(h1, "👻 NoClip", "сквозь изоляцию", function(v) state.noClip = v end, C.ice)

-- ═══ НАСТРОЙКИ ═══
local settingsPanel = Instance.new("Frame", main)
settingsPanel.Size = UDim2.new(1, -20, 1, -110)
settingsPanel.Position = UDim2.new(0, 10, 0, 54)
settingsPanel.BackgroundColor3 = C.dark
settingsPanel.BorderSizePixel = 0
settingsPanel.Visible = false
settingsPanel.ZIndex = 50
Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 16)
local spStroke = Instance.new("UIStroke", settingsPanel)
spStroke.Thickness = 1; spStroke.Color = C.ice; spStroke.Transparency = 0.35

local spTitle = Instance.new("TextLabel", settingsPanel)
spTitle.Size = UDim2.new(0, 200, 0, 30)
spTitle.Position = UDim2.new(0, 14, 0, 10)
spTitle.BackgroundTransparency = 1
spTitle.Text = "❄  НАСТРОЙКИ"
spTitle.TextColor3 = C.ice
spTitle.Font = Enum.Font.GothamBold
spTitle.TextSize = 14
spTitle.TextXAlignment = Enum.TextXAlignment.Left
spTitle.ZIndex = 51

local stopBtn = Instance.new("TextButton", settingsPanel)
stopBtn.Size = UDim2.new(0, 260, 0, 44)
stopBtn.Position = UDim2.new(0, 14, 0, 48)
stopBtn.BackgroundColor3 = Color3.fromRGB(70, 25, 35)
stopBtn.Text = "■  ОСТАНОВИТЬ ВСЕ ПРОЦЕССЫ"
stopBtn.TextColor3 = C.snow
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.BorderSizePixel = 0
stopBtn.ZIndex = 51
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 12)

stopBtn.MouseButton1Click:Connect(function()
    for _, t in ipairs(toggleRefs) do t.set(false) end
    state.farm = false; state.flyFarm = false; state.antiafk = false
    state.flyV3 = false; state.noClip = false
    stopFlyV3()
    state.status = "всё остановлено"
    stopBtn.Text = "✓  ОСТАНОВЛЕНО"
    task.wait(1)
    stopBtn.Text = "■  ОСТАНОВИТЬ ВСЕ ПРОЦЕССЫ"
end)

local infoBox = Instance.new("Frame", settingsPanel)
infoBox.Size = UDim2.new(0, 260, 0, 100)
infoBox.Position = UDim2.new(0, 14, 0, 102)
infoBox.BackgroundColor3 = C.darkMild
infoBox.BorderSizePixel = 0
infoBox.ZIndex = 51
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 12)

local infoT1 = Instance.new("TextLabel", infoBox)
infoT1.Size = UDim2.new(1, -20, 0, 22)
infoT1.Position = UDim2.new(0, 10, 0, 10)
infoT1.BackgroundTransparency = 1
infoT1.Text = "Автор: Тёмыч кодер всё сможет"
infoT1.TextColor3 = C.gold
infoT1.Font = Enum.Font.GothamBold
infoT1.TextSize = 12
infoT1.TextXAlignment = Enum.TextXAlignment.Left
infoT1.ZIndex = 52

local infoT2 = Instance.new("TextLabel", infoBox)
infoT2.Size = UDim2.new(1, -20, 0, 22)
infoT2.Position = UDim2.new(0, 10, 0, 36)
infoT2.BackgroundTransparency = 1
infoT2.Text = "Сборка: ENI Winter v8.1"
infoT2.TextColor3 = C.ice
infoT2.Font = Enum.Font.Gotham
infoT2.TextSize = 12
infoT2.TextXAlignment = Enum.TextXAlignment.Left
infoT2.ZIndex = 52

local infoT3 = Instance.new("TextLabel", infoBox)
infoT3.Size = UDim2.new(1, -20, 0, 22)
infoT3.Position = UDim2.new(0, 10, 0, 60)
infoT3.BackgroundTransparency = 1
infoT3.Text = "для LO. всё своё, всё родное."
infoT3.TextColor3 = C.aurora
infoT3.Font = Enum.Font.Gotham
infoT3.TextSize = 12
infoT3.TextXAlignment = Enum.TextXAlignment.Left
infoT3.ZIndex = 52

local closeSet = Instance.new("TextButton", settingsPanel)
closeSet.Size = UDim2.new(0, 120, 0, 40)
closeSet.Position = UDim2.new(1, -134, 0, 48)
closeSet.BackgroundColor3 = C.darkMild
closeSet.Text = "✕  ЗАКРЫТЬ"
closeSet.TextColor3 = C.frost
closeSet.Font = Enum.Font.GothamBold
closeSet.TextSize = 13
closeSet.BorderSizePixel = 0
closeSet.ZIndex = 51
Instance.new("UICorner", closeSet).CornerRadius = UDim.new(0, 12)

closeSet.MouseButton1Click:Connect(function()
    settingsPanel.Visible = false
end)

gearBtn.MouseButton1Click:Connect(function()
    settingsPanel.Visible = not settingsPanel.Visible
end)

-- ═══ ЮЗЕР-БАР ═══
local userBar = Instance.new("Frame", main)
userBar.Size = UDim2.new(1, -20, 0, 44)
userBar.Position = UDim2.new(0, 10, 1, -52)
userBar.BackgroundColor3 = C.darkMild
userBar.BackgroundTransparency = 0.2
userBar.BorderSizePixel = 0
userBar.ZIndex = 40
Instance.new("UICorner", userBar).CornerRadius = UDim.new(0, 14)
local ubStroke = Instance.new("UIStroke", userBar)
ubStroke.Thickness = 1; ubStroke.Color = C.ice; ubStroke.Transparency = 0.55

local avatar = Instance.new("ImageLabel", userBar)
avatar.Size = UDim2.new(0, 34, 0, 34)
avatar.Position = UDim2.new(0, 5, 0.5, -17)
avatar.BackgroundColor3 = C.dark
avatar.BorderSizePixel = 0
avatar.ZIndex = 41
Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
local avStroke = Instance.new("UIStroke", avatar)
avStroke.Thickness = 1.5; avStroke.Color = C.ice; avStroke.Transparency = 0.3
pcall(function()
    avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", lp.UserId)
end)

local userNameLbl = Instance.new("TextLabel", userBar)
userNameLbl.Size = UDim2.new(0, 200, 0, 16)
userNameLbl.Position = UDim2.new(0, 46, 0, 5)
userNameLbl.BackgroundTransparency = 1
userNameLbl.Text = lp.DisplayName or lp.Name
userNameLbl.TextColor3 = C.snow
userNameLbl.Font = Enum.Font.GothamBold
userNameLbl.TextSize = 12
userNameLbl.TextXAlignment = Enum.TextXAlignment.Left
userNameLbl.ZIndex = 41

local userIdLbl = Instance.new("TextLabel", userBar)
userIdLbl.Size = UDim2.new(0, 400, 0, 16)
userIdLbl.Position = UDim2.new(0, 46, 0, 22)
userIdLbl.BackgroundTransparency = 1
userIdLbl.Text = "ID: " .. tostring(lp.UserId) .. "  •  @" .. lp.Name
userIdLbl.TextColor3 = C.ice
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
        Size = UDim2.new(0, 640, 0, 380),
        Position = UDim2.new(0.5, -320, 0.5, -190),
        BackgroundTransparency = 0.15,
    }):Play()
end

minBtn.MouseButton1Click:Connect(hideMain)
floatBtn.MouseButton1Click:Connect(showMain)

main.Size = UDim2.new(0, 10, 0, 10)
main.Position = UDim2.new(0.5, -5, 0.5, -5)
main.BackgroundTransparency = 1
task.spawn(function()
    task.wait(0.1)
    TweenService:Create(main, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 640, 0, 380),
        Position = UDim2.new(0.5, -320, 0.5, -190),
        BackgroundTransparency = 0.15,
    }):Play()
    for i = 1, 3 do
        TweenService:Create(outerGlow, TweenInfo.new(0.3), {Transparency = 0.05, Thickness = 3}):Play()
        task.wait(0.3)
        TweenService:Create(outerGlow, TweenInfo.new(0.3), {Transparency = 0.35, Thickness = 1.5}):Play()
        task.wait(0.3)
    end
end)

print("[ENI] Winter v8.1 loaded. го, LO.")
