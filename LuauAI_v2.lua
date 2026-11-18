local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local lp = Players.LocalPlayer

_G.AI_L0 = _G.AI_L0 or {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
}

local PRELUDE = [==[
local P = game:GetService("Players")
local lp = P.LocalPlayer
local RS = game:GetService("RunService")
local L = game:GetService("Lighting")
local W = workspace
local function say(t) if _G.AI_Say then _G.AI_Say(t) else print(t) end end
local function cam() return W.CurrentCamera end
local function hum() local c = lp.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function tg(k, f)
	k = "AI_T_" .. k
	if _G[k] then pcall(_G[k]) _G[k] = nil return end
	_G[k] = f()
end
local function cn(s, f) local c = s:Connect(f) return function() c:Disconnect() end end
local function cl(...) local a = {...} return function() for _, f in ipairs(a) do pcall(f) end end end
local function kill(o) return function() pcall(function() o:Destroy() end) end end
local function copy(s)
	local f = setclipboard or toclipboard
	if f then f(tostring(s)) say("Đã copy: " .. tostring(s)) else say(tostring(s)) end
end
local function findp(q)
	q = q:lower()
	local sub
	for _, p in ipairs(P:GetPlayers()) do
		if p ~= lp then
			local n, d = p.Name:lower(), p.DisplayName:lower()
			if n:sub(1, #q) == q or d:sub(1, #q) == q then return p end
			if not sub and (n:find(q, 1, true) or d:find(q, 1, true)) then sub = p end
		end
	end
	return sub
end
local function stat(k, v)
	_G.AI_Stats = _G.AI_Stats or {}
	_G.AI_Orig = _G.AI_Orig or {}
	if _G.AI_Orig[k] == nil then
		local h = hum()
		if h then _G.AI_Orig[k] = h[k] end
	end
	_G.AI_Stats[k] = v
	if not _G.AI_StatLoop then
		_G.AI_StatLoop = RS.Heartbeat:Connect(function()
			local h, s = hum(), _G.AI_Stats
			if not (h and s) then return end
			for key, val in pairs(s) do
				if key == "JumpPower" then h.UseJumpPower = true end
				if h[key] ~= val then h[key] = val end
			end
		end)
	end
end
local function hud(k, y, f)
	tg(k, function()
		local g = Instance.new("ScreenGui")
		g.Name = "AI_HUD"
		g.ResetOnSpawn = false
		g.DisplayOrder = 998
		if not pcall(function() g.Parent = (gethui and gethui()) or game:GetService("CoreGui") end) or not g.Parent then
			g.Parent = lp:WaitForChild("PlayerGui")
		end
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(0, 210, 0, 18)
		t.Position = UDim2.new(1, -216, 0, y)
		t.BackgroundColor3 = Color3.new(0, 0, 0)
		t.BackgroundTransparency = 0.5
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Font = Enum.Font.Code
		t.TextSize = 12
		t.Parent = g
		local acc = 1
		local c = RS.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 0.25 then
				acc = 0
				local ok, s = pcall(f, dt)
				t.Text = ok and tostring(s) or "?"
			end
		end)
		return function() c:Disconnect() g:Destroy() end
	end)
end
_G.AI_L0 = _G.AI_L0 or {Brightness = L.Brightness, ClockTime = L.ClockTime, FogEnd = L.FogEnd, GlobalShadows = L.GlobalShadows, Ambient = L.Ambient, OutdoorAmbient = L.OutdoorAmbient}
]==]

local HOP = [==[
local ok, res = pcall(function()
	return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=__ORDER__&limit=100"))
end)
if not ok or type(res) ~= "table" or not res.data then say("Không lấy được danh sách server (executor thiếu HttpGet?)") return end
local list = {}
for _, s in ipairs(res.data) do
	if s.id ~= game.JobId and s.playing < s.maxPlayers then list[#list + 1] = s.id end
end
if #list == 0 then say("Không có server phù hợp") return end
say("Đang chuyển server...")
game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, list[math.random(1, #list)], lp)]==]

local CATS = {
	{id = "move", label = "Di chuyển", kw = {"di chuyen", "move"}},
	{id = "cam", label = "Camera", kw = {"camera"}},
	{id = "visual", label = "Hình ảnh", kw = {"hinh anh", "anh sang", "visual"}},
	{id = "perf", label = "Hiệu năng", kw = {"hieu nang", "am thanh"}},
	{id = "info", label = "Thông tin", kw = {"thong tin", "hud", "info"}},
	{id = "server", label = "Server", kw = {"server", "may chu"}},
	{id = "tool", label = "Công cụ", kw = {"cong cu", "tuong tac", "tool"}},
	{id = "char", label = "Nhân vật", kw = {"nhan vat", "char"}},
}

local INTENTS = {}
local function I(cat, name, keys, code, def, min, max, arg)
	INTENTS[#INTENTS + 1] = {cat = cat, name = name, keys = keys, code = code, def = def, min = min, max = max, arg = arg}
end
local function A(cat, name, keys, code, arg) I(cat, name, keys, code, nil, nil, nil, arg) end

-- DI CHUYỂN
I("move", "Bay", {"fly", "bay", "bay tren troi", "bay di"}, [==[
tg("fly", function()
	local h, r = hum(), hrp()
	if not (h and r) then return function() end end
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bv.Velocity = Vector3.zero
	bv.Parent = r
	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bg.P = 9e4
	bg.CFrame = r.CFrame
	bg.Parent = r
	local c
	local function stop()
		if c then c:Disconnect() end
		bv:Destroy() bg:Destroy()
		if h.Parent then h.PlatformStand = false end
	end
	c = RS.RenderStepped:Connect(function()
		if not r.Parent then stop() _G.AI_T_fly = nil return end
		local cf = cam().CFrame
		local look, right = cf.LookVector, cf.RightVector
		local fl, fr = Vector3.new(look.X, 0, look.Z), Vector3.new(right.X, 0, right.Z)
		local v = Vector3.zero
		if fl.Magnitude > 0.01 and fr.Magnitude > 0.01 then
			local d = h.MoveDirection
			v = look * d:Dot(fl.Unit) + right * d:Dot(fr.Unit)
		end
		if h.Jump then v += Vector3.new(0, 1, 0) end
		if v.Magnitude > 1 then v = v.Unit end
		bv.Velocity = v * __N__
		bg.CFrame = cf
		h.PlatformStand = true
	end)
	return stop
end)]==], 60, 5, 500)

I("move", "Tốc độ chạy", {"toc do", "speed", "walkspeed", "chay nhanh"}, [==[
stat("WalkSpeed", __N__)]==], 50, 1, 500)

I("move", "Nhảy cao", {"nhay cao", "jump power", "jumppower", "jump", "nhay"}, [==[
stat("JumpPower", __N__)]==], 100, 1, 1000)

I("move", "Nhảy vô hạn", {"nhay vo han", "nhay mai", "infinite jump", "inf jump", "infjump"}, [==[
tg("infjump", function()
	return cn(game:GetService("UserInputService").JumpRequest, function()
		local h = hum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)
end)]==])

I("move", "Xuyên tường (Noclip)", {"noclip", "xuyen tuong", "di xuyen", "xuyen vat"}, [==[
tg("noclip", function()
	return cn(RS.Stepped, function()
		local c = lp.Character
		if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
		end
	end)
end)]==])

I("move", "Xoay vòng", {"xoay", "spin", "quay tron"}, [==[
tg("spin", function()
	return cn(RS.RenderStepped, function()
		local r = hrp()
		if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(__N__), 0) end
	end)
end)]==], 10, 1, 90)

I("move", "Click Teleport", {"click tp", "clicktp", "tp click", "tap tp", "dich chuyen khi cham"}, [==[
local bp = lp:WaitForChild("Backpack")
local old = bp:FindFirstChild("ClickTP")
if old then old:Destroy() end
local t = Instance.new("Tool")
t.Name = "ClickTP"
t.RequiresHandle = false
t.CanBeDropped = false
t.Activated:Connect(function()
	local r = hrp()
	local m = lp:GetMouse()
	if r and m.Hit then r.CFrame = CFrame.new(m.Hit.Position + Vector3.new(0, 3, 0)) end
end)
t.Parent = bp]==])

A("move", "Dịch chuyển tới người chơi", {"tp den", "tp toi", "tp to", "teleport to", "dich chuyen den", "tele den"}, [==[
local t = findp("__NAME__")
local r = hrp()
local tr = t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
if r and tr then r.CFrame = tr.CFrame * CFrame.new(0, 0, 3) else say("Không tìm thấy người chơi: __NAME__") end]==], "word")

I("move", "Trọng lực", {"trong luc", "gravity"}, [==[
W.Gravity = __N__]==], 50, 0, 1000)

I("move", "Đi trên không", {"di tren khong", "air walk", "airwalk", "nen khong"}, [==[
tg("airwalk", function()
	local r = hrp()
	if not r then return function() end end
	local y = r.Position.Y - 3.5
	local p = Instance.new("Part")
	p.Size = Vector3.new(8, 1, 8)
	p.Anchored = true
	p.Transparency = 0.7
	p.Parent = W
	local c = RS.Heartbeat:Connect(function()
		local rr = hrp()
		if rr then p.Position = Vector3.new(rr.Position.X, y, rr.Position.Z) end
	end)
	return cl(function() c:Disconnect() end, kill(p))
end)]==])

I("move", "Leo dốc cao", {"leo doc", "climb slope", "di len doc"}, [==[
stat("MaxSlopeAngle", 89)]==])

I("move", "Chân cao", {"chan cao", "hip height", "hipheight", "nang cao nhan vat"}, [==[
stat("HipHeight", __N__)]==], 6, 0, 60)

I("move", "Chống ngã (ragdoll)", {"chong nga", "no ragdoll", "khong nga"}, [==[
tg("noragdoll", function()
	local h = hum()
	if not h then return function() end end
	local st = {Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll}
	for _, s in ipairs(st) do h:SetStateEnabled(s, false) end
	return function() for _, s in ipairs(st) do h:SetStateEnabled(s, true) end end
end)]==])

I("move", "Chống sát thương rơi", {"chong roi", "no fall", "khong mat mau khi roi"}, [==[
tg("nofall", function()
	return cn(RS.Heartbeat, function()
		local r = hrp()
		if r then
			local v = r.AssemblyLinearVelocity
			if v.Y < -50 then r.AssemblyLinearVelocity = Vector3.new(v.X, -50, v.Z) end
		end
	end)
end)]==])

I("move", "Lên cao", {"len cao", "bay len", "tang do cao"}, [==[
local r = hrp()
if r then r.CFrame = r.CFrame + Vector3.new(0, __N__, 0) end]==], 50, 1, 5000)

I("move", "Xuống mặt đất", {"xuong dat", "ha canh", "land"}, [==[
local r = hrp()
if r then
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {lp.Character}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local hit = W:Raycast(r.Position, Vector3.new(0, -5000, 0), rp)
	if hit then r.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.5, 0)) * r.CFrame.Rotation
	else say("Không thấy mặt đất bên dưới") end
end]==])

I("move", "Về điểm hồi sinh", {"ve spawn", "spawn", "ve diem hoi sinh"}, [==[
local s = W:FindFirstChildWhichIsA("SpawnLocation", true)
local r = hrp()
if s and r then r.CFrame = s.CFrame + Vector3.new(0, 4, 0) else say("Không tìm thấy điểm hồi sinh") end]==])

I("move", "Lưu vị trí", {"luu vi tri", "save pos", "danh dau vi tri"}, [==[
local r = hrp()
if r then _G.AI_Saved = r.CFrame say("Đã lưu vị trí") end]==])

I("move", "Về vị trí đã lưu", {"ve vi tri", "load pos", "quay lai vi tri"}, [==[
local r = hrp()
if r and _G.AI_Saved then r.CFrame = _G.AI_Saved else say("Chưa lưu vị trí nào") end]==])

A("move", "Đi theo người chơi", {"di theo", "follow"}, [==[
local t = findp("__NAME__")
if not t then say("Không tìm thấy người chơi: __NAME__") return end
tg("follow", function()
	return cn(RS.Heartbeat, function()
		local h = hum()
		local tr = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
		if h and tr then h:MoveTo(tr.Position) end
	end)
end)]==], "word")

A("cam", "Xem người chơi (spectate)", {"xem nguoi choi", "spectate", "theo doi"}, [==[
local t = findp("__NAME__")
if not t then say("Không tìm thấy người chơi: __NAME__") return end
tg("spectate", function()
	local c = cn(RS.RenderStepped, function()
		local th = t.Character and t.Character:FindFirstChildOfClass("Humanoid")
		if th and cam().CameraSubject ~= th then cam().CameraSubject = th end
	end)
	return function()
		c()
		local h = hum()
		if h then cam().CameraSubject = h end
	end
end)]==], "word")

I("move", "Đứng yên (neo)", {"dung yen", "freeze", "neo nhan vat", "dong bang ban than"}, [==[
tg("freeze", function()
	local r = hrp()
	if not r then return function() end end
	r.Anchored = true
	return function() r.Anchored = false end
end)]==])

I("move", "Ngồi xuống", {"ngoi xuong", "sit", "ngoi"}, [==[
local h = hum()
if h then h.Sit = true end]==])

I("move", "Nhảy liên tục", {"bunny hop", "bhop", "nhay lien tuc", "auto jump"}, [==[
tg("bhop", function()
	return cn(RS.Heartbeat, function()
		local h = hum()
		if h and h.FloorMaterial ~= Enum.Material.Air then h.Jump = true end
	end)
end)]==])

I("move", "Tự động đi tới", {"tu dong di", "auto walk", "autowalk", "di bo tu dong"}, [==[
tg("autowalk", function()
	return cn(RS.Heartbeat, function()
		local h = hum()
		if h then h:Move(Vector3.new(0, 0, -1), true) end
	end)
end)]==])

I("move", "Lướt (dash)", {"dash", "lao toi", "luot toi"}, [==[
local r = hrp()
if r then r.AssemblyLinearVelocity = cam().CFrame.LookVector * __N__ end]==], 120, 10, 500)

I("move", "Chống rơi vực", {"chong roi vuc", "anti void", "antivoid"}, [==[
tg("antivoid", function()
	local safe
	return cn(RS.Heartbeat, function()
		local r, h = hrp(), hum()
		if not (r and h) then return end
		if h.FloorMaterial ~= Enum.Material.Air then safe = r.CFrame end
		if safe and r.Position.Y < W.FallenPartsDestroyHeight + 150 then
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = safe + Vector3.new(0, 5, 0)
		end
	end)
end)]==])

I("move", "Quay lại chỗ chết", {"quay lai cho chet", "back on death", "hoi sinh tai cho"}, [==[
tg("backdeath", function()
	local last
	local c1 = cn(RS.Heartbeat, function()
		local r, h = hrp(), hum()
		if r and h and h.Health > 0 then last = r.CFrame end
	end)
	local c2 = cn(lp.CharacterAdded, function(c)
		local r = c:WaitForChild("HumanoidRootPart", 10)
		if r and last then task.wait(0.3) r.CFrame = last end
	end)
	return cl(c1, c2)
end)]==])

A("move", "Dịch chuyển theo tọa độ", {"tp toa do", "dich chuyen toa do", "goto xyz"}, [==[
local r = hrp()
local x, y, z = __NAME__
if r then r.CFrame = CFrame.new(x, y, z) end]==], "xyz")

A("move", "Dịch chuyển tới vật thể", {"tp vat the", "goto part", "di den vat the"}, [==[
local q = "__NAME__"
local r = hrp()
if not r then return end
local best, bd
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and d.Name:lower():find(q, 1, true) and not (lp.Character and d:IsDescendantOf(lp.Character)) then
		local m = (d.Position - r.Position).Magnitude
		if not bd or m < bd then best, bd = d, m end
	end
end
if best then r.CFrame = best.CFrame + Vector3.new(0, 4, 0) else say("Không tìm thấy vật thể: " .. q) end]==], "word")

I("move", "Dịch chuyển tới người gần nhất", {"tp nguoi gan nhat", "den nguoi gan nhat"}, [==[
local r = hrp()
local best, bd
for _, p in ipairs(P:GetPlayers()) do
	local tr = p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if r and tr then
		local m = (tr.Position - r.Position).Magnitude
		if not bd or m < bd then best, bd = tr, m end
	end
end
if best then r.CFrame = best.CFrame * CFrame.new(0, 0, 3) else say("Không có ai khác") end]==])

I("move", "Dịch chuyển ngẫu nhiên tới người chơi", {"tp ngau nhien", "tp random"}, [==[
local r = hrp()
local list = {}
for _, p in ipairs(P:GetPlayers()) do
	local tr = p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if tr then list[#list + 1] = tr end
end
if r and #list > 0 then r.CFrame = list[math.random(1, #list)].CFrame * CFrame.new(0, 0, 3) else say("Không có ai khác") end]==])

I("move", "Khóa hướng quay", {"khoa huong quay", "no autorotate"}, [==[
stat("AutoRotate", false)]==])

I("move", "Xuyên người chơi khác", {"xuyen nguoi choi", "no collide players", "khong va cham nguoi"}, [==[
tg("nocollideplayers", function()
	return cn(RS.Stepped, function()
		for _, p in ipairs(P:GetPlayers()) do
			if p ~= lp and p.Character then
				for _, d in ipairs(p.Character:GetChildren()) do
					if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
				end
			end
		end
	end)
end)]==])

-- CAMERA
I("cam", "FOV camera", {"fov", "goc nhin", "field of view"}, [==[
cam().FieldOfView = __N__]==], 100, 1, 120)

I("cam", "Mở khóa zoom camera", {"zoom xa", "tam nhin xa", "unlock zoom", "mo khoa zoom"}, [==[
lp.CameraMode = Enum.CameraMode.Classic
lp.CameraMinZoomDistance = 0.5
lp.CameraMaxZoomDistance = __N__]==], 1000, 10, 100000)

I("cam", "Góc nhìn thứ nhất", {"goc nhin thu nhat", "first person", "ngoi thu nhat"}, [==[
lp.CameraMode = Enum.CameraMode.LockFirstPerson]==])

I("cam", "Góc nhìn thứ ba", {"goc nhin thu ba", "third person", "ngoi thu ba"}, [==[
lp.CameraMode = Enum.CameraMode.Classic
lp.CameraMinZoomDistance = 0.5
lp.CameraMaxZoomDistance = math.max(lp.CameraMaxZoomDistance, 128)]==])

I("cam", "Camera xuyên tường", {"camera xuyen tuong", "invisicam"}, [==[
lp.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam]==])

I("cam", "Bật khóa chuột (Shift Lock)", {"shift lock", "shiftlock", "khoa chuot"}, [==[
lp.DevEnableMouseLock = true]==])

I("cam", "Sửa camera", {"reset camera", "sua camera", "camera loi"}, [==[
local c, h = cam(), hum()
c.CameraType = Enum.CameraType.Custom
if h then c.CameraSubject = h end
c.FieldOfView = 70
lp.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom]==])

I("cam", "Ẩn toàn bộ giao diện", {"an giao dien", "hide ui", "an ui"}, [==[
tg("hideui", function()
	local sg = game:GetService("StarterGui")
	local off = {}
	pcall(function() sg:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	for _, g in ipairs(lp.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then g.Enabled = false off[#off + 1] = g end
	end
	return function()
		pcall(function() sg:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
		for _, g in ipairs(off) do g.Enabled = true end
	end
end)]==])

I("cam", "Bật lại giao diện Roblox", {"bat giao dien", "hien giao dien", "show ui"}, [==[
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)]==])

I("cam", "Bật nút reset", {"bat nut reset", "enable reset"}, [==[
pcall(function() game:GetService("StarterGui"):SetCore("ResetButtonCallback", true) end)]==])

-- HÌNH ẢNH
I("visual", "ESP người chơi (tên + khoảng cách)", {"esp", "nhin xuyen", "wallhack", "thay nguoi choi"}, [==[
tg("esp", function()
	local items, labels, conns = {}, {}, {}
	local function add(p)
		if p == lp then return end
		local function onChar(c)
			local h = Instance.new("Highlight")
			h.FillColor = p.Neutral and Color3.fromRGB(255, 60, 60) or p.TeamColor.Color
			h.OutlineColor = Color3.new(1, 1, 1)
			h.FillTransparency = 0.5
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = c
			items[#items + 1] = h
			local hd = c:WaitForChild("Head", 5)
			if hd then
				local b = Instance.new("BillboardGui")
				b.Size = UDim2.new(0, 140, 0, 20)
				b.StudsOffset = Vector3.new(0, 2.5, 0)
				b.AlwaysOnTop = true
				b.Adornee = hd
				b.Parent = c
				local t = Instance.new("TextLabel")
				t.Size = UDim2.new(1, 0, 1, 0)
				t.BackgroundTransparency = 1
				t.TextColor3 = Color3.new(1, 1, 1)
				t.TextStrokeTransparency = 0
				t.Font = Enum.Font.GothamBold
				t.TextSize = 12
				t.Parent = b
				items[#items + 1] = b
				labels[#labels + 1] = {t = t, p = p, h = hd}
			end
		end
		if p.Character then task.spawn(onChar, p.Character) end
		conns[#conns + 1] = p.CharacterAdded:Connect(onChar)
	end
	for _, p in ipairs(P:GetPlayers()) do add(p) end
	conns[#conns + 1] = P.PlayerAdded:Connect(add)
	local acc = 0
	conns[#conns + 1] = RS.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then return end
		acc = 0
		local r = hrp()
		for i = #labels, 1, -1 do
			local l = labels[i]
			if not l.h.Parent then table.remove(labels, i)
			elseif r then l.t.Text = l.p.DisplayName .. " [" .. math.floor((l.h.Position - r.Position).Magnitude) .. "m]" end
		end
	end)
	return function()
		for _, c in ipairs(conns) do c:Disconnect() end
		for _, i in ipairs(items) do pcall(function() i:Destroy() end) end
	end
end)]==])

I("visual", "ESP vật phẩm (Tool)", {"esp vat pham", "esp tool", "esp do"}, [==[
tg("esptool", function()
	local items = {}
	local function add(d)
		if d:IsA("Tool") and d:FindFirstChild("Handle") and not P:GetPlayerFromCharacter(d.Parent) then
			local h = Instance.new("Highlight")
			h.Adornee = d.Handle
			h.FillColor = Color3.fromRGB(80, 255, 120)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = d.Handle
			items[#items + 1] = h
		end
	end
	for _, d in ipairs(W:GetDescendants()) do add(d) end
	local c = W.DescendantAdded:Connect(add)
	return function()
		c:Disconnect()
		for _, h in ipairs(items) do pcall(function() h:Destroy() end) end
	end
end)]==])

I("visual", "ESP NPC", {"esp npc", "esp quai", "esp mob"}, [==[
tg("espnpc", function()
	local items = {}
	for _, d in ipairs(W:GetDescendants()) do
		if d:IsA("Humanoid") and d.Parent and not P:GetPlayerFromCharacter(d.Parent) and d.Parent:IsA("Model") then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 200, 40)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = d.Parent
			items[#items + 1] = h
		end
	end
	return function() for _, h in ipairs(items) do pcall(function() h:Destroy() end) end end
end)]==])

A("visual", "Tìm & đánh dấu vật thể theo tên", {"tim vat the", "find part", "tim object"}, [==[
local q = "__NAME__"
tg("find_" .. q, function()
	local items = {}
	for _, d in ipairs(W:GetDescendants()) do
		if #items >= 100 then break end
		if (d:IsA("BasePart") or d:IsA("Model")) and d.Name:lower():find(q, 1, true) and not (lp.Character and d:IsDescendantOf(lp.Character)) then
			local h = Instance.new("Highlight")
			h.Adornee = d
			h.FillColor = Color3.fromRGB(80, 200, 255)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = d
			items[#items + 1] = h
		end
	end
	say("Đã đánh dấu " .. #items .. " vật thể tên '" .. q .. "'")
	return function() for _, h in ipairs(items) do pcall(function() h:Destroy() end) end end
end)]==], "word")

I("visual", "Sáng toàn map", {"fullbright", "full bright", "sang map", "sang hon", "nhin ban dem"}, [==[
L.Brightness = 2
L.ClockTime = 14
L.FogEnd = 1e6
L.GlobalShadows = false
L.Ambient = Color3.fromRGB(178, 178, 178)
L.OutdoorAmbient = Color3.fromRGB(178, 178, 178)]==])

I("visual", "Tắt sương mù", {"tat suong mu", "no fog", "xoa suong"}, [==[
L.FogEnd = 1e6
for _, a in ipairs(L:GetChildren()) do
	if a:IsA("Atmosphere") then a.Density = 0 a.Haze = 0 end
end]==])

I("visual", "Ban ngày", {"ban ngay", "troi sang"}, [==[
L.ClockTime = 14]==])
I("visual", "Ban đêm", {"ban dem", "troi toi", "night"}, [==[
L.ClockTime = 0]==])
I("visual", "Hoàng hôn", {"hoang hon", "sunset"}, [==[
L.ClockTime = 18]==])
I("visual", "Bình minh", {"binh minh", "sunrise"}, [==[
L.ClockTime = 6]==])

I("visual", "Đặt giờ trong game", {"gio game", "clocktime", "dat gio"}, [==[
L.ClockTime = __N__]==], 12, 0, 24)

I("visual", "Khóa giờ", {"khoa gio", "lock time"}, [==[
tg("locktime", function()
	local t = __N__
	return cn(RS.Heartbeat, function() L.ClockTime = t end)
end)]==], 14, 0, 24)

I("visual", "Tắt hiệu ứng hậu kỳ", {"tat hieu ung hau ky", "no blur", "tat blur", "tat bloom"}, [==[
tg("nopost", function()
	local off = {}
	local function scan(o)
		for _, e in ipairs(o:GetDescendants()) do
			if e:IsA("PostEffect") and e.Enabled then e.Enabled = false off[#off + 1] = e end
		end
	end
	scan(L)
	if cam() then scan(cam()) end
	return function() for _, e in ipairs(off) do e.Enabled = true end end
end)]==])

I("visual", "Tắt bóng đổ", {"tat bong", "no shadows"}, [==[
L.GlobalShadows = false]==])

I("visual", "Độ sáng", {"do sang", "brightness"}, [==[
L.Brightness = __N__]==], 3, 0, 10)

I("visual", "Khôi phục ánh sáng", {"khoi phuc anh sang", "reset lighting"}, [==[
local o = _G.AI_L0
if o then for k, v in pairs(o) do L[k] = v end end]==])

I("visual", "X-ray (xuyên thấu map)", {"xray", "x ray", "nhin xuyen map"}, [==[
tg("xray", function()
	local list = {}
	for _, d in ipairs(W:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsA("Terrain") then
			local m = d:FindFirstAncestorOfClass("Model")
			if not (m and m:FindFirstChildOfClass("Humanoid")) then
				d.LocalTransparencyModifier = 0.6
				list[#list + 1] = d
			end
		end
	end
	return function() for _, d in ipairs(list) do d.LocalTransparencyModifier = 0 end end
end)]==])

I("visual", "Đèn pin", {"den pin", "flashlight"}, [==[
tg("flashlight", function()
	local c = lp.Character
	local hd = c and c:FindFirstChild("Head")
	if not hd then return function() end end
	local l = Instance.new("PointLight")
	l.Range = __N__
	l.Brightness = 3
	l.Parent = hd
	return kill(l)
end)]==], 60, 8, 200)

-- NHÂN VẬT
I("char", "Reset mặc định", {"reset", "mac dinh", "khoi phuc mac dinh"}, [==[
_G.AI_Stats = nil
local h = hum()
if h and _G.AI_Orig then for k, v in pairs(_G.AI_Orig) do h[k] = v end end
_G.AI_Orig = nil
W.Gravity = 196.2
cam().FieldOfView = 70]==])

I("char", "Hồi sinh (reset nhân vật)", {"respawn", "hoi sinh", "reset nhan vat", "tu sat"}, [==[
local h = hum()
if h then h.Health = 0 end]==])

I("char", "Tắt hết chức năng đang bật", {"tat het", "tat tat ca", "stop all"}, [==[
for k, v in pairs(_G) do
	if type(k) == "string" and k:sub(1, 5) == "AI_T_" and type(v) == "function" then
		pcall(v)
		_G[k] = nil
	end
end]==])

I("char", "Ẩn nhân vật (chỉ phía bạn)", {"an nhan vat", "an hinh", "invisible"}, [==[
tg("hidechar", function()
	local c = cn(RS.RenderStepped, function()
		local ch = lp.Character
		if ch then
			for _, d in ipairs(ch:GetDescendants()) do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
			end
		end
	end)
	return function()
		c()
		local ch = lp.Character
		if ch then
			for _, d in ipairs(ch:GetDescendants()) do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
			end
		end
	end
end)]==])

I("char", "Nhân vật cầu vồng", {"cau vong", "rainbow"}, [==[
tg("rainbow", function()
	local t = 0
	return cn(RS.Heartbeat, function(dt)
		t += dt * 0.5
		local col = Color3.fromHSV(t % 1, 1, 1)
		local c = lp.Character
		if c then
			for _, p in ipairs(c:GetChildren()) do
				if p:IsA("BasePart") then p.Color = col end
			end
		end
	end)
end)]==])

I("char", "Kích thước nhân vật", {"kich thuoc", "size", "to nhan vat"}, [==[
local h = hum()
if h then
	for _, n in ipairs({"BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale"}) do
		local v = h:FindFirstChild(n)
		if v then v.Value = __N__ end
	end
end]==], 1.5, 0.3, 5)

I("char", "Phát sáng (Neon)", {"phat sang", "neon"}, [==[
tg("neon", function()
	local old = {}
	local c = lp.Character
	if c then
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then old[p] = p.Material p.Material = Enum.Material.Neon end
		end
	end
	return function() for p, m in pairs(old) do if p.Parent then p.Material = m end end end
end)]==])

A("char", "Đổi màu nhân vật", {"doi mau", "mau nhan vat", "color"}, [==[
local m = {["do"] = {255, 50, 50}, red = {255, 50, 50}, cam = {255, 150, 40}, orange = {255, 150, 40}, vang = {255, 230, 50}, yellow = {255, 230, 50}, luc = {60, 220, 90}, green = {60, 220, 90}, xanh = {60, 220, 90}, duong = {60, 130, 255}, blue = {60, 130, 255}, tim = {160, 80, 230}, purple = {160, 80, 230}, hong = {255, 120, 190}, pink = {255, 120, 190}, den = {25, 25, 25}, black = {25, 25, 25}, trang = {245, 245, 245}, white = {245, 245, 245}}
local v = m["__NAME__"]
if not v then say("Màu hỗ trợ: đỏ, cam, vàng, lục, dương, tím, hồng, đen, trắng") return end
local c = lp.Character
if c then
	for _, p in ipairs(c:GetChildren()) do
		if p:IsA("BasePart") then p.Color = Color3.fromRGB(v[1], v[2], v[3]) end
	end
end]==], "word")

I("char", "Ẩn tên trên đầu", {"an ten", "hide name"}, [==[
local h = hum()
if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end]==])

I("char", "Gỡ phụ kiện", {"go phu kien", "bo phu kien", "remove accessories"}, [==[
local c = lp.Character
if c then
	for _, a in ipairs(c:GetChildren()) do
		if a:IsA("Accessory") then a:Destroy() end
	end
end]==])

I("char", "Dừng mọi animation", {"dung animation", "stop anim", "dung hoat anh"}, [==[
local h = hum()
local an = h and h:FindFirstChildOfClass("Animator")
if an then for _, t in ipairs(an:GetPlayingAnimationTracks()) do t:Stop() end end]==])

I("char", "Xem kiểu nhân vật (R6/R15)", {"kieu rig", "rig type", "r6 hay r15"}, [==[
local h = hum()
say(h and ("Kiểu nhân vật: " .. h.RigType.Name) or "Chưa có nhân vật")]==])

-- HIỆU NĂNG
I("perf", "Tăng FPS (giảm đồ họa)", {"tang fps", "fps boost", "giam do hoa", "giam lag", "chong lag"}, [==[
task.spawn(function()
	pcall(function() settings().Rendering.QualityLevel = 1 end)
	L.GlobalShadows = false
	local function fix(d)
		if d:IsA("BasePart") and not d:IsA("Terrain") then
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0
			d.CastShadow = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
			d.Enabled = false
		elseif d:IsA("PostEffect") then
			d.Enabled = false
		end
	end
	local n = 0
	for _, d in ipairs(W:GetDescendants()) do
		pcall(fix, d)
		n += 1
		if n % 400 == 0 then task.wait() end
	end
	for _, d in ipairs(L:GetDescendants()) do pcall(fix, d) end
	say("Đã giảm đồ họa để tăng FPS")
end)]==])

I("perf", "Tắt hạt & hiệu ứng", {"tat hat", "no particles", "tat hieu ung hat"}, [==[
task.spawn(function()
	local n = 0
	for _, d in ipairs(W:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Beam") then
			pcall(function() d.Enabled = false end)
		end
		n += 1
		if n % 500 == 0 then task.wait() end
	end
end)]==])

I("perf", "Chất lượng đồ họa", {"chat luong do hoa", "quality level"}, [==[
pcall(function() settings().Rendering.QualityLevel = __N__ end)]==], 1, 1, 21)

I("perf", "Giới hạn FPS", {"gioi han fps", "fps cap", "setfpscap", "mo khoa fps"}, [==[
if setfpscap then setfpscap(__N__) else say("Executor không hỗ trợ setfpscap") end]==], 60, 5, 999)

I("perf", "Tắt cỏ (terrain)", {"tat co", "no grass"}, [==[
if not pcall(function() W.Terrain.Decoration = false end) and sethiddenproperty then
	pcall(sethiddenproperty, W.Terrain, "Decoration", false)
end]==])

I("perf", "Tắt âm thanh game", {"tat am thanh", "mute", "tat nhac"}, [==[
tg("mute", function()
	local old = {}
	local function m(s)
		if s:IsA("Sound") then old[s] = s.Volume s.Volume = 0 end
	end
	for _, s in ipairs(game:GetDescendants()) do m(s) end
	local c = game.DescendantAdded:Connect(m)
	return function()
		c:Disconnect()
		for s, v in pairs(old) do if s.Parent then s.Volume = v end end
	end
end)]==])

I("perf", "Âm lượng", {"am luong", "volume"}, [==[
pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = __N__ / 100 end)]==], 50, 0, 100)

-- THÔNG TIN & HUD
I("info", "HUD FPS & ping", {"hien fps", "hien ping", "hud fps"}, [==[
hud("hud_fps", 6, function(dt)
	return "FPS " .. math.floor(1 / math.max(dt, 0.001)) .. " | Ping " .. math.floor(lp:GetNetworkPing() * 2000) .. "ms"
end)]==])

I("info", "HUD tọa độ", {"hien toa do", "hud toa do"}, [==[
hud("hud_pos", 28, function()
	local r = hrp()
	if not r then return "-" end
	local p = r.Position
	return "XYZ " .. math.floor(p.X) .. " " .. math.floor(p.Y) .. " " .. math.floor(p.Z)
end)]==])

I("info", "HUD tốc độ", {"hien toc do", "hud toc do"}, [==[
hud("hud_vel", 50, function()
	local r = hrp()
	if not r then return "-" end
	local v = r.AssemblyLinearVelocity
	return "Tốc độ " .. math.floor(Vector3.new(v.X, 0, v.Z).Magnitude) .. " st/s"
end)]==])

I("info", "HUD máu", {"hien mau", "hud mau"}, [==[
hud("hud_hp", 72, function()
	local h = hum()
	if not h then return "-" end
	return "Máu " .. math.floor(h.Health) .. "/" .. math.floor(h.MaxHealth)
end)]==])

I("info", "HUD thời gian chơi", {"hien thoi gian choi", "hud thoi gian"}, [==[
hud("hud_time", 94, function()
	local s = math.floor(W.DistributedGameTime)
	return "Đã chơi " .. math.floor(s / 3600) .. "h " .. math.floor(s / 60) % 60 .. "m " .. s % 60 .. "s"
end)]==])

I("info", "HUD đồng hồ", {"hien dong ho", "hud dong ho"}, [==[
hud("hud_clock", 116, function() return os.date("%H:%M:%S") end)]==])

I("info", "Thông tin server", {"thong tin server", "server info"}, [==[
local name = "?"
pcall(function() name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
say("Game: " .. name .. "\nNgười chơi: " .. #P:GetPlayers() .. "/" .. P.MaxPlayers .. "\nPlaceId: " .. game.PlaceId .. "\nJobId: " .. game.JobId .. "\nPing: " .. math.floor(lp:GetNetworkPing() * 2000) .. "ms")]==])

I("info", "Danh sách người chơi", {"danh sach nguoi choi", "players list"}, [==[
local t = {}
for _, p in ipairs(P:GetPlayers()) do t[#t + 1] = p.DisplayName .. " (@" .. p.Name .. ")" end
say("Có " .. #t .. " người chơi:\n" .. table.concat(t, "\n"))]==])

I("info", "Vị trí của tôi", {"toi dang o dau", "vi tri cua toi", "my position"}, [==[
local r = hrp()
if r then
	local p = r.Position
	say("Vị trí: " .. math.floor(p.X) .. ", " .. math.floor(p.Y) .. ", " .. math.floor(p.Z))
end]==])

A("info", "Thông tin người chơi", {"thong tin nguoi choi", "player info"}, [==[
local t = findp("__NAME__")
if not t then say("Không tìm thấy người chơi: __NAME__") return end
local r = hrp()
local tr = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
local d = (r and tr) and math.floor((r.Position - tr.Position).Magnitude) or "?"
say(t.DisplayName .. " (@" .. t.Name .. ")\nUserId: " .. t.UserId .. "\nTuổi tài khoản: " .. t.AccountAge .. " ngày\nĐội: " .. (t.Team and t.Team.Name or "không có") .. "\nKhoảng cách: " .. d)]==], "word")

I("info", "Người chơi gần nhất", {"nguoi gan nhat", "ai gan toi"}, [==[
local r = hrp()
local best, bd
for _, p in ipairs(P:GetPlayers()) do
	local tr = p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if r and tr then
		local m = (tr.Position - r.Position).Magnitude
		if not bd or m < bd then best, bd = p, m end
	end
end
say(best and (best.DisplayName .. " cách " .. math.floor(bd) .. " studs") or "Không có ai ở gần")]==])

I("info", "Danh sách tool đang có", {"danh sach tool", "liet ke tool", "toi co tool gi"}, [==[
local t = {}
for _, v in ipairs(lp.Backpack:GetChildren()) do t[#t + 1] = v.Name end
local c = lp.Character
if c then
	for _, v in ipairs(c:GetChildren()) do
		if v:IsA("Tool") then t[#t + 1] = v.Name .. " (đang cầm)" end
	end
end
say(#t > 0 and table.concat(t, ", ") or "Không có tool nào")]==])

I("info", "Giờ thực", {"gio thuc", "may gio", "real time"}, [==[
say(os.date("%H:%M:%S - %d/%m/%Y"))]==])

I("info", "Đếm số part trong map", {"dem part", "count parts", "so luong part"}, [==[
local n = 0
for _, d in ipairs(W:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
say("Số part trong map: " .. n)]==])

I("info", "Danh sách đội", {"danh sach doi", "teams"}, [==[
local t = {}
for _, tm in ipairs(game:GetService("Teams"):GetTeams()) do t[#t + 1] = tm.Name .. ": " .. #tm:GetPlayers() end
say(#t > 0 and table.concat(t, "\n") or "Game không có đội")]==])

I("info", "Copy JobId", {"copy jobid", "sao chep jobid"}, [==[
copy(game.JobId)]==])
I("info", "Copy PlaceId", {"copy placeid", "sao chep placeid"}, [==[
copy(game.PlaceId)]==])
I("info", "Copy tọa độ", {"copy toa do", "sao chep toa do"}, [==[
local r = hrp()
if r then
	local p = r.Position
	copy(math.floor(p.X) .. ", " .. math.floor(p.Y) .. ", " .. math.floor(p.Z))
end]==])

I("info", "Nhắc hẹn giờ", {"nhac nho", "hen gio", "nhac toi sau", "reminder"}, [==[
local m = __N__
say("Sẽ nhắc bạn sau " .. m .. " phút")
task.delay(m * 60, function()
	say("⏰ Hết " .. m .. " phút rồi!")
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = "LuauAI", Text = "Hết giờ!", Duration = 6})
	end)
end)]==], 5, 1, 600)

-- SERVER
I("server", "Vào lại server", {"rejoin", "vao lai", "join lai"}, [==[
game:GetService("TeleportService"):Teleport(game.PlaceId, lp)]==])

I("server", "Chống AFK", {"anti afk", "chong afk", "chong kick", "treo may", "afk"}, [==[
if _G.AI_AFK then return end
_G.AI_AFK = true
local VU = game:GetService("VirtualUser")
lp.Idled:Connect(function()
	VU:CaptureController()
	VU:ClickButton2(Vector2.new())
end)]==])

I("server", "Đổi sang server ít người", {"server it nguoi", "doi server", "server hop", "serverhop"}, (HOP:gsub("__ORDER__", "Asc")))
I("server", "Đổi sang server đông người", {"server dong nguoi", "server dong"}, (HOP:gsub("__ORDER__", "Desc")))

I("server", "Tự động vào lại khi bị kick", {"tu dong vao lai", "auto rejoin"}, [==[
tg("autorejoin", function()
	local ok, c = pcall(function()
		return game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(o)
			if o.Name == "ErrorPrompt" then
				task.wait(2)
				game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
			end
		end)
	end)
	if not ok then say("Không truy cập được CoreGui trên executor này") return function() end end
	return function() c:Disconnect() end
end)]==])

I("server", "Thoát game", {"thoat game", "exit game", "quit game"}, [==[
if not pcall(function() game:Shutdown() end) then lp:Kick("LuauAI: thoát game") end]==])

-- CÔNG CỤ & TƯƠNG TÁC
I("tool", "Cầm tất cả tool", {"cam tat ca", "equip all", "cam het do"}, [==[
local c = lp.Character
if c then
	for _, t in ipairs(lp.Backpack:GetChildren()) do
		if t:IsA("Tool") then t.Parent = c end
	end
end]==])

I("tool", "Cất tất cả tool", {"cat do", "unequip", "bo do"}, [==[
local h = hum()
if h then h:UnequipTools() end]==])

I("tool", "Tự động nhặt vật phẩm", {"tu dong nhat do", "auto collect", "auto pickup"}, [==[
if not firetouchinterest then say("Executor không hỗ trợ firetouchinterest") return end
tg("autocollect", function()
	local tools = {}
	local function add(d)
		if d:IsA("Tool") and d:FindFirstChild("Handle") and not P:GetPlayerFromCharacter(d.Parent) then tools[#tools + 1] = d end
	end
	for _, d in ipairs(W:GetDescendants()) do add(d) end
	local c1 = W.DescendantAdded:Connect(add)
	local on = true
	task.spawn(function()
		while on do
			local r = hrp()
			if r then
				for i = #tools, 1, -1 do
					local t = tools[i]
					local hd = t.Parent and t:FindFirstChild("Handle")
					if not hd or not t:IsDescendantOf(W) or P:GetPlayerFromCharacter(t.Parent) then
						table.remove(tools, i)
					elseif (hd.Position - r.Position).Magnitude < 40 then
						firetouchinterest(r, hd, 0)
						firetouchinterest(r, hd, 1)
					end
				end
			end
			task.wait(0.5)
		end
	end)
	return function() on = false c1:Disconnect() end
end)]==])

I("tool", "Tự động tương tác (ProximityPrompt)", {"tu dong tuong tac", "auto prompt", "auto interact"}, [==[
if not fireproximityprompt then say("Executor không hỗ trợ fireproximityprompt") return end
tg("autoprompt", function()
	local ps = {}
	local function add(d) if d:IsA("ProximityPrompt") then ps[#ps + 1] = d end end
	for _, d in ipairs(W:GetDescendants()) do add(d) end
	local c = W.DescendantAdded:Connect(add)
	local on = true
	task.spawn(function()
		while on do
			local r = hrp()
			if r then
				for i = #ps, 1, -1 do
					local p = ps[i]
					if not p.Parent then
						table.remove(ps, i)
					elseif p.Enabled then
						local a = p.Parent
						local pos = a:IsA("BasePart") and a.Position or (a:IsA("Attachment") and a.WorldPosition)
						if pos and (pos - r.Position).Magnitude <= p.MaxActivationDistance then fireproximityprompt(p) end
					end
				end
			end
			task.wait(0.3)
		end
	end)
	return function() on = false c:Disconnect() end
end)]==])

I("tool", "Prompt tức thì (bỏ thời gian giữ)", {"prompt tuc thi", "instant prompt", "giu nhanh"}, [==[
tg("instantprompt", function()
	local function fix(d) if d:IsA("ProximityPrompt") then d.HoldDuration = 0 end end
	for _, d in ipairs(W:GetDescendants()) do fix(d) end
	return cn(W.DescendantAdded, fix)
end)]==])

I("tool", "Tăng tầm tương tác", {"tam tuong tac", "prompt range", "interact range"}, [==[
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("ProximityPrompt") then d.MaxActivationDistance = __N__ end
end]==], 30, 5, 500)

I("tool", "Auto click", {"auto click", "autoclick", "tu dong click"}, [==[
tg("autoclick", function()
	local on = true
	local delay = 1 / __N__
	task.spawn(function()
		local VU = game:GetService("VirtualUser")
		while on do
			if mouse1click then
				pcall(mouse1click)
			else
				pcall(function() VU:CaptureController() VU:ClickButton1(Vector2.new(0, 0)) end)
			end
			task.wait(delay)
		end
	end)
	return function() on = false end
end)]==], 10, 1, 50)

I("tool", "Công cụ xóa vật thể (cục bộ)", {"cong cu xoa", "delete tool", "xoa vat the"}, [==[
local bp = lp:WaitForChild("Backpack")
local old = bp:FindFirstChild("XoaVatThe")
if old then old:Destroy() end
local t = Instance.new("Tool")
t.Name = "XoaVatThe"
t.RequiresHandle = false
t.CanBeDropped = false
t.Activated:Connect(function()
	local tgt = lp:GetMouse().Target
	if tgt and not tgt:IsA("Terrain") and not (lp.Character and tgt:IsDescendantOf(lp.Character)) then tgt:Destroy() end
end)
t.Parent = bp]==])

I("tool", "Bỏ va chạm vật thể gần", {"bo va cham", "xoa va cham", "no collision map"}, [==[
local r = hrp()
if r then
	for _, p in ipairs(W:GetPartBoundsInRadius(r.Position, __N__)) do
		if not (lp.Character and p:IsDescendantOf(lp.Character)) then p.CanCollide = false end
	end
end]==], 20, 3, 200)

---------------------------------------------------------------- NLP
local groups = {
	a = "àáạảãâầấậẩẫăằắặẳẵÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ",
	e = "èéẹẻẽêềếệểễÈÉẸẺẼÊỀẾỆỂỄ",
	i = "ìíịỉĩÌÍỊỈĨ",
	o = "òóọỏõôồốộổỗơờớợởỡÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ",
	u = "ùúụủũưừứựửữÙÚỤỦŨƯỪỨỰỬỮ",
	y = "ỳýỵỷỹỲÝỴỶỸ",
	d = "đĐ",
}
local map = {}
for base, chars in pairs(groups) do
	for _, cp in utf8.codes(chars) do map[cp] = base end
end

local function normalize(s)
	local ok, out = pcall(function()
		local t = {}
		for _, cp in utf8.codes(s) do t[#t + 1] = map[cp] or utf8.char(cp) end
		return table.concat(t)
	end)
	if ok then s = out end
	s = s:lower()
	s = s:gsub("[^%w%._%-%s]", " ")
	s = s:gsub("%s+", " ")
	return " " .. s .. " "
end

local function blank(text, a, b)
	return text:sub(1, a - 1) .. string.rep(" ", b - a + 1) .. text:sub(b + 1)
end

local FLAT, HAY = {}, {}
for _, it in ipairs(INTENTS) do
	HAY[it] = normalize(it.name .. " " .. table.concat(it.keys, " "))
	for _, k in ipairs(it.keys) do FLAT[#FLAT + 1] = {k = k, it = it} end
end
table.sort(FLAT, function(x, y) return #x.k > #y.k end)

local function parse(raw)
	local text = normalize(raw)
	local found, missing, used = {}, {}, {}
	for _, e in ipairs(FLAT) do
		local it = e.it
		if not used[it] then
			local a, b = text:find(" " .. e.k .. " ", 1, true)
			if a then
				used[it] = true
				text = blank(text, a, b)
				local val
				if it.arg == "word" then
					local s, f, w = text:find("(%S+)", b + 1)
					if s then val = w text = blank(text, s, f) end
				elseif it.arg == "xyz" then
					local nums, pos = {}, b + 1
					while #nums < 3 do
						local s, f, n = text:find("(%-?%d+%.?%d*)", pos)
						if not s or s > b + 60 then break end
						nums[#nums + 1] = n
						text = blank(text, s, f)
						pos = f + 1
					end
					if #nums == 3 then val = table.concat(nums, ", ") end
				elseif it.def then
					local s, f, num = text:find("(%d+%.?%d*)", b + 1)
					if s and f <= b + 14 then
						local words = 0
						for _ in text:sub(b + 1, s - 1):gmatch("%a+") do words += 1 end
						if words > 1 then s = nil end
					else
						s = nil
					end
					if s then
						val = tonumber(num)
						text = blank(text, s, f)
					else
						local before
						for n in text:sub(math.max(1, a - 12), a - 1):gmatch("%d+%.?%d*") do before = n end
						val = tonumber(before) or it.def
					end
					val = math.clamp(val, it.min, it.max)
				end
				if it.arg and val == nil then
					missing[#missing + 1] = it.name
				else
					local code = it.code
					if val ~= nil then
						local sv = tostring(val)
						code = code:gsub("__N__", function() return sv end)
						code = code:gsub("__NAME__", function() return sv end)
					end
					local label = it.name
					if val ~= nil then label ..= " (" .. tostring(val) .. ")" end
					found[#found + 1] = {pos = a, label = label, code = code}
				end
			end
		end
	end
	table.sort(found, function(x, y) return x.pos < y.pos end)
	return found, missing, text
end

local function suggest(text)
	local words = {}
	for w in text:gmatch("%a%a%a%a+") do words[#words + 1] = w end
	local scored = {}
	for _, it in ipairs(INTENTS) do
		local s = 0
		for _, w in ipairs(words) do
			if HAY[it]:find(w, 1, true) then s += 1 end
		end
		if s > 0 then scored[#scored + 1] = {it = it, s = s} end
	end
	table.sort(scored, function(x, y) return x.s > y.s end)
	local out = {}
	for i = 1, math.min(4, #scored) do
		out[i] = scored[i].it.name .. " (" .. scored[i].it.keys[1] .. ")"
	end
	return out
end

local function listCat(c)
	local t = {}
	for _, it in ipairs(INTENTS) do
		if it.cat == c.id then t[#t + 1] = "• " .. it.name .. " — " .. it.keys[1] end
	end
	return c.label .. " (" .. #t .. "):\n" .. table.concat(t, "\n")
end

---------------------------------------------------------------- GUI
for _, root in ipairs({CoreGui, lp:FindFirstChild("PlayerGui")}) do
	pcall(function()
		local old = root and root:FindFirstChild("LuauAI_GUI")
		if old then old:Destroy() end
	end)
end
pcall(function()
	if gethui then
		local old = gethui():FindFirstChild("LuauAI_GUI")
		if old then old:Destroy() end
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "LuauAI_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
local okParent = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
if not okParent or not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

local function round(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end
local function pad(o, p)
	local u = Instance.new("UIPadding")
	u.PaddingTop, u.PaddingBottom = UDim.new(0, p), UDim.new(0, p)
	u.PaddingLeft, u.PaddingRight = UDim.new(0, p), UDim.new(0, p)
	u.Parent = o
end

local FULL_H = 370
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 330, 0, FULL_H)
main.Position = UDim2.new(0.5, -165, 0.08, 0)
main.BackgroundColor3 = Color3.fromRGB(24, 25, 33)
main.BorderSizePixel = 0
main.Parent = gui
round(main, 10)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 32)
top.BackgroundColor3 = Color3.fromRGB(38, 40, 54)
top.BorderSizePixel = 0
top.Parent = main
round(top, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🤖 LuauAI v2"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local function mkBtn(parent, text, color, pos, size, ts)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = ts or 12
	b.BorderSizePixel = 0
	b.Parent = parent
	round(b, 6)
	return b
end

local minBtn = mkBtn(top, "–", Color3.fromRGB(80, 84, 110), UDim2.new(1, -62, 0, 4), UDim2.new(0, 26, 0, 24), 16)
local closeBtn = mkBtn(top, "X", Color3.fromRGB(200, 70, 70), UDim2.new(1, -32, 0, 4), UDim2.new(0, 26, 0, 24))

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -32)
body.Position = UDim2.new(0, 0, 0, 32)
body.BackgroundTransparency = 1
body.Parent = main

local chat = Instance.new("ScrollingFrame")
chat.Size = UDim2.new(1, -12, 1, -116)
chat.Position = UDim2.new(0, 6, 0, 6)
chat.BackgroundTransparency = 1
chat.BorderSizePixel = 0
chat.ScrollBarThickness = 3
chat.CanvasSize = UDim2.new()
chat.AutomaticCanvasSize = Enum.AutomaticSize.Y
chat.Parent = body
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = chat

local chips = Instance.new("ScrollingFrame")
chips.Size = UDim2.new(1, -12, 0, 26)
chips.Position = UDim2.new(0, 6, 1, -106)
chips.BackgroundTransparency = 1
chips.BorderSizePixel = 0
chips.ScrollBarThickness = 0
chips.CanvasSize = UDim2.new()
chips.AutomaticCanvasSize = Enum.AutomaticSize.X
chips.ScrollingDirection = Enum.ScrollingDirection.X
chips.Parent = body
local chipLayout = Instance.new("UIListLayout")
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.Padding = UDim.new(0, 4)
chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipLayout.Parent = chips

local runBtn = mkBtn(body, "▶ Chạy", Color3.fromRGB(46, 160, 90), UDim2.new(0, 6, 1, -76), UDim2.new(0.33, -8, 0, 28))
local copyBtn = mkBtn(body, "📋 Copy", Color3.fromRGB(52, 120, 246), UDim2.new(0.33, 2, 1, -76), UDim2.new(0.33, -4, 0, 28))
local clearBtn = mkBtn(body, "🗑 Xóa", Color3.fromRGB(110, 114, 140), UDim2.new(0.66, 0, 1, -76), UDim2.new(0.34, -6, 0, 28))

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -80, 0, 38)
box.Position = UDim2.new(0, 6, 1, -44)
box.BackgroundColor3 = Color3.fromRGB(38, 40, 54)
box.TextColor3 = Color3.new(1, 1, 1)
box.PlaceholderText = "VD: bay 80 và esp, tp đến Tên..."
box.PlaceholderColor3 = Color3.fromRGB(140, 144, 165)
box.Text = ""
box.ClearTextOnFocus = false
box.TextWrapped = true
box.Font = Enum.Font.Gotham
box.TextSize = 13
box.TextXAlignment = Enum.TextXAlignment.Left
box.Parent = body
round(box, 6)
pad(box, 6)

local sendBtn = mkBtn(body, "Gửi", Color3.fromRGB(52, 120, 246), UDim2.new(1, -68, 1, -44), UDim2.new(0, 62, 0, 38), 13)

local dragging, dragStart, startPos
top.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging, dragStart, startPos = true, i.Position, main.Position
		i.Changed:Connect(function()
			if i.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
		local d = i.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

local minimized = false
minBtn.Activated:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = minimized and UDim2.new(0, 330, 0, 32) or UDim2.new(0, 330, 0, FULL_H)
end)
closeBtn.Activated:Connect(function()
	_G.AI_Say = nil
	gui:Destroy()
end)

local order = 0
local lastCode

local function scrollDown()
	task.spawn(function()
		RS.Heartbeat:Wait()
		chat.CanvasPosition = Vector2.new(0, 99999)
	end)
end

local function bubble(who, isCode)
	order += 1
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -6, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundColor3 = (who == "user") and Color3.fromRGB(52, 120, 246)
		or (isCode and Color3.fromRGB(16, 17, 24) or Color3.fromRGB(45, 47, 62))
	l.TextColor3 = isCode and Color3.fromRGB(170, 235, 190) or Color3.new(1, 1, 1)
	l.Font = isCode and Enum.Font.Code or Enum.Font.Gotham
	l.TextSize = isCode and 11 or 13
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = " "
	l.LayoutOrder = order
	l.Parent = chat
	round(l, 8)
	pad(l, 7)
	return l
end

local function reveal(lbl, text, pat, delay)
	local acc = ""
	for chunk in text:gmatch(pat) do
		if chunk ~= "" then
			acc ..= chunk
			lbl.Text = acc
			scrollDown()
			task.wait(delay)
		end
	end
	lbl.Text = text
	scrollDown()
end

local function bot(text)
	reveal(bubble("bot"), text, "%S+%s*", #text > 400 and 0.005 or 0.02)
end
local function codeBubble(code)
	local _, n = code:gsub("\n", "")
	reveal(bubble("bot", true), code, "[^\n]*\n?", n > 40 and 0.004 or 0.03)
end
local function user(text) bubble("user").Text = text scrollDown() end

_G.AI_Say = function(t) task.spawn(bot, tostring(t)) end

local function clearChat()
	for _, c in ipairs(chat:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	lastCode = nil
end

local function runCode()
	if not lastCode then bot("Chưa có script nào.") return end
	if not loadstring then bot("Executor không hỗ trợ loadstring, hãy dùng Copy.") return end
	local f, err = loadstring(lastCode)
	if not f then bot("Lỗi cú pháp: " .. tostring(err)) return end
	local ok, e = pcall(f)
	bot(ok and "Đã chạy!" or ("Lỗi: " .. tostring(e)))
end

local function copyCode()
	if not lastCode then bot("Chưa có script nào.") return end
	local fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
	if fn then
		fn(lastCode)
		bot("Đã copy!")
	else
		bot("Executor không hỗ trợ clipboard.")
	end
end

local HELP = "Mình có " .. #INTENTS .. " chức năng. Bấm nút nhóm bên dưới để xem danh sách, hoặc cứ nói tự nhiên, ví dụ:\n• bay 80 và noclip\n• tốc độ 100, nhảy cao 120\n• tp đến Tên\nBay/noclip/esp... nói lần nữa để tắt, 'tắt hết' để tắt tất cả, 'reset' để về mặc định."

local function respond(raw)
	local found, missing, rest = parse(raw)

	if #found > 0 then
		local names, blocks = {}, {}
		for _, r in ipairs(found) do
			names[#names + 1] = r.label
			blocks[#blocks + 1] = "task.spawn(function()\n" .. r.code .. "\nend)"
		end
		local body = table.concat(blocks, "\n\n")
		lastCode = PRELUDE .. "\n" .. body
		bot("Đang viết: " .. table.concat(names, ", "))
		codeBubble(body)
		if loadstring then
			local f, err = loadstring(lastCode)
			bot(f and "Cú pháp hợp lệ. Bấm Chạy để dùng." or ("Lỗi cú pháp: " .. tostring(err)))
		else
			bot("Bấm Copy rồi dán vào executor.")
		end
		if #missing > 0 then bot("Thiếu thông tin cho: " .. table.concat(missing, ", ")) end
		return
	end

	if #missing > 0 then
		bot("Thiếu thông tin cho: " .. table.concat(missing, ", ") .. ". Ví dụ: tp đến Tên, tp tọa độ 0 50 0")
		return
	end

	local t = rest
	local function has(...)
		for _, k in ipairs({...}) do
			if t:find(k, 1, true) then return true end
		end
		return false
	end

	if has("giup", "help", "menu", "chuc nang", "danh sach") then
		for _, c in ipairs(CATS) do
			for _, k in ipairs(c.kw) do
				if t:find(k, 1, true) then bot(listCat(c)) return end
			end
		end
		bot(HELP)
	elseif has(" chay ", " run ", "thuc thi") then
		runCode()
	elseif has("copy", "sao chep") then
		copyCode()
	elseif has(" xoa ", " clear ") then
		clearChat()
	else
		local sug = suggest(t)
		if #sug > 0 then
			bot("Mình chưa chắc ý bạn. Có phải: " .. table.concat(sug, "; ") .. "?")
		else
			bot("Mình chưa hiểu. Gõ 'giúp' để xem danh sách.")
		end
	end
end

local busy = false
local function submit(raw, shown)
	if busy then return end
	busy = true
	user(shown or raw)
	task.spawn(function()
		local ok, err = pcall(respond, raw)
		if not ok then bot("Lỗi: " .. tostring(err)) end
		busy = false
	end)
end

local function send()
	local raw = box.Text
	if not raw:match("%S") then return end
	box.Text = ""
	submit(raw)
end

for i, c in ipairs(CATS) do
	local b = Instance.new("TextButton")
	b.Text = c.label
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.new(0, 0, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(56, 60, 82)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.BorderSizePixel = 0
	b.LayoutOrder = i
	b.Parent = chips
	round(b, 13)
	pad(b, 2)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	p.Parent = b
	b.Activated:Connect(function() submit("giup " .. c.kw[1], c.label) end)
end

sendBtn.Activated:Connect(send)
box.FocusLost:Connect(function(enter) if enter then send() end end)
runBtn.Activated:Connect(function() task.spawn(runCode) end)
copyBtn.Activated:Connect(function() task.spawn(copyCode) end)
clearBtn.Activated:Connect(clearChat)

task.spawn(function() bot("Xin chào! Mình có " .. #INTENTS .. " chức năng. Bấm nhóm bên dưới hoặc nói thẳng điều bạn cần.") end)
