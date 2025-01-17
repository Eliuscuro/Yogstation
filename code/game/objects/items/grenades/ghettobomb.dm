//improvised explosives//

/obj/item/grenade/iedcasing
	name = "improvised firebomb"
	desc = "A weak, improvised incendiary device."
	w_class = WEIGHT_CLASS_SMALL
	icon = 'icons/obj/grenade.dmi'
	icon_state = "improvised_grenade"
	item_state = "flashbang"
	lefthand_file = 'icons/mob/inhands/equipment/security_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/security_righthand.dmi'
	throw_speed = 3
	throw_range = 7
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	active = 0
	det_time = 50
	display_timer = 0
	var/range = 3
	var/list/times

/obj/item/grenade/iedcasing/Initialize(mapload)
	. = ..()
	add_overlay("improvised_grenade_filled")
	add_overlay("improvised_grenade_wired")
	times = list("5" = 10, "-1" = 20, "[rand(30,80)]" = 50, "[rand(65,180)]" = 20)// "Premature, Dud, Short Fuse, Long Fuse"=[weighting value]
	det_time = text2num(pickweight(times))
	if(det_time < 0) //checking for 'duds'
		range = 1
		det_time = rand(30,80)
	else
		range = pick(2,2,2,3,3,3,4)

/obj/item/grenade/iedcasing/CheckParts(list/parts_list)
	..()
	var/obj/item/reagent_containers/food/drinks/soda_cans/can = locate() in contents
	if(can)
		can.pixel_x = 0 //Reset the sprite's position to make it consistent with the rest of the IED
		can.pixel_y = 0
		var/mutable_appearance/can_underlay = new(can)
		can_underlay.layer = FLOAT_LAYER
		can_underlay.plane = FLOAT_PLANE
		underlays += can_underlay

/obj/item/grenade/iedcasing/attack_self(mob/user) //
	if(!active)
		if(clown_check(user))
			to_chat(user, span_warning("You light the [name]!"))
			cut_overlay("improvised_grenade_filled")
			preprime(user, null, FALSE)

/obj/item/grenade/iedcasing/prime() //Blowing that can up
	update_mob()
	explosion(src.loc,-1,-1,2, flame_range = 4)	// small explosion, plus a very large fireball.
	qdel(src)

/obj/item/grenade/iedcasing/examine(mob/user)
	. = ..()
	. += "You can't tell when it will explode!"

/obj/item/grenade/pipebomb
	name = "improvised pipebomb"
	desc = "A weak, improvised explosive with a mousetrap attached. For all your mailbombing needs."
	w_class = WEIGHT_CLASS_SMALL
	icon = 'icons/obj/grenade.dmi'
	icon_state = "pipebomb"
	lefthand_file = 'icons/mob/inhands/equipment/security_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/security_righthand.dmi'
	throw_speed = 3
	throw_range = 7
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	active = 0
	var/armed = 0
	display_timer = 0

/obj/item/grenade/pipebomb/Initialize(mapload)
	. = ..()

/obj/item/grenade/pipebomb/attack_self(mob/user)
	if(!armed)
		to_chat(user, span_warning("You pull back the mousetrap, arming the [name]! It will detonate whenever someone opens the container it is put inside of!"))
		playsound(src, 'sound/weapons/handcuffs.ogg', 30, TRUE, -3)
		log_admin("[key_name(user)] armed a [name] at [AREACOORD(src)]")
		armed = 1
	else
		to_chat(user, span_warning("The [name] is already armed!"))
	
/obj/item/grenade/pipebomb/on_found(mob/finder)
	if(armed)
		if(finder)
			to_chat(finder, span_userdanger("Oh fuck-"))
			preprime(finder, TRUE, FALSE)	
			return TRUE	//end the search!
		else
			visible_message(span_warning("[src] detonates!"))
			preprime(finder, TRUE, FALSE)	
			return FALSE
	return FALSE

/obj/item/grenade/pipebomb/prime() //Blowing that can up
	update_mob()
	explosion(src.loc,-1,-1,2, flame_range = 4)	// small explosion, plus a very large fireball. same as the IED.
	qdel(src)
