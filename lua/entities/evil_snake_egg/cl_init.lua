include("shared.lua")

-- The egg is the scaled watermelon model wearing a whitened greyscale copy of the watermelon's own
-- texture (materials/evil_snake/egg_shell.png), tinted through $color2, so it shows as a purple
-- shell with the melon's faint streaks. It is a model material (VertexLitGeneric), so map light and
-- flashlights land on it on their own.
local HALF = ENT.EGG_HALF
local TINT = Vector(150 / 255, 70 / 255, 200 / 255) -- purple

-- A new name, so a map that already built the untinted material does not hand that one back.
local Shell = CreateMaterial("evil_snake_egg_shell_purple", "VertexLitGeneric", {
	["$basetexture"] = "models/props_junk/fruit_objects01",
	["$model"] = 1,
	["$halflambert"] = 1,
	["$color2"] = ("[%f %f %f]"):format(TINT.x, TINT.y, TINT.z),
})
local white = Material("evil_snake/egg_shell.png", "smooth mips")
if not white:IsError() then Shell:SetTexture("$basetexture", white:GetTexture("$basetexture")) end

function ENT:Initialize()
	self:SetRenderBounds(-HALF * 1.1, HALF * 1.1)
end

function ENT:Draw()
	-- Set again every frame, as the crawler's egg does: a tint set only once at load can be lost.
	Shell:SetVector("$color2", TINT)
	render.MaterialOverride(Shell)
	self:DrawModel()
	render.MaterialOverride()
end
