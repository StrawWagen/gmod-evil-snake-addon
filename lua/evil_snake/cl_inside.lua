EvilSnake = EvilSnake or {}

local BACK = 110
local HULL = Vector(4, 4, 4)
local STALE = 0.25
local CATCH = 5

local blob, focus, lastOrigin, lastAngles, lastTime

function EvilSnake.Inside(pos, back)
	blob = { pos = pos, back = BACK + back, seen = RealTime() }
end

hook.Add("RenderScene", "EvilSnakeInside", function(origin, angles)
	lastOrigin, lastAngles = origin, angles
end)

hook.Add("CalcView", "EvilSnakeInside", function(ply, _, angles, fov)
	if ply:Alive() or not ply:GetNW2Bool("EvilSnakeInside") then
		focus = nil
		return
	end
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
	if fresh then
		focus = LerpVector(1 - math.exp(-CATCH * (now - lastTime)), focus, blob.pos)
	end
	lastTime = now
	local tr = util.TraceHull({
		start = focus, endpos = focus - angles:Forward() * (blob and blob.back or BACK),
		mins = -HULL, maxs = HULL, mask = MASK_SOLID_BRUSHONLY,
	})
	return { origin = tr.HitPos, angles = angles, fov = fov, drawviewer = false }
end)
