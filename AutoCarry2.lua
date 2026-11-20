--[[
    Auto Carry v2 | Roblox Mobile | Luau
    - Zero-delay follow (Stepped + RenderStepped)
    - Modes: all players in turn / other teams only / selected list
    - ESP: box + tracer + names (team colour), distance limit
    - Virtual tap signal (on/off, interval)
    - Translucent, draggable, lockable GUI; collapses to 2 buttons
    - Languages: English (UK), Tiếng Việt (VN)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- Clean up an older instance
local genv = (getgenv and getgenv()) or _G
if genv.__AutoCarry then pcall(genv.__AutoCarry) end

local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

------------------------------------------------------------------ Strings
local STR = {
	en = {
		title = "Auto Carry", tab_main = "Main", tab_players = "Players", tab_esp = "ESP", tab_style = "Customise",
		enable = "Auto Carry", on = "ON", off = "OFF", mode = "Target mode",
		mode_all = "All players (in turn)", mode_team = "Other teams only", mode_list = "Selected list",
		duration = "Time per player (s), 0 = unlimited", distance = "Distance", height = "Height",
		skipdead = "Skip dead players", refresh = "Refresh", all = "Select all", clear = "Clear",
		transparency = "Transparency", accent = "Accent colour", scale = "UI scale",
		language = "Language", target = "Target", none = "None",
		lock = "Lock GUI position",
		esp = "ESP", esp_box = "Box", esp_tracer = "Tracer", esp_name = "Names", esp_dist = "ESP distance",
		tap = "Send tap signal", tap_int = "Tap interval (s)",
	},
	vi = {
		title = "Tự động Carry", tab_main = "Chính", tab_players = "Người chơi", tab_esp = "ESP", tab_style = "Tuỳ chỉnh",
		enable = "Tự động Carry", on = "BẬT", off = "TẮT", mode = "Chế độ mục tiêu",
		mode_all = "Tất cả (lần lượt)", mode_team = "Chỉ team khác", mode_list = "Danh sách đã chọn",
		duration = "Thời gian mỗi người (giây), 0 = vô hạn", distance = "Khoảng cách", height = "Độ cao",
		skipdead = "Bỏ qua người đã chết", refresh = "Làm mới", all = "Chọn tất cả", clear = "Bỏ chọn",
		transparency = "Độ trong suốt", accent = "Màu chủ đạo", scale = "Cỡ giao diện",
		language = "Ngôn ngữ", target = "Mục tiêu", none = "Không có",
		lock = "Khoá vị trí GUI",
		esp = "ESP", esp_box = "Khung", esp_tracer = "Tia", esp_name = "Tên", esp_dist = "Khoảng cách ESP",
		tap = "Gửi tín hiệu chạm", tap_int = "Chu kỳ chạm (giây)",
	},
}

------------------------------------------------------------------ State
local S = {
	Enabled = false,
	Mode = "All", -- "All" | "Team" | "List"
	Duration = 10,
	Distance = 1.5,
	Height = 0,
	SkipDead = true,
	Lang = "en",
	Transparency = 0.3,
	Accent = Color3.fromRGB(0, 170, 255),
	Scale = 1,
	Selected = {},
	Locked = false,
	ESP = false, ESPBox = true, ESPTracer = true, ESPName = true, ESPDist = 500,
	Tap = false, TapInterval = 0.5,
}
local current, startT = nil, 0

local function L(k) return STR[S.Lang][k] or k end

------------------------------------------------------------------ Carry logic
local function valid(p)
	if not p or p == LP then return false end
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not (h and r) then return false end
	if S.SkipDead and h.Health <= 0 then return false end
	return true
end

local function inPool(p)
	if S.Mode == "Team" then
		if LP.Team and p.Team == LP.Team then return false end
	elseif S.Mode == "List" then
		if not S.Selected[p.UserId] then return false end
	end
	return true
end

local function pickNext()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and inPool(p) and valid(p) then list[#list + 1] = p end
	end
	if #list == 0 then return nil end
	local idx = 0
	for i, p in ipairs(list) do
		if p == current then idx = i break end
	end
	return list[idx % #list + 1]
end

local function step()
	if not S.Enabled then return end
	local myChar = LP.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end

	local now = os.clock()
	local expired = S.Duration > 0 and (now - startT) >= S.Duration
	if (not current) or expired or not valid(current) or not inPool(current) then
		current = pickNext()
		startT = now
	end

	if current then
		local tr = current.Character and current.Character:FindFirstChild("HumanoidRootPart")
		if tr then
			myRoot.CFrame = tr.CFrame * CFrame.new(0, S.Height, S.Distance)
			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

connect(RunService.Stepped, step)
connect(RunService.RenderStepped, step)

------------------------------------------------------------------ GUI helpers
local R = {}
local rebuildPlayers
local function bind(fn) R[#R + 1] = fn fn() end
local function refreshAll()
	for _, f in ipairs(R) do f() end
	if rebuildPlayers then rebuildPlayers() end
end
local function tr(d) return math.clamp(S.Transparency + (d or 0), 0, 0.95) end

local PANEL = Color3.fromRGB(40, 40, 52)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.SourceSansBold

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	if parent then i.Parent = parent end
	return i
end
local function corner(i, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, i) end

local function mountGui(g)
	if syn and syn.protect_gui then pcall(syn.protect_gui, g) end
	local ok = pcall(function() g.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
	if not ok or not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
end

local gui = new("ScreenGui", {
	Name = "AutoCarryUI", ResetOnSpawn = false, DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
mountGui(gui)

local espGui = new("ScreenGui", {
	Name = "AutoCarryESP", ResetOnSpawn = false, DisplayOrder = 998,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
mountGui(espGui)

-- Drag helper (touch + mouse). Returns a function telling whether the last press became a drag.
local function makeDrag(handle, target)
	local dragging, moved, dStart, dPos = false, false, nil, nil
	connect(handle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, moved, dStart, dPos = true, false, i.Position, target.Position
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = i.Position - dStart
			if d.Magnitude > 6 then moved = true end
			if moved and not S.Locked then
				target.Position = UDim2.new(dPos.X.Scale, dPos.X.Offset + d.X, dPos.Y.Scale, dPos.Y.Offset + d.Y)
			end
		end
	end)
	connect(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	return function() return moved end
end

------------------------------------------------------------------ Window
local main = new("Frame", {
	Size = UDim2.fromOffset(320, 380), Position = UDim2.fromOffset(16, 60),
	BackgroundColor3 = Color3.fromRGB(18, 18, 24), BorderSizePixel = 0, Active = true,
}, gui)
corner(main, 12)
local stroke = new("UIStroke", { Thickness = 1.5 }, main)
local uiscale = new("UIScale", {}, main)
bind(function()
	main.BackgroundTransparency = tr(0)
	stroke.Color = S.Accent
	stroke.Transparency = tr(-0.1)
	uiscale.Scale = S.Scale
end)

local titleBar = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 }, main)
local titleLbl = new("TextLabel", {
	Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
	Font = FONT, TextSize = 18, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)
bind(function() titleLbl.Text = L("title") end)

local function smallBtn(xOff)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, xOff, 0.5, -12),
		Font = FONT, TextSize = 16, TextColor3 = WHITE, BorderSizePixel = 0,
	}, titleBar)
	corner(b, 6)
	bind(function() b.BackgroundColor3 = PANEL b.BackgroundTransparency = tr(0.1) end)
	return b
end
local lockBtn = smallBtn(-100)
local minBtn = smallBtn(-68)
local closeBtn = smallBtn(-36)
minBtn.Text = "-"
closeBtn.Text = "X"
bind(function() lockBtn.Text = S.Locked and "🔒" or "🔓" end)
connect(lockBtn.Activated, function() S.Locked = not S.Locked refreshAll() end)

makeDrag(titleBar, main)

local body = new("Frame", {
	Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1,
}, main)

-- Collapsed mode: only two buttons (open/close + off)
local mini = new("Frame", {
	Size = UDim2.fromOffset(76, 36), Position = main.Position, BackgroundTransparency = 1, Visible = false,
}, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, mini)

local function miniBtn(text)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(34, 36), Text = text, Font = FONT, TextSize = 18, TextColor3 = WHITE, BorderSizePixel = 0,
	}, mini)
	corner(b, 10)
	local st = new("UIStroke", { Thickness = 1.5 }, b)
	bind(function()
		b.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
		b.BackgroundTransparency = tr(0)
		st.Color = S.Accent
		st.Transparency = tr(-0.1)
	end)
	return b
end
local openBtn = miniBtn("+")
local offBtn = miniBtn("X")
local openMoved = makeDrag(openBtn, mini)

local minimized = false
local function setCollapsed(c)
	minimized = c
	if c then
		mini.Position = main.Position
		main.Visible = false
		mini.Visible = true
	else
		main.Position = mini.Position
		main.Visible = true
		mini.Visible = false
	end
end
connect(minBtn.Activated, function() setCollapsed(true) end)
connect(openBtn.Activated, function()
	if not openMoved() then setCollapsed(false) end
end)

------------------------------------------------------------------ Components
local function button(parent, textFn, cb, h)
	local b = new("TextButton", {
		Size = UDim2.new(1, -6, 0, h or 32), Font = FONT, TextSize = 16, TextColor3 = WHITE, BorderSizePixel = 0,
	}, parent)
	corner(b, 8)
	bind(function() b.Text = textFn() b.BackgroundColor3 = PANEL b.BackgroundTransparency = tr(0.15) end)
	connect(b.Activated, cb)
	return b
end

local function sectionLabel(parent, key)
	local l = new("TextLabel", {
		Size = UDim2.new(1, -6, 0, 20), BackgroundTransparency = 1, Font = FONT, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 190, 205),
	}, parent)
	bind(function() l.Text = L(key) end)
end

local function toggle(parent, key, get, set)
	local b = new("TextButton", {
		Size = UDim2.new(1, -6, 0, 34), Font = FONT, TextSize = 16, TextColor3 = WHITE, BorderSizePixel = 0,
	}, parent)
	corner(b, 8)
	bind(function()
		b.Text = L(key) .. ": " .. (get() and L("on") or L("off"))
		b.BackgroundColor3 = get() and S.Accent or PANEL
		b.BackgroundTransparency = tr(0.15)
	end)
	connect(b.Activated, function() set(not get()) refreshAll() end)
end

local function radio(parent, key, value)
	local b = new("TextButton", {
		Size = UDim2.new(1, -6, 0, 30), Font = FONT, TextSize = 15, TextColor3 = WHITE, BorderSizePixel = 0,
	}, parent)
	corner(b, 8)
	bind(function()
		b.Text = ((S.Mode == value) and "(o) " or "(  ) ") .. L(key)
		b.BackgroundColor3 = (S.Mode == value) and S.Accent or PANEL
		b.BackgroundTransparency = tr(0.15)
	end)
	connect(b.Activated, function()
		S.Mode = value
		current = nil
		refreshAll()
	end)
end

local function numInput(parent, key, get, set)
	local row = new("Frame", { Size = UDim2.new(1, -6, 0, 44), BorderSizePixel = 0 }, parent)
	corner(row, 8)
	local lab = new("TextLabel", {
		Size = UDim2.new(1, -86, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
		Font = FONT, TextSize = 14, TextColor3 = WHITE, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local box = new("TextBox", {
		Size = UDim2.fromOffset(64, 28), Position = UDim2.new(1, -72, 0.5, -14), Font = FONT, TextSize = 16,
		TextColor3 = WHITE, ClearTextOnFocus = false, BorderSizePixel = 0, Text = tostring(get()),
	}, row)
	corner(box, 6)
	bind(function()
		lab.Text = L(key)
		row.BackgroundColor3 = PANEL
		row.BackgroundTransparency = tr(0.15)
		box.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
		box.BackgroundTransparency = tr(0.1)
	end)
	connect(box.FocusLost, function()
		local n = tonumber(box.Text)
		if n then set(math.max(0, n)) startT = os.clock() end
		box.Text = tostring(get())
	end)
end

local function slider(parent, key, min, max, dec, get, set)
	local h = new("Frame", { Size = UDim2.new(1, -6, 0, 46), BorderSizePixel = 0 }, parent)
	corner(h, 8)
	local lab = new("TextLabel", {
		Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 18), BackgroundTransparency = 1,
		Font = FONT, TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
	}, h)
	local bar = new("TextButton", {
		Text = "", AutoButtonColor = false, Position = UDim2.new(0, 10, 0, 29), Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = Color3.fromRGB(70, 70, 84), BorderSizePixel = 0,
	}, h)
	corner(bar, 5)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, bar)
	corner(fill, 5)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, bar)
	corner(knob, 9)
	bind(function()
		local a = math.clamp((get() - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		fill.BackgroundColor3 = S.Accent
		lab.Text = L(key) .. ": " .. string.format("%." .. dec .. "f", get())
		h.BackgroundColor3 = PANEL
		h.BackgroundTransparency = tr(0.15)
	end)

	local drag = false
	local function upd(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local m = 10 ^ dec
		set(math.floor((min + (max - min) * a) * m + 0.5) / m)
		refreshAll()
	end
	connect(bar.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = true
			parent.ScrollingEnabled = false
			upd(i.Position.X)
		end
	end)
	connect(UIS.InputChanged, function(i)
		if drag and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			upd(i.Position.X)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if drag and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1) then
			drag = false
			parent.ScrollingEnabled = true
		end
	end)
end

------------------------------------------------------------------ Tabs / pages
local curTab = 1
local pages = {}

local tabBar = new("Frame", { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 2), BackgroundTransparency = 1 }, body)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, tabBar)

local function newPage()
	local f = new("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -68), Position = UDim2.fromOffset(6, 36), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Visible = false,
	}, body)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	pages[#pages + 1] = f
	return f
end

local pMain, pPlayers, pESP, pStyle = newPage(), newPage(), newPage(), newPage()

local function showTab(n)
	curTab = n
	for i, p in ipairs(pages) do p.Visible = (i == n) end
	refreshAll()
end

for i, key in ipairs({ "tab_main", "tab_players", "tab_esp", "tab_style" }) do
	local b = new("TextButton", {
		Size = UDim2.new(0.25, -3, 1, 0), Font = FONT, TextSize = 14, TextColor3 = WHITE, BorderSizePixel = 0,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tabBar)
	corner(b, 8)
	bind(function()
		b.Text = L(key)
		b.BackgroundColor3 = (curTab == i) and S.Accent or PANEL
		b.BackgroundTransparency = tr(0.1)
	end)
	connect(b.Activated, function() showTab(i) end)
end

local status = new("TextLabel", {
	Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0, 6, 1, -28), BackgroundTransparency = 1,
	Font = FONT, TextSize = 14, TextColor3 = Color3.fromRGB(200, 200, 215),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, body)

------------------------------------------------------------------ Main page
toggle(pMain, "enable", function() return S.Enabled end, function(v)
	S.Enabled = v
	current = nil
	startT = os.clock()
end)
sectionLabel(pMain, "mode")
radio(pMain, "mode_all", "All")
radio(pMain, "mode_team", "Team")
radio(pMain, "mode_list", "List")
numInput(pMain, "duration", function() return S.Duration end, function(v) S.Duration = v end)
slider(pMain, "distance", -15, 20, 1, function() return S.Distance end, function(v) S.Distance = v end)
slider(pMain, "height", -15, 20, 1, function() return S.Height end, function(v) S.Height = v end)
toggle(pMain, "skipdead", function() return S.SkipDead end, function(v) S.SkipDead = v end)
toggle(pMain, "tap", function() return S.Tap end, function(v) S.Tap = v end)
numInput(pMain, "tap_int", function() return S.TapInterval end, function(v) S.TapInterval = math.max(0.05, v) end)

------------------------------------------------------------------ Players page
do
	local row = new("Frame", { Size = UDim2.new(1, -6, 0, 32), BackgroundTransparency = 1 }, pPlayers)
	new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -3, 1, 0), CellPadding = UDim2.fromOffset(4, 0) }, row)

	local listBox = new("Frame", {
		Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2,
	}, pPlayers)
	new("UIListLayout", { Padding = UDim.new(0, 4) }, listBox)

	rebuildPlayers = function()
		for _, c in ipairs(listBox:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP then
				local b = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, Font = FONT, TextSize = 15,
					TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, listBox)
				new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
				corner(b, 8)
				local function paint()
					local sel = S.Selected[p.UserId]
					b.BackgroundColor3 = sel and S.Accent or PANEL
					b.BackgroundTransparency = tr(0.15)
					b.Text = (sel and "[x] " or "[  ] ") .. p.DisplayName .. " (@" .. p.Name .. ")"
				end
				paint()
				b.Activated:Connect(function()
					S.Selected[p.UserId] = (not S.Selected[p.UserId]) or nil
					paint()
				end)
			end
		end
	end

	local function mini(key, cb)
		local b = new("TextButton", { Font = FONT, TextSize = 14, TextColor3 = WHITE, BorderSizePixel = 0 }, row)
		corner(b, 8)
		bind(function() b.Text = L(key) b.BackgroundColor3 = PANEL b.BackgroundTransparency = tr(0.15) end)
		connect(b.Activated, cb)
	end
	mini("refresh", function() rebuildPlayers() end)
	mini("all", function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP then S.Selected[p.UserId] = true end
		end
		rebuildPlayers()
	end)
	mini("clear", function() S.Selected = {} rebuildPlayers() end)

	connect(Players.PlayerAdded, function() task.defer(rebuildPlayers) end)
	connect(Players.PlayerRemoving, function(p)
		S.Selected[p.UserId] = nil
		if current == p then current = nil end
		task.defer(rebuildPlayers)
	end)
	rebuildPlayers()
end

------------------------------------------------------------------ ESP page
toggle(pESP, "esp", function() return S.ESP end, function(v) S.ESP = v end)
toggle(pESP, "esp_box", function() return S.ESPBox end, function(v) S.ESPBox = v end)
toggle(pESP, "esp_tracer", function() return S.ESPTracer end, function(v) S.ESPTracer = v end)
toggle(pESP, "esp_name", function() return S.ESPName end, function(v) S.ESPName = v end)
slider(pESP, "esp_dist", 50, 2000, 0, function() return S.ESPDist end, function(v) S.ESPDist = v end)

------------------------------------------------------------------ Style page
toggle(pStyle, "lock", function() return S.Locked end, function(v) S.Locked = v end)
slider(pStyle, "transparency", 0, 0.9, 2, function() return S.Transparency end, function(v) S.Transparency = v end)
slider(pStyle, "scale", 0.7, 1.3, 2, function() return S.Scale end, function(v) S.Scale = v end)

sectionLabel(pStyle, "accent")
do
	local row = new("Frame", { Size = UDim2.new(1, -6, 0, 32), BackgroundTransparency = 1 }, pStyle)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, row)
	for _, col in ipairs({
		Color3.fromRGB(0, 170, 255), Color3.fromRGB(0, 220, 130), Color3.fromRGB(255, 90, 120),
		Color3.fromRGB(170, 100, 255), Color3.fromRGB(255, 170, 0), Color3.fromRGB(240, 240, 240),
	}) do
		local b = new("TextButton", { Size = UDim2.fromOffset(34, 32), Text = "", BackgroundColor3 = col, BorderSizePixel = 0 }, row)
		corner(b, 8)
		connect(b.Activated, function() S.Accent = col refreshAll() end)
	end
end

sectionLabel(pStyle, "language")
do
	local row = new("Frame", { Size = UDim2.new(1, -6, 0, 34), BackgroundTransparency = 1 }, pStyle)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 1, 0), CellPadding = UDim2.fromOffset(6, 0) }, row)
	for _, lg in ipairs({ { "en", "English (UK)" }, { "vi", "Tiếng Việt (VN)" } }) do
		local b = new("TextButton", { Text = lg[2], Font = FONT, TextSize = 15, TextColor3 = WHITE, BorderSizePixel = 0 }, row)
		corner(b, 8)
		bind(function()
			b.BackgroundColor3 = (S.Lang == lg[1]) and S.Accent or PANEL
			b.BackgroundTransparency = tr(0.15)
		end)
		connect(b.Activated, function() S.Lang = lg[1] refreshAll() end)
	end
end

------------------------------------------------------------------ ESP (Frame based, no Drawing API needed)
local esp = {}

local function esc(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function getESP(p)
	local o = esp[p]
	if o then return o end
	local box = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, espGui)
	local st = new("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
	local line = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, espGui)
	local lbl = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(220, 34), BackgroundTransparency = 1,
		Font = FONT, TextSize = 14, TextColor3 = WHITE, TextStrokeTransparency = 0.4, RichText = true,
		TextYAlignment = Enum.TextYAlignment.Bottom, Visible = false,
	}, espGui)
	o = { box = box, st = st, line = line, lbl = lbl, text = "" }
	esp[p] = o
	return o
end

local function hideESP(o)
	o.box.Visible = false
	o.line.Visible = false
	o.lbl.Visible = false
end

local function removeESP(p)
	local o = esp[p]
	if o then
		o.box:Destroy() o.line:Destroy() o.lbl:Destroy()
		esp[p] = nil
	end
end
connect(Players.PlayerRemoving, removeESP)

local function updateESP()
	local cam = workspace.CurrentCamera
	if not S.ESP or not cam then
		for _, o in pairs(esp) do hideESP(o) end
		return
	end
	local vp = cam.ViewportSize
	local camPos = cam.CFrame.Position

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local o = getESP(p)
			local c = p.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			local shown = false

			if r and h and h.Health > 0 then
				local dist = (r.Position - camPos).Magnitude
				if dist <= S.ESPDist then
					local top = cam:WorldToViewportPoint(r.Position + Vector3.new(0, 2.9, 0))
					local bot = cam:WorldToViewportPoint(r.Position - Vector3.new(0, 3.1, 0))
					if top.Z > 0 and bot.Z > 0 then
						shown = true
						local col = p.Team and p.TeamColor.Color or WHITE
						local height = math.abs(bot.Y - top.Y)
						local width = height * 0.55
						local cx = (top.X + bot.X) / 2
						local fade = math.clamp(dist / S.ESPDist, 0, 1)

						-- Box
						o.box.Visible = S.ESPBox
						o.box.Position = UDim2.fromOffset(cx - width / 2, top.Y)
						o.box.Size = UDim2.fromOffset(width, height)
						o.st.Color = col

						-- Tracer (bottom centre -> feet)
						if S.ESPTracer then
							local x1, y1 = vp.X / 2, vp.Y
							local dx, dy = cx - x1, bot.Y - y1
							local len = math.sqrt(dx * dx + dy * dy)
							o.line.Visible = true
							o.line.BackgroundColor3 = col
							o.line.BackgroundTransparency = fade * 0.5
							o.line.Size = UDim2.fromOffset(len, 1.5)
							o.line.Position = UDim2.fromOffset(x1 + dx / 2, y1 + dy / 2)
							o.line.Rotation = math.deg(math.atan2(dy, dx))
						else
							o.line.Visible = false
						end

						-- Name: display name (big) + @username and distance (small, grey)
						if S.ESPName then
							local dn, un = p.DisplayName, p.Name
							local second = ((dn ~= un) and ("@" .. un .. "  ·  ") or "") .. math.floor(dist) .. "m"
							local txt = esc(dn) .. "\n<font size=\"11\" color=\"rgb(185,185,200)\">" .. esc(second) .. "</font>"
							if o.text ~= txt then
								o.text = txt
								o.lbl.Text = txt
							end
							o.lbl.TextSize = math.floor(16 - fade * 4)
							o.lbl.TextTransparency = fade * 0.5
							o.lbl.Position = UDim2.fromOffset(cx, top.Y - 3)
							o.lbl.Visible = true
						else
							o.lbl.Visible = false
						end
					end
				end
			end
			if not shown then hideESP(o) end
		end
	end
end
connect(RunService.RenderStepped, updateESP)

------------------------------------------------------------------ Virtual tap signal
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function hits(f, pt)
	if not f.Visible then return false end
	local a, s = f.AbsolutePosition, f.AbsoluteSize
	return pt.X >= a.X - 40 and pt.X <= a.X + s.X + 40 and pt.Y >= a.Y - 40 and pt.Y <= a.Y + s.Y + 40
end

-- Picks a spot not covered by this script's own GUI so it never presses its buttons
local function tapPoint()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
	for _, f in ipairs({ { 0.5, 0.5 }, { 0.5, 0.35 }, { 0.5, 0.7 }, { 0.75, 0.5 }, { 0.25, 0.5 }, { 0.9, 0.5 } }) do
		local pt = Vector2.new(vp.X * f[1], vp.Y * f[2])
		if not (hits(main, pt) or hits(mini, pt)) then return pt end
	end
	return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
end

local function sendTap()
	if not VIM then return end
	local pt = tapPoint()
	local ok = pcall(function()
		VIM:SendTouchEvent(9, 0, pt.X, pt.Y)
		VIM:SendTouchEvent(9, 2, pt.X, pt.Y)
	end)
	if not ok then
		pcall(function()
			VIM:SendMouseButtonEvent(pt.X, pt.Y, 0, true, game, 0)
			VIM:SendMouseButtonEvent(pt.X, pt.Y, 0, false, game, 0)
		end)
	end
end

------------------------------------------------------------------ Status, tap loop, unload
local t0, tapAcc = 0, 0
connect(RunService.Heartbeat, function(dt)
	if S.Tap then
		tapAcc = tapAcc + dt
		if tapAcc >= S.TapInterval then
			tapAcc = 0
			sendTap()
		end
	else
		tapAcc = 0
	end

	t0 = t0 + dt
	if t0 < 0.1 then return end
	t0 = 0
	local txt = L("none")
	if S.Enabled and current then
		txt = current.DisplayName
		if S.Duration > 0 then
			txt = txt .. string.format("  (%.1fs)", math.max(0, S.Duration - (os.clock() - startT)))
		end
	end
	status.Text = L("target") .. ": " .. txt
end)

local function unload()
	S.Enabled, S.ESP, S.Tap = false, false, false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	gui:Destroy()
	espGui:Destroy()
	genv.__AutoCarry = nil
end
genv.__AutoCarry = unload
connect(closeBtn.Activated, unload)
connect(offBtn.Activated, unload)

showTab(1)
