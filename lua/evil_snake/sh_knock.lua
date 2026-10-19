local function Down(ply)
	return ply:GetNW2Bool("EvilSnakeDown") and ply:Alive()
end

hook.Add("StartCommand", "EvilSnakeKnock", function(ply, cmd)
	if Down(ply) then
		cmd:ClearButtons()
		cmd:ClearMovement()
	end
end)

hook.Add("PlayerNoClip", "EvilSnakeKnock", function(ply)
	if Down(ply) then return false end
end)

hook.Add("PlayerSwitchWeapon", "EvilSnakeKnock", function(ply)
	if Down(ply) then return true end
end)
