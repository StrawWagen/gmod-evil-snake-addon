EvilSnake = EvilSnake or {}
local Chain = {}
EvilSnake.Chain = Chain

local Setting = EvilSnake.Setting

local DT = 1 / 33
local MAX_STEPS = 4
local DAMP = 0.995
local HULL = 0.85
local REST = 0.02
local SETTLE = 1
local NAP = 1
local PROBE = 1
local FLOOR = 0.7
local TRAIL_GAP = 4
local REBASE = 2
local TIP = 0.15
local UP = Vector(0, 0, 1)

function Chain.New(joints, filter)
	local c = {
		x = {}, old = {}, p = {}, cn = {}, cd = {}, filter = filter, awake = true, still = 0, acc = 0, nap = 0,
		mins = Vector(), maxs = Vector(), hull = {}, trail = {}, arcs = {}, speed = 0, phase = 0, girth = 1, stretch = 1,
	}
	for i, j in ipairs(joints) do c.x[i], c.old[i] = Vector(j), Vector(j) end
	return c
end

local function Hull(c, i, from, to)
	local r = c.hull[i]
	c.mins:SetUnpacked(-r, -r, -r)
	c.maxs:SetUnpacked(r, r, r)
	return util.TraceHull({ start = from, endpos = to, mins = c.mins, maxs = c.maxs, mask = MASK_SOLID, filter = c.filter })
end

local function Size(c)
	local r = Setting("radius") * c.girth * HULL
	local body, tail = EvilSnake.Shape()
	local n = #c.x
	for i = 1, n do
		local h = r * math.max(EvilSnake.Profile((i - 1) / math.max(n - 1, 1), body, tail), TIP)
		local grow = h - (c.hull[i] or h)
		if grow > 0 then
			local normal = c.cn[i]
			local lift = grow
			if normal then
				local reach = math.abs(normal.x) + math.abs(normal.y) + normal.z
				lift = grow * reach / math.max(normal.z, 0.3)
				c.cd[i] = c.cd[i] + grow * reach
			end
			c.x[i] = c.x[i] + UP * lift
			c.old[i] = c.old[i] + UP * lift
		end
		c.hull[i] = h
	end
	for i = n + 1, #c.hull do c.hull[i] = nil end
end

function Chain.Link(c)
	return Setting("segment_length") * c.stretch
end

function Chain.HeadYaw(c)
	local d = c.x[1] - c.x[2]
	return math.deg(math.atan2(d.y, d.x))
end

function Chain.Drive(c, yaw, speed)
	c.goal, c.speed = yaw, speed
	if speed > 0 then c.awake, c.still = true, 0 end
end

function Chain.Swell(c, girth)
	c.girth = girth
	Size(c)
	c.awake, c.still = true, 0
end

local function Resize(c, count)
	local x, old = c.x, c.old
	while #x > count + 1 do
		local n = #x
		x[n], old[n], c.cn[n], c.cd[n] = nil, nil, nil, nil
	end
	while #x < count + 1 do
		local n = #x
		local dir = n > 1 and (x[n] - x[n - 1]):GetNormalized() or Vector(1, 0, 0)
		Size(c)
		local tr = Hull(c, n, x[n], x[n] + dir * Chain.Link(c))
		x[n + 1], old[n + 1] = Vector(tr.HitPos), Vector(tr.HitPos)
	end
	Size(c)
	c.awake, c.still, c.driving = true, 0, false
end

function Chain.Fit(c, length)
	local count = math.max(1, math.Round(length))
	c.stretch = length / count
	if #c.x ~= count + 1 then Resize(c, count) end
end

local function Reseed(c)
	local x, trail, arcs = c.x, {}, {}
	local n = #x
	local arc = 0
	for k = 1, n do
		local p = x[n - k + 1]
		if k > 1 then arc = arc + p:Distance(trail[k - 1]) end
		trail[k], arcs[k] = Vector(p), arc
	end
	c.trail, c.arcs = trail, arcs
end

local function Record(c, head)
	local trail, arcs = c.trail, c.arcs
	local last = #trail
	local gap = head:Distance(trail[last])
	if gap < TRAIL_GAP then return end
	trail[last + 1], arcs[last + 1] = Vector(head), arcs[last] + gap
	local keep = arcs[last + 1] - (#c.x + 2) * Chain.Link(c)
	while #arcs > 2 and arcs[2] < keep do
		table.remove(trail, 1)
		table.remove(arcs, 1)
	end
end

local function Follow(c, p, amount)
	local trail, arcs = c.trail, c.arcs
	local last = #trail
	local link = Chain.Link(c)
	local head = arcs[last] + p[1]:Distance(trail[last])
	local k = last
	for i = 2, #p do
		local want = head - (i - 1) * link
		if want < arcs[1] then return false end
		local target
		if want >= arcs[last] then
			target = LerpVector((want - arcs[last]) / math.max(head - arcs[last], 1e-4), trail[last], p[1])
		else
			while k > 1 and arcs[k] > want do k = k - 1 end
			local span = arcs[k + 1] - arcs[k]
			target = LerpVector(span > 0 and (want - arcs[k]) / span or 0, trail[k], trail[k + 1])
		end
		if target:Distance(p[i]) > REBASE * link then return true end
		p[i] = LerpVector(amount, p[i], target)
	end
	return false
end

local function Grip(v, amount)
	local len = v:Length()
	if len <= amount then return v * 0 end
	return v * ((len - amount) / len)
end

local function Contact(c, i, pos)
	local tr = Hull(c, i, pos, pos - UP * PROBE)
	if tr.Hit and not tr.StartSolid and tr.HitNormal.z > 0 then
		c.cn[i], c.cd[i] = tr.HitNormal, tr.HitPos:Dot(tr.HitNormal)
	else
		c.cn[i], c.cd[i] = nil, nil
	end
end

local function Climb(c, i, from, to, reached)
	local height = Setting("step_height")
	if height <= 0 then return end
	local flat = Vector(to.x - from.x, to.y - from.y, 0)
	if flat:Length() < 1e-3 then return end
	local top = Hull(c, i, from, from + UP * height).HitPos
	local over = Hull(c, i, top, top + flat)
	if over.StartSolid then return end
	local land = over.HitPos
	local done = Vector(land.x - from.x, land.y - from.y, 0):Length()
	local slid = Vector(reached.x - from.x, reached.y - from.y, 0):Length()
	if done <= slid + 0.5 then return end
	local down = Hull(c, i, land, land - UP * (top.z - from.z + PROBE))
	if down.StartSolid or not down.Hit or down.HitNormal.z < FLOOR then return end
	return down.HitPos
end

local function Collide(c, i, from, to, along, gravity)
	local normal = c.cn[i]
	if normal then
		local move = to - from
		local into = move:Dot(normal)
		local rest = move - normal * into
		local flat = (along - normal * along:Dot(normal)):GetNormalized()
		local slide = flat * rest:Dot(flat)
		local weight = gravity * DT * DT * math.max(0, normal.z)
		rest = Grip(slide, Setting("grip_along") * weight) + Grip(rest - slide, Setting("grip_side") * weight)
		to = from + rest + normal * math.max(into, math.min(0, c.cd[i] - from:Dot(normal)))
	end
	local tr = Hull(c, i, from, to)
	if tr.StartSolid then
		local free = Hull(c, i, to, to).StartSolid and from or to
		c.cn[i], c.cd[i] = nil, nil
		return free
	end
	local final, climbed = to, false
	if tr.Hit then
		local rest = to - tr.HitPos
		rest = rest - tr.HitNormal * math.min(0, rest:Dot(tr.HitNormal))
		final = tr.HitPos
		if rest:LengthSqr() > 1e-6 then
			local tr2 = Hull(c, i, final, final + rest)
			if not tr2.StartSolid then final = tr2.HitPos end
		end
		if tr.HitNormal.z < FLOOR then
			local stepped = Climb(c, i, from, to, final)
			if stepped then final, climbed = stepped, true end
		end
	end
	Contact(c, i, final)
	return final, climbed
end

local function Steer(c)
	if not c.driving then
		c.driving, c.yaw = true, Chain.HeadYaw(c)
		Reseed(c)
	end
	local turn = Setting("turn_rate") * DT
	c.yaw = c.yaw + math.Clamp(math.AngleDifference(c.goal, c.yaw), -turn, turn)
	c.phase = (c.phase + c.speed * DT / Setting("wavelength") * math.pi * 2) % (math.pi * 2)
	local heading = math.rad(c.yaw + Setting("sway") * math.sin(c.phase))
	return Vector(math.cos(heading), math.sin(heading), 0) * (c.speed * DT)
end

local function Tick(c)
	local x, old, p, cn, cd = c.x, c.old, c.p, c.cn, c.cd
	local n = #x
	local link = Chain.Link(c)
	local fold = link * Setting("bend")
	local gravity = Setting("gravity")
	local fall = Vector(0, 0, -gravity * DT * DT)
	for i = 1, n do p[i] = x[i] + (x[i] - old[i]) * DAMP + fall end
	if c.speed > 0 then
		local step = Steer(c)
		if cn[1] then p[1] = x[1] + step + Vector(0, 0, (x[1].z - old[1].z) * DAMP) + fall end
		Record(c, x[1])
		local follow = Setting("follow")
		if follow > 0 and Follow(c, p, follow) then Reseed(c) end
	else
		c.driving = false
	end
	for _ = 1, Setting("solver_passes") do
		for i = 1, n - 1 do
			local d = p[i + 1] - p[i]
			local len = d:Length()
			if len > 1e-4 then
				local fix = d * ((len - link) / len * 0.5)
				p[i], p[i + 1] = p[i] + fix, p[i + 1] - fix
			end
		end
		for i = 1, n - 2 do
			local d = p[i + 2] - p[i]
			local len = d:Length()
			if len < fold and len > 1e-4 then
				local fix = d * ((len - fold) / len * 0.5)
				p[i], p[i + 2] = p[i] + fix, p[i + 2] - fix
			end
		end
		for i = 1, n do
			local normal = cn[i]
			if normal then
				local depth = p[i]:Dot(normal) - cd[i]
				if depth < 0 then p[i] = p[i] - normal * depth end
			end
		end
	end
	local moved = 0
	for i = 1, n do
		local along = (p[math.min(i + 1, n)] - p[math.max(i - 1, 1)]):GetNormalized()
		local to, climbed = Collide(c, i, x[i], p[i], along, gravity)
		old[i], x[i] = climbed and Vector(x[i].x, x[i].y, to.z) or x[i], to
		moved = math.max(moved, to:DistToSqr(old[i]))
	end
	return moved
end

function Chain.Update(c, dt)
	Size(c)
	if not c.awake then
		c.nap = c.nap + dt
		if c.nap < NAP then return false end
		c.nap = 0
		if Tick(c) < REST * REST then return false end
		c.awake, c.still = true, 0
		return true
	end
	c.acc = math.min(c.acc + dt, DT * MAX_STEPS)
	local moved = 0
	while c.acc >= DT do
		c.acc = c.acc - DT
		moved = math.max(moved, Tick(c))
	end
	if moved > REST * REST or c.speed > 0 then
		c.still = 0
	else
		c.still = c.still + dt
		if c.still > SETTLE then c.awake = false end
	end
	return true
end
