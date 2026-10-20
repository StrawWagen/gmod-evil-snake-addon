EvilSnake = EvilSnake or {}
local Tongue = {}
EvilSnake.Tongue = Tongue

local Bright, CatmullRom = EvilSnake.Bright, EvilSnake.CatmullRom
local sqrt, sin, cos, min, max, abs = math.sqrt, math.sin, math.cos, math.min, math.max, math.abs

local IN, OUT, WRAP, BACK = EvilSnake.TONGUE_IN, EvilSnake.TONGUE_OUT, EvilSnake.TONGUE_WRAP, EvilSnake.TONGUE_BACK
local BONE = EvilSnake.TONGUE_BONE
local OPEN = EvilSnake.TONGUE_OPEN
local POINTS = 16
local REACH_POINTS = 12
local COIL_POINTS = 18
local SUB = 2
local SIDES = 8
local ROOT = 0.4
local LIP = 2
local LEAD = 0.3
local WIDTH = 0.26
local TAPER = 0.65
local GAPE = 1.6
local WAVES = { [OUT] = 1.2, [WRAP] = 1, [BACK] = 2 }
local AMP = { [OUT] = 0.05, [WRAP] = 0.03, [BACK] = 0.14 }
local WAVE_SPEED = 14
local NOISE = 3
local WRAP_TIME = 0.35
local TURNS = 2.4
local FORK = 0.6
local FORK_SPREAD = 0.5
local PAD = 48
local COLOR = { 230, 110, 140 }
local ROOT_COLOR = { 170, 60, 85 }
local TORSO = { "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Neck1", 9 }
local UP = Vector(0, 0, 1)
local SIDE = Vector(1, 0, 0)

local function Smooth(u)
	return u * u * (3 - 2 * u)
end

local function Wobble(t, phase, freq)
	return sin(t * freq + phase) + 0.5 * sin(t * freq * 2.3 + phase * 1.7),
		sin(t * freq * 0.9 + phase * 3.3) + 0.5 * sin(t * freq * 3.1 + phase * 0.6)
end

local function Bone(ent, name)
	local bone = ent:LookupBone(name)
	return bone and ent:GetBonePosition(bone)
end

function Tongue.New()
	return { state = IN, open = 0, light = {}, pts = {}, seed = math.Rand(0, 100), spin = 1, wrapAt = 0 }
end

function Tongue.Update(view, a, b, u, dt)
	local s = (u < 0.5 and a or b) or a or b
	local state = s and s.state or IN
	if state == WRAP and view.state ~= WRAP then
		view.wrapAt = RealTime()
		view.spin = math.random() < 0.5 and -1 or 1
	end
	view.state = state
	view.open = math.Approach(view.open, state ~= IN and 1 or 0, dt / OPEN)
	view.rag = nil
	if state == IN then
		view.tip, view.ent = nil, nil
		return
	end
	local ta, tb = a and a.tip, b and b.tip
	view.tip = ta and tb and LerpVector(u, ta, tb) or tb or ta
	view.ent = IsValid(s.ent) and s.ent or nil
	if state ~= WRAP or not view.ent then return end
	local rag = view.ent:GetNW2Entity("EvilRagdoll")
	if not IsValid(rag) then return end
	view.rag = rag
	view.tip = Bone(rag, BONE) or view.tip
end

function Tongue.Gape(view, head, neck, W)
	if view.open <= 0 then return end
	local f = (head - neck):GetNormalized()
	local dir
	if view.tip then
		local aim = (view.tip - head):GetNormalized()
		if aim:Dot(f) > -0.2 then dir = (f + aim):GetNormalized() end
	end
	return { fit = W * GAPE, open = view.open, dir = dir or (f + UP * 0.5):GetNormalized() }
end

function Tongue.Look(view)
	if view.state == WRAP then return view.tip end
	local ent = view.ent
	if IsValid(ent) then return ent.EyePos and ent:EyePos() or ent:WorldSpaceCenter() end
end

function Tongue.Bounds(view, mins, maxs)
	local tip = view.state ~= IN and view.tip
	if not tip then return mins, maxs end
	return Vector(min(mins.x, tip.x - PAD), min(mins.y, tip.y - PAD), min(mins.z, tip.z - PAD)),
		Vector(max(maxs.x, tip.x + PAD), max(maxs.y, tip.y + PAD), max(maxs.z, tip.z + PAD))
end

local function Free(view, pts, o, root, lip, dir, tip, now, count, state)
	local along = tip - root
	local dist = along:Length()
	if dist > 1e-3 then along = along / dist else along = dir end
	local side = along:Cross(UP)
	if side:LengthSqr() < 1e-4 then side = along:Cross(SIDE) end
	side:Normalize()
	local up = side:Cross(along)
	local ctrl = lip + dir * (lip:Distance(tip) * LEAD)
	local amp, waves, loose = dist * AMP[state], WAVES[state], state == BACK
	for i = 1, count do
		local f = (i - 1) / (count - 1)
		local g = 1 - f
		local w = (loose and f or sin(math.pi * f)) * Smooth(min(f / 0.2, 1)) * amp
		local ph = f * waves * math.pi * 2 - now * WAVE_SPEED + view.seed
		local nx, nz = Wobble(now, view.seed + i * 1.9, NOISE)
		pts[o + i] = root * (g * g) + ctrl * (2 * g * f) + tip * (f * f)
			+ side * ((sin(ph) + nx * 0.4) * w) + up * ((0.6 * cos(ph * 0.8) + nz * 0.4) * w)
	end
	return o + count
end

local function Axis(view)
	local rag = view.rag
	local a, b = Bone(rag, TORSO[1]), Bone(rag, TORSO[2])
	if a and b then return a, b, TORSO[3] end
	local ent = view.ent
	local c = rag:WorldSpaceCenter()
	local size = IsValid(ent) and ent:OBBMaxs() - ent:OBBMins() or Vector(24, 24, 48)
	return c - UP * (size.z * 0.25), c + UP * (size.z * 0.25), min(size.x, size.y) * 0.4
end

local function Coil(view, pts, root, lip, dir, width, now)
	local a, b, r = Axis(view)
	if root:DistToSqr(b) < root:DistToSqr(a) then a, b = b, a end
	local axis = b - a
	local span = axis:Length()
	axis = axis / max(span, 1)
	local out = root - a
	out = out - axis * out:Dot(axis)
	if out:LengthSqr() < 1e-4 then out = axis:Angle():Right() end
	out:Normalize()
	local v = axis:Cross(out)
	r = r + width
	local n = Free(view, pts, 0, root, lip, dir, a + out * r, now, REACH_POINTS, WRAP)
	local climb = Smooth(math.Clamp((now - view.wrapAt) / WRAP_TIME, 0, 1))
	for i = 1, COIL_POINTS do
		local f = i / COIL_POINTS * climb
		local theta = f * TURNS * math.pi * 2 * view.spin
		pts[n + i] = a + axis * (span * f) + (out * cos(theta) + v * sin(theta)) * r
	end
	return n + COIL_POINTS
end

local px, py, pz, pf = {}, {}, {}, {}
local verts, vr, vg, vb = {}, {}, {}, {}

local function Vert(i)
	mesh.Position(verts[i])
	mesh.TexCoord(0, 0, 0)
	mesh.Color(vr[i], vg[i], vb[i], 255)
	mesh.AdvanceVertex()
end

local function Tube(pts, n, r0, r1, c0, c1, light)
	local count = 0
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = pts[max(i - 1, 1)], pts[i], pts[i + 1], pts[min(i + 2, n)]
		for s = 0, SUB - 1 do
			local t = s / SUB
			local p = CatmullRom(p0, p1, p2, p3, t)
			count = count + 1
			px[count], py[count], pz[count] = p.x, p.y, p.z
			pf[count] = (i - 1 + t) / (n - 1)
		end
	end
	count = count + 1
	px[count], py[count], pz[count], pf[count] = pts[n].x, pts[n].y, pts[n].z, 1
	local tr = EvilSnake.Trig(SIDES)
	local nx, ny, nz = 0, 0, 1
	for j = 1, count do
		local a, b = max(j - 1, 1), min(j + 1, count)
		local tx, ty, tz = px[b] - px[a], py[b] - py[a], pz[b] - pz[a]
		local tl = sqrt(tx * tx + ty * ty + tz * tz)
		if tl < 1e-6 then tx, ty, tz, tl = 0, 0, 1, 1 end
		tx, ty, tz = tx / tl, ty / tl, tz / tl
		local d = nx * tx + ny * ty + nz * tz
		nx, ny, nz = nx - tx * d, ny - ty * d, nz - tz * d
		local nl = sqrt(nx * nx + ny * ny + nz * nz)
		if nl < 1e-4 then
			if abs(tz) < 0.9 then nx, ny, nz = -ty, tx, 0 else nx, ny, nz = 0, -tz, ty end
			nl = sqrt(nx * nx + ny * ny + nz * nz)
		end
		nx, ny, nz = nx / nl, ny / nl, nz / nl
		local bx, by, bz = ty * nz - tz * ny, tz * nx - tx * nz, tx * ny - ty * nx
		local f = pf[j]
		local r = Lerp(f ^ 1.5, r0, r1)
		local k = min(f * 3, 1)
		local cr, cg, cb = Lerp(k, c0[1], c1[1]), Lerp(k, c0[2], c1[2]), Lerp(k, c0[3], c1[3])
		for q = 0, SIDES - 1 do
			local c, s = tr.c[q], tr.s[q]
			local dx, dy, dz = nx * c + bx * s, ny * c + by * s, nz * c + bz * s
			local i = (j - 1) * SIDES + q + 1
			local v = verts[i]
			if not v then
				v = Vector()
				verts[i] = v
			end
			v:SetUnpacked(px[j] + dx * r, py[j] + dy * r, pz[j] + dz * r)
			local l = Bright(light, 0, dx, dy, dz)
			vr[i], vg[i], vb[i] = min(255, cr * l), min(255, cg * l), min(255, cb * l)
		end
	end
	mesh.Begin(MATERIAL_QUADS, (count - 1) * SIDES)
	for j = 1, count - 1 do
		local r0i, r1i = (j - 1) * SIDES, j * SIDES
		for q = 0, SIDES - 1 do
			local q2 = (q + 1) % SIDES
			Vert(r0i + q + 1)
			Vert(r0i + q2 + 1)
			Vert(r1i + q2 + 1)
			Vert(r1i + q + 1)
		end
	end
	mesh.End()
end

local function Fork(pts, n, W, r, light)
	local tip = pts[n]
	local t = tip - pts[n - 1]
	t:Normalize()
	local side = t:Cross(UP)
	if side:LengthSqr() < 1e-4 then side = t:Cross(SIDE) end
	side:Normalize()
	local len = W * FORK
	for s = -1, 1, 2 do
		local spread = side * (s * FORK_SPREAD)
		local prong = { tip - t * (len * 0.2), tip + (t + spread * 0.5) * (len * 0.5), tip + (t + spread) * len }
		Tube(prong, 3, r, r * 0.15, COLOR, COLOR, light)
	end
end

function Tongue.Draw(view, body, now)
	if view.state == IN or not view.tip or not body.head then return end
	local W, dir = body.W, body.dir
	local root = body.head + dir * (W * ROOT)
	local lip = body.head + dir * (W * LIP)
	local pts = view.pts
	local n
	if view.state == WRAP and view.rag then
		n = Coil(view, pts, root, lip, dir, W * WIDTH, now)
	else
		n = Free(view, pts, 0, root, lip, dir, view.tip, now, POINTS, view.state == WRAP and OUT or view.state)
	end
	for i = n + 1, #pts do pts[i] = nil end
	EvilSnake.SampleLight(pts[math.ceil(n / 2)], view.light, 0)
	render.SetMaterial(EvilSnake.Material)
	local r0 = W * WIDTH
	local r1 = r0 * (1 - TAPER)
	Tube(pts, n, r0, r1, ROOT_COLOR, COLOR, view.light)
	if view.state ~= WRAP then Fork(pts, n, W, r1, view.light) end
end
