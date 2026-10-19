EvilSnake = EvilSnake or {}
local Body = {}
EvilSnake.Body = Body

local Bright, CatmullRom = EvilSnake.Bright, EvilSnake.CatmullRom
local sqrt, sin, cos, max, min, abs = math.sqrt, math.sin, math.cos, math.max, math.min, math.abs

local SUB = 4
local SIDES = 20
local CAP = 6
local PAD = 4
local RELIGHT = 3
local BATCH = 100
local SPAN = 1.3
local SWELL_IN = 1
local SWELL_OUT = 2

function Body.New()
	return { light = {}, lit = 0 }
end

function Body.Bounds(pts, fattest)
	local mins, maxs = Vector(pts[1]), Vector(pts[1])
	for _, p in ipairs(pts) do
		mins.x, mins.y, mins.z = min(mins.x, p.x), min(mins.y, p.y), min(mins.z, p.z)
		maxs.x, maxs.y, maxs.z = max(maxs.x, p.x), max(maxs.y, p.y), max(maxs.z, p.z)
	end
	local pad = EvilSnake.Setting("radius") * (1 + (fattest or 1)) + PAD
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
local count = 0

local function Ring(x, y, z, dx, dy, dz, w, nr, ax, joint)
	count = count + 1
	cx[count], cy[count], cz[count] = x, y, z
	tx[count], ty[count], tz[count] = dx, dy, dz
	rw[count], rnr[count], rax[count], rlo[count] = w, nr, ax, (joint - 1) * 6
end

local function Cap(p, dx, dy, dz, joint, outward, R)
	for k = 1, CAP do
		local a = (outward and k or CAP + 1 - k) / CAP * math.pi * 0.5
		local s, c = sin(a), cos(a)
		local o = outward and s * R or -s * R
		Ring(p.x + dx * o, p.y + dy * o, p.z + dz * o, dx, dy, dz, c * R, c, outward and s or -s, joint)
	end
end

local widths = {}

local function Widths(m, n, R, bulges)
	local link = EvilSnake.Setting("segment_length")
	for j = 1, m do widths[j] = R end
	for _, b in ipairs(bulges) do
		local swell = min(1, b.at / SWELL_IN, (n - b.at) / SWELL_OUT)
		swell = swell * swell * (3 - 2 * swell)
		local fat = R * (1 + (b.size - 1) * swell)
		local reach = fat * SPAN
		local lo = max(1, math.floor((b.at - reach / link) * SUB) + 1)
		local hi = min(m, math.ceil((b.at + reach / link) * SUB) + 1)
		for j = lo, hi do
			local d = abs((j - 1) / SUB - b.at) * link
			if d < reach then
				widths[j] = max(widths[j], R + (fat - R) * (0.5 + 0.5 * cos(math.pi * d / reach)))
			end
		end
	end
end

local function Rings(pts, bulges)
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
	local last = (samples[m] - samples[m - 1]):GetNormalized()
	Widths(m, n - 1, EvilSnake.Setting("radius"), bulges)
	Cap(samples[1], first.x, first.y, first.z, 1, false, widths[1])
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
	Cap(samples[m], last.x, last.y, last.z, n, true, widths[m])
end

local vx, vy, vz, vl = {}, {}, {}, {}
local scratch = Vector()
local cr, cg, cb = 0, 0, 0

local function Vert(i)
	scratch:SetUnpacked(vx[i], vy[i], vz[i])
	mesh.Position(scratch)
	mesh.TexCoord(0, 0, 0)
	local l = vl[i]
	mesh.Color(min(255, cr * l), min(255, cg * l), min(255, cb * l), 255)
	mesh.AdvanceVertex()
end

function Body.Draw(body, pts, bulges)
	if #pts < 2 then return end
	Relight(body, pts)
	cr, cg, cb = EvilSnake.Color()
	Rings(pts, bulges or {})
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
		for q = 0, SIDES - 1 do
			local cs, sn = tr.c[q], tr.s[q]
			local dx, dy, dz = nx * cs + bx * sn, ny * cs + by * sn, nz * cs + bz * sn
			local i = (j - 1) * SIDES + q + 1
			vx[i], vy[i], vz[i] = px + dx * w, py + dy * w, pz + dz * w
			vl[i] = Bright(light, o, dx * r + ax * k, dy * r + ay * k, dz * r + az * k)
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
