-- The snake's egg: the crawler's egg, white and half again as big. The spawn-menu PHX cannonball
-- (models/props_phx/cannonball.mdl) at about 47 across, in a pale white shell. Its origin sits at the
-- base, so cl_init.lua draws the shell against the physics hull in init.lua. sv_eggs.lua in the snake
-- keeps its own copy of the size for the nest checks.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil Snake Egg"
ENT.Category = "Syhgma's Evil Entities"
ENT.Spawnable = EvilSnake ~= nil
ENT.RenderGroup = RENDERGROUP_OPAQUE
-- Keeps the egg out of duplicator dupes and saves. The duplicator skips any entity that sets this,
-- so a save or a dupe that includes an egg is refused rather than restoring one;
-- setting ent.NoDuplicate on the instance does nothing at all.
ENT.DoNotDuplicate = true

ENT.EGG_MODEL = "models/props_phx/cannonball.mdl"
ENT.EGG_SCALE = 1.05
ENT.EGG_HALF = Vector(22.4, 22.4, 22.4) * ENT.EGG_SCALE -- the model's visual half-size, scaled
ENT.EGG_THICK = 48
