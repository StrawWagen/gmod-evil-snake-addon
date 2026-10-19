local REFRESH = 0.5
local CATCH_UP = 0.15
local TIMEOUT = 2
local REACH = 4096
local MIN_PICK = 6
local ROW = 16

local TEXT = Color(230, 230, 230)
local DIM = Color(160, 160, 160)
local BACK = Color(0, 0, 0, 90)
local TRACK = Color(255, 255, 255, 25)
local BAR = Color(200, 60, 60)
local GOOD = Color(120, 220, 120)
local BAD = Color(230, 110, 110)

local COLUMNS = {
	{ "#", 40 }, { "Name" }, { "Kind", 80 }, { "Weapon", 100 }, { "Eaten", 64 }, { "Status", 70 },
	{ "Mass", 50 }, { "Segments", 64 }, { "Girth", 56 }, { "Brain", 50 },
}

local function Title(s)
	return (s:gsub("_", " "):gsub("^%l", string.upper))
end

local function Phrase(id, prefix)
	local phrase = language.GetPhrase(id)
	if phrase ~= id then return phrase end
	return Title((id:gsub("^" .. prefix, "")))
end

local function Display(v)
	if v.steamid then return v.name end
	return Phrase(v.name, "npc_")
end

local function Clock(t)
	return string.FormattedTime(math.max(t, 0), "%02i:%02i:%02i")
end

local function Status(v, progress)
	if v.digested then return "digested", 2 end
	return ("%d%%"):format(math.floor(progress * 100)), progress
end

local View = {}
View.__index = View

local current

function View:Ask()
	self.nextAsk = RealTime() + TIMEOUT
	local pending = {}
	for n in pairs(self.pending) do pending[#pending + 1] = n end
	local count = math.min(#pending, 255)
	net.Start("EvilSnakeStomach")
	net.WriteEntity(self.ent)
	net.WriteUInt(self.rev, 16)
	net.WriteUInt(#self.victims, 16)
	net.WriteUInt(count, 8)
	for i = 1, count do net.WriteUInt(pending[i], 16) end
	net.SendToServer()
end

function View:Think()
	if not IsValid(self.ent) then
		if not self.gone then
			self.gone = true
			self.frame:SetTitle("Evil snake stomach (gone)")
		end
		return
	end
	if RealTime() >= self.nextAsk then self:Ask() end
end

function View:Row(v)
	local line = self.list:AddLine(v.n, Display(v), Title(v.kind), v.weapon and Phrase(v.weapon, "weapon_") or "", Clock(v.at), "", "", "", "", "")
	line.n = v.n
	line.cache = {}
	line:SetSortValue(1, v.n)
	line:SetSortValue(5, v.at)
	self.lines[v.n] = line
end

local function Set(line, col, text, sort)
	if line.cache[col] == text then return end
	line.cache[col] = text
	line:SetColumnText(col, text)
	line:SetSortValue(col, sort)
end

function View:Take(d)
	if d.rev ~= self.rev then
		self.rev = d.rev
		self.victims, self.pending, self.lines = {}, {}, {}
		self.list:Clear()
	end
	for _, v in ipairs(d.victims or {}) do
		if v.n == #self.victims + 1 then
			self.victims[v.n] = v
			if not v.digested then self.pending[v.n] = true end
			self:Row(v)
		end
	end
	for _, u in ipairs(d.updates or {}) do
		local v = self.victims[u.n]
		if v then
			v.digested, v.lessons = u.digested, u.lessons
			self.pending[u.n] = nil
		end
	end
	self.transit = {}
	for _, t in ipairs(d.transit or {}) do self.transit[t[1]] = t[2] end
	self.summary, self.count = d.summary, d.count
	self:Contribute()
	self.nextAsk = RealTime() + (#self.victims < d.count and CATCH_UP or REFRESH)
end

function View:Contribute()
	local base = self.summary.base
	local mass, digested, eating = 0, 0, 0
	local kinds = {}
	for n, v in ipairs(self.victims) do
		local share = v.digested and 1 or self.transit[n] or 0
		local after = mass + v.mass * share
		v.segments = EvilSnake.GrownLength(base, after) - EvilSnake.GrownLength(base, mass)
		v.girth = EvilSnake.GrownGirth(after) - EvilSnake.GrownGirth(mass)
		mass = after
		if v.digested then digested = digested + 1 else eating = eating + 1 end
		kinds[v.kind] = (kinds[v.kind] or 0) + 1

		local line = self.lines[n]
		Set(line, 6, Status(v, share))
		Set(line, 7, ("%.2f"):format(v.mass), v.mass)
		Set(line, 8, ("+%.2f"):format(v.segments), v.segments)
		Set(line, 9, ("+%.3f"):format(v.girth), v.girth)
		Set(line, 10, ("%.2f"):format(v.brain), v.brain)
	end
	local ate = {}
	for kind, count in SortedPairsByValue(kinds, true) do ate[#ate + 1] = ("%s x%d"):format(Title(kind), count) end
	self.mass, self.digested, self.eating, self.ate = mass, digested, eating, table.concat(ate, ", ")
end

function View:PaintSummary(w, h)
	draw.RoundedBox(4, 0, 0, w, h, BACK)
	local s = self.summary
	if not s then return end
	local loaded = #self.victims
	local head = loaded < self.count and ("%d eaten, loading %d"):format(self.count, loaded)
		or ("%d eaten, %d digested, %d going down"):format(self.count, self.digested, self.eating)
	draw.SimpleText(head, "DermaDefaultBold", 8, 6, TEXT)
	draw.SimpleText(("Mass %.2f    Length %.1f (base %d)    Girth %.2fx    Brainpower %.2f    Level %.2f")
		:format(self.mass, s.length, s.base, s.girth, s.power, s.level), "DermaDefault", 8, 24, TEXT)
	draw.SimpleText(self.ate, "DermaDefault", 8, 42, DIM)
	local count = #s.knows
	local gap = 8
	local cw = (w - 16 - gap * (count - 1)) / count
	for i, k in ipairs(s.knows) do
		local x = 8 + (i - 1) * (cw + gap)
		draw.SimpleText(Title(k[1]), "DermaDefault", x, 62, TEXT)
		draw.SimpleText(("%.2f"):format(k[2]), "DermaDefault", x + cw, 62, DIM, TEXT_ALIGN_RIGHT)
		surface.SetDrawColor(TRACK)
		surface.DrawRect(x, 80, cw, 8)
		surface.SetDrawColor(BAR)
		surface.DrawRect(x, 80, math.floor(cw * k[2]), 8)
	end
end

local function Pair(label, value, w, y, color)
	draw.SimpleText(label, "DermaDefault", 0, y, DIM)
	draw.SimpleText(value, "DermaDefault", w, y, color or TEXT, TEXT_ALIGN_RIGHT)
	return y + ROW
end

function View:PaintInfo(w, h)
	local v = self.selected and self.victims[self.selected]
	if not v then return end
	draw.SimpleText(Display(v), "DermaDefaultBold", 0, 0, TEXT)
	local y = ROW + 6
	y = Pair("Order", "#" .. v.n, w, y)
	y = Pair("Kind", Title(v.kind), w, y)
	y = Pair("Class", v.class, w, y)
	if v.steamid then y = Pair("SteamID", v.steamid, w, y) end
	if v.weapon then y = Pair("Weapon", Phrase(v.weapon, "weapon_"), w, y) end
	if v.health then y = Pair("Health", tostring(v.health), w, y) end
	y = Pair("Size", ("%.2f"):format(v.size), w, y)
	y = Pair("Eaten at", Clock(v.at), w, y)
	if v.digested then
		y = Pair("Digested", ("after %.1fs"):format(v.digested - v.at), w, y)
	else
		y = Pair("Going down", Status(v, self.transit[v.n] or 0), w, y)
	end
	y = Pair("Mass", ("%.2f"):format(v.mass), w, y)
	y = Pair("Segments", ("+%.2f"):format(v.segments or 0), w, y)
	y = Pair("Girth", ("+%.3f"):format(v.girth or 0), w, y)
	y = Pair("Brainpower", ("%.2f"):format(v.brain), w, y)
	if not v.lessons then return end
	y = y + 6
	draw.SimpleText("Lessons", "DermaDefaultBold", 0, y, TEXT)
	y = y + ROW
	for aspect, gain in SortedPairsByValue(v.lessons, true) do
		y = Pair(Title(aspect), ("%+.3f"):format(gain), w, y, gain >= 0 and GOOD or BAD)
	end
end

function View:Select(n)
	self.selected = n
	local v = self.victims[n]
	local panel = self.model
	if not v or not v.model or not util.IsValidModel(v.model) then
		panel:SetVisible(false)
		return
	end
	panel:SetVisible(true)
	panel:SetModel(v.model)
	local e = panel.Entity
	if not IsValid(e) then return end
	local seq = e:LookupSequence("idle_all_01")
	if seq <= 0 then seq = e:SelectWeightedSequence(ACT_IDLE) end
	if seq > 0 then e:ResetSequence(seq) end
	local mn, mx = e:GetRenderBounds()
	local center = (mn + mx) * 0.5
	local size = mn:Distance(mx)
	panel:SetFOV(40)
	panel:SetLookAt(center)
	panel:SetCamPos(center + Vector(size, size * 0.4, size * 0.3))
end

function EvilSnake.OpenStomach(ent)
	if IsValid(current) then current:Remove() end
	local frame = vgui.Create("DFrame")
	current = frame
	frame:SetTitle("Evil snake stomach")
	frame:SetSize(math.min(1040, ScrW() - 40), math.min(660, ScrH() - 40))
	frame:SetSizable(true)
	frame:SetMinWidth(720)
	frame:SetMinHeight(480)
	frame:Center()
	frame:MakePopup()

	local view = setmetatable({ frame = frame, ent = ent, rev = 0, victims = {}, pending = {}, lines = {}, transit = {}, nextAsk = 0 }, View)
	frame.view = view

	local top = frame:Add("DPanel")
	top:Dock(TOP)
	top:SetTall(96)
	top:DockMargin(0, 0, 0, 4)
	top.Paint = function(_, w, h) view:PaintSummary(w, h) end
	top.Think = function() view:Think() end

	local side = frame:Add("DPanel")
	side:Dock(RIGHT)
	side:SetWide(280)
	side:DockMargin(4, 0, 0, 0)
	side.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, BACK) end

	local model = side:Add("DModelPanel")
	model:Dock(TOP)
	model:SetTall(170)
	model:SetVisible(false)
	model.LayoutEntity = function(p, e)
		e:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
		p:RunAnimation()
	end
	view.model = model

	local info = side:Add("DPanel")
	info:Dock(FILL)
	info:DockMargin(10, 8, 10, 8)
	info.Paint = function(_, w, h) view:PaintInfo(w, h) end

	local list = frame:Add("DListView")
	list:Dock(FILL)
	list:SetMultiSelect(false)
	for _, c in ipairs(COLUMNS) do
		local col = list:AddColumn(c[1])
		if c[2] then col:SetFixedWidth(c[2]) end
	end
	list.OnRowSelected = function(_, _, line) view:Select(line.n) end
	view.list = list
end

net.Receive("EvilSnakeStomach", function()
	local ent = net.ReadEntity()
	local raw = util.Decompress(net.ReadData(net.ReadUInt(16)))
	local data = raw and util.JSONToTable(raw)
	if not data or not IsValid(current) then return end
	local view = current.view
	if view and view.ent == ent then view:Take(data) end
end)

properties.Add("evil_snake_stomach", {
	MenuLabel = "Stomach",
	MenuIcon = "icon16/table.png",
	Order = 1500,
	Filter = function(self, ent, ply)
		return IsValid(ent) and ent:GetClass() == "evil_snake" and gamemode.Call("CanProperty", ply, "evil_snake_stomach", ent) ~= false
	end,
	Action = function(self, ent)
		EvilSnake.OpenStomach(ent)
	end,
})

local function RaySegment(o, d, a, b)
	local u = b - a
	local w = a - o
	local uu, ud, uw, dw = u:Dot(u), u:Dot(d), u:Dot(w), d:Dot(w)
	local den = uu - ud * ud
	local s = den > 1e-6 and math.Clamp((ud * dw - uw) / den, 0, 1) or 0
	local t = math.max(0, dw + s * ud)
	s = uu > 1e-6 and math.Clamp((t * ud - uw) / uu, 0, 1) or 0
	return (a + u * s):DistToSqr(o + d * t), t
end

local function Pick(eye, dir, limit)
	local best, bestT
	local body, tail = EvilSnake.Shape()
	for _, ent in ipairs(ents.FindByClass("evil_snake")) do
		local pose = ent.Pose
		if pose and #pose > 1 then
			local R = ent:Radius()
			local last = #pose - 1
			for i = 1, last do
				local r = math.max(R * EvilSnake.Profile((i - 1) / last, body, tail), MIN_PICK)
				local d2, t = RaySegment(eye, dir, pose[i], pose[i + 1])
				if d2 <= r * r and t <= limit and (not bestT or t < bestT) then best, bestT = ent, t end
			end
		end
	end
	return best
end

hook.Add("GUIMousePressed", "EvilSnakeStomach", function(code, aim)
	if code ~= MOUSE_RIGHT or input.IsButtonDown(MOUSE_LEFT) then return end
	local hovered = vgui.GetHoveredPanel()
	if not IsValid(hovered) or not hovered:IsWorldClicker() then return end
	local eye, dir = EyePos(), aim:GetNormalized()
	if properties.GetHovered(eye, dir) then return end
	local tr = util.TraceLine({ start = eye, endpos = eye + dir * REACH, filter = LocalPlayer():GetViewEntity() })
	local ent = Pick(eye, dir, tr.Fraction * REACH)
	if ent then properties.OpenEntityMenu(ent, tr) end
end)
