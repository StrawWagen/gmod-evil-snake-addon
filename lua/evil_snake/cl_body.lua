EvilSnake = EvilSnake or {}
local Body = {}
EvilSnake.Body = Body

local Smooth, Bright = EvilSnake.Smooth, EvilSnake.Bright

local skin = Material("evil_snake/skin.png", "noclamp smooth mips")
if not skin:IsError() then EvilSnake.Material:SetTexture("$basetexture", skin:GetTexture("$basetexture")) end

Body.SEGMENTS = 28
Body.SPACING = 17

local STEP = 24
local DROP = 120
local SUB = 4
local SIDES = 20
local RADIUS = 13
local HEAD = 3
local MOUTH = 1.35
local NECK = 0.85
local LIP = 0.35
local LIP_IN = 0.8
local TAIL_START = 0.3
local TAIL_POW = 1.15
local TAIL_TIP = 0.05
local FLAT = 0.82
local HEAD_FLAT = 0.8
local BELLY_FLAT = 0.45
local KEEL = 0.16
local FINE = 0.15
local COARSE = 0.32
local PAD = 72
local TILE_U = 1
local TILE_V = 140
local RIB_SPACING = 0.5
local RIB = 0.05
local LUMPS = { 5, 9 }
local WAVE = 0.14
local WAVE_WIDTH = 1.6
local WAVE_SPEED = 55
local WAVE_GAP = 0.5
local BREATHE = 0.025
local BREATHE_SPEED = 1.1
local TUFTS = { 14, 22 }
local TUFT = { 2, 6 }
local TUFT_SPREAD = 0.008
local CILIA_FROM = 0.06
local CILIA_TO = 0.8
local CILIA_SIDES = 4
local CILIA_SUB = 2
local CILIA_BEAT = 2.2
local CILIA_WAVE = 0.55
local CILIA_SWING = 0.55
local TENDRILS = { 3, 5 }
local TENDRIL_SIDES = 5
local TENDRIL_SUB = 3

local SKIN = Vector(66, 56, 64)
local BELLY = Vector(168, 146, 140)
local PALE = Vector(196, 184, 170)
local VEIN = Vector(30, 12, 22)
local BLUSH = Vector(140, 58, 66)
local TIP = Vector(128, 72, 80)

function Body.Genes(seed)
	local rand = EvilSnake.Rng(seed * 7 + 3)
	local g = { phase = {}, lumps = {}, cilia = {}, tendrils = {} }
	for i = 1, 8 do g.phase[i] = rand(0, math.pi * 2) end
	g.rib = rand(0.85, 1.15)
	g.tint = Vector(rand(0.88, 1.08), rand(0.9, 1.04), rand(0.9, 1.12))
	for i = 1, math.floor(rand(LUMPS[1], LUMPS[2] + 1)) do
		g.lumps[i] = {
			at = rand(0.1, 0.8), theta = math.pi * 0.5 + rand(-1.7, 1.7), amp = rand(0.07, 0.22),
			len = rand(0.6, 1.8) * RADIUS, width = rand(0.45, 1.1),
		}
	end
	for _ = 1, math.floor(rand(TUFTS[1], TUFTS[2] + 1)) do
		local at, theta = rand(CILIA_FROM, CILIA_TO), math.pi * 0.5 + rand(-1.1, 1.1)
		for _ = 1, math.floor(rand(TUFT[1], TUFT[2] + 1)) do
			g.cilia[#g.cilia + 1] = {
				at = at + rand(-TUFT_SPREAD, TUFT_SPREAD), theta = theta + rand(-0.25, 0.25),
				len = rand(0.45, 1.1), width = rand(0.06, 0.1), phase = rand(-0.6, 0.6), freq = rand(0.6, 1.4), drift = rand(0, 100),
			}
		end
	end
	table.sort(g.cilia, function(a, b) return a.at < b.at end)
	local count = math.floor(rand(TENDRILS[1], TENDRILS[2] + 1))
	for i = 1, count do
		g.tendrils[i] = {
			angle = (i - 1) / count * math.pi * 2 + rand(-0.4, 0.4), spread = rand(0.3, 0.8),
			len = rand(1.4, 2.6), width = rand(0.05, 0.09), phase = rand(0, 100), freq = rand(0.5, 1.2),
		}
	end
	return g
end

function Body.Layout(origin, yaw, filter)
	local fwd = Angle(0, yaw, 0):Forward()
	local ground, normals = {}, {}
	local z = origin.z
	for i = 0, Body.SEGMENTS do
		local p = origin - fwd * (i * Body.SPACING)
		local tr = util.TraceLine({
			start = Vector(p.x, p.y, z + STEP),
			endpos = Vector(p.x, p.y, z - DROP),
			mask = MASK_SOLID,
			filter = filter,
		})
		if tr.Hit and not tr.StartSolid then
			z = tr.HitPos.z
			ground[i + 1], normals[i + 1] = tr.HitPos, tr.HitNormal
		else
			ground[i + 1], normals[i + 1] = Vector(p.x, p.y, z), Vector(0, 0, 1)
		end
	end
	return ground, normals
end

function Body.Bounds(ground)
	local mins, maxs = Vector(ground[1]), Vector(ground[1])
	for _, p in ipairs(ground) do
		mins.x, mins.y, mins.z = math.min(mins.x, p.x), math.min(mins.y, p.y), math.min(mins.z, p.z)
		maxs.x, maxs.y, maxs.z = math.max(maxs.x, p.x), math.max(maxs.y, p.y), math.max(maxs.z, p.z)
	end
	return mins - Vector(PAD, PAD, PAD), maxs + Vector(PAD, PAD, PAD)
end

local function Spine(ground, normals)
	local n = #ground
	local pts, ups, dist = {}, {}, {}
	local total = 0
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = ground[math.max(i - 1, 1)], ground[i], ground[i + 1], ground[math.min(i + 2, n)]
		for s = 0, SUB - 1 do
			local t = s / SUB
			local p = EvilSnake.CatmullRom(p0, p1, p2, p3, t)
			local k = #pts
			if k > 0 then total = total + p:Distance(pts[k]) end
			pts[k + 1], ups[k + 1], dist[k + 1] = p, LerpVector(t, normals[i], normals[i + 1]), total
		end
	end
	local k = #pts
	total = total + ground[n]:Distance(pts[k])
	pts[k + 1], ups[k + 1], dist[k + 1] = ground[n], normals[n], total
	return { pts = pts, ups = ups, dist = dist, total = total }
end

local function Profile(d, total)
	local x = d / RADIUS
	local h = x / HEAD
	local w
	if h < 0.4 then
		w = MOUTH
	elseif h < 1 then
		w = Lerp(Smooth((h - 0.4) / 0.6), MOUTH, NECK)
	else
		w = Lerp(Smooth((h - 1) / 1.5), NECK, 1)
	end
	w = w * Lerp(Smooth(x / LIP), LIP_IN, 1)
	local f = d / total
	if f > TAIL_START then w = w * math.max(TAIL_TIP, ((1 - f) / (1 - TAIL_START)) ^ TAIL_POW) end
	return RADIUS * w, RADIUS * w * Lerp(Smooth(h - 0.5), HEAD_FLAT, FLAT)
end

local function Frame(spine, d, hint)
	local pts, dist = spine.pts, spine.dist
	local j = hint or 1
	while j < #pts - 1 and dist[j + 1] < d do j = j + 1 end
	local span = dist[j + 1] - dist[j]
	local t = span > 0 and math.Clamp((d - dist[j]) / span, 0, 1) or 0
	local center = LerpVector(t, pts[j], pts[j + 1])
	local up = LerpVector(t, spine.ups[j], spine.ups[j + 1])
	local tangent = (pts[j + 1] - pts[j]):GetNormalized()
	local side = tangent:Cross(up):GetNormalized()
	up = side:Cross(tangent):GetNormalized()
	local w, h = Profile(d, spine.total)
	return center + up * (h * BELLY_FLAT), side, up, w, h, j, tangent
end

local function Surface(base, side, up, w, h, theta)
	local c, s = math.cos(theta), math.sin(theta)
	local hs = s < 0 and h * BELLY_FLAT or h * (1 + KEEL * s ^ 6)
	return base + side * (c * w) + up * (s * hs), (side * (c / w) + up * (s / hs)):GetNormalized()
end

local function Rib(x, total, g)
	local fade = Smooth((x - HEAD) / 1.5) * Smooth((total / RADIUS - x) / 6)
	local wave = 0.5 + 0.5 * math.cos((x / (RIB_SPACING * g.rib) + 0.3 * math.sin(x * 0.21 + g.phase[1])) * math.pi * 2)
	return wave ^ 4 * fade
end

local function Lump(d, total, theta, g)
	local sum = 0
	for _, l in ipairs(g.lumps) do
		local e = (d - l.at * total) / l.len
		local a = math.abs((theta - l.theta + math.pi) % (math.pi * 2) - math.pi) / l.width
		sum = sum + l.amp * math.exp(-e * e - a * a)
	end
	return sum
end

local function Shade(x, theta, s, rib, lump, g)
	local p = g.phase
	local col = LerpVector(Smooth((-s - 0.1) / 0.4), SKIN, BELLY)
	local mottle = 0.5 + 0.25 * (math.sin(x * 0.23 + theta + p[2]) + math.sin(x * 0.61 - theta * 2 + p[3]))
	col = col * Lerp(mottle, 0.62, 1.15)
	col = LerpVector(rib * 0.28 * Smooth(s * 1.5 + 0.2), col, PALE)
	col = LerpVector(math.min(1, lump * 3), col, BLUSH)
	local n = math.sin(x * 0.35 + 2.4 * math.sin(theta * 2 + p[4]) + 1.6 * math.sin(x * 0.13 + p[5]))
	local vein = (1 - Smooth(math.abs(n) / 0.3)) * (0.25 + lump * 3)
	col = LerpVector(math.min(0.85, vein), col, VEIN)
	return Vector(col.x * g.tint.x, col.y * g.tint.y, col.z * g.tint.z)
end

function Body.Build(ground, normals, g)
	local spine = Spine(ground, normals)
	local total = spine.total
	local tr = EvilSnake.Trig(SIDES)
	local shape = {
		total = total, count = 0, d = {}, amp = {}, bx = {}, by = {}, bz = {},
		ox = {}, oy = {}, oz = {}, cr = {}, cg = {}, cb = {},
		cilia = {}, tendrils = {},
	}
	local hint, d = 1, 0
	while true do
		local base, side, up, w, h, j = Frame(spine, d, hint)
		hint = j
		EvilSnake.SampleLight(base + up * h)
		local n = shape.count + 1
		shape.count = n
		shape.d[n] = d
		shape.bx[n], shape.by[n], shape.bz[n] = base.x, base.y, base.z
		local x = d / RADIUS
		local rib = Rib(x, total, g)
		for k = 0, SIDES - 1 do
			local theta = k / SIDES * math.pi * 2
			local s = tr.s[k]
			local pos, normal = Surface(base, side, up, w, h, theta)
			local lump = Lump(d, total, theta, g)
			local grow = (1 + lump) * (1 + RIB * rib * math.max(0, s + 0.3))
			local off = (pos - base) * grow
			local col = Shade(x, theta, s, rib, lump, g) * Bright(normal.x, normal.y, normal.z)
			local i = (n - 1) * SIDES + k + 1
			shape.ox[i], shape.oy[i], shape.oz[i] = off.x, off.y, off.z
			shape.cr[i], shape.cg[i], shape.cb[i] = col.x, col.y, col.z
		end
		if d >= total then break end
		local fine = x < LIP * 2 or d > total * 0.9
		d = math.min(d + (fine and FINE or COARSE) * RADIUS, total)
	end

	local mouth, side, up, mw, mh, _, tangent = Frame(spine, 0)
	local below = mh * BELLY_FLAT
	shape.head = { pos = mouth, fwd = -tangent, up = up, side = side, w = mw, h = mh, below = below, floor = mouth - up * below }
	shape.mid = Frame(spine, total * 0.4) + up * mh

	hint = 1
	for i, c in ipairs(g.cilia) do
		local cd = c.at * total
		local base, cside, cup, w, h, j, ct = Frame(spine, cd, hint)
		hint = j
		local pos, normal = Surface(base, cside, cup, w, h, c.theta)
		pos = pos + normal * (Lump(cd, total, c.theta, g) * w)
		local scale = w / RADIUS
		shape.cilia[i] = {
			pos = pos, n = normal, t = ct, b = normal:Cross(ct), d = cd, len = c.len * RADIUS * scale,
			width = c.width * RADIUS * scale, phase = c.phase, freq = c.freq, drift = c.drift, points = {},
		}
	end

	local tail, tside, tup, tw, _, _, tt = Frame(spine, total)
	for i, t in ipairs(g.tendrils) do
		local o = tside * math.cos(t.angle) + tup * math.sin(t.angle)
		shape.tendrils[i] = {
			pos = tail + o * tw, dir = (tt + o * t.spread):GetNormalized(), o = o, len = t.len * RADIUS,
			width = t.width * RADIUS, phase = t.phase, freq = t.freq, points = {},
		}
	end
	return shape
end

local scratch = Vector()

local function Vert(shape, j, i, a, u, v)
	scratch:SetUnpacked(shape.bx[j] + shape.ox[i] * a, shape.by[j] + shape.oy[i] * a, shape.bz[j] + shape.oz[i] * a)
	mesh.Position(scratch)
	mesh.TexCoord(0, u, v)
	mesh.Color(math.min(255, shape.cr[i]), math.min(255, shape.cg[i]), math.min(255, shape.cb[i]), 255)
	mesh.AdvanceVertex()
end

local function Swell(shape, now)
	local total, amp = shape.total, shape.amp
	local width = WAVE_WIDTH * RADIUS
	local cycle = total + width * 4
	local lead = total + width * 2 - (now * WAVE_SPEED) % cycle
	local trail = lead + cycle * WAVE_GAP
	if trail > total + width * 2 then trail = trail - cycle end
	for j = 1, shape.count do
		local d = shape.d[j]
		local e1, e2 = (d - lead) / width, (d - trail) / width
		local taper = Smooth(d / (HEAD * RADIUS)) * Smooth((total - d) / (RADIUS * 2))
		amp[j] = 1 + BREATHE * math.sin(now * BREATHE_SPEED - d / RADIUS * 0.4)
			+ WAVE * taper * (math.exp(-e1 * e1) + 0.7 * math.exp(-e2 * e2))
	end
end

local function CiliaRadius(f, c)
	return c.width * (1 - 0.85 * f)
end

local function CiliaColor(f)
	local k = Smooth(f * 1.2)
	return Lerp(k, SKIN.x, TIP.x), Lerp(k, SKIN.y, TIP.y), Lerp(k, SKIN.z, TIP.z)
end

local function DrawCilia(shape, now)
	for _, c in ipairs(shape.cilia) do
		local beat = math.sin(now * CILIA_BEAT - c.d / RADIUS * CILIA_WAVE + c.phase)
		local pts = c.points
		for i = 1, 4 do
			local f = (i - 1) / 3
			local lean = beat * CILIA_SWING * f ^ 1.5
			local curl = math.sin(now * 0.9 * c.freq + c.drift + i) * 0.2 * f
			pts[i] = c.pos + c.n * (c.len * f * (1 - math.abs(lean) * 0.4)) + c.t * (c.len * lean) + c.b * (c.len * curl)
		end
		EvilSnake.Tube(pts, CILIA_SIDES, CILIA_SUB, CiliaRadius, CiliaColor, c)
	end
end

local function TendrilRadius(f, t)
	return t.width * (1 - 0.9 * f ^ 0.8)
end

local function DrawTendrils(shape, now)
	for _, t in ipairs(shape.tendrils) do
		local pts = t.points
		for i = 1, 5 do
			local f = (i - 1) / 4
			local wob = EvilSnake.Wobble(now, t.phase + i * 1.3, t.freq) * (t.len * 0.12 * f)
			pts[i] = t.pos + t.dir * (t.len * f) + t.o * (t.len * 0.25 * f * f) + wob
		end
		EvilSnake.Tube(pts, TENDRIL_SIDES, TENDRIL_SUB, TendrilRadius, CiliaColor, t)
	end
end

function Body.Draw(shape, now, near)
	render.SetMaterial(EvilSnake.Material)
	Swell(shape, now)
	local amp, d = shape.amp, shape.d
	mesh.Begin(MATERIAL_QUADS, (shape.count - 1) * SIDES)
	for j = 1, shape.count - 1 do
		local a, b = amp[j], amp[j + 1]
		local v0, v1 = d[j] / TILE_V, d[j + 1] / TILE_V
		local r0, r1 = (j - 1) * SIDES, j * SIDES
		for k = 0, SIDES - 1 do
			local k2 = (k + 1) % SIDES
			local u0, u1 = k / SIDES * TILE_U, (k + 1) / SIDES * TILE_U
			Vert(shape, j, r0 + k + 1, a, u0, v0)
			Vert(shape, j, r0 + k2 + 1, a, u1, v0)
			Vert(shape, j + 1, r1 + k2 + 1, b, u1, v1)
			Vert(shape, j + 1, r1 + k + 1, b, u0, v1)
		end
	end
	mesh.End()

	if not near then return end
	EvilSnake.SampleLight(shape.mid)
	DrawCilia(shape, now)
	DrawTendrils(shape, now)
end
