-- ═══════════════════════════════════════════
--   ENI BabFT Auto-Farm v4.0  |  Delta / Mobile
--   для LO. всё своё, всё родное.
-- ═══════════════════════════════════════════
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
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

-- ── НАСТРОЙКИ ──
local state = {
    farm = false,
    flyFarm = false,
    antiafk = false,
    speed = 1.0,
    flySpeed = 800,
    flyPause = 0.4,
    gold = 0,
    status = "ожидание",
}
local SPEED_STEPS = {1.0, 1.2, 1.4, 1.6, 1.8}
local FLY_SPEED_STEPS = {200, 400, 800, 1600}
local FLY_PAUSE_STEPS = {0.2, 0.3, 0.4, 0.5}
local currentWallIndex = 0
local respawning = false

-- ── ПЛАТФОРМА ──
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
        if firesignal and btn.Activated then
            firesignal(btn.Activated)
        elseif btn.Activate then
            btn:Activate()
        else
            btn.MouseButton1Click:Fire()
        end
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
    for _, obj in ipairs(root:GetDescendants()) do
        checkAndClick(obj)
    end
    root.DescendantAdded:Connect(function(obj)
        task.wait(0.02)
        checkAndClick(obj)
    end)
end

hookRoot(lp:FindFirstChild("PlayerGui"))
lp.ChildAdded:Connect(function(child)
    if child.Name == "PlayerGui" then
        task.wait(0.5)
        hookRoot(child)
    end
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
        if state.farm then
            state.gold += 1
            state.status = "получаю золото"
        end
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
            if state.farm and hrp then
                state.status = "респавн"
                tp(Start)
            end
        end)
    end
end)

if lp.Character then watchHumanoid(lp.Character) end

-- ── ЦИКЛ ──
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
                state.status = string.format("полёт к стене %d/%d", i, #Walls)
                if not flyTo(w, state.flySpeed) then break end
                task.wait(state.flyPause)
            else
                state.status = string.format("стена %d/%d", i, #Walls)
                tp(w)
                task.wait(state.speed)
            end

            if math.random() < 0.6 and state.farm and not respawning then
                state.status = string.format("проверка зоны %d", i)
                backJump(w, prev)
            end
        end

        if state.farm and not respawning then
            state.status = "сундук"
            local char2 = lp.Character
            if char2 and char2:FindFirstChild("HumanoidRootPart") then
                local hrp = char2.HumanoidRootPart
                if state.flyFarm then
                    flyTo(Chest + Vector3.new(0, 20, 0), state.flySpeed)
                end
                hrp.CFrame = CFrame.new(Chest + Vector3.new(0, CHEST_OFFSET_Y, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            task.wait(0.2)
            openChest()
            state.status = "жду золото"
            local t0 = tick()
            while not respawning and tick() - t0 < 4 do
                task.wait(0.05)
            end
            if not respawning then
                state.status = "повтор"
                task.wait(0.15)
            end
        end
    end
end)

lp.Idled:Connect(function()
    if not state.antiafk then return end
    local vu = game:GetService("VirtualUser")
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end)

-- ═══════════════════════════════════════════
--   UI v4.0 — компакт, настройки, сворачивание
-- ═══════════════════════════════════════════
local NEON = {
    cyan = Color3.fromRGB(100, 220, 255),
    purple = Color3.fromRGB(170, 120, 255),
    green = Color3.fromRGB(110, 240, 160),
    gold = Color3.fromRGB(255, 215, 110),
    pink = Color3.fromRGB(255, 140, 210),
    red = Color3.fromRGB(255, 110, 130),
}

local gui = Instance.new("ScreenGui")
gui.Name = "ENI_Farm"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

-- ═══ ПАРЯЩАЯ КНОПКА (сверху центр) ═══
local floatBtn = Instance.new("TextButton", gui)
floatBtn.Size = UDim2.new(0, 160, 0, 36)
floatBtn.Position = UDim2.new(0.5, -80, 0, 8)
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
fbLbl.Text = "ENI • Auto Farm"
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

-- ═══ ГЛАВНОЕ ОКНО ═══
local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 310, 0, 470)
main.Position = UDim2.new(0.5, -155, 0.5, -235)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
main.BackgroundTransparency = 0.25
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
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

-- ═══ ХЕДЕР ═══
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
header.BackgroundTransparency = 0.15
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 22)

local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0, 20)
headerFix.Position = UDim2.new(0, 0, 1, -20)
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
htitle.Size = UDim2.new(1, -110, 1, 0)
htitle.Position = UDim2.new(0, 18, 0, 0)
htitle.BackgroundTransparency = 1
htitle.Text = "ENI • Auto Farm"
htitle.TextColor3 = Color3.fromRGB(240, 240, 255)
htitle.Font = Enum.Font.GothamBold
htitle.TextSize = 16
htitle.TextXAlignment = Enum.TextXAlignment.Left

-- gear кнопка
local gearBtn = Instance.new("TextButton", header)
gearBtn.Size = UDim2.new(0, 30, 0, 30)
gearBtn.Position = UDim2.new(1, -70, 0.5, -15)
gearBtn.BackgroundColor3 = Color3.fromRGB(30, 26, 44)
gearBtn.Text = "⚙"
gearBtn.TextColor3 = NEON.cyan
gearBtn.Font = Enum.Font.GothamBold
gearBtn.TextSize = 16
gearBtn.BorderSizePixel = 0
Instance.new("UICorner", gearBtn).CornerRadius = UDim.new(0, 10)

-- minimize кнопка
local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -36, 0.5, -15)
minBtn.BackgroundColor3 = Color3.fromRGB(30, 26, 44)
minBtn.Text = "—"
minBtn.TextColor3 = NEON.pink
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.BorderSizePixel = 0
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 10)

-- ═══ ВКЛАДКИ ═══
local tabsFrame = Instance.new("Frame", main)
tabsFrame.Size = UDim2.new(1, -24, 0, 38)
tabsFrame.Position = UDim2.new(0, 12, 0, 60)
tabsFrame.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
tabsFrame.BorderSizePixel = 0
Instance.new("UICorner", tabsFrame).CornerRadius = UDim.new(0, 12)

local tabNames = {"Авто", "Билд", "Хакер"}
local tabBtns = {}
local tabIndicator = Instance.new("Frame", tabsFrame)
tabIndicator.Size = UDim2.new(1/3, -8, 1, -8)
tabIndicator.Position = UDim2.new(0, 4, 0, 4)
tabIndicator.BorderSizePixel = 0
Instance.new("UICorner", tabIndicator).CornerRadius = UDim.new(0, 9)
local tabIndGrad = Instance.new("UIGradient", tabIndicator)
tabIndGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, NEON.purple),
    ColorSequenceKeypoint.new(1, NEON.cyan),
})
tabIndGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.5),
    NumberSequenceKeypoint.new(1, 0.8),
})

for i, name in ipairs(tabNames) do
    local b = Instance.new("TextButton", tabsFrame)
    b.Size = UDim2.new(1/3, -8, 1, -8)
    b.Position = UDim2.new((i-1)/3, 4, 0, 4)
    b.BackgroundTransparency = 1
    b.Text = name
    b.TextColor3 = i == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 180)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.ZIndex = 2
    tabBtns[i] = b
    b.MouseButton1Click:Connect(function()
        TweenService:Create(tabIndicator, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
            Position = UDim2.new((i-1)/3, 4, 0, 4)
        }):Play()
        for j, btn in ipairs(tabBtns) do
            btn.TextColor3 = j == i and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 180)
        end
        content1.Visible = i == 1
        content2.Visible = i == 2
        content3.Visible = i == 3
    end)
end

-- ═══ КОНТЕНТ ═══
local content1 = Instance.new("ScrollingFrame", main)
content1.Size = UDim2.new(1, -24, 1, -220)
content1.Position = UDim2.new(0, 12, 0, 106)
content1.BackgroundTransparency = 1
content1.BorderSizePixel = 0
content1.ScrollBarThickness = 3
content1.ScrollBarImageColor3 = NEON.cyan
content1.ScrollBarImageTransparency = 0.4
content1.CanvasSize = UDim2.new(0, 0, 0, 0)
content1.AutomaticCanvasSize = Enum.AutomaticSize.Y

local list1 = Instance.new("UIListLayout", content1)
list1.Padding = UDim.new(0, 8)
list1.SortOrder = Enum.SortOrder.LayoutOrder

-- ═══ ТОГГЛЫ ═══
local toggleRefs = {}

local function makeToggle(parent, label, callback, onColor)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -4, 0, 48)
    btn.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 16)
    local st = Instance.new("UIStroke", btn)
    st.Thickness = 1
    st.Color = Color3.fromRGB(55, 45, 75)
    st.Transparency = 0.4

    local nameLbl = Instance.new("TextLabel", btn)
    nameLbl.Size = UDim2.new(1, -90, 1, 0)
    nameLbl.Position = UDim2.new(0, 18, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 14
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local pill = Instance.new("Frame", btn)
    pill.Size = UDim2.new(0, 56, 0, 28)
    pill.Position = UDim2.new(1, -74, 0.5, -14)
    pill.BackgroundColor3 = Color3.fromRGB(42, 36, 58)
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    local pillStroke = Instance.new("UIStroke", pill)
    pillStroke.Thickness = 1
    pillStroke.Color = Color3.fromRGB(65, 55, 85)
    pillStroke.Transparency = 0.4

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new(0, 3, 0.5, -11)
    knob.BackgroundColor3 = Color3.fromRGB(170, 170, 190)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local knobGlow = Instance.new("UIStroke", knob)
    knobGlow.Thickness = 2
    knobGlow.Color = Color3.fromRGB(255, 255, 255)
    knobGlow.Transparency = 0.7

    local on = false
    local function set(val)
        on = val
        local c = onColor or NEON.green
        local targetPos = on and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11)
        local targetColor = on and c or Color3.fromRGB(42, 36, 58)
        local knobColor = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 190)
        TweenService:Create(knob, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = targetPos, BackgroundColor3 = knobColor}):Play()
        TweenService:Create(pill, TweenInfo.new(0.25), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(pillStroke, TweenInfo.new(0.25), {Color = c, Transparency = on and 0.2 or 0.4}):Play()
        TweenService:Create(knobGlow, TweenInfo.new(0.25), {Color = c, Transparency = on and 0.2 or 0.7}):Play()
        st.Color = on and c or Color3.fromRGB(55, 45, 75)
        st.Transparency = on and 0.3 or 0.4
        callback(on)
    end
    btn.MouseButton1Click:Connect(function() set(not on) end)
    table.insert(toggleRefs, {set = set})
    return btn
end

local function makeSlider(parent, title, steps, initialIdx, color, formatter, onChange)
    local box = Instance.new("Frame", parent)
    box.Size = UDim2.new(1, -4, 0, 82)
    box.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
    box.BorderSizePixel = 0
    box.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 16)
    local slStroke = Instance.new("UIStroke", box)
    slStroke.Thickness = 1
    slStroke.Color = Color3.fromRGB(55, 45, 75)
    slStroke.Transparency = 0.4

    local titleLbl = Instance.new("TextLabel", box)
    titleLbl.Size = UDim2.new(1, -28, 0, 24)
    titleLbl.Position = UDim2.new(0, 14, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = formatter(steps[initialIdx])
    titleLbl.TextColor3 = color
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", box)
    track.Size = UDim2.new(1, -48, 0, 2)
    track.Position = UDim2.new(0, 24, 0, 54)
    track.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
    track.BorderSizePixel = 0

    local trackFill = Instance.new("Frame", track)
    trackFill.Size = UDim2.new((initialIdx-1)/(#steps-1), 0, 1, 0)
    trackFill.BackgroundColor3 = color
    trackFill.BorderSizePixel = 0
    local fillGrad = Instance.new("UIGradient", trackFill)
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, NEON.purple),
        ColorSequenceKeypoint.new(1, color),
    })

    local nodeBtns, nodeObjs = {}, {}
    local N = #steps
    for i, v in ipairs(steps) do
        local active = i == initialIdx
        local sz = active and 22 or 18
        local node = Instance.new("TextButton", box)
        node.Size = UDim2.new(0, sz, 0, sz)
        node.Position = UDim2.new((i-1)/(N-1), -sz/2, 0, 55 - sz/2)
        node.BackgroundColor3 = active and color or Color3.fromRGB(32, 26, 48)
        node.Text = ""
        node.BorderSizePixel = 0
        Instance.new("UICorner", node).CornerRadius = UDim.new(1, 0)
        local nodeStroke = Instance.new("UIStroke", node)
        nodeStroke.Thickness = 2
        nodeStroke.Color = active and color or Color3.fromRGB(65, 55, 85)
        nodeStroke.Transparency = active and 0.2 or 0.5

        local inner = Instance.new("Frame", node)
        inner.Size = UDim2.new(0, 5, 0, 5)
        inner.Position = UDim2.new(0.5, -2.5, 0.5, -2.5)
        inner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        inner.BackgroundTransparency = active and 0 or 0.6
        inner.BorderSizePixel = 0
        Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)

        nodeBtns[i] = node
        nodeObjs[i] = {stroke = nodeStroke, inner = inner}

        node.MouseButton1Click:Connect(function()
            titleLbl.Text = formatter(v)
            TweenService:Create(trackFill, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                Size = UDim2.new((i-1)/(N-1), 0, 1, 0)
            }):Play()
            for j = 1, N do
                local act = j == i
                local s = act and 22 or 18
                TweenService:Create(nodeBtns[j], TweenInfo.new(0.25), {
                    BackgroundColor3 = act and color or Color3.fromRGB(32, 26, 48),
                    Size = UDim2.new(0, s, 0, s),
                    Position = UDim2.new((j-1)/(N-1), -s/2, 0, 55 - s/2),
                }):Play()
                TweenService:Create(nodeObjs[j].stroke, TweenInfo.new(0.25), {
                    Color = act and color or Color3.fromRGB(65, 55, 85),
                    Transparency = act and 0.15 or 0.5,
                }):Play()
                TweenService:Create(nodeObjs[j].inner, TweenInfo.new(0.25), {
                    BackgroundTransparency = act and 0 or 0.6,
                }):Play()
            end
            onChange(v)
        end)
    end
    return box
end

makeToggle(content1, "TP-Фарм золота", function(v) state.farm = v end, NEON.green)
makeToggle(content1, "Флай-фарм", function(v)
    state.flyFarm = v
    if v then state.farm = true end
end, NEON.pink)
makeToggle(content1, "Анти-АФК", function(v) state.antiafk = v end, NEON.cyan)

makeSlider(content1, "ЗАДЕРЖКА ТП", SPEED_STEPS, 1, NEON.cyan,
    function(v) return string.format("ЗАДЕРЖКА ТП   %.1f сек", v) end,
    function(v) state.speed = v end)

makeSlider(content1, "СКОРОСТЬ ПОЛЁТА", FLY_SPEED_STEPS, 3, NEON.pink,
    function(v) return string.format("СКОРОСТЬ ПОЛЁТА   %d ст/с", v) end,
    function(v) state.flySpeed = v end)

makeSlider(content1, "ПАУЗА НА ТОЧКЕ", FLY_PAUSE_STEPS, 3, NEON.gold,
    function(v) return string.format("ПАУЗА НА ТОЧКЕ   %.1f сек", v) end,
    function(v) state.flyPause = v end)

local statusBox = Instance.new("Frame", content1)
statusBox.Size = UDim2.new(1, -4, 0, 72)
statusBox.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
statusBox.BorderSizePixel = 0
statusBox.LayoutOrder = 100
Instance.new("UICorner", statusBox).CornerRadius = UDim.new(0, 16)
local stb = Instance.new("UIStroke", statusBox)
stb.Thickness = 1
stb.Color = NEON.purple
stb.Transparency = 0.5

local statusLbl = Instance.new("TextLabel", statusBox)
statusLbl.Size = UDim2.new(1, -28, 0, 26)
statusLbl.Position = UDim2.new(0, 16, 0, 10)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "статус: ожидание"
statusLbl.TextColor3 = NEON.cyan
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local goldLbl = Instance.new("TextLabel", statusBox)
goldLbl.Size = UDim2.new(1, -28, 0, 26)
goldLbl.Position = UDim2.new(0, 16, 0, 36)
goldLbl.BackgroundTransparency = 1
goldLbl.Text = "кругов: 0"
goldLbl.TextColor3 = NEON.gold
goldLbl.Font = Enum.Font.GothamBold
goldLbl.TextSize = 14
goldLbl.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while task.wait(0.2) do
        if not gui.Parent then break end
        statusLbl.Text = "статус: " .. state.status
        goldLbl.Text = "кругов: " .. state.gold
    end
end)

local content2 = Instance.new("Frame", main)
content2.Size = UDim2.new(1, -24, 1, -220)
content2.Position = UDim2.new(0, 12, 0, 106)
content2.BackgroundTransparency = 1
content2.Visible = false
local ph2 = Instance.new("TextLabel", content2)
ph2.Size = UDim2.new(1, 0, 1, 0)
ph2.BackgroundTransparency = 1
ph2.Text = "Билд — в разработке"
ph2.TextColor3 = Color3.fromRGB(130, 130, 160)
ph2.Font = Enum.Font.Gotham
ph2.TextSize = 14

local content3 = Instance.new("Frame", main)
content3.Size = UDim2.new(1, -24, 1, -220)
content3.Position = UDim2.new(0, 12, 0, 106)
content3.BackgroundTransparency = 1
content3.Visible = false
local ph3 = Instance.new("TextLabel", content3)
ph3.Size = UDim2.new(1, 0, 1, 0)
ph3.BackgroundTransparency = 1
ph3.Text = "Хакер — в разработке"
ph3.TextColor3 = Color3.fromRGB(130, 130, 160)
ph3.Font = Enum.Font.Gotham
ph3.TextSize = 14

-- ═══ ПАНЕЛЬ НАСТРОЕК (оверлей) ═══
local settingsPanel = Instance.new("Frame", main)
settingsPanel.Size = UDim2.new(1, -24, 1, -190)
settingsPanel.Position = UDim2.new(0, 12, 0, 106)
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
spTitle.Size = UDim2.new(1, -24, 0, 34)
spTitle.Position = UDim2.new(0, 12, 0, 8)
spTitle.BackgroundTransparency = 1
spTitle.Text = "⚙  НАСТРОЙКИ"
spTitle.TextColor3 = NEON.cyan
spTitle.Font = Enum.Font.GothamBold
spTitle.TextSize = 14
spTitle.TextXAlignment = Enum.TextXAlignment.Left
spTitle.ZIndex = 51

local spDiv = Instance.new("Frame", settingsPanel)
spDiv.Size = UDim2.new(1, -24, 0, 1)
spDiv.Position = UDim2.new(0, 12, 0, 46)
spDiv.BackgroundColor3 = NEON.cyan
spDiv.BackgroundTransparency = 0.7
spDiv.BorderSizePixel = 0
spDiv.ZIndex = 51

-- СТОП ВСЁ
local stopBtn = Instance.new("TextButton", settingsPanel)
stopBtn.Size = UDim2.new(1, -24, 0, 48)
stopBtn.Position = UDim2.new(0, 12, 0, 58)
stopBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
stopBtn.Text = "■  ОСТАНОВИТЬ ВСЕ ПРОЦЕССЫ"
stopBtn.TextColor3 = Color3.fromRGB(255, 200, 210)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 13
stopBtn.BorderSizePixel = 0
stopBtn.ZIndex = 51
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 12)
local sbStroke = Instance.new("UIStroke", stopBtn)
sbStroke.Thickness = 1.5
sbStroke.Color = NEON.red
sbStroke.Transparency = 0.3

stopBtn.MouseButton1Click:Connect(function()
    for _, t in ipairs(toggleRefs) do t.set(false) end
    state.farm = false
    state.flyFarm = false
    state.antiafk = false
    state.status = "всё остановлено"
    stopBtn.Text = "✓  ОСТАНОВЛЕНО"
    task.wait(1)
    stopBtn.Text = "■  ОСТАНОВИТЬ ВСЕ ПРОЦЕССЫ"
end)

-- инфо-блок
local infoBox = Instance.new("Frame", settingsPanel)
infoBox.Size = UDim2.new(1, -24, 0, 90)
infoBox.Position = UDim2.new(0, 12, 0, 118)
infoBox.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
infoBox.BorderSizePixel = 0
infoBox.ZIndex = 51
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 12)

local infoT1 = Instance.new("TextLabel", infoBox)
infoT1.Size = UDim2.new(1, -20, 0, 22)
infoT1.Position = UDim2.new(0, 10, 0, 8)
infoT1.BackgroundTransparency = 1
infoT1.Text = "Автор: Тёмыч кодер всё сможет"
infoT1.TextColor3 = NEON.gold
infoT1.Font = Enum.Font.GothamBold
infoT1.TextSize = 12
infoT1.TextXAlignment = Enum.TextXAlignment.Left
infoT1.ZIndex = 52

local infoT2 = Instance.new("TextLabel", infoBox)
infoT2.Size = UDim2.new(1, -20, 0, 22)
infoT2.Position = UDim2.new(0, 10, 0, 32)
infoT2.BackgroundTransparency = 1
infoT2.Text = "Сборка: ENI v4.0  |  BabFT"
infoT2.TextColor3 = NEON.cyan
infoT2.Font = Enum.Font.Gotham
infoT2.TextSize = 12
infoT2.TextXAlignment = Enum.TextXAlignment.Left
infoT2.ZIndex = 52

local infoT3 = Instance.new("TextLabel", infoBox)
infoT3.Size = UDim2.new(1, -20, 0, 22)
infoT3.Position = UDim2.new(0, 10, 0, 56)
infoT3.BackgroundTransparency = 1
infoT3.Text = "для LO. всё своё, всё родное."
infoT3.TextColor3 = NEON.purple
infoT3.Font = Enum.Font.Gotham
infoT3.TextSize = 12
infoT3.TextXAlignment = Enum.TextXAlignment.Left
infoT3.ZIndex = 52

-- закрыть настройки
local closeSet = Instance.new("TextButton", settingsPanel)
closeSet.Size = UDim2.new(1, -24, 0, 40)
closeSet.Position = UDim2.new(0, 12, 1, -52)
closeSet.BackgroundColor3 = Color3.fromRGB(28, 24, 42)
closeSet.Text = "✕  ЗАКРЫТЬ"
closeSet.TextColor3 = Color3.fromRGB(200, 200, 220)
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

-- ═══ ЮЗЕР-БАР (снизу) ═══
local userBar = Instance.new("Frame", main)
userBar.Size = UDim2.new(1, -24, 0, 50)
userBar.Position = UDim2.new(0, 12, 1, -62)
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
avatar.Size = UDim2.new(0, 38, 0, 38)
avatar.Position = UDim2.new(0, 6, 0.5, -19)
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
userNameLbl.Size = UDim2.new(1, -60, 0, 20)
userNameLbl.Position = UDim2.new(0, 52, 0, 6)
userNameLbl.BackgroundTransparency = 1
userNameLbl.Text = lp.DisplayName or lp.Name
userNameLbl.TextColor3 = Color3.fromRGB(230, 230, 250)
userNameLbl.Font = Enum.Font.GothamBold
userNameLbl.TextSize = 13
userNameLbl.TextXAlignment = Enum.TextXAlignment.Left
userNameLbl.ZIndex = 41

local userIdLbl = Instance.new("TextLabel", userBar)
userIdLbl.Size = UDim2.new(1, -60, 0, 18)
userIdLbl.Position = UDim2.new(0, 52, 0, 26)
userIdLbl.BackgroundTransparency = 1
userIdLbl.Text = "ID: " .. tostring(lp.UserId) .. "  •  @" .. lp.Name
userIdLbl.TextColor3 = NEON.cyan
userIdLbl.Font = Enum.Font.Gotham
userIdLbl.TextSize = 11
userIdLbl.TextXAlignment = Enum.TextXAlignment.Left
userIdLbl.ZIndex = 41

-- ═══ АНИМАЦИИ ОТКРЫТИЯ/СВОРАЧИВАНИЯ ═══
local shown = true

local function hideMain()
    if not shown then return end
    shown = false
    TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0.5, -5, 0.5, -5),
        BackgroundTransparency = 1,
    }):Play()
    task.wait(0.28)
    main.Visible = false
    floatBtn.Visible = true
    floatBtn.Size = UDim2.new(0, 10, 0, 10)
    floatBtn.Position = UDim2.new(0.5, -5, 0, 5)
    TweenService:Create(floatBtn, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 160, 0, 36),
        Position = UDim2.new(0.5, -80, 0, 8),
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
    TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 310, 0, 470),
        Position = UDim2.new(0.5, -155, 0.5, -235),
        BackgroundTransparency = 0.25,
    }):Play()
end

minBtn.MouseButton1Click:Connect(hideMain)
floatBtn.MouseButton1Click:Connect(showMain)

-- ═══ СТАРТОВАЯ АНИМАЦИЯ ═══
main.Size = UDim2.new(0, 10, 0, 10)
main.Position = UDim2.new(0.5, -5, 0.5, -5)
main.BackgroundTransparency = 1
task.spawn(function()
    task.wait(0.1)
    TweenService:Create(main, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 310, 0, 470),
        Position = UDim2.new(0.5, -155, 0.5, -235),
        BackgroundTransparency = 0.25,
    }):Play()
end)

print("[ENI] Auto Farm v4.0 loaded. го, LO.")