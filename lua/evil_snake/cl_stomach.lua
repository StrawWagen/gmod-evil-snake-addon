local REACH = 4096
local MIN_PICK = 6

local TEXT = Color(230, 230, 230)
local DIM = Color(160, 160, 160)
local TRACK = Color(255, 255, 255, 25)
local BAR = Color(200, 60, 60)
local GOOD = Color(120, 220, 120)
local BAD = Color(230, 110, 110)

Evil.StomachView({
	class = "evil_snake",
	title = "Evil snake stomach",
	top = 96,
	columns = {
		{ "Mass", 50, function(v) return ("%.2f"):format(v.mass), v.mass end },
		{ "Segments", 64, function(v) return ("+%.2f"):format(v.segments), v.segments end },
		{ "Girth", 56, function(v) return ("+%.3f"):format(v.girth), v.girth end },
		{ "Brain", 50, function(v) return ("%.2f"):format(v.brain), v.brain end },
	},
	refresh = function(view)
		local base = view.summary and view.summary.base or 0
		local mass = 0
		for _, v in ipairs(view.victims) do
			local after = mass + v.mass * view:Share(v)
			v.segments = EvilSnake.GrownLength(base, after) - EvilSnake.GrownLength(base, mass)
			v.girth = EvilSnake.GrownGirth(after) - EvilSnake.GrownGirth(mass)
			mass = after
		end
		view.mass = mass
	end,
	summary = function(view, w)
		local s = view.summary
		draw.SimpleText(("Mass %.2f    Length %.1f (base %d)    Girth %.2fx    Brainpower %.2f    Level %.2f")
			:format(view.mass, s.length, s.base, s.girth, s.power, s.level), "DermaDefault", 8, 42, TEXT)
		local count = #s.knows
		local gap = 8
		local cw = (w - 16 - gap * (count - 1)) / count
		for i, k in ipairs(s.knows) do
			local x = 8 + (i - 1) * (cw + gap)
			draw.SimpleText(view.Title(k[1]), "DermaDefault", x, 62, TEXT)
			draw.SimpleText(("%.2f"):format(k[2]), "DermaDefault", x + cw, 62, DIM, TEXT_ALIGN_RIGHT)
			surface.SetDrawColor(TRACK)
			surface.DrawRect(x, 80, cw, 8)
			surface.SetDrawColor(BAR)
			surface.DrawRect(x, 80, math.floor(cw * k[2]), 8)
		end
	end,
	info = function(view, v)
		view:Pair("Size", ("%.2f"):format(v.size))
		view:Pair("Mass", ("%.2f"):format(v.mass))
		view:Pair("Segments", ("+%.2f"):format(v.segments or 0))
		view:Pair("Girth", ("+%.3f"):format(v.girth or 0))
		view:Pair("Brainpower", ("%.2f"):format(v.brain))
		if not v.lessons then return end
		view:Heading("Lessons")
		for aspect, gain in SortedPairsByValue(v.lessons, true) do
			view:Pair(view.Title(aspect), ("%+.3f"):format(gain), gain >= 0 and GOOD or BAD)
		end
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
