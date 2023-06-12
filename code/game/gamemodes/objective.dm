GLOBAL_LIST(admin_objective_list) //Prefilled admin assignable objective list
GLOBAL_LIST_EMPTY(objectives)

/datum/objective
	var/datum/mind/owner				//The primary owner of the objective. !!SOMEWHAT DEPRECATED!! Prefer using 'team' for new code.
	var/datum/team/team					//An alternative to 'owner': a team. Use this when writing new code.
	var/name = "generic objective" 		//Name for admin prompts
	var/objective_name = "Objective"	///name used in printing this objective (Objective #1)		//Name for admin prompts
	var/explanation_text = "Nothing"	//What that person is supposed to do.
	var/team_explanation_text			//For when there are multiple owners.
	var/datum/mind/target = null		//If they are focused on a particular person.
	var/target_amount = 0				//If they are focused on a particular number. Steal objectives have their own counter.
	var/completed = 0					//currently only used for custom objectives.
	var/martyr_compatible = 0			//If the objective is compatible with martyr objective, i.e. if you can still do it while dead.

/datum/objective/New(var/text)
	GLOB.objectives += src
	if(text)
		explanation_text = text

/datum/objective/Destroy(force, ...)
	GLOB.objectives -= src
	if(owner)
		for(var/datum/antagonist/A in owner.antag_datums)
			A.objectives -= src
	if(team)
		team.objectives -= src
	. = ..()

/datum/objective/proc/get_owners() // Combine owner and team into a single list.
	. = (team && team.members) ? team.members.Copy() : list()
	if(owner)
		. += owner

/datum/objective/proc/admin_edit(mob/admin)
	return

/datum/objective/proc/is_valid_target(possible_target)
	return TRUE

//Shared by few objective types
/datum/objective/proc/admin_simple_target_pick(mob/admin)
	var/list/possible_targets = list("Free objective","Random")
	var/def_value
	for(var/datum/mind/possible_target in SSticker.minds)
		if ((possible_target != src) && ishuman(possible_target.current))
			possible_targets += possible_target.current


	if(target && target.current)
		def_value = target.current

	var/mob/new_target = input(admin,"Select target:", "Objective target", def_value) as null|anything in possible_targets
	if (!new_target)
		return

	if (new_target == "Free objective")
		target = null
	else if (new_target == "Random")
		find_target()
	else
		target = new_target.mind

	update_explanation_text()

/datum/objective/proc/considered_escaped(datum/mind/M, needs_living = TRUE)
	if((needs_living && !considered_alive(M)))
		return FALSE
	if(M.force_escaped)
		return TRUE
	if(SSticker.force_ending || SSticker.mode.station_was_nuked) // Just let them win.
		return TRUE
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return FALSE
	var/turf/location = get_turf(M.current)
	if(!location || istype(location, /turf/open/floor/plasteel/shuttle/red) || istype(location, /turf/open/floor/mineral/plastitanium/red/brig)) // Fails if they are in the shuttle brig
		return FALSE
	if(iscarbon(M.current))
		var/mob/living/carbon/C = M.current
		if(C.handcuffed && (C.buckled || C.pulledby)) // If handcuffed and being pulled/buckled
			return FALSE
	return location.onCentCom() || location.onSyndieBase()

/datum/objective/proc/check_completion()
	return completed

/datum/objective/proc/is_unique_objective(possible_target, dupe_search_range)
	if(!islist(dupe_search_range))
		stack_trace("Non-list passed as duplicate objective search range")
		dupe_search_range = list(dupe_search_range)

	for(var/A in dupe_search_range)
		var/list/objectives_to_compare
		if(istype(A,/datum/mind))
			var/datum/mind/M = A
			objectives_to_compare = M.get_all_objectives()
		else if(istype(A,/datum/antagonist))
			var/datum/antagonist/G = A
			objectives_to_compare = G.objectives
		else if(istype(A,/datum/team))
			var/datum/team/T = A
			objectives_to_compare = T.objectives
		for(var/datum/objective/O in objectives_to_compare)
			if(istype(O, type) && O.get_target() == possible_target)
				return FALSE
	return TRUE

/datum/objective/proc/get_target()
	return target

/datum/objective/proc/get_crewmember_minds()
	. = list()
	for(var/V in GLOB.data_core.locked)
		var/datum/data/record/R = V
		var/datum/mind/M = R.fields["mindref"]
		if(M)
			. += M

//dupe_search_range is a list of antag datums / minds / teams
/datum/objective/proc/find_target(dupe_search_range, blacklist)
	var/list/datum/mind/owners = get_owners()
	if(!dupe_search_range)
		dupe_search_range = get_owners()
	var/list/possible_targets = list()
	var/try_target_late_joiners = FALSE
	for(var/I in owners)
		var/datum/mind/O = I
		if(O.late_joiner)
			try_target_late_joiners = TRUE
	for(var/datum/mind/possible_target in get_crewmember_minds())
		if(is_valid_target(possible_target) && !(possible_target in owners) && ishuman(possible_target.current) && (possible_target.current.stat != DEAD) && is_unique_objective(possible_target,dupe_search_range))
			//yogs start -- Quiet Rounds
			var/mob/living/carbon/human/guy = possible_target.current
			if(possible_target.antag_datums || !(guy.client && (guy.client.prefs.yogtoggles & QUIET_ROUND)))
				if (!(possible_target in blacklist))
					possible_targets += possible_target//yogs indent
			//yogs end
	if(try_target_late_joiners)
		var/list/all_possible_targets = possible_targets.Copy()
		for(var/I in all_possible_targets)
			var/datum/mind/PT = I
			if(!PT.late_joiner)
				possible_targets -= PT
		if(!possible_targets.len)
			possible_targets = all_possible_targets
	if(possible_targets.len > 0)
		target = pick(possible_targets)
	update_explanation_text()
	return target

/datum/objective/proc/find_target_by_role(role, role_type=FALSE,invert=FALSE)//Option sets either to check assigned role or special role. Default to assigned., invert inverts the check, eg: "Don't choose a Ling"
	var/list/datum/mind/owners = get_owners()
	var/list/possible_targets = list()
	for(var/datum/mind/possible_target in get_crewmember_minds())
		if(!(possible_target in owners) && ishuman(possible_target.current))
		// yogs start
			if(possible_target.quiet_round)
				continue
		// yogs end
			var/is_role = FALSE
			if(role_type)
				if(possible_target.special_role == role)
					is_role = TRUE
			else
				if(possible_target.assigned_role == role)
					is_role = TRUE

			if(invert)
				if(is_role)
					continue
				possible_targets += possible_target
				break
			else if(is_role)
				possible_targets += possible_target
				break
	if(length(possible_targets))
		target = pick(possible_targets)
	update_explanation_text()
	return target

/datum/objective/proc/update_explanation_text()
	if(team_explanation_text && LAZYLEN(get_owners()) > 1)
		explanation_text = team_explanation_text

/datum/objective/proc/give_special_equipment(special_equipment)
	if(istype(team, /datum/team/infiltrator))
		for(var/eq_path in special_equipment)
			if(eq_path)
				for(var/turf/T in GLOB.infiltrator_objective_items)
					if(!(eq_path in T.contents))
						new eq_path(T)
		return
	var/datum/mind/receiver = pick(get_owners())
	if(receiver && receiver.current)
		if(ishuman(receiver.current))
			var/mob/living/carbon/human/H = receiver.current
			var/list/slots = list("backpack" = ITEM_SLOT_BACKPACK)
			for(var/eq_path in special_equipment)
				var/obj/O = new eq_path
				H.equip_in_one_of_slots(O, slots)

/// Copy the target from the other objective
/datum/objective/proc/copy_target(datum/objective/old_obj)
	target = old_obj.get_target()
	target_amount = old_obj.target_amount
	explanation_text = explanation_text

/datum/objective/assassinate
	name = "assassinate"
	var/target_role_type=FALSE
	martyr_compatible = 1

/datum/objective/assassinate/find_target_by_role(role, role_type=FALSE,invert=FALSE)
	if(!invert)
		target_role_type = role_type
	..()

/datum/objective/assassinate/check_completion()
	return completed || (!considered_alive(target) || considered_afk(target))

/datum/objective/assassinate/update_explanation_text()
	..()
	if(target && target.current)
		if(ishuman(target.current))
			var/mob/living/carbon/human/H = target.current
			// This should just check for an uppercase flag
			explanation_text = "Assassinate [target.name], the [isipc(H) ? H.dna.species.name : lowertext(H.dna.species.name)] [!target_role_type ? target.assigned_role : target.special_role]."
		else
			explanation_text = "Assassinate [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/assassinate/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/assassinate/once
	name = "assassinate revival allowed"

/datum/objective/assassinate/once/update_explanation_text()
	START_PROCESSING(SSprocessing, src)
	if(target && target.current)
		if(ishuman(target.current))
			var/mob/living/carbon/human/H = target.current
			explanation_text = "Ensure [target.name], the [lowertext(H.dna.species.name)] [!target_role_type ? target.assigned_role : target.special_role] has died at least once."
		else
			explanation_text = "Ensure [target.name], the [!target_role_type ? target.assigned_role : target.special_role] has died at least once."
	else
		explanation_text = "Free Objective"

/datum/objective/assassinate/once/process()
	if(target?.current?.stat == DEAD)
		completed = TRUE
		STOP_PROCESSING(SSprocessing, src)

/datum/objective/assassinate/cloned
	name = "assassinate cloning allowed"
	var/mob/living/original

/datum/objective/assassinate/cloned/update_explanation_text()
	if(target && target.current)
		if(ishuman(target.current))
			var/mob/living/carbon/human/H = target.current
			explanation_text = "Ensure the [lowertext(H.dna.species.name)] [!target_role_type ? target.assigned_role : target.special_role] [target.name]'s original body is dead."
		else
			explanation_text = "Ensure the [!target_role_type ? target.assigned_role : target.special_role] [target.name]'s original body is dead."
		original = target.current
	else
		explanation_text = "Free Objective"

/datum/objective/assassinate/cloned/check_completion()
	. = ..()
	if(.)
		return
	if(target && target.current != original)
		return TRUE

/datum/objective/assassinate/internal
	var/stolen = 0 		//Have we already eliminated this target?

/datum/objective/assassinate/internal/update_explanation_text()
	..()
	if(target && !target.current)
		explanation_text = "Assassinate [target.name], who was obliterated."

/datum/objective/mutiny
	name = "mutiny"
	var/target_role_type=FALSE
	martyr_compatible = 1

/datum/objective/mutiny/find_target_by_role(role, role_type=FALSE,invert=FALSE)
	if(!invert)
		target_role_type = role_type
	..()

/datum/objective/mutiny/check_completion()
	if(..())
		return TRUE
	if(!target || !considered_alive(target) || considered_afk(target))
		return TRUE
	var/turf/T = get_turf(target.current)
	return !T || !is_station_level(T.z)

/datum/objective/mutiny/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Assassinate or exile [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/maroon
	name = "maroon"
	var/target_role_type=FALSE
	martyr_compatible = 1

/datum/objective/maroon/find_target_by_role(role, role_type=FALSE,invert=FALSE)
	if(!invert)
		target_role_type = role_type
	..()

/datum/objective/maroon/check_completion()
	if(..())
		return TRUE
	return !target || !considered_alive(target) || (!target.current.onCentCom() && !target.current.onSyndieBase())

/datum/objective/maroon/update_explanation_text()
	if(target && target.current)
		if(ishuman(target.current))
			var/mob/living/carbon/human/H = target.current
			explanation_text = "Prevent [target.name], the [lowertext(H.dna.species.name)] [!target_role_type ? target.assigned_role : target.special_role], from escaping alive."
		else
			explanation_text = "Prevent [target.name], the [!target_role_type ? target.assigned_role : target.special_role], from escaping alive."
	else
		explanation_text = "Free Objective"

/datum/objective/maroon/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/debrain
	name = "debrain"
	var/target_role_type=0

/datum/objective/debrain/find_target_by_role(role, role_type=FALSE,invert=FALSE)
	if(!invert)
		target_role_type = role_type
	..()

/datum/objective/debrain/check_completion()
	if(..())
		return TRUE
	if(!target)//If it's a free objective.
		return TRUE
	if(!target.current || !isbrain(target.current))
		return FALSE
	var/atom/A = target.current
	var/list/datum/mind/owners = get_owners()

	while(A.loc) // Check to see if the brainmob is on our person
		A = A.loc
		for(var/datum/mind/M in owners)
			if(M.current && M.current.stat != DEAD && A == M.current)
				return TRUE
	return FALSE

/datum/objective/debrain/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Steal the brain of [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/debrain/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/protect//The opposite of killing a dude.
	name = "protect"
	martyr_compatible = 1
	var/target_role_type = FALSE
	var/human_check = TRUE

/datum/objective/protect/find_target_by_role(role, role_type=FALSE,invert=FALSE)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/protect/check_completion()
	if(..())
		return TRUE
	return !target || considered_alive(target, enforce_human = human_check)

/datum/objective/protect/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Protect [target.name], the [!target_role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"

/datum/objective/protect/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/protect/nonhuman
	name = "protect nonhuman"
	human_check = FALSE

/datum/objective/assist
	name = "assist"
	var/target_role_type
	martyr_compatible = TRUE

/datum/objective/assist/find_target_by_role(role, role_type=FALSE,invert=FALSE)
	if(!invert)
		target_role_type = role_type
	..()
	return target

/datum/objective/assist/check_completion()
	if(..())
		return TRUE
	if(target)
		for(var/datum/antagonist/antag in target.antag_datums)
			for(var/datum/objective/O in antag.objectives)
				if(istype(O, /datum/objective/assist))//assuming someone gives people assist objectives in a circle for some reason
					continue
				if(!O.check_completion())
					return FALSE
	return TRUE

/datum/objective/assist/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Ensure [target.name], the [!target_role_type ? target.assigned_role : target.special_role] completes their objectives."
	else
		explanation_text = "Free Objective"

/datum/objective/assist/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/hijack
	name = "hijack"
	explanation_text = "Hijack the shuttle to ensure no loyalist Nanotrasen crew escape alive and out of custody."
	team_explanation_text = "Hijack the shuttle to ensure no loyalist Nanotrasen crew escape alive and out of custody. Leave no team member behind."
	martyr_compatible = 0 //Technically you won't get both anyway.

/datum/objective/hijack/check_completion() // Requires all owners to escape.
	if(..())
		return TRUE
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return FALSE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_alive(M) || !SSshuttle.emergency.shuttle_areas[get_area(M.current)])
			return FALSE
	return SSshuttle.emergency.is_hijacked()

/datum/objective/block
	name = "no organics on shuttle"
	explanation_text = "Do not allow any organic lifeforms to escape on the shuttle alive."
	martyr_compatible = 1

/datum/objective/block/check_completion()
	if(..())
		return TRUE
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return TRUE
	for(var/mob/living/player in GLOB.player_list)
		if(player.mind && player.stat != DEAD && ((MOB_ORGANIC in player.mob_biotypes) || !(MOB_ROBOTIC in player.mob_biotypes)))
			if(get_area(player) in SSshuttle.emergency.shuttle_areas)
				return FALSE
	return TRUE

/datum/objective/purge
	name = "no mutants on shuttle"
	explanation_text = "Ensure no mutant humanoids or nonhuman species are present aboard the escape shuttle. Felinids/Catpeople do NOT count as nonhuman."
	martyr_compatible = 1

/datum/objective/purge/check_completion()
	if(..())
		return TRUE
	if(SSshuttle.emergency.mode != SHUTTLE_ENDGAME)
		return TRUE
	for(var/mob/living/player in GLOB.player_list)
		if((get_area(player) in SSshuttle.emergency.shuttle_areas) && player.mind && player.stat != DEAD && ishuman(player))
			var/mob/living/carbon/human/H = player
			if(!ishumanbasic(H))
				return FALSE
	return TRUE

/datum/objective/robot_army
	name = "robot army"
	martyr_compatible = 0
	var/number_of_borgs = 2

/datum/objective/robot_army/New()
	. = ..()
	number_of_borgs = ROUND_UP((length(GLOB.joined_player_list) / 10) + 2)
	explanation_text = "Have at least [number_of_borgs] active cyborgs synced to you."

/datum/objective/robot_army/check_completion()
	if(..())
		return TRUE
	var/counter = 0
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!M.current || !isAI(M.current))
			continue
		var/mob/living/silicon/ai/A = M.current
		for(var/mob/living/silicon/robot/R in A.connected_robots)
			if(R.stat != DEAD)
				counter++
	return counter >= number_of_borgs

/datum/objective/escape
	name = "escape"
	explanation_text = "Escape on the shuttle or an escape pod alive and without being in custody."
	team_explanation_text = "Have all members of your team escape on a shuttle or pod alive, without being in custody."

/datum/objective/escape/check_completion()
	if(..())
		return TRUE
	// Require all owners escape safely.
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_escaped(M))
			return FALSE
	return TRUE

/datum/objective/escape/onesurvivor
	name = "escape team can die"
	team_explanation_text = "Have all members of your team escape outside custody on a shuttle or pod, with at least one surviving member."

/datum/objective/escape/onesurvivor/check_completion()
	if(completed)
		return TRUE
	var/has_survivor = FALSE	//is there a surviving member of the team?
	var/list/datum/mind/owners = get_owners()
	for(var/O in owners)
		var/datum/mind/M = O
		if(!considered_escaped(M, FALSE)) //NO MAN LEFT BEHIND
			return FALSE
		if(considered_alive(M))
			has_survivor = TRUE
	return has_survivor

/datum/objective/escape/escape_with_identity/is_valid_target(possible_target)
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		if(!M.has_antag_datum(/datum/antagonist/changeling))
			continue
		var/datum/mind/T = possible_target
		if(!istype(T)) // if you can't absorb them you shouldn't have an objective to do so
			return FALSE
		if(ishuman(T.current))
			var/mob/living/carbon/human/H = T.current
			if((NO_DNA_COPY in H.dna.species.species_traits) || (NOHUSK in H.dna.species.species_traits))
				return FALSE
	return TRUE

/datum/objective/escape/escape_with_identity
	name = "escape with identity"
	var/target_real_name // Has to be stored because the target's real_name can change over the course of the round
	var/target_missing_id

/datum/objective/escape/escape_with_identity/find_target(dupe_search_range, blacklist)
	target = ..()
	update_explanation_text()

/datum/objective/escape/escape_with_identity/update_explanation_text()
	if(target && target.current)
		target_real_name = target.current.real_name
		explanation_text = "Escape on the shuttle or an escape pod with the identity of [target_real_name], the [target.assigned_role]"
		var/mob/living/carbon/human/H
		if(ishuman(target.current))
			H = target.current
		if(H && H.get_id_name() != target_real_name)
			target_missing_id = 1
		else
			explanation_text += " while wearing their identification card"
		explanation_text += "." //Proper punctuation is important!

	else
		explanation_text = "Free Objective."

/datum/objective/escape/escape_with_identity/check_completion()
	if(..())
		return TRUE
	if(!target || !target_real_name)
		return TRUE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!ishuman(M.current) || !considered_escaped(M))
			continue
		var/mob/living/carbon/human/H = M.current
		if(H.dna.real_name == target_real_name && (H.get_id_name() == target_real_name || target_missing_id))
			return TRUE
	return FALSE

/datum/objective/escape/escape_with_identity/admin_edit(mob/admin)
	admin_simple_target_pick(admin)

/datum/objective/escape/escape_with_identity/copy_target(datum/objective/escape/escape_with_identity/old_obj)
	target_real_name = old_obj.target_real_name
	target_missing_id = old_obj.target_missing_id

/datum/objective/survive
	name = "survive"
	explanation_text = "Stay alive until the end."

/datum/objective/survive/check_completion()
	if(..())
		return TRUE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_alive(M))
			return FALSE
	return TRUE

/datum/objective/survive/exist //Like survive, but works for silicons and zombies and such.
	name = "survive nonhuman"

/datum/objective/survive/exist/check_completion()
	if(..())
		return TRUE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!considered_alive(M, FALSE))
			return FALSE
	return TRUE

/datum/objective/martyr
	name = "martyr"
	explanation_text = "Die a glorious death."

/datum/objective/martyr/check_completion()
	if(..())
		return TRUE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(considered_alive(M))
			return FALSE
		if(M.current?.suiciding) //killing yourself ISN'T glorious.
			return FALSE
	return TRUE

/datum/objective/nuclear
	name = "nuclear"
	explanation_text = "Destroy the station with a nuclear device."
	martyr_compatible = 1

/datum/objective/nuclear/check_completion()
	if(..())
		return TRUE
	if(SSticker && SSticker.mode && SSticker.mode.station_was_nuked)
		return TRUE
	return FALSE

GLOBAL_LIST_EMPTY(possible_items)
/datum/objective/steal
	name = "steal"
	var/datum/objective_item/targetinfo = null //Save the chosen item datum so we can access it later.
	var/obj/item/steal_target = null //Needed for custom objectives (they're just items, not datums).
	martyr_compatible = 0

/datum/objective/steal/get_target()
	return steal_target

/datum/objective/steal/New()
	..()
	if(!GLOB.possible_items.len)//Only need to fill the list when it's needed.
		for(var/I in subtypesof(/datum/objective_item/steal))
			new I

/datum/objective/steal/find_target(dupe_search_range, blacklist)
	var/list/datum/mind/owners = get_owners()
	if(!dupe_search_range)
		dupe_search_range = get_owners()
	var/approved_targets = list()
	check_items:
		for(var/datum/objective_item/possible_item in GLOB.possible_items)
			if(!is_unique_objective(possible_item.targetitem,dupe_search_range))
				continue
			for(var/datum/mind/M in owners)
				if(M.assigned_role in possible_item.excludefromjob)
					continue check_items
			approved_targets += possible_item
	return set_target(pick(approved_targets))

/datum/objective/steal/proc/set_target(datum/objective_item/item)
	if(item)
		targetinfo = item
		targetinfo.objective = src
		steal_target = targetinfo.targetitem
		explanation_text = "Steal [targetinfo.name]"
		give_special_equipment(targetinfo.special_equipment)
		return steal_target
	else
		explanation_text = "Free objective"
		return

/datum/objective/steal/copy_target(datum/objective/steal/old_obj)
	. = ..()
	set_target(old_obj.targetinfo)

/datum/objective/steal/admin_edit(mob/admin)
	var/list/possible_items_all = GLOB.possible_items+"custom"
	var/new_target = input(admin,"Select target:", "Objective target", steal_target) as null|anything in possible_items_all
	if (!new_target)
		return

	if (new_target == "custom") //Can set custom items.
		var/custom_path = input(admin,"Search for target item type:","Type") as null|text
		if (!custom_path)
			return
		var/obj/item/custom_target = pick_closest_path(custom_path, make_types_fancy(subtypesof(/obj/item)))
		var/custom_name = initial(custom_target.name)
		custom_name = stripped_input(admin,"Enter target name:", "Objective target", custom_name)
		if (!custom_name)
			return
		steal_target = custom_target
		explanation_text = "Steal [custom_name]."

	else
		set_target(new_target)

/datum/objective/steal/check_completion()
	if(..())
		return TRUE
	var/list/datum/mind/owners = get_owners()
	if(!steal_target)
		return TRUE
	for(var/datum/mind/M in owners)
		if(!isliving(M.current))
			continue

		var/list/all_items = M.current.get_all_contents()	//this should get things in cheesewheels, books, etc.

		for(var/obj/I in all_items) //Check for items
			if(istype(I, steal_target))
				if(!targetinfo) //If there's no targetinfo, then that means it was a custom objective. At this point, we know you have the item, so return 1.
					return TRUE
				else if(targetinfo.check_special_completion(I))//Returns 1 by default. Items with special checks will return 1 if the conditions are fulfilled.
					return TRUE

			if(targetinfo && (I.type in targetinfo.altitems)) //Ok, so you don't have the item. Do you have an alternative, at least?
				if(targetinfo.check_special_completion(I))//Yeah, we do! Don't return 0 if we don't though - then you could fail if you had 1 item that didn't pass and got checked first!
					return TRUE
	if (istype(team, /datum/team/infiltrator))
		for (var/area/A in world)
			if (is_type_in_typecache(A, GLOB.infiltrator_objective_areas))
				for (var/obj/item/I in A.get_all_contents()) //Check for items
					if (istype(I, steal_target))
						if (!targetinfo)
							return TRUE
						else if (targetinfo.check_special_completion(I))
							return TRUE
					if (targetinfo && (I.type in targetinfo.altitems))
						if (targetinfo.check_special_completion(I))
							return TRUE
					CHECK_TICK
			CHECK_TICK
		CHECK_TICK
	return FALSE

GLOBAL_LIST_EMPTY(possible_items_special)
/datum/objective/steal/special //ninjas are so special they get their own subtype good for them
	name = "steal special"

/datum/objective/steal/special/New()
	..()
	if(!GLOB.possible_items_special.len)
		for(var/I in subtypesof(/datum/objective_item/special) + subtypesof(/datum/objective_item/stack))
			new I

/datum/objective/steal/special/find_target(dupe_search_range, blacklist)
	return set_target(pick(GLOB.possible_items_special))

/datum/objective/steal/exchange
	name = "exchange"
	martyr_compatible = 0

/datum/objective/steal/exchange/admin_edit(mob/admin)
	return

/datum/objective/steal/exchange/proc/set_faction(faction,otheragent)
	target = otheragent
	if(faction == "red")
		targetinfo = new/datum/objective_item/unique/docs_blue
	else if(faction == "blue")
		targetinfo = new/datum/objective_item/unique/docs_red
	explanation_text = "Acquire [targetinfo.name] held by [target.current.real_name], the [target.assigned_role] and syndicate agent"
	steal_target = targetinfo.targetitem


/datum/objective/steal/exchange/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Acquire [targetinfo.name] held by [target.name], the [target.assigned_role] and syndicate agent"
	else
		explanation_text = "Free Objective"


/datum/objective/steal/exchange/backstab
	name = "prevent exchange"

/datum/objective/steal/exchange/backstab/set_faction(faction)
	if(faction == "red")
		targetinfo = new/datum/objective_item/unique/docs_red
	else if(faction == "blue")
		targetinfo = new/datum/objective_item/unique/docs_blue
	explanation_text = "Do not give up or lose [targetinfo.name]."
	steal_target = targetinfo.targetitem


/datum/objective/download
	name = "download"

/datum/objective/download/proc/gen_amount_goal()
	target_amount = rand(20,40)
	update_explanation_text()
	return target_amount

/datum/objective/download/update_explanation_text()
	..()
	explanation_text = "Download [target_amount] research node\s."

/datum/objective/download/check_completion()
	if(..())
		return TRUE
	var/datum/techweb/checking = new
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/owner in owners)
		if(ismob(owner.current))
			var/mob/M = owner.current			//Yeah if you get morphed and you eat a quantum tech disk with the RD's latest backup good on you soldier.
			if(ishuman(M))
				var/mob/living/carbon/human/H = M
				if(H && (H.stat != DEAD) && istype(H.wear_suit, /obj/item/clothing/suit/space/space_ninja))
					var/obj/item/clothing/suit/space/space_ninja/S = H.wear_suit
					S.stored_research.copy_research_to(checking)
			var/list/otherwise = M.get_all_contents()
			for(var/obj/item/disk/tech_disk/TD in otherwise)
				TD.stored_research.copy_research_to(checking)
	if (istype(team, /datum/team/infiltrator))
		for (var/area/A in world)
			if (is_type_in_typecache(A, GLOB.infiltrator_objective_areas))
				for (var/obj/item/disk/tech_disk/TD in A.get_all_contents()) //Check for items
					TD.stored_research.copy_research_to(checking)
				CHECK_TICK
			CHECK_TICK
		CHECK_TICK
	return checking.researched_nodes.len >= target_amount

/datum/objective/download/admin_edit(mob/admin)
	var/count = input(admin,"How many nodes ?","Nodes",target_amount) as num|null
	if(count)
		target_amount = count
	update_explanation_text()

/datum/objective/capture
	name = "capture"

/datum/objective/capture/proc/gen_amount_goal()
	target_amount = rand(3,5)
	update_explanation_text()
	return target_amount

/datum/objective/capture/update_explanation_text()
	. = ..()
	explanation_text = "Capture [target_amount] lifeform\s with an energy net. Live, rare specimens are worth more."

/datum/objective/capture/check_completion()//Basically runs through all the mobs in the area to determine how much they are worth.
	if(..())
		return TRUE
	var/captured_amount = 0
	var/area/centcom/holding/A = GLOB.areas_by_type[/area/centcom/holding]
	for(var/mob/living/carbon/human/M in A)//Humans.
		if(!istype(src,/datum/objective/capture/living) && M.stat == DEAD)
			captured_amount+= 0.5
		else
			captured_amount+= 1 //dont care if they are dead or alive in living capture because you shouldn't be able to capture them if they dead
	for(var/mob/living/carbon/monkey/M in A)//Monkeys are almost worthless, you failure.
		captured_amount+=0.1
	for(var/mob/living/carbon/alien/larva/M in A)//Larva are important for research.
		if(M.stat == DEAD)
			captured_amount+=0.5
			continue
		captured_amount+=1
	for(var/mob/living/carbon/alien/humanoid/M in A)//Aliens are worth twice as much as humans.
		if(istype(M, /mob/living/carbon/alien/humanoid/royal/queen))//Queens are worth three times as much as humans.
			if(M.stat == DEAD)
				captured_amount+=1.5
			else
				captured_amount+=3
			continue
		if(M.stat == DEAD)
			captured_amount+=1
			continue
		captured_amount+=2
	return captured_amount >= target_amount

/datum/objective/capture/admin_edit(mob/admin)
	var/count = input(admin,"How many mobs to capture ?","capture",target_amount) as num|null
	if(count)
		target_amount = count
	update_explanation_text()

/datum/objective/capture/living
	name = "capture living"

/datum/objective/capture/living/update_explanation_text()
	. = ..()
	explanation_text = "Capture [target_amount] sapient lifeform\s with an energy net. Only living specimens count."

/datum/objective/protect_object
	name = "protect object"
	var/obj/protect_target

/datum/objective/protect_object/proc/set_target(obj/O)
	protect_target = O
	update_explanation_text()

/datum/objective/protect_object/update_explanation_text()
	. = ..()
	if(protect_target)
		explanation_text = "Protect \the [protect_target] at all costs."
	else
		explanation_text = "Free objective."

/datum/objective/protect_object/check_completion()
	if(..())
		return TRUE
	return !QDELETED(protect_target)

//Changeling Objectives

/datum/objective/absorb
	name = "absorb"

/datum/objective/absorb/proc/gen_amount_goal(lowbound = 4, highbound = 6)
	target_amount = rand (lowbound,highbound)
	var/n_p = 1 //autowin
	var/list/datum/mind/owners = get_owners()
	if (SSticker.current_state == GAME_STATE_SETTING_UP)
		for(var/mob/dead/new_player/P in GLOB.player_list)
			if(P.client && P.ready == PLAYER_READY_TO_PLAY && !(P.mind in owners))
				n_p ++
	else if (SSticker.IsRoundInProgress())
		for(var/mob/living/carbon/human/P in GLOB.player_list)
			if(P.client && !(P.mind.has_antag_datum(/datum/antagonist/changeling)) && !(P.mind in owners))
				n_p ++
	target_amount = min(target_amount, n_p)

	update_explanation_text()
	return target_amount

/datum/objective/absorb/update_explanation_text()
	. = ..()
	explanation_text = "Extract [target_amount] compatible genome\s."

/datum/objective/absorb/admin_edit(mob/admin)
	var/count = input(admin,"How many people to absorb?","absorb",target_amount) as num|null
	if(count)
		target_amount = count
	update_explanation_text()

/datum/objective/absorb/check_completion()
	if(..())
		return TRUE
	var/list/datum/mind/owners = get_owners()
	var/absorbedcount = 0
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		var/datum/antagonist/changeling/changeling = M.has_antag_datum(/datum/antagonist/changeling)
		if(!changeling || !changeling.stored_profiles)
			continue
		absorbedcount += changeling.absorbedcount
	return absorbedcount >= target_amount

/datum/objective/absorb_most
	name = "absorb most"
	explanation_text = "Extract more compatible genomes than any other Changeling."

/datum/objective/absorb_most/check_completion()
	if(..())
		return TRUE
	var/list/datum/mind/owners = get_owners()
	var/absorbedcount = 0
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		var/datum/antagonist/changeling/changeling = M.has_antag_datum(/datum/antagonist/changeling)
		if(!changeling || !changeling.stored_profiles)
			continue
		absorbedcount += changeling.absorbedcount

	for(var/datum/antagonist/changeling/changeling2 in GLOB.antagonists)
		if(!changeling2.owner || changeling2.owner == owner || !changeling2.stored_profiles || changeling2.absorbedcount < absorbedcount)
			continue
		return FALSE
	return TRUE

/datum/objective/absorb_changeling
	name = "absorb changeling"
	explanation_text = "Absorb another Changeling."

/datum/objective/absorb_changeling/check_completion()
	if(..())
		return TRUE
	var/list/datum/mind/owners = get_owners()
	for(var/datum/mind/M in owners)
		if(!M)
			continue
		var/datum/antagonist/changeling/changeling = M.has_antag_datum(/datum/antagonist/changeling)
		if(!changeling)
			continue
		var/total_genetic_points = changeling.geneticpoints

		for(var/datum/action/changeling/p in changeling.purchasedpowers)
			total_genetic_points += p.dna_cost

		if(total_genetic_points > initial(changeling.geneticpoints))
			return TRUE
	return FALSE

//End Changeling Objectives

/datum/objective/destroy
	name = "destroy AI"
	martyr_compatible = 1

/datum/objective/destroy/find_target(dupe_search_range, blacklist)
	var/list/possible_targets = active_ais(1)
	var/mob/living/silicon/ai/target_ai = pick(possible_targets)
	target = target_ai.mind
	update_explanation_text()
	return target

/datum/objective/destroy/check_completion()
	if(..())
		return TRUE
	if(target && target.current)
		return target.current.stat == DEAD || target.current.z > 6 || !target.current.ckey //Borgs/brains/AIs count as dead for traitor objectives.
	return TRUE

/datum/objective/destroy/update_explanation_text()
	..()
	if(target && target.current)
		explanation_text = "Destroy [target.name], the experimental AI."
	else
		explanation_text = "Free Objective"

/datum/objective/destroy/admin_edit(mob/admin)
	var/list/possible_targets = active_ais(1)
	if(possible_targets.len)
		var/mob/new_target = input(admin,"Select target:", "Objective target") as null|anything in possible_targets
		target = new_target.mind
	else
		to_chat(admin, span_warning("No active AIs with minds!"))
	update_explanation_text()

/datum/objective/destroy/internal
	var/stolen = FALSE 		//Have we already eliminated this target?

/datum/objective/steal_n_of_type
	name = "steal five of"
	explanation_text = "Steal some items!"
	//what types we want to steal
	var/list/wanted_items = list()
	//how many we want to steal
	var/amount = 5

/datum/objective/steal_n_of_type/New()
	..()
	wanted_items = typecacheof(wanted_items)

/datum/objective/steal_n_of_type/check_completion()
	var/list/datum/mind/owners = get_owners()
	var/stolen_count = 0
	for(var/datum/mind/M in owners)
		if(!isliving(M.current))
			continue
		var/list/all_items = M.current.get_all_contents() //this should get things in cheesewheels, books, etc.
		for(var/obj/current_item in all_items) //Check for wanted items
			if(is_type_in_typecache(current_item, wanted_items))
				if(check_if_valid_item(current_item))
					stolen_count++
	return stolen_count >= amount

/datum/objective/steal_n_of_type/proc/check_if_valid_item(obj/item/current_item)
	return TRUE

/datum/objective/steal_n_of_type/summon_guns
	name = "steal guns"
	explanation_text = "Steal at least five guns!"
	wanted_items = list(/obj/item/gun)
	amount = 5

/datum/objective/steal_n_of_type/summon_guns/check_if_valid_item(obj/item/current_item)
	var/obj/item/gun/gun = current_item
//	return !(gun.gun_flags & NOT_A_REAL_GUN)
	return istype(gun)

/datum/objective/steal_n_of_type/summon_magic
	name = "steal magic"
	explanation_text = "Steal at least five magical artefacts!"
	wanted_items = list()
	amount = 5

/datum/objective/steal_n_of_type/summon_magic/New()
	wanted_items = GLOB.summoned_magic_objectives
	..()

/datum/objective/steal_n_of_type/summon_magic/check_completion()
	var/list/datum/mind/owners = get_owners()
	var/stolen_count = 0
	for(var/datum/mind/M in owners)
		if(!isliving(M.current))
			continue
		var/list/all_items = M.current.get_all_contents() //this should get things in cheesewheels, books, etc.
		for(var/obj/thing in all_items) //Check for wanted items
			if(istype(thing, /obj/item/book/granter/action/spell))
				var/obj/item/book/granter/action/spell/spellbook = thing
				if(spellbook.uses > 0) //if the book still has powers...
					stolen_count++ //it counts. nice.
			else if(is_type_in_typecache(thing, wanted_items))
				stolen_count++
	return stolen_count >= amount

/datum/objective/steal_n_of_type/organs
	name = "steal organs"
	explanation_text = "Steal at least 5 organic organs! They must be kept healthy."
	wanted_items = list(/obj/item/organ)
	amount = 5 //i want this to be higher, but the organs must be fresh at roundend

/datum/objective/steal_n_of_type/organs/check_completion()
	var/list/datum/mind/owners = get_owners()
	var/stolen_count = 0
	for(var/datum/mind/mind in owners)
		if(!isliving(mind.current))
			continue
		var/list/all_items = mind.current.get_all_contents() //this should get things in cheesewheels, books, etc.
		for(var/obj/item/stolen in all_items) //Check for wanted items
			var/found = FALSE
			for(var/wanted_type in wanted_items)
				if(istype(stolen, wanted_type))
					found = TRUE
					break
			if(!found)
				continue
			//this is an objective item
			var/obj/item/organ/wanted = stolen
			if(!(wanted.organ_flags & ORGAN_FAILING) && !(wanted.organ_flags & ORGAN_SYNTHETIC))
				stolen_count++
	return stolen_count >= amount


//Created by admin tools
/datum/objective/custom
	name = "custom"

/datum/objective/custom/admin_edit(mob/admin)
	var/expl = stripped_input(admin, "Custom objective:", "Objective", explanation_text)
	if(expl)
		explanation_text = expl

////////////////////////////////
// Changeling team objectives //
////////////////////////////////

/datum/objective/changeling_team_objective //Abstract type
	martyr_compatible = 0	//Suicide is not teamwork!
	explanation_text = "Changeling Friendship!"
	var/min_lings = 3 //Minimum amount of lings for this team objective to be possible
	var/escape_objective_compatible = FALSE

/datum/objective/changeling_team_objective/proc/prepare()
	return FALSE

//Impersonate department
//Picks as many people as it can from a department (Security,Engineer,Medical,Science)
//and tasks the lings with killing and replacing them
/datum/objective/changeling_team_objective/impersonate_department
	explanation_text = "Ensure X department are killed, impersonated, and replaced by Changelings."
	var/command_staff_only = FALSE //if this is true, it picks command staff instead
	var/list/department_minds = list()
	var/list/department_real_names = list()
	var/department_string = ""


/datum/objective/changeling_team_objective/impersonate_department/prepare()
	var/result = FALSE
	if(command_staff_only)
		result = get_heads()
	else
		result = get_department_staff()
	if(result)
		update_explanation_text()
		return TRUE
	else
		return FALSE


/datum/objective/changeling_team_objective/impersonate_department/proc/get_department_staff()
	department_minds = list()
	department_real_names = list()

	var/list/departments = list("Head of Security","Research Director","Chief Engineer","Chief Medical Officer")
	var/department_head = pick(departments)
	switch(department_head)
		if("Head of Security")
			department_string = "security"
		if("Research Director")
			department_string = "science"
		if("Chief Engineer")
			department_string = "engineering"
		if("Chief Medical Officer")
			department_string = "medical"

	var/list/lings = get_antag_minds(/datum/antagonist/changeling,TRUE)
	var/ling_count = lings.len

	for(var/datum/mind/M in SSticker.minds)
		if(M in lings)
			continue
		if(isipc(M.current))
			continue
		if(department_head in get_department_heads(M.assigned_role))
			if(ling_count)
				ling_count--
				department_minds += M
				department_real_names += M.current.real_name
			else
				break

	if(!department_minds.len)
		log_game("[type] has failed to find department staff, and has removed itself. the round will continue normally")
		return FALSE
	return TRUE


/datum/objective/changeling_team_objective/impersonate_department/proc/get_heads()
	department_minds = list()
	department_real_names = list()

	//Needed heads is between min_lings and the maximum possible amount of command roles
	//So at the time of writing, rand(3,6), it's also capped by the amount of lings there are
	//Because you can't fill 6 head roles with 3 lings
	var/list/lings = get_antag_minds(/datum/antagonist/changeling,TRUE)
	var/needed_heads = rand(min_lings,GLOB.command_positions.len)
	needed_heads = min(lings.len,needed_heads)

	var/list/heads = SSjob.get_living_heads()
	for(var/datum/mind/head in heads)
		if(head in lings) //Looking at you HoP.
			continue
		if(isipc(head.current))
			continue
		if(needed_heads)
			department_minds += head
			department_real_names += head.current.real_name
			needed_heads--
		else
			break

	if(!department_minds.len)
		log_game("[type] has failed to find department heads, and has removed itself. the round will continue normally")
		return FALSE
	return TRUE


/datum/objective/changeling_team_objective/impersonate_department/update_explanation_text()
	..()
	if(!department_real_names.len || !department_minds.len)
		explanation_text = "Free Objective"
		return  //Something fucked up, give them a win

	if(command_staff_only)
		explanation_text = "Ensure changelings impersonate and escape as the following heads of staff: "
	else
		explanation_text = "Ensure changelings impersonate and escape as the following members of \the [department_string] department: "

	var/first = 1
	for(var/datum/mind/M in department_minds)
		var/string = "[M.name] the [M.assigned_role]"
		if(!first)
			string = ", [M.name] the [M.assigned_role]"
		else
			first--
		explanation_text += string

	if(command_staff_only)
		explanation_text += ", while the real heads are dead. This is a team objective."
	else
		explanation_text += ", while the real members are dead. This is a team objective."


/datum/objective/changeling_team_objective/impersonate_department/check_completion()
	if(..())
		return TRUE
	if(!department_real_names.len || !department_minds.len)
		return TRUE //Something fucked up, give them a win

	var/list/check_names = department_real_names.Copy()

	//Check each department member's mind to see if any of them made it to centcom alive, if they did it's an automatic fail
	for(var/datum/mind/M in department_minds)
		if(M.has_antag_datum(/datum/antagonist/changeling)) //Lings aren't picked for this, but let's be safe
			continue

		if(M.current)
			var/turf/mloc = get_turf(M.current)
			if(mloc.onCentCom() && (M.current.stat != DEAD))
				return FALSE //A Non-ling living target got to centcom, fail

	//Check each staff member has been replaced, by cross referencing changeling minds, changeling current dna, the staff minds and their original DNA names
	var/success = 0
	changelings:
		for(var/datum/mind/changeling in get_antag_minds(/datum/antagonist/changeling,TRUE))
			if(success >= department_minds.len) //We did it, stop here!
				return TRUE
			if(ishuman(changeling.current))
				var/mob/living/carbon/human/H = changeling.current
				var/turf/cloc = get_turf(changeling.current)
				if(cloc && cloc.onCentCom() && (changeling.current.stat != DEAD)) //Living changeling on centcom....
					for(var/name in check_names) //Is he (disguised as) one of the staff?
						if(H.dna.real_name == name)
							check_names -= name //This staff member is accounted for, remove them, so the team don't succeed by escape as 7 of the same engineer
							success++ //A living changeling staff member made it to centcom
							continue changelings

	if(success >= department_minds.len)
		return TRUE
	return FALSE

//A subtype of impersonate_department
//This subtype always picks as many command staff as it can (HoS,HoP,Cap,CE,CMO,RD)
//and tasks the lings with killing and replacing them
/datum/objective/changeling_team_objective/impersonate_department/impersonate_heads
	explanation_text = "Have X or more heads of staff escape on the shuttle disguised as heads, while the real heads are dead."
	command_staff_only = TRUE

////////////////////////////////
//  Minor traitor Objectives  //
////////////////////////////////
/**
  * # Minor Objectives
  *
  * Objectives given to traitors without hijack or martyr, just small flavour things that shouldn't be too hard or impactful.
  */
/datum/objective/minor

/**
  * Sets up the achievement, returns TRUE if it was set up successfully and can be used, FALSE otherwise
  */
/datum/objective/minor/proc/finalize()
	return FALSE


/**
  * # Delete your security records
  *
  * Just delete the original record. For now, you don't have to prevent other records being made of your identity
  */
/datum/objective/minor/secrecords
	name = "Delete your security records."
	explanation_text = "Delete your Nanotrasen security records."
	/// The security record that needs to be deleted
	var/datum/data/record/record

/**
  * Search through all the security records, and find ours.
  */
/datum/objective/minor/secrecords/finalize()
	for(var/datum/data/record/s in GLOB.data_core.security)
		if(s.fields["name"] == owner.name)
			record = s
			return TRUE
	return FALSE

/**
  * Returns TRUE if there's no record, returns FALSE otherwise
  */
/datum/objective/minor/secrecords/check_completion()
	if(..())
		return TRUE
	return !record || !(record in GLOB.data_core.security)

/datum/objective/minor/secrecords/copy_target(datum/objective/minor/secrecords/old_obj)
	. = ..()
	record = old_obj.record

/**
  * # Kill Pet
  *
  * Kill Pet
  */
/datum/objective/minor/pet
	name = "assasinate-pet"
	explanation_text = "Assassinate the HoP's assistant, Ian."
	/// Pet
	var/mob/living/pet
	var/list/pets = list(/mob/living/simple_animal/pet/dog/corgi/Ian,
						 /mob/living/simple_animal/pet/cat/Runtime,
						 /mob/living/simple_animal/pet/penguin/emperor/shamebrero,
						 /mob/living/carbon/monkey/punpun,
						 /mob/living/simple_animal/parrot/Poly,
						 /mob/living/simple_animal/pet/fox/Renault,
						 /mob/living/simple_animal/pet/fox/fennec/Autumn)

/**
  * Chooses and finds pet.area
  *
  * Choices are: Ian, Runtime, Anadear, Pun pun, Poly, Renault, Autumn.
  */
/datum/objective/minor/pet/finalize()
	var/list/possible_pets = list()
	for(var/P in pets)
		var/mob/A = locate(P) in GLOB.mob_living_list
		if(A && is_station_level(A.z))
			possible_pets += P
	if(!possible_pets)
		return
	var/chosen_pet = rand(1, possible_pets.len)
	pet = locate(possible_pets[chosen_pet]) in GLOB.mob_living_list
	name = "Kill [pet.name]]"
	explanation_text = "Assassinate the important animal, [pet.name]."
	return pet

/datum/objective/minor/pet/admin_edit(mob/admin)
	var/list/possible_targets = list()
	for(var/P in pets)
		var/A = locate(P) in GLOB.mob_living_list
		if(A)
			possible_targets += A
	if(possible_targets.len)
		var/selected_pet = input(admin,"Select target:", "Objective target") as null|anything in possible_targets
		if(!selected_pet)
			return
		pet = selected_pet
	else
		to_chat(admin, span_warning("No living pets!"))
	update_explanation_text()

/datum/objective/minor/pet/update_explanation_text()
	explanation_text = "Assassinate the important animal, [pet.name]"

/datum/objective/minor/pet/copy_target(datum/objective/minor/pet/old_obj)
	. = ..()
	pet = old_obj.pet

/**
  * Check whether Pet is dead
  */
/datum/objective/minor/pet/check_completion()
	if(..())
		return TRUE
	return (!pet || pet.stat == DEAD)

/**
  * # Take a picture of your target's dead body
  *
  * Escape with a picture of their dead body
  */

/datum/objective/minor/deadpics
	name = "Photograph your target's dead body"
	explanation_text = "Escape with a photo of the dead body of your target"

/**
  * Checks whether our owner has an assassinate target, and sets the objective up if so, returns FALSE otherwise
  */
/datum/objective/minor/deadpics/finalize()
	var/datum/objective/assassinate/A = locate() in owner.objectives
	if(!A)
		return FALSE
	target = A.target
	explanation_text = "Escape with a photo of the dead body of [target.name]."
	return TRUE

/**
  * Ripped code straight from [/datum/objective/steal], checks all the owner's items for a picture with the dead target
  */
/datum/objective/minor/deadpics/check_completion()
	if(..())
		return TRUE
	var/list/all_items = owner.current.get_all_contents()
	for(var/obj/item/photo/P in all_items)
		for(var/mob/M in P.picture.dead_seen)
			if(M.real_name == target.name)
				return TRUE
	return FALSE

/**
  * # Mindshielding
  *
  * get mindshielded
  */
/datum/objective/minor/mindshield
	name = "Get mindshielded."
	explanation_text = "Extract with an NT mindshield implanted in you."

/datum/objective/minor/mindshield/finalize()
	return TRUE

/datum/objective/minor/mindshield/check_completion()
	if(..())
		return TRUE
	return HAS_TRAIT(owner.current, TRAIT_MINDSHIELD)

/**
  * # Photograph a head of staff
  *
  * photograph a head of staff
  */
/datum/objective/minor/staffpics
	name = "Photograph a head of staff."
	explanation_text = "Extract with a photograph of this head of staff."

/**
  * Find a head of staff to photograph
  */
/datum/objective/minor/staffpics/finalize()
	var/list/datum/mind/heads = SSjob.get_living_heads()
	if(!heads.len || (owner in heads))
		return FALSE

	target = pick(heads)
	name = "Photograph [target.name]."
	explanation_text = "Extract with a photograph of [target.name], the [target.assigned_role]."
	return TRUE

/**
  * return true if we escape with a picture of the head of staff
  */
/datum/objective/minor/staffpics/check_completion()
	if(..())
		return TRUE
	var/list/all_items = owner.current.get_all_contents()
	for(var/obj/item/photo/P in all_items)
		for(var/mob/M in P.picture.mobs_seen)
			if(M.real_name == target.name)
				return TRUE
	return FALSE

//Ideally this would be all of them but laziness and unusual subtypes
/proc/generate_admin_objective_list()
	GLOB.admin_objective_list = list()

	var/list/allowed_types = list(
		/datum/objective/assassinate,
		/datum/objective/assassinate/cloned,
		/datum/objective/assassinate/once,
		/datum/objective/maroon,
		/datum/objective/debrain,
		/datum/objective/protect,
		/datum/objective/assist,
		// Fulp edit START - Bloodsuckers
		// DEFAULT OBJECTIVES //
		/datum/objective/bloodsucker/lair,
		/datum/objective/survive/bloodsucker,
		/datum/objective/bloodsucker/protege,
		/datum/objective/bloodsucker/heartthief,
		/datum/objective/bloodsucker/vassalhim,
		/datum/objective/bloodsucker/gourmand,
		// MISC OBJECTIVES //
		/datum/objective/bloodsucker/monsterhunter,
		/datum/objective/bloodsucker/frenzy,
		// Fulp edit END
		/datum/objective/destroy,
		/datum/objective/hijack,
		/datum/objective/escape,
		/datum/objective/survive,
		/datum/objective/martyr,
		/datum/objective/steal,
		/datum/objective/download,
		/datum/objective/nuclear,
		/datum/objective/capture,
		/datum/objective/absorb,
		/datum/objective/minor/pet,
		/datum/objective/custom
	)

	for(var/T in allowed_types)
		var/datum/objective/X = T
		GLOB.admin_objective_list[initial(X.name)] = T

/datum/objective/contract
	var/payout = 0
	var/payout_bonus = 0
	var/area/dropoff = null

// Generate a random valid area on the station that the dropoff will happen.
/datum/objective/contract/proc/generate_dropoff()
	var/found = FALSE
	while (!found)
		var/area/dropoff_area = pick(GLOB.areas)
		if(dropoff_area && is_station_level(dropoff_area.z) && !dropoff_area.outdoors)
			dropoff = dropoff_area
			found = TRUE

// Check if both the contractor and contract target are at the dropoff point.
/datum/objective/contract/proc/dropoff_check(mob/user, mob/target)
	var/area/user_area = get_area(user)
	var/area/target_area = get_area(target)

	return (istype(user_area, dropoff) && istype(target_area, dropoff))
