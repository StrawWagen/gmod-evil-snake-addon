include("shared.lua")

language.Add("evil_snake", "Evil snake")

local REBUILD = 0.25
local RELIGHT = 1

local function Same(a, b)
	if not b or #a ~= #b then return false end
	for i, p in ipairs(a) do
		if p:DistToSqr(b[i]) > 0.01 then return false end
	end
	return true
end

function ENT:Think()
	local now = RealTime()
	if now < (self.NextLayout or 0) then return end
	self.NextLayout = now + REBUILD
	local ground, normals = EvilSnake.Body.Layout(self:GetPos(), self:GetAngles().y, function(e)
		return e ~= self and not e:IsPlayer() and not e:IsNPC()
	end)
	if not Same(ground, self.Ground) or now > (self.Relight or 0) then
		self.Ground, self.Normals, self.Dirty = ground, normals, true
		self:SetRenderBoundsWS(EvilSnake.Body.Bounds(ground))
	end
end

function ENT:Draw()
	if not self.Ground then return end
	if self.Dirty or not self.Shape then
		self.Dirty = false
		self.Relight = RealTime() + RELIGHT
		self.Shape = EvilSnake.Body.Build(self.Ground, self.Normals)
	end
	EvilSnake.Body.Draw(self.Shape, UnPredictedCurTime(), self:GetSeed() % 1000 / 1000 * math.pi * 2)
end
