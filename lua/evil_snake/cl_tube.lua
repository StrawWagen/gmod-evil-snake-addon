EvilSnake = EvilSnake or {}

EvilSnake.Material = CreateMaterial("evil_snake_flesh", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$vertexcolor"] = 1,
	["$nocull"] = 1,
})

local AXES = { Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1) }
local cube = { 0, 0, 0, 0, 0, 0 }

function EvilSnake.SampleLight(pos)
	for i, axis in ipairs(AXES) do
		local c = render.ComputeLighting(pos, axis) + render.ComputeDynamicLighting(pos, axis)
		cube[i] = (c.x + c.y + c.z) / 3
	end
end

function EvilSnake.Bright(nx, ny, nz)
	local l = nx * nx * (nx > 0 and cube[1] or cube[2])
		+ ny * ny * (ny > 0 and cube[3] or cube[4])
		+ nz * nz * (nz > 0 and cube[5] or cube[6])
	return math.min(1.6, 0.08 + math.sqrt(l) * 1.3)
end

function EvilSnake.Smooth(x)
	x = math.Clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function EvilSnake.CatmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

function EvilSnake.Wobble(t, phase, freq)
	return Vector(
		math.sin(t * freq + phase) + 0.5 * math.sin(t * freq * 2.3 + phase * 1.7),
		math.sin(t * freq * 1.3 + phase * 2.1) + 0.5 * math.sin(t * freq * 2.9 + phase),
		math.sin(t * freq * 0.9 + phase * 3.3) + 0.5 * math.sin(t * freq * 3.1 + phase * 0.6)
	)
end

function EvilSnake.Rng(seed)
	local state = math.floor(seed) % 2147483647
	if state <= 0 then state = state + 2147483646 end
	return function(a, b)
		state = state * 16807 % 2147483647
		local x = (state - 1) / 2147483646
		if not a then return x end
		return a + (b - a) * x
	end
end

local scratch = Vector()
local px, py, pz, pf = {}, {}, {}, {}
local vx, vy, vz, vr, vg, vb = {}, {}, {}, {}, {}, {}

local function Vert(i, u, v)
	scratch:SetUnpacked(vx[i], vy[i], vz[i])
	mesh.Position(scratch)
	mesh.TexCoord(0, u, v)
	mesh.Color(math.min(255, vr[i]), math.min(255, vg[i]), math.min(255, vb[i]), 255)
	mesh.AdvanceVertex()
end

local trig = {}
function EvilSnake.Trig(sides)
	local t = trig[sides]
	if not t then
		t = { c = {}, s = {} }
		for k = 0, sides do
			local a = k / sides * math.pi * 2
			t.c[k], t.s[k] = math.cos(a), math.sin(a)
		end
		trig[sides] = t
	end
	return t
end

local CatmullRom, Bright = EvilSnake.CatmullRom, EvilSnake.Bright

function EvilSnake.Tube(pts, sides, sub, radiusAt, colorAt, data, closed, hint)
	local n = #pts
	if n < 2 then return end
	local segs = closed and n or n - 1

	local count = 0
	for i = 1, segs do
		local p0, p1, p2, p3
		if closed then
			p0, p1, p2, p3 = pts[(i - 2) % n + 1], pts[i], pts[i % n + 1], pts[(i + 1) % n + 1]
		else
			p0, p1, p2, p3 = pts[math.max(i - 1, 1)], pts[i], pts[i + 1], pts[math.min(i + 2, n)]
		end
		for s = 0, sub - 1 do
			local t = s / sub
			local p = CatmullRom(p0, p1, p2, p3, t)
			count = count + 1
			px[count], py[count], pz[count] = p.x, p.y, p.z
			pf[count] = (i - 1 + t) / segs
		end
	end
	if not closed then
		count = count + 1
		px[count], py[count], pz[count], pf[count] = pts[n].x, pts[n].y, pts[n].z, 1
	end

	local tr = EvilSnake.Trig(sides)
	local nx, ny, nz
	if hint then nx, ny, nz = hint.x, hint.y, hint.z end
	for j = 1, count do
		local a, b
		if closed then
			a, b = (j - 2) % count + 1, j % count + 1
		else
			a, b = math.max(j - 1, 1), math.min(j + 1, count)
		end
		local tx, ty, tz = px[b] - px[a], py[b] - py[a], pz[b] - pz[a]
		local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
		if tl < 1e-6 then tx, ty, tz, tl = 0, 0, 1, 1 end
		tx, ty, tz = tx / tl, ty / tl, tz / tl

		if not nx then
			if math.abs(tz) < 0.9 then nx, ny, nz = 0, 0, 1 else nx, ny, nz = 1, 0, 0 end
		end
		local d = nx * tx + ny * ty + nz * tz
		nx, ny, nz = nx - tx * d, ny - ty * d, nz - tz * d
		local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
		if nl < 1e-6 then
			if math.abs(tz) < 0.9 then nx, ny, nz = -ty, tx, 0 else nx, ny, nz = 0, -tz, ty end
			nl = math.sqrt(nx * nx + ny * ny + nz * nz)
		end
		nx, ny, nz = nx / nl, ny / nl, nz / nl
		local bx, by, bz = ty * nz - tz * ny, tz * nx - tx * nz, tx * ny - ty * nx

		local f = pf[j]
		local r = radiusAt(f, data)
		local cr, cg, cb = colorAt(f, data)
		for k = 0, sides - 1 do
			local c, s = tr.c[k], tr.s[k]
			local dx, dy, dz = nx * c + bx * s, ny * c + by * s, nz * c + bz * s
			local i = (j - 1) * sides + k + 1
			vx[i], vy[i], vz[i] = px[j] + dx * r, py[j] + dy * r, pz[j] + dz * r
			local l = Bright(dx, dy, dz)
			vr[i], vg[i], vb[i] = cr * l, cg * l, cb * l
		end
	end

	local last = closed and count or count - 1
	mesh.Begin(MATERIAL_QUADS, last * sides)
	for j = 1, last do
		local j2 = j % count + 1
		local v0, v1 = (j - 1) / last * 2, j / last * 2
		for k = 0, sides - 1 do
			local k2 = (k + 1) % sides
			local u0, u1 = k / sides, (k + 1) / sides
			Vert((j - 1) * sides + k + 1, u0, v0)
			Vert((j - 1) * sides + k2 + 1, u1, v0)
			Vert((j2 - 1) * sides + k2 + 1, u1, v1)
			Vert((j2 - 1) * sides + k + 1, u0, v1)
		end
	end
	mesh.End()
end
