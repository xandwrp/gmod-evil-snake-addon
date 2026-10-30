include("shared.lua")
if not EvilSnake then return end

language.Add("evil_snake", "Evil snake")
killicon.Add("evil_snake", "killicons/evil_snake.png", Color(170, 210, 80))

local ASK = 1
local SLITHER = {
	{ key = "SmoothSlither", path = "physics/body/body_medium_scrape_smooth_loop1.wav", light = 1, heavy = 0.3, pitch = 1 },
	{ key = "RoughSlither", path = "physics/flesh/flesh_scrape_rough_loop.wav", light = 0.25, heavy = 1, pitch = 0.9 },
}
local SLITHER_FULL = 220
local SLITHER_FADE = 0.15
local SLITHER_GAP = 0.1
local SLITHER_REST = 1
local SLITHER_LEVEL = 75
local HEAVIEST = 8
local DELAY = EvilSnake.SEND * 2
local GAP = EvilSnake.SEND * 3
local KEEP = 8
local DRIFT = 0.05
local FIT = 0.75
local SHUT = { 0.9, 1.15 }
local DEAD_DIM = 0.55
local PACK = EvilSnake.PACK

local min = math.min

net.Receive("EvilSnakeBody", function()
	local ent = net.ReadEntity()
	local t = net.ReadDouble()
	local pts, meals = {}, {}
	local n = net.ReadUInt(8)
	if n > 0 then
		local x, y, z = net.ReadFloat(), net.ReadFloat(), net.ReadFloat()
		pts[1] = Vector(x, y, z)
		local bits = net.ReadUInt(5)
		for i = 2, n do
			x, y, z = x + net.ReadInt(bits) / PACK, y + net.ReadInt(bits) / PACK, z + net.ReadInt(bits) / PACK
			pts[i] = Vector(x, y, z)
		end
	end
	local up = net.ReadNormal()
	for i = 1, net.ReadUInt(6) do meals[i] = { at = net.ReadFloat(), size = net.ReadFloat(), ply = net.ReadEntity() } end
	local held
	if net.ReadBool() then
		held = { ent = net.ReadEntity(), at = net.ReadDouble(), hold = net.ReadFloat(), pace = net.ReadFloat(), size = net.ReadFloat() }
	end
	local tongue = { state = net.ReadUInt(2) }
	if tongue.state ~= EvilSnake.TONGUE_IN then
		tongue.tip = net.ReadVector()
		tongue.ent = net.ReadEntity()
	end
	if IsValid(ent) and ent.Snapshot then ent:Snapshot(t, pts, meals, held, tongue, up) end
end)

function ENT:Initialize()
	self:DrawShadow(false)
	self.Body = EvilSnake.Body.New()
	self.Tongue = EvilSnake.Tongue.New()
	self.Bulges = {}
	self.Snaps = self.Snaps or {}
end

function ENT:Snapshot(t, pts, meals, held, tongue, up)
	local snaps = self.Snaps or {}
	self.Snaps = snaps
	local d, off = UnPredictedCurTime() - t, self.Offset
	self.Offset = (not off or d < off or d - off > GAP) and d or off + (d - off) * DRIFT
	local last = snaps[#snaps]
	if last then
		if t <= last.t then return end
		if t - last.t > GAP then
			snaps[#snaps + 1] = {
				t = t - EvilSnake.SEND, pts = last.pts, meals = last.meals, fed = last.fed, held = last.held, tongue = last.tongue,
				up = last.up,
			}
		end
	end
	snaps[#snaps + 1] = { t = t, pts = pts, meals = meals, fed = t, held = held, tongue = tongue, up = up }
	while #snaps > KEEP do table.remove(snaps, 1) end
end

function ENT:EvilPose(victim)
	local pose = self.Pose
	if not pose then return end
	local head, neck = EvilSnake.HeadPoints(pose[1], pose[2], self:Radius(), self.Up)
	local height = victim:OBBMaxs().z
	local depth = height * (self.HeldDepth or 0)
	local pos, ang, f, mouth = EvilSnake.HeldPlace(head, neck, depth, self.Up, height)
	local roll, tilt, lunge = EvilSnake.Thrash(victim)
	if roll then
		ang:RotateAroundAxis(ang:Forward(), roll)
		ang:RotateAroundAxis(ang:Right(), tilt)
		pos = mouth - ang:Up() * (height - depth + lunge)
	end
	return pos, ang, f, f:Dot(mouth)
end

local function Fit(ent, r)
	if not IsValid(ent) then return r end
	local lo, hi = ent:OBBMins(), ent:OBBMaxs()
	return math.max(hi.x - lo.x, hi.y - lo.y) * 0.5 * FIT
end

local function Sample(snaps, rt, pose)
	local n = #snaps
	if rt <= snaps[1].t then return snaps[1].pts, snaps[1], snaps[1], 0 end
	if rt >= snaps[n].t then return snaps[n].pts, snaps[n], snaps[n], 0 end
	local k = n - 1
	while snaps[k].t > rt do k = k - 1 end
	local a, b = snaps[k], snaps[k + 1]
	local p, q = snaps[k - 1] or a, snaps[k + 2] or b
	local h = b.t - a.t
	local u = (rt - a.t) / h
	local u2, u3 = u * u, u * u * u
	local h00, h01 = 2 * u3 - 3 * u2 + 1, 3 * u2 - 2 * u3
	local h10, h11 = (u3 - 2 * u2 + u) * h / (b.t - p.t), (u3 - u2) * h / (q.t - a.t)
	local A, B, P, Q = a.pts, b.pts, p.pts, q.pts
	local na, nb, np, nq = #A, #B, #P, #Q
	for i = 1, nb do
		local ax, ay, az = A[min(i, na)]:Unpack()
		local bx, by, bz = B[i]:Unpack()
		local px, py, pz = P[min(i, np)]:Unpack()
		local qx, qy, qz = Q[min(i, nq)]:Unpack()
		local v = pose[i]
		if not v then
			v = Vector()
			pose[i] = v
		end
		v:SetUnpacked(
			ax * h00 + bx * h01 + (bx - px) * h10 + (qx - ax) * h11,
			ay * h00 + by * h01 + (by - py) * h10 + (qy - ay) * h11,
			az * h00 + bz * h01 + (bz - pz) * h10 + (qz - az) * h11)
	end
	for i = #pose, nb + 1, -1 do pose[i] = nil end
	return pose, a, b, u
end

local function Blob(pose, at)
	local n = #pose
	local i = math.min(math.floor(at) + 1, n - 1)
	return EvilSnake.CatmullRom(pose[math.max(i - 1, 1)], pose[i], pose[i + 1], pose[min(i + 2, n)], at - (i - 1))
end

function ENT:Slither(now)
	if now < (self.NextSlither or 0) then return end
	self.NextSlither = now + SLITHER_GAP
	local pace = math.Clamp(self:GetSlide() / SLITHER_FULL, 0, 1)
	local mass = math.max(self:Weight(), 1e-3)
	local heavy = math.Clamp(math.log(mass) / math.log(HEAVIEST), 0, 1)
	local volume = pace * (0.6 + 0.4 * heavy) * EvilSnake.Setting("slither_volume")
	local pitch = (80 + 40 * pace) / mass ^ 0.12
	for _, layer in ipairs(SLITHER) do
		local patch = self[layer.key]
		local vol = math.min(volume * Lerp(heavy, layer.light, layer.heavy), 1)
		local p = math.Clamp(pitch * layer.pitch, 40, 180)
		if vol > 0.01 then
			if not patch then
				patch = CreateSound(self, layer.path)
				patch:SetSoundLevel(SLITHER_LEVEL)
				self[layer.key] = patch
			end
			if not patch:IsPlaying() then patch:PlayEx(0, p) end
			patch:ChangeVolume(vol, SLITHER_FADE)
			patch:ChangePitch(p, SLITHER_FADE)
			self[layer.key .. "Quiet"] = nil
		elseif patch and patch:IsPlaying() then
			patch:ChangeVolume(0, SLITHER_FADE)
			local quiet = self[layer.key .. "Quiet"] or now
			self[layer.key .. "Quiet"] = quiet
			if now - quiet > SLITHER_REST then patch:Stop() end
		end
	end
end

function ENT:OnRemove()
	for _, layer in ipairs(SLITHER) do
		if self[layer.key] then self[layer.key]:Stop() end
	end
end

function ENT:Think()
	local now = RealTime()
	self:Slither(now)
	local snaps = self.Snaps
	if not snaps or #snaps == 0 then
		if now >= (self.NextAsk or 0) then
			self.NextAsk = now + ASK
			net.Start("EvilSnakeBody")
			net.WriteEntity(self)
			net.SendToServer()
		end
		return
	end
	local rt = math.min(UnPredictedCurTime() - self.Offset - DELAY, snaps[#snaps].t)
	self.Posing = self.Posing or {}
	local pose, snap, later, u = Sample(snaps, rt, self.Posing)
	self.Pose = pose
	local up = LerpVector(u, snap.up, later.up)
	up:Normalize()
	self.Up = up
	self.Link = EvilSnake.Setting("segment_length") * math.max(self:GetLength(), 1) / math.max(#pose - 1, 1)
	local ahead = math.max(rt - snap.fed, 0) * EvilSnake.Setting("bulge_speed") * math.max(self:GetDigest(), 1) / self.Link
	local bulges, fattest, mine = {}, 1, nil
	local me = LocalPlayer()
	for i, m in ipairs(snap.meals) do
		bulges[i] = { at = math.min(m.at + ahead, #pose - 1), size = m.size }
		fattest = math.max(fattest, m.size)
		if m.ply == me then mine = bulges[i] end
	end
	local tongue = self.Tongue
	EvilSnake.Tongue.Update(tongue, snap.tongue, later.tongue, u, now - (self.LastTongue or now))
	self.LastTongue = now
	local r = self:Radius()
	local held = snap.held
	self.HeldDepth = 0
	self.Gape = nil
	if held then
		local depth, at, swell = EvilSnake.Hold((rt - held.at) * held.pace, held.hold)
		local fit = Fit(held.ent, r)
		local snug = EvilSnake.Body.Snug(fit, EvilSnake.HeadRadius(r))
		bulges[#bulges + 1] = { at = at, size = Lerp(at, snug, held.size), swell = swell }
		fattest = math.max(fattest, held.size, snug)
		self.HeldDepth = depth
		local shut = math.Clamp((depth - SHUT[1]) / (SHUT[2] - SHUT[1]), 0, 1)
		local head, neck = EvilSnake.HeadPoints(pose[1], pose[2], r, self.Up)
		local _, up = EvilSnake.Gape(head, neck, self.Up)
		local snap = swell < 1 and math.sin(math.pi * swell) or 0
		self.Gape = { fit = fit, open = swell * (1 - shut * shut * (3 - 2 * shut)), dir = up, snap = snap }
	else
		local head, neck = EvilSnake.HeadPoints(pose[1], pose[2], r, self.Up)
		self.Gape = EvilSnake.Tongue.Gape(tongue, head, neck, EvilSnake.HeadRadius(r))
	end
	self.Bulges = bulges
	if mine then EvilSnake.Inside(Blob(pose, mine.at), r * mine.size) end
	local target = held and held.ent or self:GetPrey()
	local dead = self:GetDead()
	self.Body.dim = dead and DEAD_DIM or nil
	self.Body.eyes.dead = dead
	self.Body.look = not dead and (not held and EvilSnake.Tongue.Look(tongue)
		or IsValid(target) and (target.EyePos and target:EyePos() or target:WorldSpaceCenter())) or nil
	local mins, maxs = EvilSnake.Body.Bounds(pose, fattest, r)
	self:SetRenderBoundsWS(EvilSnake.Tongue.Bounds(tongue, mins, maxs))
end

function ENT:Draw()
	if not self.Pose then return end
	EvilSnake.Body.Draw(self.Body, self.Pose, self.Bulges, self:Radius(), self.Link, self.Gape, self.Up)
	EvilSnake.Tongue.Draw(self.Tongue, self.Body, RealTime())
end
