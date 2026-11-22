EvilSnake = EvilSnake or {}

EvilSnake.SETTINGS = {
	{ name = "hunt_npcs", default = 1, min = 0, max = 1, label = "Hunts NPCs",
		help = "Goes after NPCs and swallows them. At 0 it leaves them alone" },
	{ name = "hunt_players", default = 1, min = 0, max = 1, label = "Hunts players",
		help = "Goes after players and swallows them. At 0 it leaves them alone" },
	{ name = "npcs_fight", default = 1, min = 0, max = 1, label = "NPCs fight back",
		help = "NPCs treat it as an enemy and attack it. At 0 they ignore it" },
	{ name = "max_meals", default = 0, min = 0, max = 500, decimals = 0, label = "Max people eaten",
		help = "How many it can eat in its life before it stops hunting. At 0 there is no limit" },
	{ name = "escape_presses", default = 12, min = 0, max = 60, decimals = 0, label = "Escape presses",
		help = "How many times a grabbed player has to hit jump to break free. At 0 there is no getting out" },
	{ name = "skip_swallow", default = 0, min = 0, max = 1, label = "Allow players to skip swallow",
		help = "Swallowed players can hold jump for 3 seconds to respawn right away instead of riding down to the tail" },
	{ name = "sight_range", default = 3000, min = 0, max = 10000, decimals = 0, label = "Sight range",
		help = "How far away it notices prey" },
	{ name = "bite_reach", default = 24, min = 0, max = 200, decimals = 0, label = "Bite reach",
		help = "How close its mouth has to get to someone to grab them" },
	{ name = "hold_time", default = 3, min = 0, max = 15, decimals = 1, label = "Swallow time",
		help = "Seconds it holds someone half in its mouth before pulling them down" },
	{ name = "instant_npcs", default = 1, min = 0, max = 1, label = "Instantly swallow NPCs",
		help = "NPCs get pulled down in a blink instead of being held in its mouth first" },
	{ name = "tongue", default = 1, min = 0, max = 1, label = "Tongue mode",
		help = "Gives the snake a lashing tongue" },
	{ name = "tongue_reach", default = 300, min = 50, max = 1500, decimals = 0, label = "Tongue reach",
		help = "How far the tongue lashes out to grab someone" },
	{ name = "tongue_reel", default = 60, min = 10, max = 600, decimals = 0, label = "Tongue reel speed",
		help = "How fast the tongue drags someone back to its mouth" },
	{ name = "propellor", default = 0, min = 0, max = 1, label = "Propellor mode", needs = "EvilCrawler",
		help = "A crawler that finds a snake with nothing on its head hops on and spins its legs like helicopter blades, and the snake flies after whoever it hunts, noclippers first" },
	{ name = "fly_speed", default = 250, min = 0, max = 2000, decimals = 0, label = "Flying speed", needs = "EvilCrawler",
		help = "How fast the head flies with a crawler spinning on it" },
	{ name = "bulge_size", default = 1.8, min = 1, max = 4, decimals = 2, label = "Bulge size",
		help = "How fat a swallowed victim makes the body, in body thicknesses. Bigger victims bulge more" },
	{ name = "bulge_speed", default = 80, min = 5, max = 1000, decimals = 0, label = "Bulge speed",
		help = "How fast a swallowed victim travels down to the tail" },
	{ name = "growth", default = 2, min = 0, max = 20, decimals = 0, label = "Growth per meal",
		help = "Segments it gains from each victim, bit by bit as they travel down. Bigger victims add more" },
	{ name = "fattening", default = 0.15, min = 0, max = 1, decimals = 2, label = "Fattening",
		help = "How much thicker it gets from everyone it has eaten. Each meal adds less than the last" },
	{ name = "girth_max", default = 3, min = 1, max = 8, decimals = 2, label = "Max fattening",
		help = "Thickest eating can make it, in starting thicknesses" },
	{ name = "learning", default = 1, min = 0, max = 5, decimals = 2, label = "Learning",
		help = "How much it takes from the minds of what it eats" },
	{ name = "habituation", default = 0.5, min = 0, max = 5, decimals = 2, label = "Habituation",
		help = "How fast eating the same kind of thing over and over stops teaching it anything" },
	{ name = "wits", default = 1, min = 0, max = 3, decimals = 2, label = "Uses what it learns",
		help = "How much everything it has learned from what it ate makes it faster, stronger and sharper. At 0 it learns but never uses any of it" },
	{ name = "open_doors", default = 1, min = 0, max = 1, label = "Opens doors",
		help = "Its tongue flicks doors in its way open, locked or not" },
	{ name = "wander", default = 1, min = 0, max = 1, label = "Wanders",
		help = "Crawls around on its own when there is nothing to hunt" },
	{ name = "wall_addiction", default = 0, min = 0, max = 1, label = "Wall addiction",
		help = "Always grips walls and ceilings, heads for the nearest wall whenever it wanders onto the floor and never drops off the ceiling on its own" },
	{ name = "eggs", default = 0, min = 0, max = 1, label = "Eggs",
		help = "It lays an egg after digesting someone, which hatches into another snake. At 0 it never lays" },
	{ name = "egg_cap", default = 10, min = 0, max = 100, decimals = 0, label = "Population cap",
		help = "Most snakes and unhatched eggs there can be at once. At this count it stops laying, and "
			.. "eggs that are already due wait unhatched until the count drops below it. At 0 there is no cap" },
	{ name = "egg_time", default = 60, min = 1, max = 600, decimals = 0, label = "Egg gestation",
		help = "Seconds an egg takes to hatch into a snake. A snake lays one somewhere secluded after it digests someone. "
			.. "Eggs are physics props with 100 health: they can be knocked loose, picked up, thrown, and break when "
			.. "shot or slammed. A broken egg spills bones and a dead snake" },
	{ name = "fungus_smear", default = 10, min = 0, max = 60, decimals = 0, label = "Fungus smear", needs = "EvilFungus",
		help = "Seconds it keeps smearing fresh fungus behind it after crawling through live fungus. At 0 it never picks any up" },
	{ name = "hunt_speed", default = 170, min = 0, max = 1000, decimals = 0, label = "Hunting speed",
		help = "How fast the head moves when it is going after someone" },
	{ name = "wander_speed", default = 60, min = 0, max = 1000, decimals = 0, label = "Wander speed",
		help = "How fast the head moves when it is just crawling around" },
	{ name = "turn_rate", default = 120, min = 10, max = 720, decimals = 0, label = "Turn rate",
		help = "Degrees a second the head can turn" },
	{ name = "sway", default = 35, min = 0, max = 80, decimals = 0, label = "Sway",
		help = "Degrees the head swings either side of where it is going. At 0 it slides along in a straight line" },
	{ name = "wavelength", default = 150, min = 40, max = 600, decimals = 0, label = "Wave length",
		help = "Distance the head covers in one full swing left and right" },
	{ name = "follow", default = 0.5, min = 0, max = 1, decimals = 2, label = "Path following",
		help = "How tightly the body sticks to the path the head took. At 0 it gets dragged like a rope" },
	{ name = "step_height", default = 18, min = 0, max = 64, decimals = 0, label = "Step height",
		help = "Tallest ledge it climbs straight over" },
	{ name = "segments", default = 28, min = 4, max = 80, decimals = 0, label = "Body segments",
		help = "Segments new snakes spawn with. Each one adds a segment length of body" },
	{ name = "segment_length", default = 17, min = 4, max = 64, decimals = 0, label = "Segment length" },
	{ name = "radius", default = 14, min = 2, max = 64, decimals = 0, label = "Thickness" },
	{ name = "head_size", default = 1.2, min = 1, max = 2, decimals = 2, label = "Head size",
		help = "How many times thicker the head is than the body" },
	{ name = "tail_length", default = 0.3, min = 0.05, max = 1, decimals = 2, label = "Tail length",
		help = "How much of the body tapers down to the tail tip" },
	{ name = "teeth", default = 0, min = 0, max = 1, label = "Teeth" },
	{ name = "static_head", default = 1, min = 0, max = 1, label = "Static head size",
		help = "Head stays the same size as it eats, only the body gets fatter" },
	{ name = "color", default = 9858664, min = 0, max = 16777215, color = true, label = "Colour" },
	{ name = "slither_volume", default = 1, min = 0, max = 1, decimals = 2, label = "Slither volume" },
	{ name = "eat_volume", default = 1, min = 0, max = 1, decimals = 2, label = "Eating volume" },
	{ name = "gravity", default = 600, min = 0, max = 3000, decimals = 0, label = "Gravity" },
	{ name = "grip_along", default = 0.3, min = 0, max = 5, decimals = 2, label = "Lengthwise grip",
		help = "Ground friction against the body sliding along its length" },
	{ name = "grip_side", default = 1.2, min = 0, max = 5, decimals = 2, label = "Sideways grip",
		help = "Ground friction against the body sliding sideways" },
	{ name = "curl", default = 2, min = 0, max = 5, decimals = 2, label = "Tightest curl",
		help = "Tightest it can bend, in body thicknesses. Lower lets it coil tighter" },
	{ name = "self_collide", default = 1, min = 0, max = 1, label = "Self collision",
		help = "Body pushes off itself instead of passing through" },
	{ name = "solver_passes", default = 8, min = 1, max = 32, decimals = 0, label = "Solver passes",
		help = "Physics passes per step. More keeps the body from stretching but costs more" },
}

EvilSnake.HURT = {
	{ name = "killable", default = 1, min = 0, max = 1, label = "Killable",
		help = "Takes damage and dies. At 0 nothing hurts it" },
	{ name = "health", default = 500, min = 1, max = 20000, decimals = 0, label = "Health",
		help = "Health a fresh snake spawns with" },
	{ name = "size_health", default = 0.5, min = 0, max = 2, decimals = 2, label = "Health from size",
		help = "How much getting bigger adds to its health. At 1 it goes up with its weight, at 0 eating never makes it tougher" },
	{ name = "regen", default = 0, min = 0, max = 200, decimals = 1, label = "Regeneration",
		help = "Health it heals a second" },
	{ name = "regen_delay", default = 5, min = 0, max = 60, decimals = 1, label = "Regeneration delay",
		help = "Seconds after getting hurt before it starts healing" },
	{ name = "meal_heal", default = 0.25, min = 0, max = 1, decimals = 2, label = "Heals from eating",
		help = "Share of its health it gets back from each meal once it's digested" },
	{ name = "armor", default = 0, min = 0, max = 200, decimals = 0, label = "Armor",
		help = "Taken off every hit. Anything weaker does nothing" },
	{ name = "head_damage", default = 2, min = 0, max = 10, decimals = 2, label = "Head damage",
		help = "Damage multiplier for hits to the head" },
	{ name = "body_damage", default = 1, min = 0, max = 10, decimals = 2, label = "Body damage",
		help = "Damage multiplier for hits anywhere else, and for explosions, fire and gas" },
	{ name = "from_players", default = 1, min = 0, max = 5, decimals = 2, label = "Damage from players" },
	{ name = "from_npcs", default = 1, min = 0, max = 5, decimals = 2, label = "Damage from NPCs" },
	{ name = "from_world", default = 1, min = 0, max = 5, decimals = 2, label = "Damage from the world",
		help = "Damage nobody gets credit for, like loose fire, stray props and trigger hurts" },
	{ name = "exposed_only", default = 0, min = 0, max = 1, label = "Only hurt while eating",
		help = "Only takes damage while it's got someone in its mouth or on its tongue" },
	{ name = "hurt_gap", default = 0, min = 0, max = 5, decimals = 2, label = "Invulnerable after hits",
		help = "Seconds it ignores everything after taking a hit" },
	{ name = "spawn_grace", default = 0, min = 0, max = 60, decimals = 1, label = "Spawn protection",
		help = "Seconds a new snake can't be hurt" },
	{ name = "drop_damage", default = 60, min = 0, max = 1000, decimals = 0, label = "Hurt to let go",
		help = "Damage it has to take in a couple of seconds to spit out who it's holding. At 0 it never lets go" },
	{ name = "knockback", default = 1, min = 0, max = 5, decimals = 2, label = "Knockback",
		help = "How hard explosions and big hits throw it around. A small snake goes flying, a fat one barely moves. At 0 nothing moves it" },
	{ name = "untenable_meals", default = 15, min = 0, max = 200, decimals = 0, label = "Meals to untenable",
		help = "How much it has to eat before explosions and hits stop moving it at all. Big meals count for more. At 0 it never gets there" },
	{ name = "retaliate", default = 1, min = 0, max = 1, label = "Goes after attackers",
		help = "Turns on whoever hurts it if it can eat them" },
	{ name = "corpse_time", default = 10, min = 0, max = 120, decimals = 0, label = "Corpse time",
		help = "Seconds the body lies there after it dies" },
	{ name = "npc_kill", default = 1, min = 0, max = 1, label = "Counts as an NPC kill",
		help = "Its death goes through the NPC death hook, so kill feeds, scoring and XP mods notice it" },
}
table.Add(EvilSnake.HURT, Evil.DamageRows())

for i, s in ipairs(EvilSnake.SETTINGS) do
	if s.name == "instant_npcs" then
		for k, h in ipairs(EvilSnake.HURT) do table.insert(EvilSnake.SETTINGS, i + k, h) end
		break
	end
end

EvilSnake.PRESETS = {
	{ name = "chill", label = "Chill", values = {
		hunt_npcs = 1, hunt_players = 1, escape_presses = 8, health = 250, regen = 0,
		sight_range = 800, bite_reach = 16, hold_time = 5, bulge_size = 2.2, bulge_speed = 35,
		growth = 1, fattening = 0.25, girth_max = 3.5, learning = 0.5, habituation = 1, wits = 0.5,
		wander = 1, hunt_speed = 80, wander_speed = 30, turn_rate = 70, sway = 45, wavelength = 220,
	} },
	{ name = "normal", label = "Normal", values = {
		hunt_npcs = 1, hunt_players = 1, escape_presses = 12, health = 500, regen = 0,
		sight_range = 3000, bite_reach = 24, hold_time = 3, bulge_size = 1.8, bulge_speed = 80,
		growth = 2, fattening = 0.15, girth_max = 3, learning = 1, habituation = 0.5, wits = 1,
		wander = 1, hunt_speed = 170, wander_speed = 60, turn_rate = 120, sway = 35, wavelength = 150,
	} },
	{ name = "aggressive", label = "Aggressive", values = {
		hunt_npcs = 1, hunt_players = 1, escape_presses = 15, health = 1200, regen = 5,
		sight_range = 5500, bite_reach = 40, hold_time = 2, bulge_size = 1.6, bulge_speed = 180,
		growth = 4, fattening = 0.12, girth_max = 3, learning = 1.5, habituation = 0.3, wits = 1.5,
		wander = 1, hunt_speed = 320, wander_speed = 110, turn_rate = 240, sway = 25, wavelength = 120,
	} },
	{ name = "unhinged", label = "Unhinged", values = {
		hunt_npcs = 1, hunt_players = 1, escape_presses = 20, health = 5000, regen = 25,
		sight_range = 10000, bite_reach = 90, hold_time = 0.8, bulge_size = 2.8, bulge_speed = 600,
		growth = 12, fattening = 0.4, girth_max = 6, learning = 4, habituation = 0, wits = 3,
		wander = 1, hunt_speed = 700, wander_speed = 280, turn_rate = 600, sway = 60, wavelength = 70,
	} },
}

EvilSnake.Settings = Evil.Settings({
	id = "evil_snake", title = "Evil snake", rows = EvilSnake.SETTINGS, presets = EvilSnake.PRESETS,
})

function EvilSnake.Setting(name)
	return EvilSnake.Settings:Get(name)
end

function EvilSnake.Color()
	return EvilSnake.Settings:Color("color")
end

-- Living snakes, not counting corpses (killed ones and stillborn ones from broken eggs).
function EvilSnake.Population()
	local n = 0
	for _, s in ipairs(ents.FindByClass("evil_snake")) do
		if not s:GetDead() and not s.Stillborn then n = n + 1 end
	end
	return n
end

-- Whether the population cap is reached or over. Always false at cap 0.
function EvilSnake.AtCap()
	local cap = EvilSnake.Setting("egg_cap")
	return cap > 0 and EvilSnake.Population() >= cap
end
