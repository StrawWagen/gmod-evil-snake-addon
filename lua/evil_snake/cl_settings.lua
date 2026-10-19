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

local function Pack(c)
	return math.Round(c.r) * 65536 + math.Round(c.g) * 256 + math.Round(c.b)
end

local function Current()
	return Color(EvilSnake.Color())
end

local function Admin(control)
	local ply = LocalPlayer()
	local admin = IsValid(ply) and ply:IsSuperAdmin()
	if control:IsEnabled() ~= admin then control:SetEnabled(admin) end
end

local function Presets(panel)
	local row = vgui.Create("DPanel")
	row:SetPaintBackground(false)
	row:SetTall(24)
	panel:AddItem(row)
	local buttons = {}
	for _, preset in ipairs(EvilSnake.PRESETS) do
		local b = vgui.Create("DButton", row)
		b:SetText(preset.label)
		b.DoClick = function()
			for _, s in ipairs(EvilSnake.SETTINGS) do
				if preset.values[s.name] then
					s.pending = nil
					timer.Remove("EvilSnakeSetting_" .. s.name)
				end
			end
			RunConsoleCommand("evil_snake_preset", preset.name)
		end
		b.Think = function(self)
			Admin(self)
			local on = EvilSnake.PresetActive(preset)
			if self:GetToggle() ~= on then self:SetToggle(on) end
		end
		buttons[#buttons + 1] = b
	end
	row.PerformLayout = function(self, w, h)
		local gap = 4
		local bw = (w - gap * (#buttons - 1)) / #buttons
		for i, b in ipairs(buttons) do
			b:SetPos(math.Round((i - 1) * (bw + gap)), 0)
			b:SetSize(math.Round(bw), h)
		end
	end
end

local function Build(panel)
	Presets(panel)
	for _, s in ipairs(EvilSnake.SETTINGS) do
		local cv = GetConVar(s.convar)
		local control
		if s.color then
			panel:Help(s.label)
			control = vgui.Create("DColorMixer")
			control:SetAlphaBar(false)
			control:SetTall(180)
			panel:AddItem(control)
			control:SetColor(Current())
			control.ValueChanged = function(_, c) Send(s, Pack(c)) end
			control.Think = function(self)
				local ply = LocalPlayer()
				self:SetMouseInputEnabled(IsValid(ply) and ply:IsSuperAdmin())
				if Settled(s) and Pack(self:GetColor()) ~= cv:GetInt() then self:SetColor(Current()) end
			end
		elseif s.max == 1 and not s.decimals then
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
		if s.help then control:SetTooltip(s.help) end
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
