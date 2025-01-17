/mob/living/simple_animal/hostile/asteroid/polarbear
	name = "polar bear"
	desc = "An aggressive animal that defends it's territory with incredible power. These beasts don't run from their enemies."
	icon = 'icons/mob/icemoon/icemoon_monsters.dmi'
	icon_state = "polarbear"
	icon_living = "polarbear"
	icon_dead = "polarbear_dead"
	friendly = "wails at"
	mob_biotypes = list(MOB_ORGANIC, MOB_BEAST)
	mouse_opacity = MOUSE_OPACITY_ICON
	friendly = "growls at"
	speak_emote = list("growls")
	speed = 5
	move_to_delay = 15
	maxHealth = 300
	health = 300
	obj_damage = 40
	melee_damage_lower = 25
	melee_damage_upper = 25
	attack_vis_effect = ATTACK_EFFECT_CLAW
	attacktext = "claws"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	vision_range = 2 // don't aggro unless you basically antagonize it, though they will kill you worse than a goliath will
	aggro_vision_range = 9
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG
	butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/slab/bear = 3, /obj/item/stack/sheet/bone = 2)
	guaranteed_butcher_results = list(/obj/item/stack/sheet/animalhide/goliath_hide/polar_bear_hide = 1)
	loot = list()
	stat_attack = UNCONSCIOUS
	robust_searching = TRUE
	var/aggressive_message_said = FALSE

/mob/living/simple_animal/hostile/asteroid/polarbear/adjustHealth(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(health <= maxHealth*0.5)
		if(!aggressive_message_said && target)
			visible_message(span_danger("The [name] gets an enraged look at [target]!"))
			aggressive_message_said = TRUE
		rapid_melee = 2
	else
		rapid_melee = initial(rapid_melee)

/mob/living/simple_animal/hostile/asteroid/polarbear/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(target == null)
		adjustHealth(-maxHealth*0.025)
		aggressive_message_said = FALSE

/mob/living/simple_animal/hostile/asteroid/polarbear/death(gibbed)
	move_force = MOVE_FORCE_DEFAULT
	move_resist = MOVE_RESIST_DEFAULT
	pull_force = PULL_FORCE_DEFAULT
	..(gibbed)
