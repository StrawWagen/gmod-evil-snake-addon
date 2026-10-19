EvilSnake = EvilSnake or {}
local Body = {}
EvilSnake.Body = Body

local Bright, CatmullRom = EvilSnake.Bright, EvilSnake.CatmullRom
local sqrt, sin, cos, max, min, abs = math.sqrt, math.sin, math.cos, math.max, math.min, math.abs

local SUB = 4
local SIDES = 20
local OUTER = 4
local ROLL = 6
local BOWL = 5
local LIP = 0.18
local WALL = 0.1
local IDLE = 0.3
local GULLET = 0.7
local THROAT = { 120, 28, 38 }
local DARK = 0.2
local PAD = 4
local RELIGHT = 3
local BATCH = 100
local SPAN = 1.3
local SWELL_IN = 1

function Body.New()
	return { light = {}, lit = 0 }
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
	local n, light = #pts, body.light
	for i = 1, n do
		if not light[i * 6] then EvilSnake.SampleLight(pts[i], light, (i - 1) * 6) end
	end
	for _ = 1, min(RELIGHT, n) do
		body.lit = body.lit % n + 1
		EvilSnake.SampleLight(pts[body.lit], light, (body.lit - 1) * 6)
	end
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

local function Along(p, d, z, rho, nr, nf, r, g, b)
	Ring(p.x + d.x * z, p.y + d.y * z, p.z + d.z * z, -d.x, -d.y, -d.z, rho, nr, -nf, 1, r, g, b)
end

local function Tint(t, shade)
	return Lerp(t, cr, THROAT[1]) * shade, Lerp(t, cg, THROAT[2]) * shade, Lerp(t, cb, THROAT[3]) * shade
end

function Body.Snug(fit, R)
	return max(1, fit / R + 2 * LIP + WALL)
end

local function Mouth(p, back, W, R, mouth)
	local fwd = -back
	local open = mouth and mouth.open or 0
	local dir = mouth and mouth.dir and LerpVector(open, fwd, mouth.dir):GetNormalized() or fwd
	local lr = R * LIP
	local ap = Lerp(open, W * IDLE, mouth and mouth.fit or 0)
	ap = math.Clamp(ap, R * 0.05, max(W - 2 * lr - R * WALL, R * 0.05))
	local inner = W - lr
	local am = math.acos(math.Clamp((ap + lr) / inner, 0, 1))
	local zc, rc = inner * sin(am), inner * cos(am)
	local deep = W * GULLET
	for k = 0, BOWL - 1 do
		local phi = (1 - k / BOWL) * math.pi * 0.5
		local c, s = cos(phi), sin(phi)
		local nr, nf = -c * deep, s * ap
		local nl = sqrt(nr * nr + nf * nf)
		Along(p, dir, zc - deep * s, ap * c, nr / nl, nf / nl, Tint(1, Lerp(c, DARK, 0.7)))
	end
	for k = 0, ROLL do
		local th = math.pi - (math.pi - am) * k / ROLL
		local c, s = cos(th), sin(th)
		Along(p, dir, zc + lr * s, rc + lr * c, c, s, Tint(math.Clamp(-c * 2, 0, 1), Lerp(math.Clamp(-c, 0, 1), 1, 0.7)))
	end
	for k = 1, OUTER do
		local a = am * (1 - k / (OUTER + 1))
		local c, s = cos(a), sin(a)
		Along(p, LerpVector(a / am, fwd, dir):GetNormalized(), W * s, W * c, c, s)
	end
end

local widths, swells = {}, {}

local function Widths(m, n, R, bulges, link)
	local body, tail = EvilSnake.Shape()
	for j = 1, m do
		widths[j] = R * EvilSnake.Profile((j - 1) / (m - 1), body, tail)
		swells[j] = 1
	end
	for _, b in ipairs(bulges) do
		local swell = b.swell or min(1, b.at / SWELL_IN)
		swell = swell * swell * (3 - 2 * swell)
		local size = 1 + (b.size - 1) * swell
		local reach = R * EvilSnake.Profile(b.at / n, body, tail) * size * SPAN
		local lo = max(1, math.floor((b.at - reach / link) * SUB) + 1)
		local hi = min(m, math.ceil((b.at + reach / link) * SUB) + 1)
		for j = lo, hi do
			local d = abs((j - 1) / SUB - b.at) * link
			if d < reach then
				swells[j] = max(swells[j], 1 + (size - 1) * (0.5 + 0.5 * cos(math.pi * d / reach)))
			end
		end
	end
	for j = 1, m do widths[j] = widths[j] * swells[j] end
end

local function Rings(pts, bulges, R, link, mouth)
	count = 0
	local n = #pts
	local samples = {}
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = pts[max(i - 1, 1)], pts[i], pts[i + 1], pts[min(i + 2, n)]
		for s = 0, SUB - 1 do samples[#samples + 1] = CatmullRom(p0, p1, p2, p3, s / SUB) end
	end
	samples[#samples + 1] = pts[n]
	local m = #samples
	local first = (samples[2] - samples[1]):GetNormalized()
	Widths(m, n - 1, R, bulges, link)
	Mouth(samples[1], first, widths[1], R, mouth)
	for j = 1, m do
		local a, b = max(j - 1, 1), min(j + 1, m)
		local d = samples[b] - samples[a]
		local len = d:Length()
		d:Normalize()
		local slope = len > 1e-4 and (widths[b] - widths[a]) / len or 0
		local inv = 1 / sqrt(1 + slope * slope)
		local p = samples[j]
		local link = math.floor((j - 1) / SUB)
		local joint = min(n, link + 1 + ((j - 1) % SUB >= SUB / 2 and 1 or 0))
		Ring(p.x, p.y, p.z, d.x, d.y, d.z, widths[j], inv, -slope * inv, joint)
	end
end

local vx, vy, vz, vr, vg, vb = {}, {}, {}, {}, {}, {}
local scratch = Vector()

local function Vert(i)
	scratch:SetUnpacked(vx[i], vy[i], vz[i])
	mesh.Position(scratch)
	mesh.TexCoord(0, 0, 0)
	mesh.Color(vr[i], vg[i], vb[i], 255)
	mesh.AdvanceVertex()
end

function Body.Draw(body, pts, bulges, R, link, mouth)
	if #pts < 2 then return end
	Relight(body, pts)
	cr, cg, cb = EvilSnake.Color()
	Rings(pts, bulges or {}, R, link, mouth)
	local tr = EvilSnake.Trig(SIDES)
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
		for q = 0, SIDES - 1 do
			local cs, sn = tr.c[q], tr.s[q]
			local dx, dy, dz = nx * cs + bx * sn, ny * cs + by * sn, nz * cs + bz * sn
			local i = (j - 1) * SIDES + q + 1
			vx[i], vy[i], vz[i] = px + dx * w, py + dy * w, pz + dz * w
			local l = Bright(light, o, dx * r + ax * k, dy * r + ay * k, dz * r + az * k)
			vr[i], vg[i], vb[i] = min(255, r0 * l), min(255, g0 * l), min(255, b0 * l)
		end
	end

	render.SetMaterial(EvilSnake.Material)
	for a = 1, count - 1, BATCH do
		local b = min(a + BATCH - 1, count - 1)
		mesh.Begin(MATERIAL_QUADS, (b - a + 1) * SIDES)
		for j = a, b do
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
end
