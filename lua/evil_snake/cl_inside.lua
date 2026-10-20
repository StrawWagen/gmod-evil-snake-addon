EvilSnake = EvilSnake or {}

local BACK = 110
local HULL = Vector(4, 4, 4)
local STALE = 0.25
local CATCH = 5
local FIRST_SIZE = 1.5
local KEY_SIZE = { 150, 44 }
local KEY_Y = 0.7
local BAR_SIZE = { 220, 6 }
local BAR_GAP = 14
local BONE = Color(170, 160, 145)
local KEY_BG = Color(10, 8, 9, 200)
local BAR_BG = Color(255, 255, 255, 25)

local blob, focus, lastOrigin, lastAngles, lastTime

function EvilSnake.Inside(snake, at, size)
	blob = {
		snake = snake, at = at, size = size, seen = RealTime(),
		pos = EvilSnake.Along(snake.Pose, at), back = BACK + snake:Radius() * size,
	}
end

function EvilSnake.Swallowed(ply)
	return IsValid(ply) and not ply:Alive() and ply:GetNW2Bool("EvilSnakeInside")
end

function EvilSnake.InsideSpot(ply)
	if blob and IsValid(blob.snake) then return blob.snake, blob.at, blob.size end
	local snake = ply:GetNW2Entity("EvilSnakeBelly")
	if IsValid(snake) then return snake, EvilSnake.GULP_AT, FIRST_SIZE end
end

hook.Add("RenderScene", "EvilSnakeInside", function(origin, angles)
	lastOrigin, lastAngles = origin, angles
end)

hook.Add("CalcView", "EvilSnakeInside", function(ply, _, angles, fov)
	if not EvilSnake.Swallowed(ply) then
		blob, focus = nil, nil
		return
	end
	if EvilSnake.Setting("belly_view") ~= 0 then return EvilSnake.Belly.View(ply, angles, fov) end
	local now = RealTime()
	local fresh = blob and now - blob.seen <= STALE
	if not focus then
		if not fresh then
			if lastOrigin then return { origin = lastOrigin, angles = angles, fov = fov, drawviewer = false } end
			return
		end
		focus = lastOrigin and lastOrigin + lastAngles:Forward() * BACK or blob.pos
		lastTime = now
	end
	if blob then
		focus = LerpVector(1 - math.exp(-CATCH * (now - lastTime)), focus, blob.pos)
	end
	lastTime = now
	local tr = util.TraceHull({
		start = focus, endpos = focus - angles:Forward() * (blob and blob.back or BACK),
		mins = -HULL, maxs = HULL, mask = MASK_SOLID_BRUSHONLY,
	})
	return { origin = tr.HitPos, angles = angles, fov = fov, drawviewer = false }
end)

hook.Add("HUDPaint", "EvilSnakeInside", function()
	local ply = LocalPlayer()
	if not EvilSnake.Swallowed(ply) then return end
	if EvilSnake.Setting("skip_swallow") == 0 or ply:GetNW2Bool("EvilSnakeDone") then return end
	local start = ply:GetNW2Float("EvilSnakeSkip", 0)
	local k = start > 0 and math.Clamp((CurTime() - start) / EvilSnake.SKIP_HOLD, 0, 1) or 0
	local cx, cy = ScrW() * 0.5, ScrH() * KEY_Y
	local kw, kh = KEY_SIZE[1], KEY_SIZE[2]
	local x, y = cx - kw * 0.5, cy - kh * 0.5
	draw.RoundedBox(6, x, y, kw, kh, KEY_BG)
	surface.SetDrawColor(BONE)
	surface.DrawOutlinedRect(x, y, kw, kh, 2)
	local name = input.LookupBinding("+jump") or "?"
	draw.SimpleText(name:upper(), "EvilMashKey", cx, cy, BONE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	local bw, bh = BAR_SIZE[1], BAR_SIZE[2]
	local bx, by = cx - bw * 0.5, y + kh + BAR_GAP
	surface.SetDrawColor(BAR_BG)
	surface.DrawRect(bx, by, bw, bh)
	surface.SetDrawColor(BONE)
	surface.DrawRect(bx, by, bw * k, bh)
end)
