include("shared.lua")

language.Add("evil_snake", "Evil snake")

local ASK = 1

net.Receive("EvilSnakeBody", function()
	local ent = net.ReadEntity()
	local pts, meals = {}, {}
	for i = 1, net.ReadUInt(8) do pts[i] = net.ReadVector() end
	for i = 1, net.ReadUInt(6) do meals[i] = { at = net.ReadFloat(), size = net.ReadFloat() } end
	if IsValid(ent) and ent.Snapshot then ent:Snapshot(pts, meals) end
end)

function ENT:Initialize()
	self.Body = EvilSnake.Body.New()
	self.Bulges = {}
end

function ENT:Snapshot(pts, meals)
	self.From = self.Pose and #self.Pose == #pts and self.Pose or pts
	self.To = pts
	self.Meals = meals
	self.Since = RealTime()
end

function ENT:Think()
	local now = RealTime()
	if not self.To then
		if now >= (self.NextAsk or 0) then
			self.NextAsk = now + ASK
			net.Start("EvilSnakeBody")
			net.WriteEntity(self)
			net.SendToServer()
		end
		return
	end
	local t = math.Clamp((now - self.Since) / EvilSnake.SEND, 0, 1)
	local from, to = self.From, self.To
	local pose = {}
	for i, p in ipairs(to) do pose[i] = t >= 1 and p or LerpVector(t, from[i], p) end
	self.Pose = pose
	self.Link = EvilSnake.Setting("segment_length") * math.max(self:GetLength(), 1) / math.max(#pose - 1, 1)
	local ahead = (now - self.Since) * EvilSnake.Setting("bulge_speed") / self.Link
	local bulges, fattest = {}, 1
	for i, m in ipairs(self.Meals) do
		bulges[i] = { at = math.min(m.at + ahead, #pose - 1), size = m.size }
		fattest = math.max(fattest, m.size)
	end
	self.Bulges = bulges
	self:SetRenderBoundsWS(EvilSnake.Body.Bounds(pose, fattest, self:Radius()))
end

function ENT:Draw()
	if self.Pose then EvilSnake.Body.Draw(self.Body, self.Pose, self.Bulges, self:Radius(), self.Link) end
end
