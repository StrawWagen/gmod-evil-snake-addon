EvilSnake = EvilSnake or {}
local Belly = {}
EvilSnake.Belly = Belly

local Setting, Along = EvilSnake.Setting, EvilSnake.Along
local sqrt, sin, cos, max, min, abs, floor, pi = math.sqrt, math.sin, math.cos, math.max, math.min, math.abs, math.floor, math.pi

local SUB = 4
local SIDES = 20
local RANGE = 500
local INNER = 0.8
local THROAT = 1
local POCKET = 0.85
local POCKET_SPAN = 1.6
local ROOM = 7
local FOLDS = 9
local FOLD = 0.14
local FOLD_TWIST = 0.02
local RUGA = 2 * pi / 22
local WAVE = 140
local WAVE_SPEED = 90
local SQUEEZE = 0.35
local BREATH = 0.05
local BREATH_RATE = 1.4
local FLESH = { 150, 42, 52 }
local GLOW = { 255, 70, 45 }
local SHEEN_COLOR = { 255, 190, 190 }
local FOLD_DARK = 0.5
local AMBIENT = 0.06
local FILL = 1.1
local FILL_REACH = 60
local TRANSMIT = 0.35
local SHEEN = 0.45
local SHEEN_POW = 10
local FOG = 260
local FADE_IN = 0.8
local CLOSE = 0.8
local ZNEAR = 1
local CULL = 2
local BATCH = 100
local GURGLE = { "npc/barnacle/barnacle_digesting1.wav", "npc/barnacle/barnacle_digesting2.wav" }
local GURGLE_GAP = { 3, 7 }
local SQUELCH = {
	"physics/flesh/flesh_squishy_impact_hard1.wav", "physics/flesh/flesh_squishy_impact_hard2.wav",
	"physics/flesh/flesh_squishy_impact_hard3.wav", "physics/flesh/flesh_squishy_impact_hard4.wav",
}
local SOUND_LEVEL = 70

local state = {}

local function Smooth(u)
	return u * u * (3 - 2 * u)
end

local function Active(ply)
	return EvilSnake.Swallowed(ply) and Setting("belly_view") ~= 0
end

local function Reset()
	if state.enter then state = {} end
end

local function Eye(ply)
	local snake, at, size = EvilSnake.InsideSpot(ply)
	if not snake or not snake.Pose or #snake.Pose < 2 then return end
	return snake, at, size, Along(snake.Pose, at)
end

function Belly.View(ply, angles, fov)
	local _, _, _, eye = Eye(ply)
	return { origin = eye or ply:EyePos(), angles = angles, fov = fov, drawviewer = false, znear = ZNEAR, zfar = CULL }
end

local function Pocket(u, at, size, R, link, scale)
	local pr = R * size * POCKET * scale
	local span = pr * POCKET_SPAN
	local d = abs(u - at) * link
	if d >= span then return 0 end
	return pr * (0.5 + 0.5 * cos(pi * d / span))
end

local px, py, pz, cx, cy, cz, tx, ty, tz, rw, ru = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local vx, vy, vz, vr, vg, vb = {}, {}, {}, {}, {}, {}
local count = 0
local scratch = Vector()

local function Vert(i)
	scratch:SetUnpacked(vx[i], vy[i], vz[i])
	mesh.Position(scratch)
	mesh.TexCoord(0, 0, 0)
	mesh.Color(vr[i], vg[i], vb[i], 255)
	mesh.AdvanceVertex()
end

local function Rings(snake, at, size, now, close)
	local pose = snake.Pose
	local n = #pose
	local R = snake:Radius()
	local link = snake.Link or Setting("segment_length")
	local body, tail = EvilSnake.Shape()
	local breath = 1 + BREATH * sin(now * BREATH_RATE)
	local reach = RANGE / link
	local lo = max(0, floor((at - reach) * SUB))
	local hi = min((n - 1) * SUB, math.ceil((at + reach) * SUB))
	local m = 0
	for k = lo, hi do
		m = m + 1
		local p = Along(pose, k / SUB)
		px[m], py[m], pz[m] = p.x, p.y, p.z
	end
	count = 0
	local bulges = snake.Bulges or {}
	for j = 1, m do
		local u = (lo + j - 1) / SUB
		local a, b = max(j - 1, 1), min(j + 1, m)
		local dx, dy, dz = px[b] - px[a], py[b] - py[a], pz[b] - pz[a]
		local len = sqrt(dx * dx + dy * dy + dz * dz)
		if len > 1e-4 then
			local r = R * EvilSnake.Profile(u / (n - 1), body, tail) * INNER
			r = max(r, Pocket(u, at, size, R, link, breath * close))
			for _, bl in ipairs(bulges) do
				if abs(bl.at - at) > 0.25 then r = max(r, Pocket(u, bl.at, bl.size, R, link, breath)) end
			end
			local w = max(0, sin(2 * pi * (u * link - now * WAVE_SPEED) / WAVE))
			r = r * (1 - SQUEEZE * w * w * w * w) * Smooth(min(u / THROAT, (n - 1 - u) / THROAT, 1))
			if abs(u - at) * link < ROOM * 2 then r = max(r, ROOM) end
			count = count + 1
			cx[count], cy[count], cz[count] = px[j], py[j], pz[j]
			tx[count], ty[count], tz[count] = dx / len, dy / len, dz / len
			rw[count], ru[count] = r, u
		end
	end
	return R, link, n
end

local function Shade(snake, eye, R, link, n, fade)
	local light = snake.Body and snake.Body.light or {}
	local ex, ey, ez = eye.x, eye.y, eye.z
	local inner = R * INNER
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
		local o = (min(n, floor(ru[j]) + 1) - 1) * 6
		local outside = 0
		for q = 1, 6 do outside = outside + (light[o + q] or 0) end
		outside = sqrt(max(outside / 6, 0))
		local along = ru[j] * link
		local w, c0x, c0y, c0z = rw[j], cx[j], cy[j], cz[j]
		local glow = TRANSMIT * outside * min(max(w / inner, 1), 3)
		for q = 0, SIDES - 1 do
			local ang = q / SIDES * 2 * pi
			local cs, sn = cos(ang), sin(ang)
			local dx, dy, dz = nx * cs + bx * sn, ny * cs + by * sn, nz * cs + bz * sn
			local f = 0.6 * sin(FOLDS * ang + along * FOLD_TWIST) + 0.4 * sin(along * RUGA + 0.8 * sin(3 * ang))
			local wv = w * (1 + FOLD * f)
			local x, y, z = c0x + dx * wv, c0y + dy * wv, c0z + dz * wv
			local rx, ry, rz = x - ex, y - ey, z - ez
			local dist2 = rx * rx + ry * ry + rz * rz
			local dist = sqrt(dist2)
			local fill = FILL / (1 + dist2 / (FILL_REACH * FILL_REACH))
			local fog = fade / (1 + dist2 / (FOG * FOG))
			local facing = max(0, (dx * rx + dy * ry + dz * rz) / max(dist, 1e-3))
			local sheen = SHEEN * facing ^ SHEEN_POW * fill
			local base = (fill + AMBIENT) * Lerp(f * 0.5 + 0.5, FOLD_DARK, 1)
			local i = (j - 1) * SIDES + q + 1
			vx[i], vy[i], vz[i] = x, y, z
			vr[i] = min(255, (FLESH[1] * base + GLOW[1] * glow + SHEEN_COLOR[1] * sheen) * fog)
			vg[i] = min(255, (FLESH[2] * base + GLOW[2] * glow + SHEEN_COLOR[2] * sheen) * fog)
			vb[i] = min(255, (FLESH[3] * base + GLOW[3] * glow + SHEEN_COLOR[3] * sheen) * fog)
		end
	end
end

local function Draw()
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

hook.Add("RenderScene", "EvilSnakeBelly", function()
	local ply = LocalPlayer()
	if not Active(ply) then
		Reset()
		return
	end
	local now = RealTime()
	if not state.enter then
		state.enter = now
		state.tone = render.GetToneMappingScaleLinear()
	end
	render.SetToneMappingScaleLinear(state.tone)
	if ply:GetNW2Bool("EvilSnakeDone") then state.done = state.done or now else state.done = nil end
end)

hook.Add("PostDrawTranslucentRenderables", "EvilSnakeBelly", function(depth, skybox, sky3d)
	if depth or skybox or sky3d or not state.enter then return end
	local ply = LocalPlayer()
	if not Active(ply) then return end
	local now = RealTime()
	local fade = Smooth(min((now - state.enter) / FADE_IN, 1))
	local close = 1
	if state.done then
		local u = Smooth(min((now - state.done) / EvilSnake.DIGESTED_HOLD, 1))
		fade, close = fade * (1 - u), 1 - CLOSE * u
	end
	render.Clear(0, 0, 0, 255, true, true)
	local snake, at, size, eye = Eye(ply)
	state.eye = eye
	if not eye or fade <= 0 then return end
	local R, link, n = Rings(snake, at, size, now, close)
	state.at, state.link = at, link
	Shade(snake, eye, R, link, n, fade)
	local view = render.GetViewSetup()
	cam.Start3D(eye, view.angles, view.fov, view.x, view.y, view.width, view.height, ZNEAR, RANGE * 2)
	Draw()
	cam.End3D()
end)

hook.Add("Think", "EvilSnakeBelly", function()
	local eye = state.eye
	if not eye or not Active(LocalPlayer()) then return end
	local volume = Setting("eat_volume")
	if volume <= 0 or state.done then return end
	local now = RealTime()
	if now >= (state.gurgle or 0) then
		if state.gurgle then sound.Play(table.Random(GURGLE), eye, SOUND_LEVEL, math.random(85, 105), volume * 0.8) end
		state.gurgle = now + math.Rand(GURGLE_GAP[1], GURGLE_GAP[2])
	end
	if not state.link then return end
	local wave = floor((state.at * state.link - now * WAVE_SPEED) / WAVE)
	if state.wave and wave ~= state.wave then
		sound.Play(table.Random(SQUELCH), eye, SOUND_LEVEL, math.random(55, 70), volume * 0.35)
	end
	state.wave = wave
end)
