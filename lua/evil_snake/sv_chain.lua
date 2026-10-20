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
local SELF_ARC = 1.6
local SELF_MARGIN = 8
local SELF_STIFF = 0.8
local AIM = 3
local SPIN = 6
local SPIN_SPEED = 50
local SWAY_EASE = 3
local CLOSE = 0.5
local TURN_SLOW = 0.35
local PACE = 4
local CRAWL = 1
local MAX_BEND = 1.4
local WATER = bit.bor(CONTENTS_WATER, CONTENTS_SLIME)
local BUOY = 1.3
local WET_DAMP = 0.9
local DIVE = 0.8
local SURGE = 0.5
local ESCAPE = {
	Vector(0, 0, 1), Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0),
	Vector(0.7071, 0.7071, 0), Vector(0.7071, -0.7071, 0), Vector(-0.7071, 0.7071, 0), Vector(-0.7071, -0.7071, 0),
	Vector(0.7071, 0, 0.7071), Vector(-0.7071, 0, 0.7071), Vector(0, 0.7071, 0.7071), Vector(0, -0.7071, 0.7071),
}

local folds = {}

function Chain.New(joints, filter)
	local c = {
		x = {}, old = {}, p = {}, cn = {}, cd = {}, filter = filter, awake = true, still = 0, acc = 0, nap = 0,
		mins = Vector(), maxs = Vector(), hull = {}, trail = {}, arcs = {}, speed = 0, phase = 0, girth = 1, stretch = 1, wet = {},
	}
	for i, j in ipairs(joints) do c.x[i], c.old[i] = Vector(j), Vector(j) end
	return c
end

local function Wet(pos)
	return bit.band(util.PointContents(pos), WATER) ~= 0
end

local function Soak(c, i, pos)
	if not Wet(pos) then return 0 end
	return Wet(pos + UP * (c.hull[i] / HULL * 0.5)) and 1 or 0.5
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

function Chain.Drive(c, yaw, speed, aim)
	c.goal, c.want, c.aim = yaw, speed, aim
	if speed > 0 then c.awake, c.still = true, 0 end
end

function Chain.Swell(c, girth)
	c.girth = girth
	Size(c)
	c.awake, c.still = true, 0
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
	Reseed(c)
	c.awake, c.still = true, 0
end

function Chain.Fit(c, length)
	local count = math.max(1, math.Round(length))
	c.stretch = length / count
	if #c.x ~= count + 1 then Resize(c, count) end
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

local function Unstick(c, i, pos)
	if not Hull(c, i, pos, pos).StartSolid then return pos end
	local reach = c.hull[i] * 2 + 1
	local best, bestDist
	for _, dir in ipairs(ESCAPE) do
		local tr = Hull(c, i, pos + dir * reach, pos)
		if tr.Hit and not tr.StartSolid then
			local d = tr.HitPos:DistToSqr(pos)
			if not bestDist or d < bestDist then best, bestDist = tr.HitPos, d end
		end
	end
	return best
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
		local free = Unstick(c, i, to) or Unstick(c, i, from) or from
		Contact(c, i, free)
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
	local wave = Setting("wavelength")
	local sway = Setting("sway")
	local aim, dist = c.aim, nil
	if aim then
		local head = c.x[1]
		local dx, dy = aim.x - head.x, aim.y - head.y
		dist = math.max(math.sqrt(dx * dx + dy * dy), 1)
		c.goal = math.deg(math.atan2(dy, dx))
		sway = sway * math.Clamp(dist / wave - CLOSE, 0, 1)
	end
	c.sway = c.sway and c.sway + (sway - c.sway) * math.min(1, SWAY_EASE * DT) or sway
	if not c.driving then
		c.driving, c.spin = true, 0
		c.yaw = Chain.HeadYaw(c) - c.sway * math.sin(c.phase)
		Reseed(c)
	end
	local turn = Setting("turn_rate") * (c.quick or 1)
	local diff = math.AngleDifference(c.goal, c.yaw)
	local want = diff * AIM
	if dist then
		local chase = math.deg(2 * math.sin(math.rad(diff)) * c.speed / dist)
		if math.abs(chase) > math.abs(want) then want = chase end
	end
	want = math.Clamp(want, -turn, turn)
	c.spin = c.spin + (want - c.spin) * math.min(1, (SPIN + c.speed / SPIN_SPEED) * DT)
	c.yaw = c.yaw + c.spin * DT
	c.phase = (c.phase + c.speed * DT / wave * math.pi * 2) % (math.pi * 2)
	local heading = math.rad(c.yaw + c.sway * math.sin(c.phase))
	return Vector(math.cos(heading), math.sin(heading), 0) * (c.speed * DT)
end

local function CellKey(x, y, z)
	return (x + 2048) + (y + 2048) * 4096 + (z + 2048) * 16777216
end

local function Nearby(c, p, n, link)
	local hull = c.hull
	local widest = 0
	for i = 1, n do widest = math.max(widest, hull[i]) end
	widest = widest / HULL
	local cell = link + widest * 2 + SELF_MARGIN
	local grid, at = {}, {}
	for s = 1, n - 1 do
		local a, b = p[s], p[s + 1]
		local gx = math.floor((a.x + b.x) * 0.5 / cell)
		local gy = math.floor((a.y + b.y) * 0.5 / cell)
		local gz = math.floor((a.z + b.z) * 0.5 / cell)
		at[s] = { gx, gy, gz }
		local key = CellKey(gx, gy, gz)
		local bucket = grid[key]
		if not bucket then
			bucket = {}
			grid[key] = bucket
		end
		bucket[#bucket + 1] = s
	end
	local found = {}
	for s = 1, n - 1 do
		local g = at[s]
		local rs = math.max(hull[s], hull[s + 1]) / HULL
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					local bucket = grid[CellKey(g[1] + dx, g[2] + dy, g[3] + dz)]
					if bucket then
						for _, t in ipairs(bucket) do
							if t > s + 1 then
								local rt = math.max(hull[t], hull[t + 1]) / HULL
								if (t - s) * link >= (rs + rt) * SELF_ARC then
									found[#found + 1] = s
									found[#found + 1] = t
								end
							end
						end
					end
				end
			end
		end
	end
	return found
end

local function Push(p, i, wx, wy, wz)
	local v = p[i]
	v:SetUnpacked(v.x + wx, v.y + wy, v.z + wz)
end

local function Separate(c, p, found)
	local hull = c.hull
	for k = 1, #found, 2 do
		local i, j = found[k], found[k + 1]
		local p1, q1, p2, q2 = p[i], p[i + 1], p[j], p[j + 1]
		local d1x, d1y, d1z = q1.x - p1.x, q1.y - p1.y, q1.z - p1.z
		local d2x, d2y, d2z = q2.x - p2.x, q2.y - p2.y, q2.z - p2.z
		local rx, ry, rz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
		local a = d1x * d1x + d1y * d1y + d1z * d1z
		local e = d2x * d2x + d2y * d2y + d2z * d2z
		if a > 1e-6 and e > 1e-6 then
			local b = d1x * d2x + d1y * d2y + d1z * d2z
			local cc = d1x * rx + d1y * ry + d1z * rz
			local f = d2x * rx + d2y * ry + d2z * rz
			local denom = a * e - b * b
			local s = denom > 1e-6 and math.Clamp((b * f - cc * e) / denom, 0, 1) or 0
			local t = (b * s + f) / e
			if t < 0 then
				t, s = 0, math.Clamp(-cc / a, 0, 1)
			elseif t > 1 then
				t, s = 1, math.Clamp((b - cc) / a, 0, 1)
			end
			local nx = rx + d1x * s - d2x * t
			local ny = ry + d1y * s - d2y * t
			local nz = rz + d1z * s - d2z * t
			local dist = math.sqrt(nx * nx + ny * ny + nz * nz)
			local reach = (Lerp(s, hull[i], hull[i + 1]) + Lerp(t, hull[j], hull[j + 1])) / HULL
			if dist < reach then
				if dist > 1e-4 then
					nx, ny, nz = nx / dist, ny / dist, nz / dist
				else
					nx, ny, nz = 0, 0, 1
				end
				local half = (reach - dist) * 0.5 * SELF_STIFF
				local ks = half / ((1 - s) ^ 2 + s * s)
				local kt = half / ((1 - t) ^ 2 + t * t)
				Push(p, i, nx * ks * (1 - s), ny * ks * (1 - s), nz * ks * (1 - s))
				Push(p, i + 1, nx * ks * s, ny * ks * s, nz * ks * s)
				Push(p, j, -nx * kt * (1 - t), -ny * kt * (1 - t), -nz * kt * (1 - t))
				Push(p, j + 1, -nx * kt * t, -ny * kt * t, -nz * kt * t)
			end
		end
	end
end

local function Tick(c)
	local x, old, p, cn, cd = c.x, c.old, c.p, c.cn, c.cd
	local n = #x
	local link = Chain.Link(c)
	local curl = Setting("curl")
	for i = 1, n - 2 do
		local bend = math.min(link / math.max(curl * c.hull[i + 1] / HULL, 1e-3), MAX_BEND)
		folds[i] = 2 * link * math.cos(bend * 0.5)
	end
	local gravity = Setting("gravity")
	local fall = Vector(0, 0, -gravity * DT * DT)
	local wet = c.wet
	for i = 1, n do
		local soak = Soak(c, i, x[i])
		wet[i] = soak
		p[i] = x[i] + (x[i] - old[i]) * (soak > 0 and WET_DAMP or DAMP) + fall * (1 - BUOY * soak)
	end
	local want = c.want or 0
	if c.driving and c.goal then
		want = want * math.max(math.cos(math.rad(math.AngleDifference(c.goal, c.yaw))), TURN_SLOW)
	end
	c.speed = c.speed + (want - c.speed) * math.min(1, PACE * DT)
	if want <= 0 and c.speed < CRAWL then c.speed = 0 end
	local swim = wet[1] > 0 and (not cn[1] or wet[1] >= 1 and not (c.aim and c.aim.z < x[1].z))
	if c.speed > 0 then
		local step = Steer(c)
		if cn[1] and not swim then
			p[1] = x[1] + step + Vector(0, 0, (x[1].z - old[1].z) * DAMP) + fall
		elseif swim then
			local cap = c.speed * DT * DIVE
			local to = x[1] + step * (1 + SURGE * math.cos(c.phase * 2))
			to.z = to.z + math.Clamp(c.aim and c.aim.z - x[1].z or cap, -cap, cap)
			if to.z > x[1].z and not Wet(to) then to.z = x[1].z end
			p[1] = to
		end
		Record(c, x[1])
		local follow = Setting("follow")
		if follow > 0 and Follow(c, p, follow) then Reseed(c) end
	else
		c.driving = false
	end
	local pin = c.driving and (cn[1] ~= nil or swim)
	local found = Setting("self_collide") ~= 0 and n > 3 and Nearby(c, p, n, link) or nil
	if found and #found == 0 then found = nil end
	for _ = 1, Setting("solver_passes") do
		for i = 1, n - 1 do
			local d = p[i + 1] - p[i]
			local len = d:Length()
			if len > 1e-4 then
				local fix = d * ((len - link) / len * 0.5)
				if i == 1 and pin then
					p[2] = p[2] - fix * 2
				else
					p[i], p[i + 1] = p[i] + fix, p[i + 1] - fix
				end
			end
		end
		for i = 1, n - 2 do
			local d = p[i + 2] - p[i]
			local len = d:Length()
			local fold = folds[i]
			if len < fold and len > 1e-4 then
				local fix = d * ((len - fold) / len * 0.5)
				if i == 1 and pin then
					p[3] = p[3] - fix * 2
				else
					p[i], p[i + 2] = p[i] + fix, p[i + 2] - fix
				end
			end
		end
		if found then Separate(c, p, found) end
		for i = 1, n do
			local normal = cn[i]
			if normal then
				local depth = p[i]:Dot(normal) - cd[i]
				if depth < 0 then p[i] = p[i] - normal * depth end
			end
		end
	end
	local moved, slid = 0, 0
	for i = 1, n do
		local along = (p[math.min(i + 1, n)] - p[math.max(i - 1, 1)]):GetNormalized()
		local to, climbed = Collide(c, i, x[i], p[i], along, gravity)
		old[i], x[i] = climbed and Vector(x[i].x, x[i].y, to.z) or x[i], to
		moved = math.max(moved, to:DistToSqr(old[i]))
		if cn[i] then slid = slid + math.sqrt((to.x - old[i].x) ^ 2 + (to.y - old[i].y) ^ 2) end
	end
	c.slide = slid / n / DT
	return moved
end

function Chain.Update(c, dt)
	Size(c)
	if not c.awake then
		c.slide = 0
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
