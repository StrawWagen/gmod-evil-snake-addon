EvilSnake = EvilSnake or {}

EvilSnake.SEND = 1 / 15

local STEP = 24
local DROP = 120

function EvilSnake.Layout(origin, yaw, count, filter)
	local link = EvilSnake.Setting("segment_length")
	local fwd = Angle(0, yaw, 0):Forward()
	local lift = Vector(0, 0, EvilSnake.Setting("radius"))
	local joints = {}
	local z = origin.z
	for i = 0, count do
		local p = origin - fwd * (i * link)
		local tr = util.TraceLine({
			start = Vector(p.x, p.y, z + STEP),
			endpos = Vector(p.x, p.y, z - DROP),
			mask = MASK_SOLID,
			filter = filter,
		})
		if tr.Hit and not tr.StartSolid then z = tr.HitPos.z end
		joints[i + 1] = Vector(p.x, p.y, z) + lift
	end
	return joints
end

function EvilSnake.Shape()
	local tail = math.Clamp(EvilSnake.Setting("tail_length"), 0.01, 1)
	return 1 / math.max(EvilSnake.Setting("head_size"), 1), tail
end

function EvilSnake.Profile(t, body, tail)
	local start = 1 - tail
	local s = start > 0 and 1 - math.min(t / start, 1) or 0
	local u = math.max(0, (t - start) / tail)
	return (body + (1 - body) * s * s) * (1 - u * u)
end

local GRAB_IN = 0.25
local PULL = 0.8
local PULL_DEEP = 0.7
local HALF = 0.45
local CREEP = 0.15
local DEEP = 1.15
local LIFT = 0.5
local UP = Vector(0, 0, 1)

local function Smooth(u)
	return u * u * (3 - 2 * u)
end

function EvilSnake.HoldLength(hold)
	return GRAB_IN + hold + PULL
end

function EvilSnake.Hold(t, hold)
	t = math.max(t, 0)
	if t < GRAB_IN then
		local u = Smooth(t / GRAB_IN)
		return HALF * u, 0, u
	end
	t = t - GRAB_IN
	if t < hold then return HALF + CREEP * t / hold, 0, 1 end
	local u = math.min((t - hold) / PULL, 1)
	return Lerp(Smooth(math.min(u / PULL_DEEP, 1)), HALF + CREEP, DEEP), Smooth(u), 1
end

function EvilSnake.Gape(head, neck)
	local f = head - neck
	f:Normalize()
	local up = f + UP * LIFT
	up:Normalize()
	return f, up
end

function EvilSnake.HeldPlace(head, neck, depth)
	local f, up = EvilSnake.Gape(head, neck)
	local fwd = UP - up * UP:Dot(up)
	if fwd:LengthSqr() < 1e-4 then fwd = -f end
	fwd:Normalize()
	return head - up * depth, fwd:AngleEx(up), up, head
end
