EvilSnake = EvilSnake or {}
local Mouth = {}
EvilSnake.Mouth = Mouth

local Smooth, Bright, Tube = EvilSnake.Smooth, EvilSnake.Bright, EvilSnake.Tube

local OUT = 0.06
local RIM = 0.95
local RIM_POINTS = 28
local RIM_SIDES = 12
local RIM_THICK = 0.17
local RIM_LUMPS = 5
local THROAT_DEPTH = 2.4
local THROAT_START = 0.85
local THROAT_SIDES = 20
local THROAT_STEPS = 8
local TEETH = { 16, 22 }
local INNER = { 10, 14 }
local INNER_AT = 0.3
local TOOTH_SIDES = 5
local TOOTH_SUB = 2
local CHATTER = 0.15
local CHATTER_SPEED = 19
local LEG_SIDES = 8
local LEG_SUB = 3
local PERIOD = 3.8
local GAPE = 0.14
local BREATHE = 0.04
local SWAY = 0.15
local WOBBLE = 0.04
local FLOOR_GAP = 0.05

local LIP = Vector(100, 40, 50)
local THROAT = Vector(92, 20, 28)
local PIT = Vector(8, 2, 3)
local SKIN = Vector(66, 56, 64)
local BONE = Vector(200, 188, 160)

local LEGS = {
	{ phi = -42, len = 3.2, width = 0.1 },
	{ phi = 42, len = 3.2, width = 0.1 },
	{ phi = -118, len = 2.4, width = 0.085 },
	{ phi = 118, len = 2.4, width = 0.085 },
}

local REACH = { { 1, 0, 0 }, { 1, 0.25, 0.22 }, { 1, 0.45, 0.52 }, { 1, 0.52, 0.82 }, { 1, 0.42, 1.04 } }
local CURL = { { 1, 0, 0 }, { 1, 0.2, 0.32 }, { 1, 0.08, 0.6 }, { 0.55, 0, 0.62 }, { 0.1, 0, 0.3 } }

local function Cycle(t)
	if t < 0.6 then return Lerp(Smooth(t / 0.6), 1, 0) end
	if t < 0.72 then return Lerp(Smooth((t - 0.6) / 0.12), 0, 1.1) end
	return Lerp(Smooth((t - 0.72) / 0.28), 1.1, 1)
end

function Mouth.Create(seed)
	local rand = EvilSnake.Rng(seed * 11 + 5)
	local state = { legs = {}, teeth = {}, inner = {} }
	for i, l in ipairs(LEGS) do
		state.legs[i] = {
			phi = math.rad(l.phi + rand(-8, 8)), len = l.len * rand(0.85, 1.15), width = l.width * rand(0.9, 1.1),
			phase = rand(0, 1), freq = rand(0.7, 1.4), drift = rand(0, 100), points = {},
		}
	end
	local n = math.floor(rand(TEETH[1], TEETH[2] + 1))
	for i = 1, n do
		state.teeth[i] = {
			phi = (i - 1 + rand(-0.3, 0.3)) / n * math.pi * 2, len = rand(0.3, 0.55), width = rand(0.05, 0.08),
			lean = rand(-0.2, 0.2), phase = rand(0, math.pi * 2), points = {},
		}
	end
	n = math.floor(rand(INNER[1], INNER[2] + 1))
	for i = 1, n do
		state.inner[i] = {
			phi = (i - 0.5 + rand(-0.3, 0.3)) / n * math.pi * 2, len = rand(0.25, 0.4), width = rand(0.04, 0.06),
			lean = rand(-0.2, 0.2), phase = rand(0, math.pi * 2), points = {},
		}
	end
	return state
end

local function RimRadius(f, m)
	return m.thick * (1 + 0.18 * math.sin(f * math.pi * 2 * RIM_LUMPS + m.now * 0.8))
end

local function RimColor()
	return LIP.x, LIP.y, LIP.z
end

local function ThroatColor(f)
	local k = Smooth(f * 1.4)
	return Lerp(k, THROAT.x, PIT.x), Lerp(k, THROAT.y, PIT.y), Lerp(k, THROAT.z, PIT.z)
end

local function LegRadius(f, leg)
	local r = leg.r * (1 - 0.95 * f ^ 1.1)
	for k = 1, 3 do
		local d = (f - k / 4) / 0.04
		r = r + leg.r * 0.2 * math.exp(-d * d)
	end
	return r
end

local function LegColor(f)
	local k = Smooth((f - 0.55) / 0.45)
	return Lerp(k, SKIN.x, BONE.x), Lerp(k, SKIN.y, BONE.y), Lerp(k, SKIN.z, BONE.z)
end

local function ToothRadius(f, t)
	return t.r * (1 - 0.95 * f)
end

local function ToothColor(f)
	local k = Smooth(f * 4)
	return Lerp(k, LIP.x, BONE.x), Lerp(k, LIP.y, BONE.y), Lerp(k, LIP.z, BONE.z)
end

local scratch = Vector()

local function Throat(center, back, Radial)
	local rings = {}
	for j = 0, THROAT_STEPS do
		local d = j / THROAT_STEPS
		local k = THROAT_START * (1 - d) ^ 0.7
		local cr, cg, cb = ThroatColor(d)
		local ring = {}
		for i = 0, THROAT_SIDES - 1 do
			local o = Radial(i / THROAT_SIDES * math.pi * 2)
			local n = o:GetNormalized()
			local l = Bright(-n.x, -n.y, -n.z)
			ring[i] = { center + back * d + o * k, cr * l, cg * l, cb * l }
		end
		rings[j] = ring
	end
	local function Vert(v, u, w)
		scratch:Set(v[1])
		mesh.Position(scratch)
		mesh.TexCoord(0, u, w)
		mesh.Color(math.min(255, v[2]), math.min(255, v[3]), math.min(255, v[4]), 255)
		mesh.AdvanceVertex()
	end
	mesh.Begin(MATERIAL_QUADS, THROAT_STEPS * THROAT_SIDES)
	for j = 0, THROAT_STEPS - 1 do
		local a, b = rings[j], rings[j + 1]
		local v0, v1 = j / THROAT_STEPS, (j + 1) / THROAT_STEPS
		for i = 0, THROAT_SIDES - 1 do
			local i2 = (i + 1) % THROAT_SIDES
			local u0, u1 = i / THROAT_SIDES * 2, (i + 1) / THROAT_SIDES * 2
			Vert(a[i], u0, v0)
			Vert(a[i2], u1, v0)
			Vert(b[i2], u1, v1)
			Vert(b[i], u0, v1)
		end
	end
	mesh.End()
end

local function Lift(p, floor, up, gap)
	local under = gap - (p - floor):Dot(up)
	if under > 0 then return p + up * under end
	return p
end

local function Tooth(t, root, dir, f, s, len, now, open)
	local chatter = 1 + CHATTER * math.sin(now * CHATTER_SPEED + t.phase) * open
	local aim = (dir * Lerp(open, -0.8, -0.3) + f * Lerp(open, -0.6, 0.5) + s * t.lean):GetNormalized()
	local l = len * chatter
	local pts = t.points
	pts[1] = root
	pts[2] = root + aim * (l * 0.5) + f * (l * 0.08)
	pts[3] = root + aim * l - f * (l * 0.12)
	Tube(pts, TOOTH_SIDES, TOOTH_SUB, ToothRadius, ToothColor, t)
end

function Mouth.Draw(state, head, now)
	if not state or not head then return end
	local f, u, s = head.fwd, head.up, head.side
	local W = head.w
	local center = head.pos + f * (OUT * W)
	local open = math.Clamp(1 - Cycle((now / PERIOD + 0.1) % 1), 0, 1)
	local scale = RIM * (1 + GAPE * open + BREATHE * math.sin(now * 1.7))
	local function Radial(phi)
		local c = math.cos(phi)
		return u * (c * (c > 0 and head.h or head.below) * scale) + s * (math.sin(phi) * head.w * scale)
	end

	EvilSnake.SampleLight(center + f * W)
	render.SetMaterial(EvilSnake.Material)

	state.now, state.thick = now, RIM_THICK * W
	local rim = state.rim or {}
	state.rim = rim
	for i = 1, RIM_POINTS do
		rim[i] = center + Radial((i - 1) / RIM_POINTS * math.pi * 2)
	end
	Tube(rim, RIM_SIDES, 1, RimRadius, RimColor, state, true, f)

	local depth = THROAT_DEPTH * W
	Throat(center, -f * depth, Radial)

	for _, t in ipairs(state.teeth) do
		local o = Radial(t.phi)
		t.r = t.width * W
		Tooth(t, center + o * 0.82 + f * (0.02 * W), o:GetNormalized(), f, s, t.len * W, now, open)
	end
	local inner = THROAT_START * (1 - INNER_AT) ^ 0.7
	for _, t in ipairs(state.inner) do
		local o = Radial(t.phi)
		t.r = t.width * W
		Tooth(t, center - f * (depth * INNER_AT) + o * inner, o:GetNormalized(), f, s, t.len * W, now, open * 0.5)
	end

	for _, leg in ipairs(state.legs) do
		local c = Cycle((now / PERIOD + leg.phase) % 1)
		local phi = leg.phi + SWAY * math.sin(now * 0.7 + leg.drift)
		local o = Radial(phi)
		local dir = o:GetNormalized()
		local len = leg.len * W
		leg.r = leg.width * W
		local pts = leg.points
		for i, a in ipairs(REACH) do
			local b = CURL[i]
			local ra, rb = o * a[1] + dir * (len * a[2]), o * b[1] + dir * (len * b[2])
			local p = center + ra + (rb - ra) * c + f * (len * (a[3] + (b[3] - a[3]) * c))
			p = p + EvilSnake.Wobble(now, leg.drift + i * 1.9, leg.freq) * (len * WOBBLE * (i - 1) / 4)
			pts[i] = Lift(p, head.floor, u, FLOOR_GAP * W + LegRadius((i - 1) / 4, leg))
		end
		Tube(pts, LEG_SIDES, LEG_SUB, LegRadius, LegColor, leg, false, dir:Cross(f))
	end
end
