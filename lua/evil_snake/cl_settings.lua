local SEND_DELAY = 0.25
local SETTLE = 1

local function Send(s, value)
	s.pending = RealTime() + SEND_DELAY + SETTLE
	timer.Create("EvilSnakeSetting_" .. s.name, SEND_DELAY, 1, function()
		if math.abs(GetConVar(s.convar):GetFloat() - value) < 1e-3 then return end
		net.Start("EvilSnakeSetting")
		net.WriteString(s.convar)
		net.WriteString(tostring(value))
		net.SendToServer()
	end)
end

local function Settled(s)
	return RealTime() > (s.pending or 0)
end

local function Admin(control)
	local ply = LocalPlayer()
	local admin = IsValid(ply) and ply:IsSuperAdmin()
	if control:IsEnabled() ~= admin then control:SetEnabled(admin) end
end

local function Build(panel)
	for _, s in ipairs(EvilSnake.SETTINGS) do
		local cv = GetConVar(s.convar)
		local control
		if s.max == 1 and not s.decimals then
			control = panel:CheckBox(s.label)
			control:SetChecked(cv:GetBool())
			control.OnChange = function(_, on) Send(s, on and 1 or 0) end
			control.Think = function(self)
				Admin(self)
				if Settled(s) and self:GetChecked() ~= cv:GetBool() then self:SetChecked(cv:GetBool()) end
			end
		else
			control = panel:NumSlider(s.label, nil, s.min, s.max, s.decimals)
			control:SetValue(cv:GetFloat())
			control.OnValueChanged = function(_, value) Send(s, value) end
			control.Think = function(self)
				Admin(self)
				if Settled(s) and not self:IsEditing() and math.abs(self:GetValue() - cv:GetFloat()) > 1e-3 then self:SetValue(cv:GetFloat()) end
			end
		end
		control:SetTooltip(s.help)
	end
	local reset = panel:Button("Reset to defaults")
	reset.DoClick = function()
		for _, s in ipairs(EvilSnake.SETTINGS) do Send(s, s.default) end
	end
	reset.Think = Admin
end

hook.Add("PopulateToolMenu", "EvilSnakeSettings", function()
	spawnmenu.AddToolMenuOption("Utilities", "Syhgma's Evil Entities", "evil_snake_settings", "Evil snake", "", "", Build)
end)
