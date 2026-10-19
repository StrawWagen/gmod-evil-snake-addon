EvilSnake = EvilSnake or {}
local Chain = {}
EvilSnake.Chain = Chain

local DT = 1 / 33
local MAX_STEPS = 4
local GRAVITY = 600
local ITERATIONS = 8
local DAMP = 0.995
local HULL = 0.85
local FOLD = 1.3
local GRIP_ALONG = 0.3
local GRIP_SIDE = 1.2
local REST = 0.02
local SETTLE = 1
local NAP = 1
local PROBE = 1
local UP = Vector(0, 0, 1)

function Chain.New(joints, filter)
	local r = EvilSnake.RADIUS * HULL
	local c = {
		x = {}, old = {}, p = {}, cn = {}, cd = {}, filter = filter, awake = true, still = 0, acc = 0, nap = 0,
		mins = Vector(-r, -r, -r), maxs = Vector(r, r, r),
	}
	for i, j in ipairs(joints) do c.x[i], c.old[i] = Vector(j), Vector(j) end
	return c
end

local function Hull(c, from, to)
	return util.TraceHull({ start = from, endpos = to, mins = c.mins, maxs = c.maxs, mask = MASK_SOLID, filter = c.filter })
end

function Chain.Resize(c, count)
	local x, old = c.x, c.old
	while #x > count + 1 do
		local n = #x
		x[n], old[n], c.cn[n], c.cd[n] = nil, nil, nil, nil
	end
	while #x < count + 1 do
		local n = #x
		local dir = n > 1 and (x[n] - x[n - 1]):GetNormalized() or Vector(1, 0, 0)
		local tr = Hull(c, x[n], x[n] + dir * EvilSnake.LINK)
		x[n + 1], old[n + 1] = Vector(tr.HitPos), Vector(tr.HitPos)
	end
	c.awake, c.still = true, 0
end

local function Grip(v, amount)
	local len = v:Length()
	if len <= amount then return v * 0 end
	return v * ((len - amount) / len)
end

local function Contact(c, i, pos, normal)
	local tr = Hull(c, pos, pos - normal * PROBE)
	if tr.Hit and not tr.StartSolid then
		c.cn[i], c.cd[i] = tr.HitNormal, tr.HitPos:Dot(tr.HitNormal)
	else
		c.cn[i], c.cd[i] = nil, nil
	end
end

local function Collide(c, i, from, to, along)
	local normal = c.cn[i]
	if normal then
		local move = to - from
		local into = move:Dot(normal)
		local rest = move - normal * into
		local flat = (along - normal * along:Dot(normal)):GetNormalized()
		local slide = flat * rest:Dot(flat)
		local weight = GRAVITY * DT * DT * math.max(0, normal.z)
		rest = Grip(slide, GRIP_ALONG * weight) + Grip(rest - slide, GRIP_SIDE * weight)
		to = from + rest + normal * math.max(into, math.min(0, c.cd[i] - from:Dot(normal)))
	end
	local tr = Hull(c, from, to)
	if tr.StartSolid then
		local free = Hull(c, to, to).StartSolid and from or to
		c.cn[i], c.cd[i] = nil, nil
		return free
	end
	local final = to
	if tr.Hit then
		local rest = to - tr.HitPos
		rest = rest - tr.HitNormal * math.min(0, rest:Dot(tr.HitNormal))
		final = tr.HitPos
		if rest:LengthSqr() > 1e-6 then
			local tr2 = Hull(c, final, final + rest)
			if not tr2.StartSolid then final = tr2.HitPos end
		end
		normal = tr.HitNormal
	end
	Contact(c, i, final, normal or UP)
	return final
end

local function Tick(c)
	local x, old, p, cn, cd = c.x, c.old, c.p, c.cn, c.cd
	local n = #x
	local link, fold = EvilSnake.LINK, EvilSnake.LINK * FOLD
	local fall = Vector(0, 0, -GRAVITY * DT * DT)
	for i = 1, n do p[i] = x[i] + (x[i] - old[i]) * DAMP + fall end
	for _ = 1, ITERATIONS do
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
		local to = Collide(c, i, x[i], p[i], along)
		old[i], x[i] = x[i], to
		moved = math.max(moved, to:DistToSqr(old[i]))
	end
	return moved
end

function Chain.Update(c, dt)
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
	if moved > REST * REST then
		c.still = 0
	else
		c.still = c.still + dt
		if c.still > SETTLE then c.awake = false end
	end
	return true
end
