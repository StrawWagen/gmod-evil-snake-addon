EvilSnake = EvilSnake or {}
local Eyes = {}
EvilSnake.Eyes = Eyes

local sqrt, sin, cos, min, max, exp = math.sqrt, math.sin, math.cos, math.min, math.max, math.exp

local STALK = 1.05
local STALK_R = 0.1
local STALK_TIP = 0.055
local SEGS = 7
local SIDES = 6
local BALL = 0.25
local BALL_RINGS = 10
local BALL_SIDES = 12
local SPRING = 240
local DAMP = 6
local LEAN = 0.9
local UPRIGHT = 1.2
local ALERT_UPRIGHT = 0.7
local ALERT_REACH = 1.15
local KICK = 70
local JITTER = 6
local SACCADE = 16
local GLANCE = { 0.5, 2.2 }
local STARE = 500
local STEP = 1 / 60
local SCLERA = { 235, 215, 120 }
local IRIS = { 215, 95, 20 }
local PUPIL = { 8, 6, 6 }
local PUPIL_W = 0.22
local PUPIL_H = 0.6
local IRIS_AT = 0.55

local cube
local scratch = Vector()

local function Emit(x, y, z, r, g, b, nx, ny, nz)
	local l = EvilSnake.Bright(cube, 0, nx, ny, nz)
	scratch:SetUnpacked(x, y, z)
	mesh.Position(scratch)
	mesh.TexCoord(0, 0, 0)
	mesh.Color(min(255, r * l), min(255, g * l), min(255, b * l), 255)
	mesh.AdvanceVertex()
end

local function Want(e, base, now, look, head)
	if look then
		if not e.alert then
			e.alert = true
			e.vel = e.vel + VectorRand() * KICK
		end
		if now >= e.next then
			e.next = now + math.Rand(0.15, 0.5)
			e.jit = VectorRand() * JITTER
		end
		return look + e.jit
	end
	e.alert = false
	if now >= e.next then
		e.next = now + math.Rand(GLANCE[1], GLANCE[2])
		e.vel = e.vel + VectorRand() * KICK * 0.5
		local ply = LocalPlayer()
		if IsValid(ply) and ply:Alive() and ply:EyePos():DistToSqr(base) < STARE * STARE and math.random() < 0.5 then
			e.ent, e.aim = ply, nil
		else
			e.ent = nil
			e.aim = head.p + head.f * math.Rand(60, 260) + head.r * math.Rand(-220, 220) + head.u * math.Rand(-20, 90)
		end
	end
	if IsValid(e.ent) then return e.ent:EyePos() end
	return e.aim or base + head.f * 100
end

local function Simulate(e, base, up, want, L, dt)
	local to = want - base
	to:Normalize()
	local aim = up * (e.alert and ALERT_UPRIGHT or UPRIGHT) + to * LEAN
	aim:Normalize()
	local rest = base + aim * (L * (e.alert and ALERT_REACH or 1))
	if not e.tip then e.tip, e.vel, e.look = rest, Vector(), Vector(to) end
	local steps = math.ceil(dt / STEP)
	local h = steps > 0 and dt / steps or 0
	for _ = 1, steps do
		e.vel = e.vel + ((rest - e.tip) * (SPRING * e.k) - e.vel * DAMP) * h
		e.tip = e.tip + e.vel * h
	end
	local d = e.tip - base
	local len = d:Length()
	if len > 1e-3 then e.tip = base + d * (math.Clamp(len, L * 0.7, L * 1.25) / len) end
	local lv = want - e.tip
	lv:Normalize()
	e.look = LerpVector(1 - exp(-dt * SACCADE * e.k), e.look, lv)
	e.look:Normalize()
end

local function Stalk(base, up, tip, side, W, cr, cg, cb)
	local L = (tip - base):Length()
	local ctrl = base + up * (L * 0.55)
	mesh.Begin(MATERIAL_QUADS, SEGS * SIDES)
	local prev
	for i = 0, SEGS do
		local t = i / SEGS
		local a, b = (1 - t) * (1 - t), 2 * (1 - t) * t
		local c = t * t
		local p = base * a + ctrl * b + tip * c
		local tan = (ctrl - base) * (2 * (1 - t)) + (tip - ctrl) * (2 * t)
		tan:Normalize()
		local n1 = side - tan * side:Dot(tan)
		n1:Normalize()
		local n2 = tan:Cross(n1)
		local r = W * Lerp(t, STALK_R, STALK_TIP) * (i % 2 == 1 and 1.18 or 1)
		local shade = i % 2 == 1 and 0.85 or 1
		local ring = {}
		for q = 0, SIDES do
			local ang = q / SIDES * math.pi * 2
			local nx = n1 * cos(ang) + n2 * sin(ang)
			ring[q] = { p + nx * r, nx, cr * shade, cg * shade, cb * shade }
		end
		if prev then
			for q = 0, SIDES - 1 do
				for _, v in ipairs({ prev[q], prev[q + 1], ring[q + 1], ring[q] }) do
					Emit(v[1].x, v[1].y, v[1].z, v[3], v[4], v[5], v[2].x, v[2].y, v[2].z)
				end
			end
		end
		prev = ring
	end
	mesh.End()
	local tan = tip - ctrl
	tan:Normalize()
	return tan
end

local function Ball(center, look, r)
	local right = look:Cross(Vector(0, 0, 1))
	if right:LengthSqr() < 1e-4 then right = look:Cross(Vector(1, 0, 0)) end
	right:Normalize()
	local top = right:Cross(look)
	mesh.Begin(MATERIAL_QUADS, BALL_RINGS * BALL_SIDES)
	local function Corner(i, q)
		local lat = (i / BALL_RINGS - 0.5) * math.pi
		local lon = q / BALL_SIDES * math.pi * 2
		local n = look * sin(lat) + (right * cos(lon) + top * sin(lon)) * cos(lat)
		local f, s, u = n:Dot(look), n:Dot(right), n:Dot(top)
		local col = SCLERA
		if f > 0.3 then
			local pupil = (s / PUPIL_W) ^ 2 + (u / PUPIL_H) ^ 2
			if pupil < 1 then
				col = PUPIL
			elseif f > IRIS_AT then
				col = IRIS
			end
		end
		local p = center + n * r
		Emit(p.x, p.y, p.z, col[1], col[2], col[3], n.x, n.y, n.z)
	end
	for i = 0, BALL_RINGS - 1 do
		for q = 0, BALL_SIDES - 1 do
			Corner(i, q)
			Corner(i, q + 1)
			Corner(i + 1, q + 1)
			Corner(i + 1, q)
		end
	end
	mesh.End()
end

function Eyes.Draw(state, light, stalks, head, W, look, cr, cg, cb)
	cube = light
	local now = RealTime()
	local dt = math.Clamp(now - (state.t or now), 0, 0.1)
	state.t = now
	local L = W * STALK
	for i, s in ipairs(stalks) do
		local e = state[i]
		if not e then
			e = { vel = Vector(), next = 0, k = 1 + (i - 1.5) * 0.3, jit = Vector() }
			state[i] = e
		end
		Simulate(e, s.base, s.up, Want(e, s.base, now, look, head), L, dt)
		local tan = Stalk(s.base, s.up, e.tip, s.side, W, cr * 0.9, cg * 0.9, cb * 0.9)
		Ball(e.tip + tan * (W * BALL * 0.6), e.look, W * BALL)
	end
end
