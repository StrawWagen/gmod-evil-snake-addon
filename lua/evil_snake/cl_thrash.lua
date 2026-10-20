EvilSnake = EvilSnake or {}

local TIME = 0.4
local FREQ = 30
local ROLL = 16
local TILT = 10
local LUNGE = 5
local FLAIL = 55
local BONES = {
	"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm",
	"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Head1",
}

local thrashing = {}

local function Settle(ent, t)
	for bone in pairs(t.limbs) do ent:ManipulateBoneAngles(bone, angle_zero) end
end

hook.Add("EntityNetworkedVarChanged", "EvilSnakeThrash", function(ent, name, old, new)
	if name ~= "EvilSnakeThrash" or not IsValid(ent) or new == 0 or new == old then return end
	local was = thrashing[ent]
	if was then Settle(ent, was) end
	local limbs = {}
	for _, path in ipairs(BONES) do
		local bone = ent:LookupBone(path)
		if bone then limbs[bone] = { aim = AngleRand() * (FLAIL / 180), phase = math.Rand(0, math.pi * 2) } end
	end
	thrashing[ent] = {
		at = RealTime(), roll = (math.random(2) == 1 and -1 or 1) * math.Rand(0.6, 1), tilt = math.Rand(-1, 1), limbs = limbs,
	}
end)

function EvilSnake.Thrash(ent)
	local t = thrashing[ent]
	if not t then return end
	local k = RealTime() - t.at
	if k >= TIME then return end
	local e = 1 - k / TIME
	local w = math.sin(k * FREQ) * e * e
	return w * ROLL * t.roll, w * TILT * t.tilt, math.abs(w) * LUNGE
end

hook.Add("Think", "EvilSnakeThrash", function()
	local now = RealTime()
	for ent, t in pairs(thrashing) do
		if not IsValid(ent) then
			thrashing[ent] = nil
		else
			local k = now - t.at
			if k >= TIME then
				Settle(ent, t)
				thrashing[ent] = nil
			else
				local e = 1 - k / TIME
				e = e * e
				for bone, limb in pairs(t.limbs) do
					ent:ManipulateBoneAngles(bone, limb.aim * (math.sin(k * FREQ * 0.7 + limb.phase) * e))
				end
			end
		end
	end
end)
