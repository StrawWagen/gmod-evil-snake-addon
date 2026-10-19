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
