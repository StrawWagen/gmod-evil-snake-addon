EvilSnake = EvilSnake or {}

local EYE_FLAGS = 65536 + 131072

local function Disposition()
	return EvilSnake.Setting("npcs_fight") > 0 and D_HT or D_NU
end

local function Fights(npc)
	return IsValid(npc) and npc:IsNPC() and npc:GetClass() ~= "npc_bullseye"
end

local function Eyes()
	local eyes = {}
	for _, snake in ipairs(ents.FindByClass("evil_snake")) do
		if IsValid(snake.Eye) then eyes[#eyes + 1] = snake.Eye end
	end
	return eyes
end

local function Meet(ent, eyes)
	local d = Disposition()
	if ent.IsDrGNextbot and ent.SetClassRelationship then ent:SetClassRelationship("evil_snake", d, 2) end
	if not Fights(ent) then return end
	for _, eye in ipairs(eyes) do ent:AddEntityRelationship(eye, d, 0) end
end

function EvilSnake.Expose(snake)
	local eye = ents.Create("npc_bullseye")
	eye:SetPos(snake:GetPos())
	eye:SetParent(snake)
	eye:SetKeyValue("spawnflags", tostring(EYE_FLAGS))
	eye:Spawn()
	eye:Activate()
	snake:DeleteOnRemove(eye)
	snake.Eye = eye
	snake:AddFlags(FL_OBJECT)
	snake.DrGBase_Target = true
	snake.VJ_ID_Destructible = true
	local d = Disposition()
	for _, npc in ipairs(ents.GetAll()) do
		if Fights(npc) then npc:AddEntityRelationship(eye, d, 0) end
		if npc.IsDrGNextbot and npc.SetClassRelationship then npc:SetClassRelationship("evil_snake", d, 2) end
	end
end

function EvilSnake.Unexpose(snake)
	SafeRemoveEntity(snake.Eye)
	snake.Eye = nil
end

hook.Add("OnEntityCreated", "EvilSnakeEnemy", function(ent)
	if not (ent:IsNPC() or ent:IsNextBot()) then return end
	timer.Simple(0, function()
		if IsValid(ent) then Meet(ent, Eyes()) end
	end)
end)

cvars.AddChangeCallback("evil_snake_npcs_fight", function()
	local eyes = Eyes()
	for _, ent in ipairs(ents.GetAll()) do Meet(ent, eyes) end
end, "EvilSnakeEnemy")
