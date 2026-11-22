include("shared.lua")

-- The egg is the scaled watermelon model wearing a pale shell made from the melon's own texture.
-- Rather than shipping a copy of a HL2 texture in the addon, the shell is built on the client:
-- the game's texture is drawn into a render target over white, which washes it out the way the
-- old hand-made copy looked, and $color2 tints it purple.
local HALF = ENT.EGG_HALF
local TINT = Vector(150 / 255, 70 / 255, 200 / 255) -- purple

-- A new name, so a map that already built the untinted material does not hand that one back.
local Shell = CreateMaterial("evil_snake_egg_shell_purple", "VertexLitGeneric", {
	["$basetexture"] = "models/props_junk/fruit_objects01",
	["$model"] = 1,
	["$halflambert"] = 1,
	["$color2"] = ("[%f %f %f]"):format(TINT.x, TINT.y, TINT.z),
})

-- The game's own texture, drawn only to make the shell.
local SOURCE = CreateMaterial("evil_snake_egg_source", "UnlitGeneric", {
	["$basetexture"] = "models/props_junk/fruit_objects01",
})
local built = false

-- Runs once, from a draw, so the render target is safe to push.
local function BuildShell()
	if built then return end
	built = true
	local size = 256
	local rt = GetRenderTarget("evil_snake_egg_shell", size, size)
	if not rt then return end
	render.PushRenderTarget(rt)
	render.Clear(255, 255, 255, 255, true, true)
	cam.Start2D()
	surface.SetDrawColor(255, 255, 255, 90)
	surface.SetMaterial(SOURCE)
	surface.DrawTexturedRect(0, 0, size, size)
	cam.End2D()
	render.PopRenderTarget()
	Shell:SetTexture("$basetexture", rt)
end

function ENT:Initialize()
	self:SetRenderBounds(-HALF * 1.1, HALF * 1.1)
end

function ENT:Draw()
	-- Set again every frame, as the crawler's egg does: a tint set only once at load can be lost.
	BuildShell()
	Shell:SetVector("$color2", TINT)
	render.MaterialOverride(Shell)
	self:DrawModel()
	render.MaterialOverride()
end
