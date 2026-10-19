EvilSnake = EvilSnake or {}
local Body = {}
EvilSnake.Body = Body

local Smooth, Bright = EvilSnake.Smooth, EvilSnake.Bright
local sqrt, sin, cos = math.sqrt, math.sin, math.cos

Body.SEGMENTS = 28
Body.SPACING = 17

local STEP = 24
local DROP = 120
local SUB = 4
local SIDES = 20
local RADIUS = 14
local LIFT = 0.92
local CAP = 6
local COARSE = 0.3
local PAD = 72
local AMPLITUDE = 16
local WAVELENGTH = 170
local SPEED = 70
local CALM = 0.35
local COLOR = Vector(150, 110, 104)

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
	return center + up * (RADIUS * LIFT), tangent, side, up, j
end

local function Rings(total)
	local list = {}
	for i = 0, CAP - 1 do list[#list + 1] = RADIUS * (1 - cos(i / CAP * math.pi * 0.5)) end
	local body = total - RADIUS * 2
	local n = math.max(1, math.ceil(body / (COARSE * RADIUS)))
	for i = 0, n - 1 do list[#list + 1] = RADIUS + body * i / n end
	for i = CAP, 0, -1 do list[#list + 1] = total - RADIUS * (1 - cos(i / CAP * math.pi * 0.5)) end
	return list
end

function Body.Build(ground, normals)
	local spine = Spine(ground, normals)
	local total = spine.total
	local shape = { count = 0, d = {}, w = {}, axial = {}, c = {}, t = {}, s = {}, u = {}, light = {} }
	local hint = 1
	for n, d in ipairs(Rings(total)) do
		local c, t, s, u, j = Frame(spine, d, hint)
		hint = j
		local axial = 0
		if d < RADIUS then
			axial = -(RADIUS - d) / RADIUS
		elseif d > total - RADIUS then
			axial = (d - total + RADIUS) / RADIUS
		end
		shape.count = n
		shape.d[n], shape.axial[n], shape.w[n] = d, axial, RADIUS * sqrt(math.max(0, 1 - axial * axial))
		shape.c[n], shape.t[n], shape.s[n], shape.u[n] = c, t, s, u
		EvilSnake.SampleLight(c, shape.light, (n - 1) * 6)
	end
	return shape
end

local vx, vy, vz, vl = {}, {}, {}, {}
local scratch = Vector()

local function Vert(i)
	scratch:SetUnpacked(vx[i], vy[i], vz[i])
	mesh.Position(scratch)
	mesh.TexCoord(0, 0, 0)
	local l = vl[i]
	mesh.Color(math.min(255, COLOR.x * l), math.min(255, COLOR.y * l), math.min(255, COLOR.z * l), 255)
	mesh.AdvanceVertex()
end

function Body.Draw(shape, now, phase)
	local tr = EvilSnake.Trig(SIDES)
	local k = math.pi * 2 / WAVELENGTH
	local drift = SPEED * k * now - phase
	local count = shape.count
	for j = 1, count do
		local d = shape.d[j]
		local amp = AMPLITUDE * Lerp(Smooth(d / (WAVELENGTH * 0.5)), CALM, 1)
		local a = k * d - drift
		local lat, slope = amp * sin(a), amp * k * cos(a)
		local c, t, s, u = shape.c[j], shape.t[j], shape.s[j], shape.u[j]
		local px, py, pz = c.x + s.x * lat, c.y + s.y * lat, c.z + s.z * lat
		local tx, ty, tz = t.x + s.x * slope, t.y + s.y * slope, t.z + s.z * slope
		local tl = sqrt(tx * tx + ty * ty + tz * tz)
		tx, ty, tz = tx / tl, ty / tl, tz / tl
		local sx, sy, sz = ty * u.z - tz * u.y, tz * u.x - tx * u.z, tx * u.y - ty * u.x
		local sl = sqrt(sx * sx + sy * sy + sz * sz)
		sx, sy, sz = sx / sl, sy / sl, sz / sl
		local ux, uy, uz = sy * tz - sz * ty, sz * tx - sx * tz, sx * ty - sy * tx
		local w, ax = shape.w[j], shape.axial[j]
		local r = w / RADIUS
		local o = (j - 1) * 6
		for q = 0, SIDES - 1 do
			local cs, sn = tr.c[q], tr.s[q]
			local dx, dy, dz = sx * cs + ux * sn, sy * cs + uy * sn, sz * cs + uz * sn
			local i = (j - 1) * SIDES + q + 1
			vx[i], vy[i], vz[i] = px + dx * w, py + dy * w, pz + dz * w
			vl[i] = Bright(shape.light, o, dx * r + tx * ax, dy * r + ty * ax, dz * r + tz * ax)
		end
	end

	render.SetMaterial(EvilSnake.Material)
	mesh.Begin(MATERIAL_QUADS, (count - 1) * SIDES)
	for j = 1, count - 1 do
		local r0, r1 = (j - 1) * SIDES, j * SIDES
		for q = 0, SIDES - 1 do
			local q2 = (q + 1) % SIDES
			Vert(r0 + q + 1)
			Vert(r0 + q2 + 1)
			Vert(r1 + q2 + 1)
			Vert(r1 + q + 1)
		end
	end
	mesh.End()
end
