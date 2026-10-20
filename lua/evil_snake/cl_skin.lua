EvilSnake = EvilSnake or {}
local Skin = {}
EvilSnake.Skin = Skin

local floor, abs, max, min, sin = math.floor, math.abs, math.max, math.min, math.sin
local band, bxor, rshift, bnot = bit.band, bit.bxor, bit.rshift, bit.bnot

local SIZE = 256
local COLUMNS = 18
local ROWS = 16
local BELLY = 0.13
local SCUTES = 16
local BLOTCH = 3
local VERSION = 1
local PATH = "evil_snake/skin_v" .. VERSION .. ".png"

local function Hash(x, y)
	local h = sin(x * 127.1 + y * 311.7) * 43758.5453
	return h - floor(h)
end

local function Noise(x, y, px, py)
	local ix, iy = floor(x), floor(y)
	local fx, fy = x - ix, y - iy
	fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	local x0, x1, y0, y1 = ix % px, (ix + 1) % px, iy % py, (iy + 1) % py
	local a, b = Hash(x0, y0), Hash(x1, y0)
	local c, d = Hash(x0, y1), Hash(x1, y1)
	return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
end

local function Step(a, b, x)
	local t = min(max((x - a) / (b - a), 0), 1)
	return t * t * (3 - 2 * t)
end

local function Pattern(u, v)
	local back = min(u, 1 - u)
	local wob = (Noise(u * 10, v * 6, 10, 6) - 0.5) * 0.05
	local y = v * BLOTCH
	local f = y - floor(y) - 0.5
	local diamond = (back + wob) / 0.13 + abs(f) / 0.5
	local lf = y + 0.5 - floor(y + 0.5) - 0.5
	local lat = abs(back - 0.27 + wob) / 0.06 + abs(lf) / 0.22
	local dark = max(Step(0.9, 0.75, diamond), Step(1, 0.8, lat))
	local rim = Step(0.7, 0.85, diamond) * Step(1.15, 0.95, diamond)
	local mottle = Noise(u * 36, v * 18, 36, 18) - 0.5
	return (0.9 - 0.5 * dark + 0.2 * rim) * (1 + 0.1 * mottle)
end

local function Scale(u, v)
	local gy = v * ROWS
	local row = floor(gy)
	local tone, shadow = nil, 1
	for r = row - 1, row + 1 do
		local gx = u * COLUMNS + (r % 2) * 0.5
		local c0 = floor(gx)
		for c = c0 - 1, c0 + 1 do
			local dx, dy = gx - c - 0.5, gy - r - 0.5
			local ax, ay = abs(dx) / 0.62, dy < 0 and -dy / 0.6 or dy / 1.05
			local d = (ax ^ 1.6 + ay ^ 1.6) ^ (1 / 1.6)
			if not tone and d < 1 then
				local cu, cv = (c + 0.5 - (r % 2) * 0.5) / COLUMNS, (r + 0.5) / ROWS
				local base = 0.6 + 0.4 * Step(-0.6, 0.95, dy)
				local dome = 1 - 0.22 * d * d
				local keel = 0.07 * Step(0.1, 0, abs(dx)) * Step(-0.3, 0.6, dy)
				local lip = 0.6 + 0.4 * Step(1, 0.86, d)
				local jitter = 1 + (Hash(c % COLUMNS, r % ROWS) - 0.5) * 0.12
				tone = (base * dome + keel) * lip * jitter * (Pattern(cu % 1, cv % 1) * 0.75 + Pattern(u, v) * 0.25)
			elseif not tone and d < 1.3 then
				shadow = min(shadow, 0.55 + 0.45 * Step(1, 1.3, d))
			end
		end
	end
	return (tone or 0.35) * shadow
end

local function Belly(u, v)
	local s = v * SCUTES
	local f = s - floor(s)
	local side = abs(u - 0.5) / BELLY
	local crease = 0.62 + 0.38 * Step(0, 0.12, f) * Step(1, 0.9, f)
	return (0.74 + 0.16 * f) * crease * (1 - 0.12 * side * side)
end

function Skin.Texel(u, v)
	local side = abs(u - 0.5)
	local belly = Step(BELLY + 0.03, BELLY - 0.02, side)
	local top = Scale(u, v)
	local l = top + (Belly(u, v) - top) * belly
	local g = min(1, max(0, l))
	return g, g, min(1, g * (1 + 0.05 * (1 - belly)))
end

local crc
local function CRC(s, c)
	if not crc then
		crc = {}
		for i = 0, 255 do
			local x = i
			for _ = 1, 8 do
				x = band(x, 1) == 1 and bxor(rshift(x, 1), 0xEDB88320) or rshift(x, 1)
			end
			crc[i] = x
		end
	end
	c = bnot(c or 0)
	for i = 1, #s do
		c = bxor(crc[band(bxor(c, s:byte(i)), 255)], rshift(c, 8))
	end
	return bnot(c)
end

local function U32(n)
	n = n % 4294967296
	return string.char(floor(n / 16777216) % 256, floor(n / 65536) % 256, floor(n / 256) % 256, n % 256)
end

local function Chunk(kind, data)
	return U32(#data) .. kind .. data .. U32(CRC(kind .. data) % 4294967296)
end

local function Deflate(raw)
	local out, a, b = { "\120\1" }, 1, 0
	local n = #raw
	for i = 1, n, 65535 do
		local block = raw:sub(i, min(i + 65534, n))
		local len = #block
		out[#out + 1] = string.char(i + 65535 > n and 1 or 0, len % 256, floor(len / 256), 255 - len % 256, 255 - floor(len / 256)) .. block
	end
	for i = 1, n do
		a = (a + raw:byte(i)) % 65521
		b = (b + a) % 65521
	end
	out[#out + 1] = U32(b * 65536 + a)
	return table.concat(out)
end

function Skin.PNG(size)
	size = size or SIZE
	local rows, line = {}, {}
	for y = 0, size - 1 do
		line[1] = 0
		local v = (y + 0.5) / size
		for x = 0, size - 1 do
			local r, g, b = Skin.Texel((x + 0.5) / size, v)
			local k = x * 3
			line[k + 2], line[k + 3], line[k + 4] = floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)
		end
		rows[y + 1] = string.char(unpack(line))
	end
	local head = U32(size) .. U32(size) .. "\8\2\0\0\0"
	return "\137PNG\r\n\26\n" .. Chunk("IHDR", head) .. Chunk("IDAT", Deflate(table.concat(rows))) .. Chunk("IEND", "")
end

if not CLIENT then return end

EvilSnake.SkinMaterial = CreateMaterial("evil_snake_skin", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$vertexcolor"] = 1,
	["$nocull"] = 1,
})

function Skin.Load()
	if not file.Exists(PATH, "DATA") then
		file.CreateDir("evil_snake")
		file.Write(PATH, Skin.PNG())
	end
	local png = Material("data/" .. PATH, "mips smooth noclamp")
	if png and not png:IsError() then
		EvilSnake.SkinMaterial:SetTexture("$basetexture", png:GetTexture("$basetexture"))
	end
end

Skin.Load()
