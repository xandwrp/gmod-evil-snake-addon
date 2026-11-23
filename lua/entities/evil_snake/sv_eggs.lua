-- Laying, the same way the crawler does it. A snake that has finished digesting someone carries
-- one egg until it finds somewhere secluded to plant it: a spot nobody is looking at, closed in
-- around it, ideally a corner under a roof, and hidden from the open map and the walkways near it.
-- While it has nothing to hunt it crawls to such a place instead of wandering, and lays on the way
-- if it passes one. Laying uses the meal up, so it has to digest someone else before it lays again.

local Setting = EvilSnake.Setting

-- Eggs already in the world count against the cap too, so a pile of eggs cannot
-- keep growing while hatching waits for room.
local function Eggs()
	local n = 0
	for _, egg in ipairs(ents.FindByClass("evil_snake_egg")) do
		if IsValid(egg) and not egg.Broken and not egg.Hatched then n = n + 1 end
	end
	return n
end

local EGG_THICK = 48     -- how thick the egg is; keep in step with ENT.EGG_THICK in evil_snake_egg/shared.lua
-- Half its reach across the surface. The scaled melon is nearly round (about 46 by 54), so both
-- axes are checked at the longer one rather than trusting which way the model's long side points.
local EGG_LONG = 27
local EGG_WIDE = 27
-- How far the egg's centre sits off the face it rests on: the scaled melon's half-height (23.49),
-- plus a hair so it does not start inside the brush. Walls and ceilings sink it in a little instead,
-- so a glued egg looks stuck on rather than hovering next to the surface.
local EGG_REST = 23.8
local EGG_SINK = 2.25
local WALL_GAP = 0.5     -- how close it snugs up to a neighbouring wall
local SUPPORT_REACH = 10 -- how far under its rim the surface may drop away before it counts as overhanging
local FIT_TRIES = 12     -- turns tried to find one where the egg does not stick into a wall
local EGG_REACH = 56     -- how far from the body it looks for a surface
local EGG_SCAN = 1.5     -- seconds between checks while it walks
local EGG_LAY_RANGE = 80 -- how close it has to get to the chosen nest to plant

local NEST_MIN = 160     -- closest nest it looks for
local NEST_RANGE = 1600  -- furthest nest it looks for
local NEST_TRIES = 16    -- surfaces tried per search
local NEST_GAP = 1.5     -- seconds between searches
local NEST_HOLD = 25     -- seconds it walks at one nest before giving up on it

-- What the verdict is measured against. Printed by the debug overlay so the numbers mean something.
-- Hard requirements: room for the egg in front of the face, at least one wall meeting the face (an
-- edge between two planes; a full corner is better but not needed), a turn of the egg that lies flat
-- on solid surface without poking into a wall, and nobody looking at the spot right now. Past those
-- it has to be secluded enough: tucked in, roofed over, and out of sight of the open map.
local EGG_OPEN = EGG_THICK -- clear space in front of the face, in units (as thick as the egg)
local OPEN_REACH = EGG_OPEN + 24
local EGG_ROOF = 160       -- a roof this close counts as cover
local ROOF_REACH = EGG_ROOF + 40

local SHELL_RAYS = 20      -- rays fanned over the half-sphere in front of the face
local SHELL_NEAR = 192     -- a ray that hits within this counts as shelter
local SHELL_FAR = 1024     -- a ray that runs this far without hitting is a view out into the open
local CORNER_REACH = 112   -- side walls this close count toward a corner
local VIEW_RANGE = 1200    -- watchers and walkways further than this do not count
local VIEW_SAMPLES = 16    -- nav areas tested for a line of sight to the spot
local SECLUDED = 0.25      -- seclusion it needs, 0 (open floor) to 1 (sealed pocket)
local EDGE_SCORE = 0.8     -- what one wall (an edge) is worth against a full two-wall corner

-- How the shelter score is put together; they add up to 1.
local W_SHELL, W_CLOSE, W_CORNER, W_ROOF = 0.35, 0.15, 0.3, 0.2
local EXPOSED = 0.3        -- how much a fully exposed spot loses off its shelter score

-- The fan of shell rays in the face's own frame (z out of the face), spread evenly with a
-- golden-angle spiral and kept off the grazing edge where they would just skim the surface.
local SHELL = {}
do
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, SHELL_RAYS - 1 do
		local z = 0.08 + 0.92 * (i + 0.5) / SHELL_RAYS
		local r = math.sqrt(1 - z * z)
		local a = golden * i
		SHELL[#SHELL + 1] = { math.cos(a) * r, math.sin(a) * r, z }
	end
end

local DIRS = {
	Vector(0, 0, -1), Vector(0, 0, 1),
	Vector(1, 0, 0), Vector(-1, 0, 0),
	Vector(0, 1, 0), Vector(0, -1, 0),
}

local PASS_COLOR = Color(0, 255, 140)
local FAIL_COLOR = Color(255, 90, 90)
local NEST_COLOR = Color(0, 220, 255)

-- evil_snake_debug_eggs turns on the checks and their world drawings.
local cv_debug = CreateConVar("evil_snake_debug_eggs", "0", 0, "Reports every egg-laying check with its numbers and thresholds. The world drawings need developer 1 on the client")

-- Only the convar, so a server running with developer 1 does not fill the console with egg checks.
local function Debug()
	return cv_debug:GetBool()
end

local function Say(ent, msg)
	MsgN(string.format("[egg #%d] %s", ent:EntIndex(), msg))
end

local function Brush(from, to)
	return util.TraceLine({ start = from, endpos = to, mask = MASK_SOLID_BRUSHONLY })
end

-- Two directions lying in the face, square to each other and to the normal.
local function Frame(normal)
	local side = normal:Cross(Vector(0, 0, 1))
	if side:LengthSqr() < 1e-4 then side = normal:Cross(Vector(1, 0, 0)) end
	side:Normalize()
	return side, normal:Cross(side)
end

-- A turn of the egg lying flat on the face whose long and short axes all stay out of the brushes.
-- Returns the angle it would be planted at, or nil when every turn tried pokes into something.
local function FitAngle(at, normal)
	local along = Frame(normal)
	local center = at
	local turn = math.Rand(0, 360)
	for i = 1, FIT_TRIES do
		local ang = along:AngleEx(normal)
		ang:RotateAroundAxis(normal, turn + (i - 1) * (180 / FIT_TRIES))
		local fwd, right = ang:Forward(), ang:Right()
		local clear = true
		for _, d in ipairs({ fwd * EGG_LONG, -fwd * EGG_LONG, right * EGG_WIDE, -right * EGG_WIDE }) do
			local tr = Brush(center, center + d)
			if tr.Hit or tr.StartSolid then clear = false break end
			-- Solid surface under the rim too, so it is not hanging half off a ledge.
			local rim = center + d * 0.6
			local under = Brush(rim, rim - normal * (EGG_REST + SUPPORT_REACH))
			if not under.Hit or under.StartSolid then clear = false break end
		end
		if clear then return ang end
	end
end

-- Whether any living player has a clear line to the spot from close enough to notice it.
local function Watched(spot)
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() then
			local eye = ply:EyePos()
			if eye:DistToSqr(spot) < VIEW_RANGE * VIEW_RANGE and not Brush(eye, spot).Hit then return true end
		end
	end
	return false
end

-- The share of the walkable places around the spot that can see it, from standing eye height.
-- Nil when the map has no navmesh; the open view out of the shell stands in for it then.
local function Walkways(spot)
	if not navmesh.IsLoaded() then return nil end
	local areas = navmesh.Find(spot, VIEW_RANGE, VIEW_RANGE, VIEW_RANGE)
	if #areas == 0 then return nil end
	local seen, tried = 0, math.min(VIEW_SAMPLES, #areas)
	for _ = 1, tried do
		local area = table.remove(areas, math.random(#areas))
		if not Brush(area:GetCenter() + Vector(0, 0, 56), spot).Hit then seen = seen + 1 end
	end
	return seen / tried
end

-- Every number a verdict is made of, cheapest first. Once a hard requirement fails the rest is left
-- unmeasured (nil), so a long search does not pay for spots that could never pass. All the probes
-- are brush-only: props, npcs and players standing about neither block a spot nor count as cover.
local function Measure(at, normal)
	local r = { normal = normal, rays = {} }
	local from = at + normal * 2

	local front = Brush(from, from + normal * OPEN_REACH)
	r.open = front.StartSolid and 0 or front.Fraction * OPEN_REACH
	r.clear = r.open >= EGG_OPEN
	r.at = at
	if not r.clear then return r end

	-- Walls round the face. Slide the egg along the face until it sits snug against the nearest wall on
	-- each axis, so it nestles into the edge (or corner) instead of sitting wherever the probe landed.
	local side, other = Frame(normal)
	local dirs = { side, other, -side, -other }
	local dist = {}
	for i, dir in ipairs(dirs) do
		local tr = Brush(from, from + dir * CORNER_REACH)
		dist[i] = (tr.Hit and not tr.HitSky and not tr.StartSolid) and tr.Fraction * CORNER_REACH or nil
	end
	local snug = at
	for axis = 1, 2 do
		local a, b = dist[axis], dist[axis + 2]
		local i = (a and (not b or a <= b)) and axis or (b and axis + 2) or nil
		if i then
			local shift = dist[i] - EGG_LONG - WALL_GAP
			if shift > 0 then snug = snug + dirs[i] * shift end
		end
	end
	-- Walls and ceilings: sink it in a little so it reads as stuck on.
	if normal.z < 0.7 then snug = snug - normal * EGG_SINK end
	r.at = snug
	from = snug + normal * 2

	local walls = (dist[1] and 1 or 0) + (dist[2] and 1 or 0) + (dist[3] and 1 or 0) + (dist[4] and 1 or 0)
	local corner = (dist[1] or dist[3]) and (dist[2] or dist[4])
	r.walls = walls
	r.edge = walls > 0
	r.corner = corner and 1 or r.edge and EDGE_SCORE or 0
	if not r.edge then return r end

	r.fit = FitAngle(snug, normal)
	r.fits = r.fit ~= nil
	if not r.fits then return r end

	r.unseen = not Watched(from)
	if not r.unseen then return r end

	-- The shell: how much of the view out of the face is closed off, and how near.
	local near, far, sum = 0, 0, 0
	for _, d in ipairs(SHELL) do
		local dir = side * d[1] + other * d[2] + normal * d[3]
		local tr = Brush(from, from + dir * SHELL_FAR)
		local dist = tr.StartSolid and 0 or tr.Fraction * SHELL_FAR
		if not tr.Hit or tr.HitSky then
			far = far + 1
			dist = SHELL_FAR
		elseif dist <= SHELL_NEAR then
			near = near + 1
			r.rays[#r.rays + 1] = tr.HitPos
		end
		sum = sum + dist
	end
	r.shell = near / #SHELL
	r.close = 1 - sum / #SHELL / SHELL_FAR
	r.openview = far / #SHELL

	local roof = Brush(from, from + Vector(0, 0, ROOF_REACH))
	r.roof = (roof.Hit and not roof.HitSky and not roof.StartSolid) and roof.Fraction * ROOF_REACH or -1
	r.covered = r.roof >= 0 and r.roof <= EGG_ROOF

	r.shelter = W_SHELL * r.shell + W_CLOSE * r.close + W_CORNER * r.corner + W_ROOF * (r.covered and 1 or 0)

	-- Exposure: how much of the map can see it. Only worth the nav traces if it could still pass.
	r.exposure = r.openview
	if r.shelter * (1 - EXPOSED * r.exposure) >= SECLUDED then
		r.walkways = Walkways(from)
		if r.walkways then r.exposure = math.max(r.openview, r.walkways) end
	end
	r.seclusion = r.shelter * (1 - EXPOSED * r.exposure)
	r.secluded = r.seclusion >= SECLUDED
	return r
end

-- Whether the spot passes, and a score to rank failures by: seclusion when it got that far,
-- below zero when a hard requirement stopped it first.
local function Verdict(r)
	r.ok = (r.clear and r.edge and r.fits and r.unseen and r.secluded) and true or false
	r.score = r.seclusion or (r.unseen == false and -0.5 or -1)
	return r.ok
end

-- Why it failed, in the order the conditions are checked.
local function Why(r)
	local out = {}
	if not r.clear then out[#out + 1] = "open" end
	if r.edge == false then out[#out + 1] = "edge" end
	if r.fits == false then out[#out + 1] = "fit" end
	if r.unseen == false then out[#out + 1] = "watched" end
	if r.seclusion and not r.secluded then out[#out + 1] = "exposed" end
	return #out > 0 and table.concat(out, ",") or "none"
end

local function Num(v, fmt)
	if v == nil then return "-" end
	return string.format(fmt or "%.2f", v)
end

-- Long form for the console, with every number next to the number it has to beat.
local function Report(ent, r, dist)
	local ok = Verdict(r)
	Say(ent, string.format(
		"probe d=%d open=%d (need >=%d) walls=%s/4 fit=%s watched=%s | shell=%s close=%s corner=%s (walls %s/4) roof=%s"
			.. " shelter=%s | openview=%s walkways=%s -> seclusion=%s (need >=%.2f) -> %s%s",
		math.floor(dist or 0),
		math.floor(r.open), EGG_OPEN,
		Num(r.walls, "%d"),
		r.fits == nil and "-" or (r.fits and "yes" or "no"),
		r.unseen == nil and "-" or (r.unseen and "no" or "YES"),
		Num(r.shell), Num(r.close), Num(r.corner), Num(r.walls, "%d"),
		r.roof and (r.roof >= 0 and string.format("%d", math.floor(r.roof)) or "none") or "-",
		Num(r.shelter), Num(r.openview), Num(r.walkways), Num(r.seclusion), SECLUDED,
		ok and "PASS" or "FAIL", ok and "" or " on " .. Why(r)
	))
end

-- Short form for the world overlay: the same numbers, colour says pass or fail.
local function Tag(r, dist)
	return string.format("d%d sec%s/%.2f shell%s corner%s exp%s",
		math.floor(dist or 0), Num(r.seclusion), SECLUDED, Num(r.shell), Num(r.corner), Num(r.exposure))
end

local function DrawProbe(r, tag)
	Verdict(r)
	local life = NEST_GAP + 0.5
	local col = r.ok and PASS_COLOR or FAIL_COLOR
	debugoverlay.Box(r.at, -Vector(1, 1, 1), Vector(1, 1, 1), life, col)
	debugoverlay.Line(r.at, r.at + r.normal * 8, life, col, true)
	for _, hp in ipairs(r.rays) do debugoverlay.Line(r.at, hp, life, col, true) end
	debugoverlay.Text(r.at + Vector(0, 0, 6), tag .. " " .. Tag(r) .. (r.ok and "" or " [" .. Why(r) .. "]"), life, true)
end

-- The thresholds themselves, so the numbers on the probes can be read without the source.
function ENT:EggLegend(at, normal)
	if not Debug() then return end
	debugoverlay.Line(at, at + normal * 8, 3, NEST_COLOR, true)
	debugoverlay.Text(at, string.format("EGG needs: open>=%d, a wall beside it (edge), room to lie flat on solid ground, unwatched, seclusion>=%.2f",
		EGG_OPEN, SECLUDED), 3, true)
end

-- Everything a chosen point has to pass, wherever it was found. Measured again on arrival, because
-- someone may have walked into view of it since it was picked.
function ENT:EggPlantable(at, normal)
	local r = Measure(at, normal)
	if Debug() then Report(self, r, self.Chain.x[1]:Distance(at)) end
	return Verdict(r), r
end

-- A face of the world right by the head that is secluded enough for an egg.
function ENT:EggSpot()
	local pos = self.Chain.x[1]
	local bestR
	for _, dir in ipairs(DIRS) do
		local tr = util.TraceLine({ start = pos, endpos = pos + dir * EGG_REACH, mask = MASK_SOLID_BRUSHONLY })
		if tr.Hit and tr.HitWorld and not tr.StartSolid and not tr.HitSky then
			local normal = tr.HitNormal
			local at = tr.HitPos + normal * EGG_REST
			local r = Measure(at, normal)
			if Verdict(r) then
				if Debug() then Report(self, r, pos:Distance(at)); DrawProbe(r, "walk-by PASS") end
				return r.at, normal
			end
			if Debug() then Report(self, r, pos:Distance(at)); DrawProbe(r, "walk-by") end
			if not bestR or r.score > bestR.score then bestR = r end
		end
	end
	if Debug() then self:EggLegend(pos + self.Chain.up * 30, self.Chain.up) end
	return nil, nil, bestR
end

-- A secluded face out in the map, in sight of the head so there is somewhere to crawl to. This is
-- the difference between hunting for a nest and happening to crawl past one.
function ENT:EggNest()
	local from = self.Chain.x[1] + self.Chain.up * 8
	local bestR, faces = nil, 0
	for _ = 1, NEST_TRIES do
		local dir = VectorRand():GetNormalized()
		dir.z = dir.z * 0.7
		local dist = math.Rand(NEST_MIN, NEST_RANGE)
		local tr = util.TraceLine({
			start = from,
			endpos = from + dir:GetNormalized() * dist,
			mask = MASK_SOLID_BRUSHONLY,
		})
		if tr.Hit and tr.HitWorld and not tr.StartSolid and not tr.HitSky then
			faces = faces + 1
			local normal = tr.HitNormal
			local at = tr.HitPos + normal * EGG_REST
			local look = util.TraceLine({ start = from, endpos = at + normal * 3, mask = MASK_SOLID_BRUSHONLY })
			if not look.Hit then
				local r = Measure(at, normal)
				if Verdict(r) then
					if Debug() then Report(self, r, from:Distance(at)); DrawProbe(r, "nest PASS") end
					return r.at, normal
				end
				if Debug() then Report(self, r, from:Distance(at)); DrawProbe(r, "nest") end
				if not bestR or r.score > bestR.score then bestR = r end
			end
		end
	end
	if Debug() then
		Say(self, string.format("search: %d probes, %d world faces, best %.2f%s",
			NEST_TRIES, faces, bestR and bestR.score or 0,
			bestR and (" (" .. Tag(bestR, 0) .. ")") or ""))
		if bestR then DrawProbe(bestR, "best") end
		self:EggLegend(from, self.Chain.up)
	end
	-- Nothing passed: no nest. The best failure is only handed back for the debug report, never crawled to.
	return nil, nil, bestR
end

function ENT:LayAt(at, normal)
	if Setting("eggs") <= 0 then return false end
	local cap = Setting("egg_cap")
	if cap > 0 and EvilSnake.Population() + Eggs() >= cap then return false end
	local ok, r = self:EggPlantable(at, normal)
	if not ok then
		if Debug() then Say(self, "refused at the last check") end
		return false
	end
	local egg = ents.Create("evil_snake_egg")
	if not IsValid(egg) then return false end
	-- Resting on the face, slid snug against its wall, at the turn the fit check found.
	egg:SetPos(r.at)
	egg:SetAngles(r.fit)
	egg.SpawnNormal = normal
	egg.Layer = self
	egg:Spawn()
	-- The laying snake's creator, not its engine owner. SetOwner writes m_hOwnerEntity, the field that
	-- cost a placed egg its collisions; SetCreator is all undo and cleanup ever needed.
	local maker = self:GetCreator()
	if IsValid(maker) then egg:SetCreator(maker) end
	egg:Activate()
	self.EggReady = false
	self.EggGoal = nil
	self.NestMiss = 0
	self:EmitSound("physics/flesh/flesh_squishy_impact_hard3.wav", 65, math.Rand(90, 105))
	if Debug() then Say(self, "egg planted") end
	return true
end

-- Called from Decide when it has nothing to hunt. While it carries an egg: lay it at a secluded spot
-- the head passes, else crawl at a nest it already chose, or pick a new one every so often. Returns
-- true when it is driving at a nest, so Decide leaves the wandering alone for this thought.
function ENT:EggSeek(now, c, head)
	if Setting("eggs") <= 0 or Setting("wander") == 0 then
		self.EggGoal = nil
		return false
	end
	if not self.EggReady then
		self.EggGoal = nil
		return false
	end

	if now >= (self.NextEgg or 0) then
		self.NextEgg = now + EGG_SCAN
		local at, normal = self:EggSpot()
		if at and self:LayAt(at, normal) then return false end
	end

	local goal = self.EggGoal
	if goal then
		local d = head:Distance(goal.pos)
		if d < EGG_LAY_RANGE then
			if Debug() then Say(self, string.format("arrived at nest d=%d, planting", math.floor(d))) end
			self:LayAt(goal.pos, goal.normal)
			self.EggGoal = nil
			return false
		elseif now > goal.expires then
			if Debug() then Say(self, string.format("giving up on nest after %ds at d=%d", NEST_HOLD, math.floor(d))) end
			self.EggGoal = nil
		end
	end

	if not self.EggGoal then
		if now < (self.NextNest or 0) then return false end
		-- A map with nowhere secluded to lay would otherwise search every NEST_GAP
		-- forever; back further off each time a search comes up empty.
		local misses = self.NestMiss or 0
		self.NextNest = now + math.min(NEST_GAP * 2 ^ math.min(misses, 4), 24)
		local at, normal = self:EggNest()
		if not at then
			self.NestMiss = misses + 1
			return false
		end
		self.NestMiss = 0
		self.EggGoal = { pos = at, normal = normal, expires = now + NEST_HOLD }
		if Debug() then
			local d = head:Distance(at)
			Say(self, string.format("nest chosen d=%d, crawling to it", math.floor(d)))
			debugoverlay.Line(head, at, NEST_GAP + 0.5, NEST_COLOR, true)
			debugoverlay.Text(head + c.up * 40, string.format("EGG -> nest d=%d", math.floor(d)), NEST_GAP + 0.5, true)
		end
	end

	-- Crawl at it like at prey, climbing when it is up a wall and dropping when it is below.
	local aim = self.EggGoal.pos
	local to = aim - head
	local r = self:Radius()
	if to.z > r then c.climb = 1 elseif to.z < -r then c.climb = -1 end
	EvilSnake.Chain.Drive(c, math.deg(math.atan2(to.y, to.x)), Setting("wander_speed") * self.Sharp.speed, aim)
	return true
end
