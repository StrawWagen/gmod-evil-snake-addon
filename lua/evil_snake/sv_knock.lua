local KNOCK_TIME = 5
local REST = 30
local LATE = 5
local RINGS = { 0, 20, 40, 64 }
local SPOKES = 8
local LIFTS = { 24, 4 }
local DROP = 64
local CORPSE = 30
local CORPSE_FADE = 2

local knocked = {}

local function Dress(rag, ent)
	rag:SetSkin(ent:GetSkin())
	for i = 0, ent:GetNumBodyGroups() - 1 do rag:SetBodygroup(i, ent:GetBodygroup(i)) end
	rag:SetMaterial(ent:GetMaterial())
	for i = 0, #ent:GetMaterials() - 1 do
		local m = ent:GetSubMaterial(i)
		if m ~= "" then rag:SetSubMaterial(i, m) end
	end
	rag:SetColor(ent:GetColor())
	rag:SetRenderMode(ent:GetRenderMode())
	if ent.GetPlayerColor then rag:SetNW2Vector("EvilSnakeColor", ent:GetPlayerColor()) end
end

local function Pose(rag, ent, vel)
	ent:SetupBones()
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local m = ent:GetBoneMatrix(rag:TranslatePhysBoneToBone(i))
			if m then
				phys:SetPos(m:GetTranslation(), true)
				phys:SetAngles(m:GetAngles())
			end
			phys:SetVelocity(vel)
			phys:Wake()
		end
	end
end

local function Push(rag, vel)
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			phys:AddVelocity(vel)
			phys:Wake()
		end
	end
end

local function Hide(ent, k)
	ent:SetNoDraw(true)
	ent:SetNotSolid(true)
	ent:DrawShadow(false)
	ent:SetMoveType(MOVETYPE_NONE)
	ent:AddFlags(FL_NOTARGET)
	ent:SetNW2Bool("EvilSnakeDown", true)
	ent:SetNW2Entity("EvilSnakeRagdoll", k.rag)
	if ent:IsPlayer() then
		if ent:FlashlightIsOn() then ent:Flashlight(false) end
		ent:DrawViewModel(false)
		ent:DrawWorldModel(false)
	else
		ent:AddEFlags(EFL_NO_THINK_FUNCTION)
		if IsValid(k.weapon) then k.weapon:SetNoDraw(true) end
	end
end

local function Show(ent, k)
	ent:SetNoDraw(false)
	ent:SetNotSolid(false)
	ent:DrawShadow(true)
	if not k.notarget then ent:RemoveFlags(FL_NOTARGET) end
	ent:SetNW2Bool("EvilSnakeDown", false)
	ent:SetNW2Entity("EvilSnakeRagdoll", NULL)
	if ent:IsPlayer() then
		ent:DrawViewModel(true)
		ent:DrawWorldModel(true)
	else
		ent:RemoveEFlags(EFL_NO_THINK_FUNCTION)
		if IsValid(k.weapon) then k.weapon:SetNoDraw(false) end
	end
end

local function Stand(ent, from, filter, home)
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local mask = ent:IsPlayer() and MASK_PLAYERSOLID or MASK_NPCSOLID
	for _, r in ipairs(RINGS) do
		local spokes = r == 0 and 1 or SPOKES
		for s = 1, spokes do
			local a = s / spokes * math.pi * 2
			local at = from + Vector(math.cos(a) * r, math.sin(a) * r, 0)
			if not util.TraceLine({ start = from, endpos = at, mask = MASK_SOLID_BRUSHONLY }).Hit then
				for _, lift in ipairs(LIFTS) do
					local tr = util.TraceHull({
						start = at + Vector(0, 0, lift), endpos = at - Vector(0, 0, DROP),
						mins = mins, maxs = maxs, mask = mask, filter = filter,
					})
					if not tr.StartSolid then return tr.HitPos end
				end
			end
		end
	end
	return home
end

function EvilSnake.Knocked(ent)
	local k = knocked[ent]
	return k and k.rag
end

function EvilSnake.Knock(ent, push, time)
	push = push or vector_origin
	time = time or KNOCK_TIME
	if not IsValid(ent) then return end
	local k = knocked[ent]
	if k then
		k.wake = math.max(k.wake, CurTime() + time)
		if IsValid(k.rag) then Push(k.rag, push) end
		return k.rag
	end
	if not (ent:IsPlayer() or ent:IsNPC()) or ent:Health() <= 0 or ent.EvilSnakeHeld then return end
	if ent:IsPlayer() then
		if not ent:Alive() then return end
		if ent:InVehicle() then ent:ExitVehicle() end
	end
	local model = ent:GetModel()
	if not model or not util.IsValidRagdoll(model) then return end
	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end
	rag:SetModel(model)
	rag:SetPos(ent:GetPos())
	rag:SetAngles(ent:GetAngles())
	Dress(rag, ent)
	rag:Spawn()
	rag:Activate()
	if rag:GetPhysicsObjectCount() == 0 then
		rag:Remove()
		return
	end
	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	Pose(rag, ent, ent:GetVelocity() + push)
	local wep = ent.GetActiveWeapon and ent:GetActiveWeapon()
	k = {
		rag = rag, wake = CurTime() + time, home = ent:GetPos(), last = ent:GetPos(),
		move = ent:GetMoveType(), notarget = ent:IsFlagSet(FL_NOTARGET), weapon = IsValid(wep) and wep or nil,
	}
	knocked[ent] = k
	rag.EvilSnakeOwner = ent
	ent.EvilSnakeKnocked = rag
	Hide(ent, k)
	hook.Run("EvilSnakeKnocked", ent, rag)
	return rag
end

function EvilSnake.Wake(ent)
	local k = knocked[ent]
	if not k then return end
	knocked[ent] = nil
	local rag = k.rag
	if IsValid(ent) then
		ent.EvilSnakeKnocked = nil
		local from = IsValid(rag) and rag:GetPos() or k.last
		Show(ent, k)
		ent:SetMoveType(k.move)
		ent:SetPos(Stand(ent, from, IsValid(rag) and { ent, rag } or ent, k.home))
		if ent:IsPlayer() then ent:SetLocalVelocity(vector_origin) end
	end
	SafeRemoveEntity(rag)
	if IsValid(ent) then hook.Run("EvilSnakeWoke", ent) end
end

local function Corpse(ent)
	local k = knocked[ent]
	if not k then return end
	knocked[ent] = nil
	ent.EvilSnakeKnocked = nil
	if ent:IsPlayer() then
		ent.EvilSnakeRestore = k
	else
		ent:RemoveEFlags(EFL_NO_THINK_FUNCTION)
		if IsValid(k.weapon) then k.weapon:SetNoDraw(false) end
	end
	local rag = k.rag
	if IsValid(rag) then
		rag.EvilSnakeOwner = nil
		rag:Fire("FadeAndRemove", tostring(CORPSE_FADE), CORPSE)
	end
end

local function Still(rag)
	local phys = rag:GetPhysicsObject()
	return not IsValid(phys) or phys:GetVelocity():Length() < REST
end

hook.Add("Think", "EvilSnakeKnock", function()
	local now = CurTime()
	for ent, k in pairs(knocked) do
		if not IsValid(ent) then
			knocked[ent] = nil
			SafeRemoveEntity(k.rag)
		elseif not IsValid(k.rag) then
			EvilSnake.Wake(ent)
		else
			k.last = k.rag:GetPos()
			ent:SetPos(k.last)
			if now >= k.wake and (Still(k.rag) or now >= k.wake + LATE) then EvilSnake.Wake(ent) end
		end
	end
end)

hook.Add("EntityTakeDamage", "EvilSnakeKnock", function(target, dmg)
	local ent = target.EvilSnakeOwner
	if not IsValid(ent) or knocked[ent] == nil then return end
	local attacker, inflictor = dmg:GetAttacker(), dmg:GetInflictor()
	if dmg:IsDamageType(DMG_CRUSH) and (not IsValid(attacker) or attacker:IsWorld() or attacker == target) then return end
	local d = DamageInfo()
	d:SetDamage(dmg:GetDamage())
	d:SetDamageType(dmg:GetDamageType())
	d:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
	d:SetInflictor(IsValid(inflictor) and inflictor or game.GetWorld())
	d:SetDamageForce(dmg:GetDamageForce())
	d:SetDamagePosition(dmg:GetDamagePosition())
	ent:TakeDamageInfo(d)
end)

hook.Add("OnNPCKilled", "EvilSnakeKnock", Corpse)

hook.Add("PostPlayerDeath", "EvilSnakeKnock", function(ply)
	if not knocked[ply] then return end
	Corpse(ply)
	local own = ply:GetRagdollEntity()
	if IsValid(own) then own:Remove() end
end)

hook.Add("PlayerSpawn", "EvilSnakeKnock", function(ply)
	local k = knocked[ply]
	if k then
		knocked[ply] = nil
		ply.EvilSnakeKnocked = nil
		SafeRemoveEntity(k.rag)
	else
		k = ply.EvilSnakeRestore
	end
	ply.EvilSnakeRestore = nil
	if k then Show(ply, k) end
end)

hook.Add("CreateEntityRagdoll", "EvilSnakeKnock", function(owner, rag)
	if IsValid(owner) and owner:GetNW2Bool("EvilSnakeDown") then
		rag:SetNoDraw(true)
		SafeRemoveEntityDelayed(rag, 0)
	end
end)

local function Block(ply)
	if knocked[ply] then return false end
end

hook.Add("PlayerUse", "EvilSnakeKnock", Block)
hook.Add("CanPlayerEnterVehicle", "EvilSnakeKnock", Block)
hook.Add("PlayerCanPickupWeapon", "EvilSnakeKnock", Block)
hook.Add("PlayerCanPickupItem", "EvilSnakeKnock", Block)
