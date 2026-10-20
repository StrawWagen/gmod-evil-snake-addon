EvilSnake = EvilSnake or {}
local Body = {}
EvilSnake.Body = Body

local Bright = EvilSnake.Bright
local sqrt, sin, cos, max, min, abs, tan, rad = math.sqrt, math.sin, math.cos, math.max, math.min, math.abs, math.tan, math.rad

local SUB = 4
local SIDES = { 20, 8 }
local SPACING = 0.55
local DETAIL = { 12, 90 }
local BOWL = 7
local MAW = 0.85
local GULLET = 0.9
local RIB = 0.12
local THROAT = { 120, 28, 38 }
local DARK = 0.1
local PAD = 4
local RELIGHT = 3
local BATCH = 100
local SPAN = 1.3
local SWELL_IN = 1
local NECK = 3
local UP = Vector(0, 0, 1)

function Body.New()
	return { light = {}, lit = 0, eyes = {} }
end

function Body.Bounds(pts, fattest, R)
	local mins, maxs = Vector(pts[1]), Vector(pts[1])
	for _, p in ipairs(pts) do
		mins.x, mins.y, mins.z = min(mins.x, p.x), min(mins.y, p.y), min(mins.z, p.z)
		maxs.x, maxs.y, maxs.z = max(maxs.x, p.x), max(maxs.y, p.y), max(maxs.z, p.z)
	end
	local pad = R * (1 + (fattest or 1)) + PAD
	return mins - Vector(pad, pad, pad), maxs + Vector(pad, pad, pad)
end

local function Relight(body, pts)
	local frame = FrameNumber()
	if body.frame == frame then return end
	body.frame = frame
	local n, light = #pts, body.light
	for i = 1, n do
		if not light[i * 6] then EvilSnake.SampleLight(pts[i], light, (i - 1) * 6) end
	end
	for _ = 1, min(RELIGHT, n) do
		body.lit = body.lit % n + 1
		EvilSnake.SampleLight(pts[body.lit], light, (body.lit - 1) * 6)
	end
end

local function Detail(pts, R)
	local eye = EyePos()
	local best = math.huge
	for i = 1, #pts do best = min(best, pts[i]:DistToSqr(eye)) end
	local view = sqrt(best) * tan(rad(render.GetViewSetup().fov * 0.5)) / R
	return math.Clamp((view - DETAIL[1]) / (DETAIL[2] - DETAIL[1]), 0, 1)
end

local cx, cy, cz, tx, ty, tz, rw, rnr, rax, rlo = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local rr, rg, rb = {}, {}, {}
local count = 0
local cr, cg, cb = 0, 0, 0

local function Ring(x, y, z, dx, dy, dz, w, nr, ax, joint, r, g, b)
	count = count + 1
	cx[count], cy[count], cz[count] = x, y, z
	tx[count], ty[count], tz[count] = dx, dy, dz
	rw[count], rnr[count], rax[count], rlo[count] = w, nr, ax, (joint - 1) * 6
	rr[count], rg[count], rb[count] = r or cr, g or cg, b or cb
end

function Body.Snug(fit, R)
	return max(1, fit / (R * MAW))
end

local fz, fr, fcr, fcg, fcb = {}, {}, {}, {}, {}
local headP, headDir, headW

local function Gullet(p, back, W, mouth)
	local fwd = -back
	local dir = mouth and mouth.dir and LerpVector(mouth.open, fwd, mouth.dir):GetNormalized() or fwd
	headP, headDir, headW = p, dir, W
	local ap, deep = W * MAW, W * GULLET
	for k = 0, BOWL - 1 do
		local phi = (1 - k / BOWL) * math.pi * 0.5
		local c = cos(phi)
		local ridge = k > 0 and k % 2 == 0
		local shade = Lerp(c, DARK, 0.6) * (ridge and 1.25 or 1)
		fz[k + 1], fr[k + 1] = -deep * sin(phi), ap * c * (ridge and 1 - RIB or 1)
		fcr[k + 1], fcg[k + 1], fcb[k + 1] = THROAT[1] * shade, THROAT[2] * shade, THROAT[3] * shade
	end
	fz[BOWL + 1], fr[BOWL + 1] = 0, W
	for k = 1, BOWL do
		local a, b = max(k - 1, 1), k + 1
		local dz, dr = fz[b] - fz[a], fr[b] - fr[a]
		local l = sqrt(dz * dz + dr * dr)
		if l < 1e-6 then dz, dr, l = 1, 0, 1 end
		local z = fz[k]
		Ring(p.x + dir.x * z, p.y + dir.y * z, p.z + dir.z * z, -dir.x, -dir.y, -dir.z, fr[k], -dz / l, -dr / l, 1, fcr[k], fcg[k], fcb[k])
	end
end

local widths, swells = {}, {}

local function Widths(m, n, R, bulges, link, sub)
	local body, tail = EvilSnake.Shape()
	for j = 1, m do
		widths[j] = R * EvilSnake.Profile((j - 1) / (m - 1), body, tail)
		swells[j] = 1
	end
	local head = EvilSnake.HeadRadius(R)
	if head < R then
		local reach = NECK * R
		for j = 1, m do
			local d = (j - 1) / sub * link
			if d >= reach then break end
			local u = d / reach
			widths[j] = widths[j] * Lerp(u * u * (3 - 2 * u), head / R, 1)
		end
	end
	for _, b in ipairs(bulges) do
		local swell = b.swell or min(1, b.at / SWELL_IN)
		swell = swell * swell * (3 - 2 * swell)
		local size = 1 + (b.size - 1) * swell
		local reach = R * EvilSnake.Profile(b.at / n, body, tail) * size * SPAN
		local lo = max(1, math.floor((b.at - reach / link) * sub) + 1)
		local hi = min(m, math.ceil((b.at + reach / link) * sub) + 1)
		for j = lo, hi do
			local d = abs((j - 1) / sub - b.at) * link
			if d < reach then
				swells[j] = max(swells[j], 1 + (size - 1) * (0.5 + 0.5 * cos(math.pi * d / reach)))
			end
		end
	end
	for j = 1, m do widths[j] = widths[j] * swells[j] end
end

local qx, qy, qz, sx, sy, sz = {}, {}, {}, {}, {}, {}

local function Coef(p0, p1, p2, p3)
	return p1, (p2 - p0) * 0.5, p0 - p1 * 2.5 + p2 * 2 - p3 * 0.5, (p1 * 3 - p0 - p2 * 3 + p3) * 0.5
end

local function Spline(pts, sub)
	local n, m = #pts, 0
	for i = 1, n do qx[i], qy[i], qz[i] = pts[i]:Unpack() end
	for i = 1, n - 1 do
		local a, d = max(i - 1, 1), min(i + 2, n)
		local x0, x1, x2, x3 = Coef(qx[a], qx[i], qx[i + 1], qx[d])
		local y0, y1, y2, y3 = Coef(qy[a], qy[i], qy[i + 1], qy[d])
		local z0, z1, z2, z3 = Coef(qz[a], qz[i], qz[i + 1], qz[d])
		for s = 0, sub - 1 do
			local t = s / sub
			local t2 = t * t
			local t3 = t2 * t
			m = m + 1
			sx[m] = x0 + x1 * t + x2 * t2 + x3 * t3
			sy[m] = y0 + y1 * t + y2 * t2 + y3 * t3
			sz[m] = z0 + z1 * t + z2 * t2 + z3 * t3
		end
	end
	m = m + 1
	sx[m], sy[m], sz[m] = qx[n], qy[n], qz[n]
	return m
end

local function Rings(pts, bulges, R, link, mouth, sub, up)
	count = 0
	local n = #pts
	local m = Spline(pts, sub)
	local drop = EvilSnake.HeadDrop(R)
	if drop > 0 then
		local reach = NECK * R
		for j = 1, m do
			local d = (j - 1) / sub * link
			if d >= reach then break end
			local u = d / reach
			local k = drop * (1 - u * u * (3 - 2 * u))
			sx[j], sy[j], sz[j] = sx[j] - up.x * k, sy[j] - up.y * k, sz[j] - up.z * k
		end
	end
	local first = Vector(sx[2] - sx[1], sy[2] - sy[1], sz[2] - sz[1])
	first:Normalize()
	Widths(m, n - 1, R, bulges, link, sub)
	Gullet(Vector(sx[1], sy[1], sz[1]), first, widths[1], mouth)
	local half = sub / 2
	for j = 1, m do
		local a, b = max(j - 1, 1), min(j + 1, m)
		local dx, dy, dz = sx[b] - sx[a], sy[b] - sy[a], sz[b] - sz[a]
		local len = sqrt(dx * dx + dy * dy + dz * dz)
		local il = len > 1e-6 and 1 / len or 0
		local slope = len > 1e-4 and (widths[b] - widths[a]) / len or 0
		local inv = 1 / sqrt(1 + slope * slope)
		local seg = math.floor((j - 1) / sub)
		local joint = min(n, seg + 1 + ((j - 1) % sub >= half and 1 or 0))
		Ring(sx[j], sy[j], sz[j], dx * il, dy * il, dz * il, widths[j], inv, -slope * inv, joint)
	end
end

local verts, vr, vg, vb = {}, {}, {}, {}

local function Vert(i)
	mesh.Position(verts[i])
	mesh.TexCoord(0, 0, 0)
	mesh.Color(vr[i], vg[i], vb[i], 255)
	mesh.AdvanceVertex()
end

function Body.Draw(body, pts, bulges, R, link, mouth, up)
	up = up or UP
	if #pts < 2 then return end
	Relight(body, pts)
	cr, cg, cb = EvilSnake.Color()
	local detail = Detail(pts, R)
	local near = math.Clamp(math.ceil(link / (R * SPACING)), 2, SUB)
	local sub = math.Round(Lerp(detail, near, 1))
	local sides = math.Round(Lerp(detail, SIDES[1], SIDES[2]))
	Rings(pts, bulges or {}, R, link, mouth, sub, up)
	local tr = EvilSnake.Trig(sides)
	local light = body.light
	local nx, ny, nz = 0, 0, 1
	for j = 1, count do
		local ax, ay, az = tx[j], ty[j], tz[j]
		local d = nx * ax + ny * ay + nz * az
		nx, ny, nz = nx - ax * d, ny - ay * d, nz - az * d
		local nl = sqrt(nx * nx + ny * ny + nz * nz)
		if nl < 1e-4 then
			if abs(az) < 0.9 then nx, ny, nz = -ay, ax, 0 else nx, ny, nz = 0, -az, ay end
			nl = sqrt(nx * nx + ny * ny + nz * nz)
		end
		nx, ny, nz = nx / nl, ny / nl, nz / nl
		local bx, by, bz = ay * nz - az * ny, az * nx - ax * nz, ax * ny - ay * nx
		local w, r, k = rw[j], rnr[j], rax[j]
		local px, py, pz, o = cx[j], cy[j], cz[j], rlo[j]
		local r0, g0, b0 = rr[j], rg[j], rb[j]
		for q = 0, sides - 1 do
			local cs, sn = tr.c[q], tr.s[q]
			local dx, dy, dz = nx * cs + bx * sn, ny * cs + by * sn, nz * cs + bz * sn
			local i = (j - 1) * sides + q + 1
			local v = verts[i]
			if not v then
				v = Vector()
				verts[i] = v
			end
			v:SetUnpacked(px + dx * w, py + dy * w, pz + dz * w)
			local l = Bright(light, o, dx * r + ax * k, dy * r + ay * k, dz * r + az * k)
			vr[i], vg[i], vb[i] = min(255, r0 * l), min(255, g0 * l), min(255, b0 * l)
		end
	end

	render.SetMaterial(EvilSnake.Material)
	for a = 1, count - 1, BATCH do
		local b = min(a + BATCH - 1, count - 1)
		mesh.Begin(MATERIAL_QUADS, (b - a + 1) * sides)
		for j = a, b do
			local r0, r1 = (j - 1) * sides, j * sides
			for q = 0, sides - 1 do
				local q2 = (q + 1) % sides
				Vert(r0 + q + 1)
				Vert(r0 + q2 + 1)
				Vert(r1 + q2 + 1)
				Vert(r1 + q + 1)
			end
		end
		mesh.End()
	end
	body.head, body.dir, body.W = headP, headDir, headW
	EvilSnake.Head.Draw(body.light, headP, headDir, headW, mouth, cr, cg, cb, body.eyes, body.look, up)
end
