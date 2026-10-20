EvilSnake = EvilSnake or {}
local Path = {}
EvilSnake.Path = Path

local SEARCH = 800
local NEAR = 400
local INSET = 0.3

local function Area(pos)
	return navmesh.GetNearestNavArea(pos, false, NEAR, true, true)
end

local function Push(heap, entry)
	local n = #heap + 1
	heap[n] = entry
	while n > 1 do
		local up = math.floor(n / 2)
		if heap[up][1] <= heap[n][1] then break end
		heap[up], heap[n] = heap[n], heap[up]
		n = up
	end
end

local function Pop(heap)
	local top = heap[1]
	local last = table.remove(heap)
	local n = #heap
	if n == 0 then return top end
	heap[1] = last
	local i = 1
	while true do
		local l, r, m = i * 2, i * 2 + 1, i
		if l <= n and heap[l][1] < heap[m][1] then m = l end
		if r <= n and heap[r][1] < heap[m][1] then m = r end
		if m == i then break end
		heap[i], heap[m] = heap[m], heap[i]
		i = m
	end
	return top
end

function Path.Find(from, to, rise)
	if not navmesh.IsLoaded() then return end
	local start, goal = Area(from), Area(to)
	if not start or not goal then return end
	local goalId, goalAt = goal:GetID(), goal:GetCenter()
	local id = start:GetID()
	local areas, g, came, closed = { [id] = start }, { [id] = 0 }, {}, {}
	local heap = { { start:GetCenter():Distance(goalAt), id } }
	local found, expanded = id == goalId, 0
	while not found and #heap > 0 and expanded < SEARCH do
		local cur = Pop(heap)[2]
		if not closed[cur] then
			closed[cur] = true
			expanded = expanded + 1
			if cur == goalId then
				found = true
				break
			end
			local area = areas[cur]
			local at = area:GetCenter()
			for _, nb in ipairs(area:GetAdjacentAreas()) do
				local nid = nb:GetID()
				if not closed[nid] and area:ComputeAdjacentConnectionHeightChange(nb) <= rise then
					local center = nb:GetCenter()
					local cost = g[cur] + at:Distance(center)
					if not g[nid] or cost < g[nid] then
						areas[nid], g[nid], came[nid] = nb, cost, cur
						Push(heap, { cost + center:Distance(goalAt), nid })
					end
				end
			end
		end
	end
	if not found then return end
	local chain = {}
	local k = goalId
	while k do
		chain[#chain + 1] = areas[k]
		k = came[k]
	end
	local pts, last = {}, from
	for i = #chain - 1, 1, -1 do
		local area = chain[i]
		last = LerpVector(INSET, area:GetClosestPointOnArea(last), area:GetCenter())
		pts[#pts + 1] = last
	end
	pts[#pts + 1] = to
	return pts
end
