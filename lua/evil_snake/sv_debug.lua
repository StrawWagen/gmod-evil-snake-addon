local function Allowed(ply)
	return not IsValid(ply) or ply:IsSuperAdmin()
end

local function Say(ply, text)
	if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
end

local function Snakes()
	local list = {}
	for _, ent in ipairs(ents.FindByClass("evil_snake")) do
		if ent.Stomach and ent.Mind then list[#list + 1] = ent end
	end
	return list
end

concommand.Add("evil_snake_mind", function(ply)
	if not Allowed(ply) then return end
	for _, ent in ipairs(Snakes()) do
		local st, mind = ent.Stomach, ent.Mind
		local digested = 0
		for _, v in ipairs(st.victims) do
			if v.digested then digested = digested + 1 end
		end
		Say(ply, ("evil_snake %d: %d eaten, %d digested, mass %.2f, %.1f segments, girth %.2f, brainpower %.2f, level %.2f")
			:format(ent:EntIndex(), st:Count(), digested, st:Mass(), ent:GetLength(), ent:GetGirth(), mind.power, mind:Level()))
		local knows = {}
		for _, aspect in ipairs(EvilSnake.ASPECTS) do
			knows[#knows + 1] = ("%s %.2f"):format(aspect, mind:Knows(aspect))
		end
		Say(ply, "  knows: " .. table.concat(knows, ", "))
		local edges = {}
		for name, k in SortedPairs(ent.Sharp or {}) do edges[#edges + 1] = ("%s %.2f"):format(name, k) end
		Say(ply, "  edge: " .. table.concat(edges, ", "))
		local seen = {}
		for kind, n in SortedPairs(mind.seen) do seen[#seen + 1] = kind .. " x" .. n end
		if #seen > 0 then Say(ply, "  ate: " .. table.concat(seen, ", ")) end
	end
end, nil, "Print what every snake on the map has eaten and learned")

concommand.Add("evil_snake_feed", function(ply, _, args)
	if not Allowed(ply) then return end
	local kind = args[1] or "citizen"
	if not EvilSnake.KINDS[kind] then return end
	local count = math.Clamp(math.floor(tonumber(args[2]) or 1), 1, 500)
	for _, ent in ipairs(Snakes()) do
		for _ = 1, count do
			local st = ent.Stomach
			st:Settle(st:Add({ kind = kind, class = "evil_snake_feed", name = kind }))
		end
	end
end, function(cmd)
	local list = {}
	for kind in SortedPairs(EvilSnake.KINDS) do list[#list + 1] = cmd .. " " .. kind end
	return list
end, "Feed every snake on the map someone of a kind, straight to digested: <kind> [count]")
