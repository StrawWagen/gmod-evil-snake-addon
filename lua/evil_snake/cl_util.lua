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
