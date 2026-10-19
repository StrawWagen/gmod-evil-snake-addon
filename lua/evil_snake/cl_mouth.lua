EvilSnake = EvilSnake or {}
local Mouth = {}
EvilSnake.Mouth = Mouth

local OUT = 0.8
local RIM = 0.95
local RIM_POINTS = 24
local RIM_SIDES = 10
local RIM_THICK = 1.25
local RIM_LUMPS = 4
local THROAT_DEPTH = 6
local THROAT_START = 0.85
local THROAT_SIDES = 16
local THROAT_STEPS = 6
local LEG_SIDES = 7
local LEG_SUB = 3
local FANG_SIDES = 6
local PERIOD = 3.4
local GAPE = 0.14
local BREATHE = 0.04
local SWAY = 0.15
local WOBBLE = 0.05
local FANG_AT = math.rad(17)
local FANG_WIDTH = 0.45
local CHATTER = 0.12
local CHATTER_SPEED = 22
local FLOOR_GAP = 0.4

local FLESH = Vector(158, 126, 98)
local LIP = Vector(176, 120, 104)
local THROAT = Vector(112, 38, 30)
local PIT = Vector(10, 3, 2)
local BONE = Vector(214, 200, 168)

local LEGS = {
	{ phi = math.rad(-42), len = 11, width = 0.8, phase = 0, freq = 1.1 },
	{ phi = math.rad(42), len = 11, width = 0.8, phase = 0.18, freq = 1.3 },
	{ phi = math.rad(-118), len = 8, width = 0.62, phase = 0.41, freq = 0.9 },
	{ phi = math.rad(118), len = 8, width = 0.62, phase = 0.57, freq = 1.2 },
}

local REACH = { { 1, 0, 0 }, { 1, 0.32, 0.3 }, { 1, 0.55, 0.68 }, { 1, 0.5, 1.02 } }
local CURL = { { 1, 0, 0 }, { 1, 0.22, 0.42 }, { 0.7, 0, 0.62 }, { 0.15, 0, 0.2 } }

local function Smooth(x)
	x = math.Clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function Cycle(t)
	if t < 0.6 then return Lerp(Smooth(t / 0.6), 1, 0) end
	if t < 0.72 then return Lerp(Smooth((t - 0.6) / 0.12), 0, 1.1) end
	return Lerp(Smooth((t - 0.72) / 0.28), 1.1, 1)
end

local function Wobble(t, phase, freq)
	return Vector(
		math.sin(t * freq + phase) + 0.5 * math.sin(t * freq * 2.3 + phase * 1.7),
		math.sin(t * freq * 1.3 + phase * 2.1) + 0.5 * math.sin(t * freq * 2.9 + phase),
		math.sin(t * freq * 0.9 + phase * 3.3) + 0.5 * math.sin(t * freq * 3.1 + phase * 0.6)
	)
end

local function CatmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

local trig = {}
local function Trig(sides)
	local t = trig[sides]
	if not t then
		t = {}
		for k = 0, sides - 1 do
			local a = k / sides * math.pi * 2
			t[k] = { math.cos(a), math.sin(a) }
		end
		trig[sides] = t
	end
	return t
end

local function Tube(pts, sides, sub, closed, hint, radiusAt, colorAt, data)
	local n = #pts
	local function At(k)
		if closed then return pts[(k - 1) % n + 1] end
		return pts[math.Clamp(k, 1, n)]
	end
	local path, frac = {}, {}
	local segs = closed and n or n - 1
	for i = 1, segs do
		local p0, p1, p2, p3 = At(i - 1), At(i), At(i + 1), At(i + 2)
		for s = 0, sub - 1 do
			local t = s / sub
			path[#path + 1] = CatmullRom(p0, p1, p2, p3, t)
			frac[#frac + 1] = (i - 1 + t) / segs
		end
	end
	if not closed then
		path[#path + 1] = pts[n]
		frac[#frac + 1] = 1
	end

	local count = #path
	local tr = Trig(sides)
	local rings = {}
	local normal = hint
	for j = 1, count do
		local a, b
		if closed then
			a, b = path[(j - 2) % count + 1], path[j % count + 1]
		else
			a, b = path[math.max(j - 1, 1)], path[math.min(j + 1, count)]
		end
		local tangent = (b - a):GetNormalized()
		normal = normal - tangent * normal:Dot(tangent)
		if normal:LengthSqr() < 1e-6 then normal = tangent:Angle():Up() end
		normal:Normalize()
		local binormal = tangent:Cross(normal)
		local r = radiusAt(frac[j], data)
		local color = colorAt(frac[j], data)
		local ring = {}
		for k = 0, sides - 1 do
			local dir = normal * tr[k][1] + binormal * tr[k][2]
			ring[k] = { path[j] + dir * r, color * EvilSnake.Body.Bright(dir) }
		end
		rings[j] = ring
	end

	local Vert = EvilSnake.Body.Vert
	local last = closed and count or count - 1
	mesh.Begin(MATERIAL_QUADS, last * sides)
	for j = 1, last do
		local a, b = rings[j], rings[j % count + 1]
		for k = 0, sides - 1 do
			local k2 = (k + 1) % sides
			Vert(a[k])
			Vert(a[k2])
			Vert(b[k2])
			Vert(b[k])
		end
	end
	mesh.End()
end

local function RimRadius(f, m)
	return RIM_THICK * (1 + 0.18 * math.sin(f * math.pi * 2 * RIM_LUMPS + m.now * 0.8))
end

local function RimColor()
	return LIP
end

local function ThroatColor(f)
	return LerpVector(Smooth(f * 1.4), THROAT, PIT)
end

local function LegRadius(f, leg)
	local r = leg.width * (1 - 0.92 * f ^ 1.2)
	for k = 1, 2 do
		local d = (f - k / 3) / 0.05
		r = r + leg.width * 0.18 * math.exp(-d * d)
	end
	return r
end

local function LegColor(f)
	return LerpVector(Smooth((f - 0.6) / 0.4), FLESH, BONE)
end

local function FangRadius(f)
	return FANG_WIDTH * (1 - 0.95 * f)
end

local function FangColor()
	return BONE
end

local function Throat(center, back, Radial)
	local Vert, Bright = EvilSnake.Body.Vert, EvilSnake.Body.Bright
	local rings = {}
	for j = 0, THROAT_STEPS do
		local d = j / THROAT_STEPS
		local k = THROAT_START * (1 - d) ^ 0.7
		local color = ThroatColor(d)
		local ring = {}
		for i = 0, THROAT_SIDES - 1 do
			local o = Radial(i / THROAT_SIDES * math.pi * 2)
			ring[i] = { center + back * d + o * k, color * Bright(-o:GetNormalized()) }
		end
		rings[j] = ring
	end
	mesh.Begin(MATERIAL_QUADS, THROAT_STEPS * THROAT_SIDES)
	for j = 0, THROAT_STEPS - 1 do
		local a, b = rings[j], rings[j + 1]
		for i = 0, THROAT_SIDES - 1 do
			local i2 = (i + 1) % THROAT_SIDES
			Vert(a[i])
			Vert(a[i2])
			Vert(b[i2])
			Vert(b[i])
		end
	end
	mesh.End()
end

local function Lift(p, floor, up, gap)
	local under = gap - (p - floor):Dot(up)
	if under > 0 then return p + up * under end
	return p
end

function Mouth.Draw(head)
	if not head then return end
	local now = UnPredictedCurTime()
	local f, u, s = head.fwd, head.up, head.side
	local center = head.pos + f * OUT
	local open = math.Clamp(1 - Cycle((now / PERIOD + 0.1) % 1), 0, 1)
	local scale = RIM * (1 + GAPE * open + BREATHE * math.sin(now * 1.7))
	local function Radial(phi)
		local c = math.cos(phi)
		return u * (c * (c > 0 and head.h or head.below) * scale) + s * (math.sin(phi) * head.w * scale)
	end

	EvilSnake.Body.SampleLight(center + f * 2)
	render.SetMaterial(EvilSnake.Body.Material)

	local m = { now = now }
	local rim = {}
	for i = 1, RIM_POINTS do
		rim[i] = center + Radial((i - 1) / RIM_POINTS * math.pi * 2)
	end
	Tube(rim, RIM_SIDES, 1, true, f, RimRadius, RimColor, m)

	Throat(center, -f * THROAT_DEPTH, Radial)

	for side = -1, 1, 2 do
		local phi = FANG_AT * side
		local o = Radial(phi)
		local chatter = math.sin(now * CHATTER_SPEED + side) * CHATTER * open
		local pts = {
			center + o * 0.92 - f * 0.3,
			center + o * (0.7 + 0.2 * open) + f * 1,
			center + o * (0.4 + 0.45 * open + chatter) + f * 0.5,
		}
		Tube(pts, FANG_SIDES, 3, false, s, FangRadius, FangColor)
	end

	for _, leg in ipairs(LEGS) do
		local c = Cycle((now / PERIOD + leg.phase) % 1)
		local phi = leg.phi + SWAY * math.sin(now * 0.7 + leg.phase * 10)
		local o = Radial(phi)
		local dir = o:GetNormalized()
		local pts = leg.points or {}
		leg.points = pts
		for i, a in ipairs(REACH) do
			local b = CURL[i]
			local ra, rb = o * a[1] + dir * (leg.len * a[2]), o * b[1] + dir * (leg.len * b[2])
			local p = center + ra + (rb - ra) * c + f * (leg.len * (a[3] + (b[3] - a[3]) * c))
			p = p + Wobble(now, leg.phase * 20 + i * 1.9, leg.freq) * (leg.len * WOBBLE * (i - 1) / 3)
			pts[i] = Lift(p, head.floor, u, FLOOR_GAP + LegRadius((i - 1) / 3, leg))
		end
		Tube(pts, LEG_SIDES, LEG_SUB, false, dir:Cross(f), LegRadius, LegColor, leg)
	end
end
