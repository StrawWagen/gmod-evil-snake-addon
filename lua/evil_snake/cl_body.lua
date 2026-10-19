EvilSnake = EvilSnake or {}
local Body = {}
EvilSnake.Body = Body

Body.Material = CreateMaterial("evil_snake_body", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$vertexcolor"] = 1,
	["$nocull"] = 1,
})

Body.SEGMENTS = 10
Body.SPACING = 10

local STEP = 24
local DROP = 96
local SUB = 4
local SIDES = 18
local RADIUS = 3.2
local HEAD_LENGTH = 8
local HEAD_WIDTH = 1.3
local SNOUT = 0.7
local NECK = 0.8
local NOSE = 2
local TAIL_START = 0.45
local FLAT = 0.8
local HEAD_FLAT = 0.6
local BELLY_FLAT = 0.5
local FINE = 0.6
local COARSE = 2
local BACK = Vector(52, 58, 38)
local BLOTCH = Vector(20, 22, 15)
local BELLY = Vector(148, 136, 92)
local BLOTCH_SPACING = 9
local CHEVRON = 2.2
local EYE_AT = 0.4
local EYE_OUT = 0.8
local EYE_UP = 0.55
local EYE_RADIUS = 0.75
local EYE_COLOR = Color(10, 8, 4)

local function Smooth(x)
	x = math.Clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function CatmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
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
	local pad = RADIUS * HEAD_WIDTH * 2
	local mins, maxs = Vector(ground[1]), Vector(ground[1])
	for _, p in ipairs(ground) do
		mins.x, mins.y, mins.z = math.min(mins.x, p.x), math.min(mins.y, p.y), math.min(mins.z, p.z)
		maxs.x, maxs.y, maxs.z = math.max(maxs.x, p.x), math.max(maxs.y, p.y), math.max(maxs.z, p.z)
	end
	return mins - Vector(pad, pad, pad), maxs + Vector(pad, pad, pad)
end

local function Spine(ground, normals)
	local n = #ground
	local pts, ups, dist = {}, {}, {}
	local total = 0
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = ground[math.max(i - 1, 1)], ground[i], ground[i + 1], ground[math.min(i + 2, n)]
		for s = 0, SUB - 1 do
			local t = s / SUB
			local p = CatmullRom(p0, p1, p2, p3, t)
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
	local h = d / HEAD_LENGTH
	local w
	if h < 0.55 then
		w = Lerp(Smooth(h / 0.55), SNOUT, HEAD_WIDTH)
	elseif h < 1 then
		w = Lerp(Smooth((h - 0.55) / 0.45), HEAD_WIDTH, NECK)
	else
		w = Lerp(Smooth((h - 1) / 1.5), NECK, 1)
	end
	w = w * math.sqrt(math.min(1, d / NOSE))
	local f = d / total
	if f > TAIL_START then w = w * ((1 - f) / (1 - TAIL_START)) ^ 0.9 end
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
	return center + up * (h * BELLY_FLAT), side, up, w, h, j
end

local AXES = { Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1) }
local cube = { 0, 0, 0, 0, 0, 0 }

local function SampleLight(pos)
	for i, axis in ipairs(AXES) do
		local c = render.ComputeLighting(pos, axis) + render.ComputeDynamicLighting(pos, axis)
		cube[i] = (c.x + c.y + c.z) / 3
	end
end

local function Bright(n)
	local l = n.x * n.x * (n.x > 0 and cube[1] or cube[2])
		+ n.y * n.y * (n.y > 0 and cube[3] or cube[4])
		+ n.z * n.z * (n.z > 0 and cube[5] or cube[6])
	return math.min(1.6, 0.08 + math.sqrt(l) * 1.3)
end

local function Shade(d, c, s)
	local belly = Smooth((-s - 0.15) / 0.35)
	local phase = d / BLOTCH_SPACING * math.pi * 2 + math.abs(c) * CHEVRON
	local blotch = Smooth((math.sin(phase) - 0.3) / 0.4) * Smooth((s + 0.3) / 0.5)
	return LerpVector(belly, LerpVector(blotch, BACK, BLOTCH), BELLY)
end

local trig = {}
for k = 0, SIDES - 1 do
	local a = k / SIDES * math.pi * 2
	trig[k] = { math.cos(a), math.sin(a) }
end

local function Ring(spine, d, hint)
	local base, side, up, w, h, j = Frame(spine, d, hint)
	SampleLight(base + up * h)
	local ring = {}
	for k = 0, SIDES - 1 do
		local c, s = trig[k][1], trig[k][2]
		local hs = s < 0 and h * BELLY_FLAT or h
		local normal = (side * (c / math.max(w, 0.01)) + up * (s / math.max(hs, 0.01))):GetNormalized()
		ring[k] = { base + side * (c * w) + up * (s * hs), Shade(d, c, s) * Bright(normal) }
	end
	return ring, j
end

local function Vert(v)
	mesh.Position(v[1])
	mesh.TexCoord(0, 0, 0)
	mesh.Color(math.min(255, v[2].x), math.min(255, v[2].y), math.min(255, v[2].z), 255)
	mesh.AdvanceVertex()
end

function Body.Build(ground, normals)
	local spine = Spine(ground, normals)
	local total = spine.total
	local rings, hint, d = {}, 1, 0
	while true do
		rings[#rings + 1], hint = Ring(spine, d, hint)
		if d >= total then break end
		local fine = d < NOSE * 2 or d > total - NOSE * 2
		d = math.min(d + (fine and FINE or COARSE), total)
	end

	local obj = Mesh(Body.Material)
	mesh.Begin(obj, MATERIAL_QUADS, (#rings - 1) * SIDES)
	for r = 1, #rings - 1 do
		local a, b = rings[r], rings[r + 1]
		for k = 0, SIDES - 1 do
			local k2 = (k + 1) % SIDES
			Vert(a[k])
			Vert(a[k2])
			Vert(b[k2])
			Vert(b[k])
		end
	end
	mesh.End()

	local base, side, up, w, h = Frame(spine, HEAD_LENGTH * EYE_AT)
	local eyes = {}
	for _, dir in ipairs({ 1, -1 }) do
		eyes[#eyes + 1] = base + side * (dir * w * EYE_OUT) + up * (h * EYE_UP)
	end
	return obj, eyes
end

function Body.Draw(obj, eyes)
	render.SetMaterial(Body.Material)
	obj:Draw()
	render.SetColorMaterial()
	for _, pos in ipairs(eyes) do render.DrawSphere(pos, EYE_RADIUS, 10, 10, EYE_COLOR) end
end
