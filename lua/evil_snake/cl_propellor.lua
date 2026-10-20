EvilSnake = EvilSnake or {}

local SPIN = 1800
local SPINUP = EvilSnake.SPINUP
local SWEEP = 0.14
local DROOP = 0.45
local CONE = 0.05
local LOOK = 0.2

local function Blades(self)
	if not IsValid(self:GetNW2Entity("EvilSnakeRide")) then
		self.UpdateLimbs, self.LimbState = self.EvilSnakeLimbs, nil
		return self:UpdateLimbs()
	end
	local morph = self:Creature()
	if not morph then return end
	local now = UnPredictedCurTime()
	local dt = math.max(now - (self.LastLimbUpdate or now), 0)
	self.LastLimbUpdate = now
	local spin = math.Clamp((now - self:GetNW2Float("EvilSnakeRideAt")) / SPINUP, 0, 1) ^ 2
	self.Churn = ((self.Churn or 0) + SPIN * spin * dt) % 360

	local pos, ang = self:GetPos(), self:GetAngles()
	ang:RotateAroundAxis(ang:Up(), self.Churn)
	local fwd, left, up = ang:Forward(), -ang:Right(), ang:Up()
	local states = self.LimbState or {}
	self.LimbState = states
	for _, limb in ipairs(morph.legs) do
		local st = states[limb]
		if not st then
			st = { points = {}, twitch = Vector(), raise = 0, wrap = 0, lumps = {}, blood = 0 }
			states[limb] = st
		end
		st.wrap, st.stepping = 0, false
		local r = limb.root
		local p = pos + fwd * r.x + left * r.y + up * r.z
		local pts = st.points
		pts[1] = p
		local yaw = math.rad(limb.angle)
		for i, l in ipairs(limb.lengths) do
			local a = yaw - SWEEP * spin * i
			local dir = fwd * math.cos(a) + left * math.sin(a) + up * Lerp(spin, -DROOP * i, CONE)
			p = p + dir:GetNormalized() * l
			pts[i + 1] = p
		end
		for i = #limb.lengths + 2, #pts do pts[i] = nil end
		st.foot, st.target, st.grounded = p, p, false
	end
end

local nextLook = 0

hook.Add("Think", "EvilSnakePropellor", function()
	local now = RealTime()
	if now < nextLook then return end
	nextLook = now + LOOK
	for _, ent in ipairs(ents.FindByClass("evil_crawler")) do
		if ent.UpdateLimbs ~= Blades and IsValid(ent:GetNW2Entity("EvilSnakeRide")) then
			ent.EvilSnakeLimbs, ent.UpdateLimbs = ent.UpdateLimbs, Blades
		end
	end
end)
