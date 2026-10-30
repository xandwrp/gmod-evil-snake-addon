EvilSnake = EvilSnake or {}
local Head = {}
EvilSnake.Head = Head

local sqrt, sin, cos, max, min, abs, atan = math.sqrt, math.sin, math.cos, math.max, math.min, math.abs, math.atan

local RINGS = 14
local SHELL = 12
local CAVITY = 10
local K = SHELL + CAVITY + 2
local LENGTH = 2.3
local HAMMER = 2.1
local FLAT = 0.58
local BOXY = 3.2
local SWEEP = 0.35
local FRONT = 0.22
local LIPIN = 0.88
local HOLLOW = 0.75
local SIDE_TEETH = 7
local FRONT_TEETH = 11
local TOOTH = 0.24
local TOOTH_W = 0.06
local STALK_AT = 0.7
local STALK_OUT = 0.8
local IDLE = 0.04
local SNAP = 0.6
local CLAMP = 0.6
local BITE_AT = 0.55
local THROAT = { 120, 28, 38 }
local BONE = { 235, 228, 205 }
local CROWN = 0.25
local UP = Vector(0, 0, 1)
local SIDE = Vector(1, 0, 0)

local function Step(a, b, x)
	local t = math.Clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function Pow(v, e)
	return v < 0 and -((-v) ^ e) or v ^ e
end

local function Shape(u, W)
	local wide, flat = Step(0.15, 0.55, u), Step(0, 0.5, u)
	local v = max(0, (u - (1 - FRONT)) / FRONT)
	local a = W * Lerp(wide, 1, HAMMER) * (1 - 0.3 * v * v)
	local b = W * Lerp(flat, 1, FLAT) * sqrt(max(1 - v * v, 0))
	return a, b, Lerp(flat, 2, BOXY), wide, Lerp(flat, 0.9, HOLLOW)
end

local function Sweep(y, W, wide)
	local s = y / (HAMMER * W)
	return SWEEP * W * wide * s * s
end

local px, py, pz, fx, fy, fz, rx, ry, rz, ux, uy, uz = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
local jc, js, jm = 1, 0, 1
local light

local function Place(x, y, z)
	z = z * jm
	local x2, z2 = x * jc - z * js, x * js + z * jc
	return px + fx * x2 + rx * y + ux * z2, py + fy * x2 + ry * y + uy * z2, pz + fz * x2 + rz * y + uz * z2
end

local function Lit(nx, ny, nz)
	local l = sqrt(nx * nx + ny * ny + nz * nz)
	if l < 1e-6 then return EvilSnake.Bright(light, 0, ux, uy, uz), ux, uy, uz end
	nx, ny, nz = nx / l, ny / l, nz / l
	return EvilSnake.Bright(light, 0, nx, ny, nz), nx, ny, nz
end

local gx, gy, gz, gr, gg, gb, gu, gv = {}, {}, {}, {}, {}, {}, {}, {}
local verts, vr, vg, vb = {}, {}, {}, {}
local scratch = Vector()

local function Set(i, x, y, z, r, g, b)
	gx[i], gy[i], gz[i] = Place(x, y, z)
	gr[i], gg[i], gb[i] = r, g, b
end

local function Jaw(W, Lw, cr, cg, cb)
	for i = 1, RINGS do
		local u = (i - 1) / (RINGS - 1)
		local a, b, n, wide, hollow = Shape(u, W)
		local e, cav, o = 2 / n, b * hollow, (i - 1) * K
		local deep = Lerp(u, 0.3, 0.85)
		local span, along = CROWN * sqrt(a / W), -u * Lw / (2 * math.pi * W)
		for k = 0, SHELL do
			local t = k / SHELL * math.pi
			local y = a * Pow(cos(t), e)
			Set(o + k + 1, u * Lw - Sweep(y, W, wide), y, b * Pow(sin(t), e), cr, cg, cb)
			gu[o + k + 1], gv[o + k + 1] = (jm == 1 and 0 or 0.5) + (k / SHELL - 0.5) * 2 * span, along
		end
		for k = 0, CAVITY do
			local s = k / CAVITY * 2 - 1
			local y = s * a * LIPIN
			local shade = deep * (0.7 + 0.3 * abs(s))
			Set(o + SHELL + 2 + k, u * Lw - Sweep(y, W, wide), y, cav * (1 - s * s), THROAT[1] * shade, THROAT[2] * shade, THROAT[3] * shade)
		end
	end
end

local function Shade(flip)
	for i = 1, RINGS do
		local i0, i1 = max(i - 1, 1), min(i + 1, RINGS)
		for k = 1, K do
			local k0, k1 = (k - 2) % K + 1, k % K + 1
			local a, b = (i0 - 1) * K + k, (i1 - 1) * K + k
			local c, d = (i - 1) * K + k0, (i - 1) * K + k1
			local ax, ay, az = gx[b] - gx[a], gy[b] - gy[a], gz[b] - gz[a]
			local bx, by, bz = gx[d] - gx[c], gy[d] - gy[c], gz[d] - gz[c]
			local l, nx, ny, nz = Lit((ay * bz - az * by) * flip, (az * bx - ax * bz) * flip, (ax * by - ay * bx) * flip)
			local j = (i - 1) * K + k
			local sh = EvilSnake.Sheen(light, 0, gx[j], gy[j], gz[j], nx, ny, nz)
			vr[j], vg[j], vb[j] = min(255, gr[j] * l + sh), min(255, gg[j] * l + sh), min(255, gb[j] * l + sh)
			local v = verts[j]
			if not v then
				v = Vector()
				verts[j] = v
			end
			v:SetUnpacked(gx[j], gy[j], gz[j])
		end
	end
end

local function Vert(j)
	mesh.Position(verts[j])
	mesh.TexCoord(0, gu[j] or 0, gv[j] or 0)
	mesh.Color(vr[j], vg[j], vb[j], 255)
	mesh.AdvanceVertex()
end

local function Quads(lo, hi)
	mesh.Begin(MATERIAL_QUADS, (RINGS - 1) * (hi - lo + 1))
	for i = 1, RINGS - 1 do
		local o0, o1 = (i - 1) * K, i * K
		for k = lo, hi do
			local k2 = k % K + 1
			Vert(o0 + k)
			Vert(o0 + k2)
			Vert(o1 + k2)
			Vert(o1 + k)
		end
	end
	mesh.End()
end

local function Shell()
	render.SetMaterial(EvilSnake.SkinMaterial)
	Quads(1, SHELL)
	render.SetMaterial(EvilSnake.Material)
	Quads(SHELL + 1, K)
end

local tx, ty, th = {}, {}, {}
local teeth = 0

local function Tooth(x, y, h)
	teeth = teeth + 1
	tx[teeth], ty[teeth], th[teeth] = x, y, h
end

local function Corner(x, y, z, r, g, b)
	scratch:SetUnpacked(x, y, z)
	mesh.Position(scratch)
	mesh.TexCoord(0, 0, 0)
	mesh.Color(r, g, b, 255)
	mesh.AdvanceVertex()
end

local function Face(ax, ay, az, bx, by, bz, cx, cy, cz, ox, oy, oz)
	local ex, ey, ez = bx - ax, by - ay, bz - az
	local gx2, gy2, gz2 = cx - ax, cy - ay, cz - az
	local nx, ny, nz = ey * gz2 - ez * gy2, ez * gx2 - ex * gz2, ex * gy2 - ey * gx2
	if nx * ((ax + bx + cx) / 3 - ox) + ny * ((ay + by + cy) / 3 - oy) + nz * ((az + bz + cz) / 3 - oz) < 0 then
		nx, ny, nz = -nx, -ny, -nz
	end
	local l = Lit(nx, ny, nz)
	local r, g, b = min(255, BONE[1] * l), min(255, BONE[2] * l), min(255, BONE[3] * l)
	Corner(ax, ay, az, r, g, b)
	Corner(bx, by, bz, r, g, b)
	Corner(cx, cy, cz, r, g, b)
end

local function Teeth(W, Lw, shift)
	teeth = 0
	local lip = (1 + LIPIN) * 0.5
	for i = 1, SIDE_TEETH do
		local u = Lerp((i - 0.5 + shift) / SIDE_TEETH, 0.3, 0.85)
		local a, _, _, wide = Shape(u, W)
		local h = TOOTH * W * (i % 2 == 0 and 0.7 or 1)
		for side = -1, 1, 2 do
			local y = side * a * lip
			Tooth(u * Lw - Sweep(y, W, wide), y, h)
		end
	end
	local a, _, _, wide = Shape(1, W)
	for i = 1, FRONT_TEETH do
		local y = Lerp((i - 1 + shift) / FRONT_TEETH, -0.85, 0.85) * a
		Tooth(Lw - Sweep(y, W, wide) - TOOTH_W * W * 0.5, y, TOOTH * W * (i % 2 == 0 and 0.7 or 1.15))
	end
	local w = TOOTH_W * W
	mesh.Begin(MATERIAL_TRIANGLES, teeth * 3)
	for t = 1, teeth do
		local x, y, h = tx[t], ty[t], th[t]
		local b1x, b1y, b1z = Place(x + w, y, w * 0.2)
		local b2x, b2y, b2z = Place(x - w * 0.5, y + w * 0.87, w * 0.2)
		local b3x, b3y, b3z = Place(x - w * 0.5, y - w * 0.87, w * 0.2)
		local ax, ay, az = Place(x, y * 0.97, -h)
		local ox, oy, oz = Place(x, y, -h * 0.3)
		Face(b1x, b1y, b1z, b2x, b2y, b2z, ax, ay, az, ox, oy, oz)
		Face(b2x, b2y, b2z, b3x, b3y, b3z, ax, ay, az, ox, oy, oz)
		Face(b3x, b3y, b3z, b1x, b1y, b1z, ax, ay, az, ox, oy, oz)
	end
	mesh.End()
end

local function Stalks(W, Lw)
	local a, b, n, wide = Shape(STALK_AT, W)
	local list = {}
	for side = -1, 1, 2 do
		local y = side * a * STALK_OUT
		local x = STALK_AT * Lw - Sweep(y, W, wide)
		local z = b * (1 - STALK_OUT ^ n) ^ (1 / n) - W * 0.03
		local bx, by, bz = Place(x, y, z)
		local tx2, ty2, tz2 = Place(x, y, z + 1)
		local sx, sy, sz = Place(x, y + side, z)
		local base = Vector(bx, by, bz)
		local up = Vector(tx2 - bx, ty2 - by, tz2 - bz)
		up:Normalize()
		local out = Vector(sx - bx, sy - by, sz - bz)
		out:Normalize()
		up = up + out * 0.35
		up:Normalize()
		list[#list + 1] = { base = base, up = up, side = out }
	end
	return list
end

function Head.Gape(mouth, W)
	if not mouth then return IDLE end
	local hold = atan(mouth.fit * CLAMP / (W * LENGTH * BITE_AT))
	return Lerp(mouth.open, IDLE, hold) + SNAP * (mouth.snap or 0)
end

function Head.Draw(cube, p, dir, W, mouth, cr, cg, cb, eyes, look, surface)
	light = cube
	local right = dir:Cross(surface or UP)
	if right:LengthSqr() < 1e-4 then right = dir:Cross(SIDE) end
	right:Normalize()
	local up = right:Cross(dir)
	px, py, pz = p:Unpack()
	fx, fy, fz = dir:Unpack()
	rx, ry, rz = right:Unpack()
	ux, uy, uz = up:Unpack()
	local Lw = W * LENGTH
	local gape = Head.Gape(mouth, W)
	for jaw = 1, -1, -2 do
		jc, js, jm = cos(gape), sin(gape) * jaw, jaw
		Jaw(W, Lw, cr, cg, cb)
		Shade(jaw)
		Shell()
		if EvilSnake.Setting("teeth") ~= 0 then Teeth(W, Lw, jaw == 1 and 0 or 0.5) end
		if jaw == 1 and eyes then
			EvilSnake.Eyes.Draw(eyes, cube, Stalks(W, Lw), { p = p, f = dir, r = right, u = up }, W, look, cr, cg, cb)
		end
	end
end
