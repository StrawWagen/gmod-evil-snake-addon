EvilSnake = EvilSnake or {}

EvilSnake.Material = CreateMaterial("evil_snake_flesh", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$vertexcolor"] = 1,
	["$nocull"] = 1,
})

local AXES = { Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1) }

function EvilSnake.SampleLight(pos, out, o)
	for i, axis in ipairs(AXES) do
		local c = render.ComputeLighting(pos, axis) + render.ComputeDynamicLighting(pos, axis)
		out[o + i] = (c.x + c.y + c.z) / 3
	end
end

function EvilSnake.Bright(cube, o, nx, ny, nz)
	local l = nx * nx * (nx > 0 and cube[o + 1] or cube[o + 2])
		+ ny * ny * (ny > 0 and cube[o + 3] or cube[o + 4])
		+ nz * nz * (nz > 0 and cube[o + 5] or cube[o + 6])
	return math.min(1.6, 0.08 + math.sqrt(l) * 1.3)
end

local SHINE, GLOSS, RIM = 16, 0.3, 0.12
local ex, ey, ez = 0, 0, 0

function EvilSnake.Gaze()
	ex, ey, ez = EyePos():Unpack()
end

function EvilSnake.Sheen(cube, o, px, py, pz, nx, ny, nz)
	local vx, vy, vz = ex - px, ey - py, ez - pz
	local vl = math.sqrt(vx * vx + vy * vy + vz * vz)
	if vl < 1e-4 then return 0 end
	vx, vy, vz = vx / vl, vy / vl, vz / vl
	local a, b, c, d, e, f = cube[o + 1], cube[o + 2], cube[o + 3], cube[o + 4], cube[o + 5], cube[o + 6]
	local amb = (a + b + c + d + e + f) / 6
	local lx, ly, lz = a - b, c - d, e - f + amb
	local ll = math.sqrt(lx * lx + ly * ly + lz * lz)
	local nv = 1 - math.abs(nx * vx + ny * vy + nz * vz)
	local rim = nv * nv * nv * RIM * math.sqrt(amb)
	if ll < 1e-4 or nx * lx + ny * ly + nz * lz <= 0 then return rim * 255 end
	local hx, hy, hz = lx / ll + vx, ly / ll + vy, lz / ll + vz
	local hl = math.sqrt(hx * hx + hy * hy + hz * hz)
	local s = math.max(0, (nx * hx + ny * hy + nz * hz) / hl)
	return (s ^ SHINE * GLOSS * math.min(1.2, math.sqrt(ll)) + rim) * 255
end

function EvilSnake.CatmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
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
