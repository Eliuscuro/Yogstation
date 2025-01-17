GLOBAL_VAR_INIT(OOC_COLOR, null)//If this is null, use the CSS for OOC. Otherwise, use a custom colour.
GLOBAL_VAR_INIT(normal_ooc_colour, "#002eb8")
GLOBAL_VAR_INIT(mentor_ooc_colour, YOGS_MENTOR_OOC_COLOUR) // yogs - mentor ooc color

GLOBAL_LIST_EMPTY(ooc_shadow_muted)
GLOBAL_LIST_EMPTY(ooc_new_long_messages)
GLOBAL_LIST_EMPTY(ooc_new_last_messsage)
GLOBAL_LIST_EMPTY(ooc_new_long_messages_short)
GLOBAL_LIST_EMPTY(ooc_new_long_messages_very)

/client/verb/ooc_wrapper()
	set hidden = TRUE
	var/message = input("", "OOC \"text\"") as null|text
	ooc(message)

/client/verb/ooc(msg as text)
	set name = "OOC" //Gave this shit a shorter name so you only have to time out "ooc" rather than "ooc message" to use it --NeoFite
	set category = "OOC"

	if(GLOB.say_disabled)	//This is here to try to identify lag problems
		to_chat(usr, span_danger("Speech is currently admin-disabled."))
		return

	if(!mob)
		return

	if(!holder)
		if(!GLOB.ooc_allowed)
			to_chat(src, span_danger("OOC is globally muted."))
			return
		if(!GLOB.dooc_allowed && (mob.stat == DEAD))
			to_chat(usr, span_danger("OOC for dead mobs has been turned off."))
			return
		if(prefs.muted & MUTE_OOC)
			to_chat(src, span_danger("You cannot use OOC (muted)."))
			return
	if(is_banned_from(ckey, "OOC"))
		to_chat(src, span_danger("You have been banned from OOC."))
		return
	if(QDELETED(src))
		return

	msg = copytext_char(sanitize(msg), 1, MAX_MESSAGE_LEN)
	var/raw_msg = msg

	if(!msg)
		return

	msg = pretty_filter(msg) //yogs
	msg = emoji_parse(msg)

	if(SSticker.HasRoundStarted() && (msg[1] in list(".",";",":","#") || findtext_char(msg, "say", 1, 5)))
		if(tgui_alert(usr,"Your message \"[raw_msg]\" looks like it was meant for in game communication, say it in OOC?", "Meant for OOC?", list("Yes", "No")) != "Yes")
			return

	if(!holder)
		if(handle_spam_prevention(msg,MUTE_OOC))
			return
		if(findtext(msg, "byond://"))
			to_chat(src, "<B>Advertising other servers is not allowed.</B>")
			log_admin("[key_name(src)] has attempted to advertise in OOC: [msg]")
			message_admins("[key_name_admin(src)] has attempted to advertise in OOC: [msg]")
			return

	if(!(prefs.chat_toggles & CHAT_OOC))
		to_chat(src, span_danger("You have OOC muted."))
		return

	var/keyname = key
	if(prefs.unlock_content)
		if(prefs.toggles & MEMBER_PUBLIC)
			keyname = "<font color='[prefs.read_preference(/datum/preference/color/ooc_color) || GLOB.normal_ooc_colour]'>[icon2html('icons/member_content.dmi', world, "blag")][keyname]</font>"
	//YOG START - Yog OOC

	if(get_exp_living(TRUE) <= 300 && length(msg) >= 450)
		if(GLOB.ooc_new_long_messages[key])
			GLOB.ooc_new_long_messages_very[key]++
		else
			GLOB.ooc_new_long_messages_very[key] = 1

	if(get_exp_living(TRUE) <= 300 && length(msg) >= 300)
		if(GLOB.ooc_new_long_messages[key])
			GLOB.ooc_new_long_messages[key]++
		else
			GLOB.ooc_new_long_messages[key] = 1

	if(get_exp_living(TRUE) <= 300 && length(msg) >= 150)
		if(GLOB.ooc_new_long_messages_short[key])
			GLOB.ooc_new_long_messages_short[key]++
		else
			GLOB.ooc_new_long_messages_short[key] = 1

	if(GLOB.ooc_new_long_messages_very[key] > 0 && !GLOB.ooc_shadow_muted[key])
		GLOB.ooc_shadow_muted[key] = TRUE
		message_admins("Shadow muted [key] from OOC. Will reset when round ends.")

	if(GLOB.ooc_new_long_messages[key] > 1 && !GLOB.ooc_shadow_muted[key])
		GLOB.ooc_shadow_muted[key] = TRUE
		message_admins("Shadow muted [key] from OOC. Will reset when round ends.")

	if(GLOB.ooc_new_long_messages_short[key] >= 3 && !GLOB.ooc_shadow_muted[key])
		GLOB.ooc_shadow_muted[key] = TRUE
		message_admins("Shadow muted [key] from OOC. Will reset when round ends.")

	if(!GLOB.ooc_shadow_muted[key])
		if(GLOB.ooc_new_last_messsage[key] > (world.time))
			to_chat(src, span_warning("Please wait a [(GLOB.ooc_new_last_messsage[key] - world.time) / 10 ] seconds before sending another OOC message"))
			return

	if(get_exp_living(TRUE) <= 300 && !isnull(holder)) // SS220 EDIT
		GLOB.ooc_new_last_messsage[key] = world.time + 5 SECONDS

	mob.log_talk(raw_msg, LOG_OOC)
	if(holder && holder.fakekey) //YOGS start - webhook support
		webhook_send_ooc(holder.fakekey, msg)
	else
		if(!GLOB.ooc_shadow_muted[key])
			webhook_send_ooc(key, msg) //YOGS end - webhook support

	//PINGS
	var/regex/ping = regex(@"@+(((([\s]{0,1}[^\s@]{0,30})[\s]*[^\s@]{0,30})[\s]*[^\s@]{0,30})[\s]*[^\s@]{0,30})","g")//Now lets check if they pinged anyone
	// Regex101 link to this specific regex, as of 3rd April 2019: https://regex101.com/r/YtmLDs/7
	var/list/pinged = list()
	while(ping.Find(msg))
		for(var/x in ping.group)
			pinged |= ckey(x)
	var/list/clientkeys = list()
	for(var/x in GLOB.clients)// If the "SENDING MESSAGES OUT" for-loop starts iterating over something else, make this GLOB *that* something else.
		var/client/Y = x //God bless typeless for-loops
		clientkeys += Y.ckey
		if(Y.holder && Y.holder.fakekey)
			clientkeys += Y.holder.fakekey
	pinged &= clientkeys
	if(pinged.len)
		if((world.time - last_ping_time) < 30)
			to_chat(src,span_danger("You are pinging too much! Please wait before pinging again."))
			return
		last_ping_time = world.time

	//MESSAGE CRAFTING -- This part handles actually making the messages that are to be displayed.
	var/bussedcolor = GLOB.OOC_COLOR ? GLOB.OOC_COLOR : "" // So /TG/ decided to fuck up how OOC colours are handled.
	// So we're sticking a weird <font color='[bussedcolor]'></font> into shit to handle their new system.
	// Completely rewrote this OOC-handling code and /TG/ still manages to make it bad. Hate tg.
	var/oocmsg = ""; // The message sent to normal people
	var/oocmsg_toadmins = FALSE; // The message sent to admins.
	if(holder) // If the speaker is an admin or something
		if(check_rights_for(src, R_ADMIN)) // If they're supposed to have their own admin OOC colour
			var/ooc_color = prefs.read_preference(/datum/preference/color/ooc_color)
			oocmsg += "<span class='adminooc'>[(CONFIG_GET(flag/allow_admin_ooccolor) && ooc_color) ? "<font color=[ooc_color]>" :"" ]<span class='prefix'>[find_admin_rank(src)]" // The header for an Admin's OOC.
		else // Else if they're an AdminObserver
			oocmsg += "<span class='adminobserverooc'><span class='prefix'>[find_admin_rank(src)]" // The header for an AO's OOC.
		//Check yogstation\code\module\client\verbs\ooc for the find_admin_rank definition.

		if(holder.fakekey) // If they're stealhminning
			oocmsg_toadmins = oocmsg + "OOC:</span> <EM>[keyname]/([holder.fakekey]):</EM> <span class='message'>[msg]</span></span></font>"
			// ^ Message sent to people who should know when someone's stealthminning
			oocmsg = span_ooc("<font color='[bussedcolor]'>[span_prefix("OOC:")] <EM>[holder.fakekey]:</EM> <span class='message'>[msg]</span></font>")
			// ^ Message sent to normal people
		else
			oocmsg += "OOC:</span> <EM>[keyname]:</EM> <span class='message'>[msg]</span></span></font>" // Footer for an admin or AO's OOC.
			oocmsg_toadmins = oocmsg
	else
		if(is_mentor()) // If the speaker is a mentor
			var mposition = "Mentor"
			mposition = src.mentor_datum?.position
			oocmsg = "<span class='ooc'>\["
			oocmsg += "[mposition]"
			oocmsg += "]<font color='[prefs.read_preference(/datum/preference/color/ooc_color)]'>"
		else
			oocmsg = "<span class='ooc'>[(is_donator(src) && !CONFIG_GET(flag/everyone_is_donator)) ? "(Donator)" : ""]"
			oocmsg += "<font color='[bussedcolor]'>"
		oocmsg += "[span_prefix("OOC:")] <EM>[keyname]:</EM> <span class='message'>[msg]</span></font></span>"
		oocmsg_toadmins = oocmsg

	//SENDING THE MESSAGES OUT
	if(!(key in GLOB.ooc_shadow_muted))
		for(var/c in GLOB.clients)
			var/client/C = c // God bless typeless for-loops
			if( (!C.prefs || (C.prefs.chat_toggles & CHAT_OOC)) && (holder || !(key in C.prefs?.ignoring)) )
				var/sentmsg // The message we're sending to this specific person
				if(C.holder) // If they're an admin-ish
					sentmsg = oocmsg_toadmins // Get the admin one
				else
					sentmsg = oocmsg
				if( (ckey(C.key) in pinged) || (C.holder && C.holder.fakekey && (C.holder.fakekey in pinged)) )
					var/sound/pingsound = sound('yogstation/sound/misc/bikehorn_alert.ogg')
					pingsound.volume = 50
					pingsound.pan = 80
					SEND_SOUND(C,pingsound)
					sentmsg = "<span style='background-color: #ccccdd'>" + sentmsg + "</span>"
				to_chat(C,sentmsg)
	else
		to_chat(src,oocmsg)
	//YOGS END
	var/data = list()
	data["normal"] = oocmsg
	data["admin"] = oocmsg_toadmins

	var/source = list()
	source["is_admin"] = !!holder
	source["key"] = key
	if(!GLOB.ooc_shadow_muted[key])
		send2otherserver(json_encode(source), json_encode(data), "ooc_relay")

/proc/toggle_ooc(toggle = null)
	if(toggle != null) //if we're specifically en/disabling ooc
		if(toggle != GLOB.ooc_allowed)
			GLOB.ooc_allowed = toggle
		else
			return
	else //otherwise just toggle it
		GLOB.ooc_allowed = !GLOB.ooc_allowed
	to_chat(world, "<B>The OOC channel has been globally [GLOB.ooc_allowed ? "enabled" : "disabled"].</B>")

/proc/toggle_dooc(toggle = null)
	if(toggle != null)
		if(toggle != GLOB.dooc_allowed)
			GLOB.dooc_allowed = toggle
		else
			return
	else
		GLOB.dooc_allowed = !GLOB.dooc_allowed

/client/proc/set_ooc(newColor as color)
	set name = "Set Player OOC Color"
	set desc = "Modifies player OOC Color"
	set category = "Server"
	GLOB.OOC_COLOR = sanitize_color(newColor)

/client/proc/reset_ooc()
	set name = "Reset Player OOC Color"
	set desc = "Returns player OOC Color to default"
	set category = "Server"
	if(IsAdminAdvancedProcCall())
		return
	if(tgui_alert(usr, "Are you sure you want to reset the OOC color of all players?", "Reset Player OOC Color", list("Yes", "No")) != "Yes")
		return
	if(!check_rights(R_FUN))
		message_admins("[usr.key] has attempted to use the Reset Player OOC Color verb!")
		log_admin("[key_name(usr)] tried to reset player ooc color without authorization.")
		return
	message_admins("[key_name_admin(usr)] has reset the players' ooc color.")
	log_admin("[key_name_admin(usr)] has reset player ooc color.")
	GLOB.OOC_COLOR = null

//Checks admin notice
/client/verb/admin_notice()
	set name = "Adminnotice"
	set category = "Admin"
	set desc ="Check the admin notice if it has been set"

	if(GLOB.admin_notice)
		to_chat(src, "[span_boldnotice("Admin Notice:")]\n \t [GLOB.admin_notice]")
	else
		to_chat(src, span_notice("There are no admin notices at the moment."))


/client/verb/motd()
	set name = "MOTD"
	set category = "OOC"
	set desc ="Check the Message of the Day"

	var/motd = global.config.motd
	if(motd)
		to_chat(src, "<div class=\"motd\">[motd]</div>", handle_whitespace=FALSE)
	else
		to_chat(src, span_notice("The Message of the Day has not been set."))

/client/proc/self_notes()
	set name = "View Own Admin Notes"
	set category = "OOC"
	set desc = "View the notes that admins have written about you"

	if(!CONFIG_GET(flag/see_own_notes))
		to_chat(usr, span_notice("Sorry, that function is not enabled on this server."))
		return

	browse_messages(null, usr.ckey, null, TRUE)

/client/proc/self_playtime()
	set name = "View tracked playtime"
	set category = "OOC"
	set desc = "View the amount of playtime for roles the server has tracked."

	if(!CONFIG_GET(flag/use_exp_tracking))
		to_chat(usr, span_notice("Sorry, tracking is currently disabled."))
		return

	new /datum/job_report_menu(src, usr)


/client/proc/ignore_key(client)
	var/client/C = client
	if(C.key in prefs.ignoring)
		prefs.ignoring -= C.key
	else
		prefs.ignoring |= C.key
	to_chat(src, "You are [(C.key in prefs.ignoring) ? "now" : "no longer"] ignoring [C.key] on the OOC channel.")
	prefs.save_preferences()

/client/verb/select_ignore()
	set name = "Ignore"
	set category = "OOC"
	set desc ="Ignore a player's messages on the OOC channel"


	var/see_ghost_names = isobserver(mob)
	var/list/choices = list()
	for(var/client/C in GLOB.clients)
		if(isobserver(C.mob) && see_ghost_names)
			choices["[C.mob]([C])"] = C
		else
			choices[C] = C
	choices = sortList(choices)
	var/selection = input("Please, select a player!", "Ignore", null, null) as null|anything in choices
	if(!selection || !(selection in choices))
		return
	selection = choices[selection]
	if(selection == src)
		to_chat(src, "You can't ignore yourself.")
		return
	ignore_key(selection)

/client/proc/show_previous_roundend_report()
	set name = "Your Last Round"
	set category = "OOC"
	set desc = "View the last round end report you've seen"

	SSticker.show_roundend_report(src, TRUE)

/client/verb/fit_viewport()
	set name = "Fit Viewport"
	set category = "OOC"
	set desc = "Fit the width of the map window to match the viewport"

	// Fetch aspect ratio
	var/view_size = getviewsize(view)
	var/aspect_ratio = view_size[1] / view_size[2]

	// Calculate desired pixel width using window size and aspect ratio
	var/sizes = params2list(winget(src, "mainwindow.split;mapwindow", "size"))
	var/map_size = splittext(sizes["mapwindow.size"], "x")
	var/height = text2num(map_size[2])
	var/desired_width = round(height * aspect_ratio)
	if (text2num(map_size[1]) == desired_width)
		// Nothing to do
		return

	var/split_size = splittext(sizes["mainwindow.split.size"], "x")
	var/split_width = text2num(split_size[1])

	// Calculate and apply a best estimate
	// +4 pixels are for the width of the splitter's handle
	var/pct = 100 * (desired_width + 4) / split_width
	winset(src, "mainwindow.split", "splitter=[pct]")

	// Apply an ever-lowering offset until we finish or fail
	var/delta
	for(var/safety in 1 to 10)
		var/after_size = winget(src, "mapwindow", "size")
		map_size = splittext(after_size, "x")
		var/got_width = text2num(map_size[1])

		if (got_width == desired_width)
			// success
			return
		else if (isnull(delta))
			// calculate a probable delta value based on the difference
			delta = 100 * (desired_width - got_width) / split_width
		else if ((delta > 0 && got_width > desired_width) || (delta < 0 && got_width < desired_width))
			// if we overshot, halve the delta and reverse direction
			delta = -delta/2

		pct += delta
		winset(src, "mainwindow.split", "splitter=[pct]")


/client/verb/policy()
	set name = "Show Policy"
	set desc = "Show special server rules related to your current character."
	set category = "OOC"

	//Collect keywords
	var/list/keywords = mob.get_policy_keywords()
	var/header = get_policy(POLICY_VERB_HEADER)
	var/list/policytext = list(header,"<hr>")
	var/anything = FALSE
	for(var/keyword in keywords)
		var/p = get_policy(keyword)
		if(p)
			policytext += p
			policytext += "<hr>"
			anything = TRUE
	if(!anything)
		policytext += "No related rules found."

	usr << browse(policytext.Join(""),"window=policy")

/client/verb/fix_stat_panel()
	set name = "Fix Stat Panel"
	set hidden = TRUE

	init_verbs()
