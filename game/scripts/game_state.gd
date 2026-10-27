extends Node
## Remembers everything about the player's cat and how far they are in the story.

const CLAN := "ThunderClan"
const KITTYPET_NAME := "Biscuit"

const FUR_COLORS := [
	{"name": "Ginger", "color": Color("f29a45")},
	{"name": "Gray", "color": Color("9aa0aa")},
	{"name": "Black", "color": Color("45404d")},
	{"name": "White", "color": Color("fbf8f2")},
	{"name": "Brown", "color": Color("a06a42")},
	{"name": "Cream", "color": Color("f6e2b8")},
	{"name": "Silver", "color": Color("d3d8e0")},
	{"name": "Golden", "color": Color("f0c35a")},
	{"name": "Blue-Gray", "color": Color("8396b3")},
	{"name": "Dark Brown", "color": Color("6e4a32")},
]

const MARKING_COLORS := [
	{"name": "Dark Brown", "color": Color("5a3622")},
	{"name": "Black", "color": Color("35303a")},
	{"name": "White", "color": Color("fffdf8")},
	{"name": "Dark Ginger", "color": Color("c8642a")},
	{"name": "Gray", "color": Color("6c717b")},
	{"name": "Cream", "color": Color("f7e8c8")},
	{"name": "Golden", "color": Color("e0a530")},
]

const PATTERNS := ["Solid", "Tabby Stripes", "Spots", "Patches", "Socks", "Chest", "Back Stripe"]

const EYE_COLORS := [
	{"name": "Green", "color": Color("5fd14a")},
	{"name": "Amber", "color": Color("f2a531")},
	{"name": "Blue", "color": Color("4fb3f0")},
	{"name": "Yellow", "color": Color("f5d63a")},
	{"name": "Copper", "color": Color("d9732f")},
	{"name": "Purple", "color": Color("a77ae8")},
]

const NAME_PREFIXES := [
	"Fire", "Bramble", "Sand", "Leaf", "Moss", "Storm", "Frost", "Sun", "Ash", "Cloud",
	"Willow", "Fern", "Rain", "Holly", "Lion", "Ivy", "Hazel", "Pebble", "Tiger", "Feather",
	"Bright", "Rose", "Snow", "Thistle", "Blue", "Squirrel", "Sky", "Raven", "Berry", "Flame",
	"Silver", "Shadow", "Dawn", "Spark", "Acorn", "Poppy", "Wind", "Honey", "Echo", "Swift",
]

## Name endings you can pick at your warrior or medicine cat ceremony
const NAME_ENDINGS := [
	"heart", "petal", "whisker", "leap", "claw", "tail", "mist", "song",
	"stripe", "pelt", "fur", "storm", "frost", "wing", "flight", "shine",
	"cloud", "breeze", "fern", "leaf", "pool", "light", "flower", "blaze",
]
const MAX_NAME_LETTERS := 10

const PERSONALITIES := [
	{"name": "Brave", "about": "Never scared of anything!", "suffix": "heart", "virtue": "bravery"},
	{"name": "Kind", "about": "Always helps their Clanmates.", "suffix": "petal", "virtue": "kindness"},
	{"name": "Clever", "about": "Thinks before they pounce.", "suffix": "whisker", "virtue": "cleverness"},
	{"name": "Speedy", "about": "Fast as the wind!", "suffix": "leap", "virtue": "speed"},
	{"name": "Strong", "about": "Tough as an old oak tree.", "suffix": "claw", "virtue": "strength"},
	{"name": "Playful", "about": "Loves games and fun!", "suffix": "tail", "virtue": "joyful spirit"},
	{"name": "Calm", "about": "Quiet and wise.", "suffix": "mist", "virtue": "calm wisdom"},
	{"name": "Loyal", "about": "Would do anything for the Clan.", "suffix": "song", "virtue": "loyalty"},
]

## The cats from the story, and what they look like
const CATS := {
	"Bluestar": {"fur": Color("8396b3"), "markings": Color("dfe6f0"), "pattern": "Chest", "eyes": Color("4fb3f0"), "size": 1.1},
	"Tigerclaw": {"fur": Color("6e4a32"), "markings": Color("2e2224"), "pattern": "Tabby Stripes", "eyes": Color("f2a531"), "size": 1.3, "mood": "grumpy"},
	"Lionheart": {"fur": Color("f0c35a"), "markings": Color("c88a2a"), "pattern": "Tabby Stripes", "eyes": Color("5fd14a"), "size": 1.2, "fluffy": true},
	"Graypaw": {"fur": Color("7c808b"), "markings": Color("4a4d57"), "pattern": "Back Stripe", "eyes": Color("f5d63a"), "size": 0.85, "fluffy": true},
	"Ravenpaw": {"fur": Color("3f3a46"), "markings": Color("fffdf8"), "pattern": "Chest", "eyes": Color("f2a531"), "size": 0.8},
	"Spottedleaf": {"fur": Color("d98a45"), "markings": Color("5a3622"), "pattern": "Patches", "eyes": Color("f2a531"), "size": 0.95},
	"Longtail": {"fur": Color("f6e2b8"), "markings": Color("35303a"), "pattern": "Tabby Stripes", "eyes": Color("f5d63a"), "size": 1.05, "mood": "grumpy"},
	"Frostfur": {"fur": Color("fbf8f2"), "markings": Color("dfe6f0"), "pattern": "Solid", "eyes": Color("4fb3f0"), "size": 1.0},
	"Cinderkit": {"fur": Color("6c717b"), "markings": Color("45404d"), "pattern": "Solid", "eyes": Color("4fb3f0"), "size": 0.55, "fluffy": true},
	"Brightkit": {"fur": Color("fbf8f2"), "markings": Color("f29a45"), "pattern": "Patches", "eyes": Color("4fb3f0"), "size": 0.55},
	"Smallear": {"fur": Color("9aa0aa"), "markings": Color("6c717b"), "pattern": "Solid", "eyes": Color("f2a531"), "size": 0.95},
	"Sandpaw": {"fur": Color("f3c98e"), "markings": Color("e0a530"), "pattern": "Solid", "eyes": Color("5fd14a"), "size": 0.85},
	"Dustpaw": {"fur": Color("a06a42"), "markings": Color("5a3622"), "pattern": "Tabby Stripes", "eyes": Color("f2a531"), "size": 0.85, "mood": "grumpy"},
	"Yellowfang": {"fur": Color("5e5862"), "markings": Color("45404d"), "pattern": "Solid", "eyes": Color("f08a24"), "size": 1.05, "fluffy": true, "mood": "grumpy"},
	"Smudge": {"fur": Color("35303a"), "markings": Color("fffdf8"), "pattern": "Socks", "eyes": Color("5fd14a"), "size": 1.1},
	"Whitestorm": {"fur": Color("fbf8f2"), "markings": Color("dfe6f0"), "pattern": "Solid", "eyes": Color("f5d63a"), "size": 1.2, "fluffy": true},
	"Mousefur": {"fur": Color("8a6a52"), "markings": Color("5a3622"), "pattern": "Solid", "eyes": Color("f2a531"), "size": 0.95, "mood": "grumpy"},
	"Darkstripe": {"fur": Color("5d6170"), "markings": Color("2e2a33"), "pattern": "Tabby Stripes", "eyes": Color("f5d63a"), "size": 1.1, "mood": "grumpy"},
	"Goldenflower": {"fur": Color("f3c98e"), "markings": Color("e0a530"), "pattern": "Tabby Stripes", "eyes": Color("f2a531"), "size": 1.05, "fluffy": true},
	"Brackenkit": {"fur": Color("c8904a"), "markings": Color("8a5a2a"), "pattern": "Tabby Stripes", "eyes": Color("f2a531"), "size": 0.55},
	"Thornkit": {"fur": Color("d9a35a"), "markings": Color("8a5a2a"), "pattern": "Spots", "eyes": Color("5fd14a"), "size": 0.55},
	"One-eye": {"fur": Color("cfcbd6"), "markings": Color("9aa0aa"), "pattern": "Solid", "eyes": Color("4fb3f0"), "size": 0.95},
	"Halftail": {"fur": Color("6e4a32"), "markings": Color("3a2620"), "pattern": "Tabby Stripes", "eyes": Color("f5d63a"), "size": 1.0},
	"Patchpelt": {"fur": Color("fbf8f2"), "markings": Color("35303a"), "pattern": "Patches", "eyes": Color("5fd14a"), "size": 0.95},
	"Cinderpelt": {"fur": Color("6c717b"), "markings": Color("45404d"), "pattern": "Solid", "eyes": Color("4fb3f0"), "size": 0.95, "fluffy": true},
	"Brightpaw": {"fur": Color("fbf8f2"), "markings": Color("f29a45"), "pattern": "Patches", "eyes": Color("4fb3f0"), "size": 0.75},
	# StarClan cats who give a new leader their nine lives
	"Redtail": {"fur": Color("c8642a"), "markings": Color("fbf8f2"), "pattern": "Tabby Stripes", "eyes": Color("f2a531"), "size": 1.1},
	"Sunstar": {"fur": Color("f0c35a"), "markings": Color("c88a2a"), "pattern": "Tabby Stripes", "eyes": Color("5fd14a"), "size": 1.15, "fluffy": true},
	"Moonflower": {"fur": Color("d3d8e0"), "markings": Color("9aa0aa"), "pattern": "Solid", "eyes": Color("f5d63a"), "size": 1.0},
	"Snowfur": {"fur": Color("fbf8f2"), "markings": Color("dfe6f0"), "pattern": "Solid", "eyes": Color("4fb3f0"), "size": 1.0, "fluffy": true},
	"Swiftbreeze": {"fur": Color("a06a42"), "markings": Color("fbf8f2"), "pattern": "Socks", "eyes": Color("f5d63a"), "size": 0.95},
	"Featherwhisker": {"fur": Color("d3d8e0"), "markings": Color("fbf8f2"), "pattern": "Chest", "eyes": Color("f2a531"), "size": 1.0, "fluffy": true},
	"Pinestar": {"fur": Color("8a3a2a"), "markings": Color("5a2a1a"), "pattern": "Solid", "eyes": Color("5fd14a"), "size": 1.15},
	"Robinwing": {"fur": Color("6e4a32"), "markings": Color("f29a45"), "pattern": "Chest", "eyes": Color("f2a531"), "size": 0.95},
	"Thrushpelt": {"fur": Color("b8a890"), "markings": Color("8a6a52"), "pattern": "Spots", "eyes": Color("5fd14a"), "size": 1.05},
	"RiverClan warrior": {"fur": Color("b8c4d6"), "markings": Color("6c7a90"), "pattern": "Tabby Stripes", "eyes": Color("4fb3f0"), "size": 1.1, "mood": "grumpy"},
	"ShadowClan warrior": {"fur": Color("4a4552"), "markings": Color("2e2a33"), "pattern": "Tabby Stripes", "eyes": Color("f5d63a"), "size": 1.1, "mood": "grumpy"},
}

## The story, in order. Steps with "from_camp" start by talking to that cat in camp.
const STORY := [
	{"id": "kittypet", "scene": "res://scenes/garden.tscn", "title": "Chapter 1: Kittypet"},
	{"id": "first_mouse", "scene": "res://scenes/hunting.tscn", "title": "Chapter 2: Into the Forest"},
	{"id": "graypaw", "scene": "res://scenes/duel.tscn", "title": "Chapter 3: A Surprise Attack!"},
	{"id": "hunt_lesson", "scene": "res://scenes/hunting.tscn", "title": "Chapter 4: Hunting Lesson", "from_camp": "Bluestar"},
	{"id": "battle_lesson", "scene": "res://scenes/duel.tscn", "title": "Chapter 5: Battle Practice", "from_camp": "Bluestar"},
	{"id": "patrol", "scene": "res://scenes/patrol.tscn", "title": "Chapter 6: Border Patrol", "from_camp": "Lionheart"},
	{"id": "yellowfang", "scene": "res://scenes/hunting.tscn", "title": "Chapter 7: The Grumpy Stranger", "from_camp": "Bluestar"},
	{"id": "rescue", "scene": "res://scenes/rescue.tscn", "title": "Chapter 8: Rescue the Kits!", "from_camp": "Bluestar"},
	{"id": "ceremony", "scene": "res://scenes/ceremony.tscn", "title": "Chapter 9: Warrior Ceremony", "from_camp": "Bluestar"},
]

## Medicine cat apprentices learn different things. Steps not listed here are the same as STORY.
const MEDICINE_STEPS := {
	"hunt_lesson": {"id": "herb_lesson", "scene": "res://scenes/herbs.tscn", "title": "Chapter 4: Herb Hunting", "from_camp": "Spottedleaf"},
	"battle_lesson": {"id": "healing_lesson", "scene": "res://scenes/healing.tscn", "title": "Chapter 5: Helping Sick Cats", "from_camp": "Spottedleaf"},
	"yellowfang": {"id": "yellowfang", "scene": "res://scenes/healing.tscn", "title": "Chapter 7: The Grumpy Stranger", "from_camp": "Spottedleaf"},
	"ceremony": {"id": "medicine_ceremony", "scene": "res://scenes/moonstone.tscn", "title": "Chapter 9: The Moonstone", "from_camp": "Spottedleaf"},
}

## Things to do once the story is over (hunting, herbs, patrols...) and their scenes
const ACTIVITY_SCENES := {
	"free_hunt": "res://scenes/hunting.tscn", "teach_battle": "res://scenes/duel.tscn",
	"gather_herbs": "res://scenes/herbs.tscn", "heal_clan": "res://scenes/healing.tscn",
	"lead_patrol": "res://scenes/patrol.tscn", "nine_lives": "res://scenes/moonstone.tscn",
}
const LESSONS_NEEDED := 3  # lessons before Cinderpaw gets her full name
const DEPUTY_TASKS := 2  # patrols a deputy leads before Bluestar has news

const SAVE_SLOTS := 3
const MAX_PAINT := 5000  # most brush dabs we keep

var fur_index := 0
var marking_index := 0
var pattern_index := 1
var eye_index := 0
var fluffy := false
var prefix_index := 0
var custom_prefix := ""  # a name you typed yourself (instead of picking one from the list)
var personality_index := 0
var name_ending := ""  # warrior name ending you picked ("" = the one that matches your personality)
var paint: Array = []  # brush dabs painted on your cat: [position, color, radius]

var step := 0  # which part of the story we're on
var met_clan := false  # the apprentice ceremony in camp has happened
var fresh_kill := 0  # prey you've brought back to the fresh-kill pile
var has_apprentice := false  # Cinderkit became your apprentice, Cinderpaw
var apprentice_lessons := 0  # how many times you've trained Cinderpaw
var path := "warrior"  # "warrior" or "medicine"
var apprentice_graduated := false  # Cinderpaw got her full name, Cinderpelt
var rank := ""  # "" or "deputy" or "leader" (warriors), "" or "head" (medicine cats)
var deputy_tasks := 0  # patrols led as deputy
var deputy_name := ""  # who you chose as your deputy when you became leader
var brightpaw_mentor := ""  # leaders can make Brightkit an apprentice

var slot := 0  # which save slot we're playing in
var just_finished := ""  # what you just did, right before coming back to camp
var activity := ""  # "free_hunt" or "teach_battle" when it's not part of the story
var den := ""  # which den you're visiting
var hunt_buddy := -1  # the slot of a friend who came hunting with you (-1 = nobody)
var together: Array = []  # two players on one keyboard: [Player 1's slot, Player 2's slot]
var return_to_online := false  # Online Play sent us to make/pick a cat: go back there after


func look() -> Dictionary:
	return {
		"fur": FUR_COLORS[fur_index].color,
		"markings": MARKING_COLORS[marking_index].color,
		"pattern": PATTERNS[pattern_index],
		"eyes": EYE_COLORS[eye_index].color,
		"fluffy": fluffy,
	}


## Makes your cat, with its looks, paint and collar
func make_player_cat() -> Cat:
	var cat := Cat.new()
	cat.set_look(look())
	cat.paint = paint
	cat.size = cat_size()
	cat.collar = is_kittypet()
	return cat


func personality() -> Dictionary:
	return PERSONALITIES[personality_index]


func prefix() -> String:
	return custom_prefix if custom_prefix != "" else NAME_PREFIXES[prefix_index]


func name_suffix() -> String:
	return name_ending if name_ending != "" else personality().suffix


func apprentice_name() -> String:
	return prefix() + "paw"


## Your name after your warrior (or medicine cat) ceremony
func warrior_name() -> String:
	return prefix() + name_suffix()


func leader_name() -> String:
	return prefix() + "star"


## Tidies up a typed name: letters only, not too long, and a capital letter first
## (or all small letters for a name ending).
static func clean_name(text: String, ending := false) -> String:
	var letters := ""
	for ch in text:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z"):
			letters += ch
	letters = letters.to_lower()
	if not ending:
		for extra in ["paw", "kit", "star"]:  # "Lunapaw" -> "Luna"
			if letters.length() > extra.length() + 1 and letters.ends_with(extra):
				letters = letters.left(-extra.length())
	letters = letters.left(MAX_NAME_LETTERS)
	return letters if ending else letters.capitalize()


## True once the story is done and you have your full warrior or medicine cat name
func is_grown() -> bool:
	return step >= STORY.size()


func is_medicine() -> bool:
	return path == "medicine"


func is_leader() -> bool:
	return rank == "leader"


func is_kittypet() -> bool:
	return not met_clan and step <= 2


func cat_name() -> String:
	if is_leader():
		return leader_name()
	if is_grown():
		return warrior_name()
	return KITTYPET_NAME if is_kittypet() else apprentice_name()


func cat_size() -> float:
	if is_leader():
		return 1.25
	return 1.15 if is_grown() else 0.9


func mentor() -> String:
	return "Spottedleaf" if is_medicine() else "Bluestar"


## What to call you, like "ThunderClan Warrior" or "Medicine Cat Apprentice"
func rank_title() -> String:
	if is_leader():
		return "Leader of %s" % CLAN
	if rank == "deputy":
		return "%s Deputy" % CLAN
	if is_medicine():
		return "%s Medicine Cat" % CLAN if is_grown() else "Medicine Cat Apprentice"
	return "%s Warrior" % CLAN if is_grown() else "%s Apprentice" % CLAN


## Cinderpaw is your apprentice and walks around with you
func apprentice_following() -> bool:
	return has_apprentice and not apprentice_graduated


## Big news waiting in camp after the story: [news, who tells you]. Empty if there's none.
func waiting_news() -> Array:
	if not is_grown():
		return []
	if not has_apprentice:
		return ["apprentice", "Bluestar"]
	if not apprentice_graduated:
		return ["graduate", "Bluestar"] if apprentice_lessons >= LESSONS_NEEDED else []
	if is_medicine():
		return ["head", "Spottedleaf"] if rank == "" else []
	if rank == "":
		return ["deputy", "Bluestar"]
	if rank == "deputy" and deputy_tasks >= DEPUTY_TASKS:
		return ["leader", "Bluestar"]
	return []


func current() -> Dictionary:
	if step >= STORY.size():
		return {}
	var part: Dictionary = STORY[step]
	return MEDICINE_STEPS.get(part.id, part) if is_medicine() else part


func current_id() -> String:
	return activity if activity != "" else current().get("id", "")


## Finish this part of the story and go to wherever the story goes next.
func complete_step() -> void:
	just_finished = current_id()
	step += 1
	save_game()
	var next := current()
	if next.is_empty() or next.has("from_camp"):
		Transition.go("res://scenes/camp.tscn")
	else:
		Transition.go(next.scene)


func start_step() -> void:
	if back_to_online_if_asked():
		return
	activity = ""
	Transition.go(current().scene)


## Things to do that aren't part of the story (hunting, herbs, training Cinderpaw, patrols)
func start_activity(what: String) -> void:
	activity = what
	Transition.go(ACTIVITY_SCENES[what])


func finish_activity() -> void:
	just_finished = activity
	if apprentice_following():
		apprentice_lessons += 1
	if rank == "deputy" and activity in ["free_hunt", "lead_patrol"]:
		deputy_tasks += 1
	activity = ""
	hunt_buddy = -1
	save_game()
	Transition.go("res://scenes/camp.tscn")


func randomize_cat() -> void:
	fur_index = randi() % FUR_COLORS.size()
	marking_index = randi() % MARKING_COLORS.size()
	pattern_index = randi() % PATTERNS.size()
	eye_index = randi() % EYE_COLORS.size()
	fluffy = randf() < 0.5
	prefix_index = randi() % NAME_PREFIXES.size()
	custom_prefix = ""
	personality_index = randi() % PERSONALITIES.size()


# --- save slots ----------------------------------------------------------------------------

const SAVED := ["fur_index", "marking_index", "pattern_index", "eye_index", "fluffy", "prefix_index",
		"custom_prefix", "personality_index", "name_ending", "step", "met_clan", "fresh_kill", "has_apprentice",
		"apprentice_lessons", "path", "apprentice_graduated", "rank", "deputy_tasks", "deputy_name",
		"brightpaw_mentor"]


func _slot_path(i: int) -> String:
	return "user://save_%d.json" % i


## Starts a brand new cat in a slot
func new_game(i: int) -> void:
	met_clan = false
	var fresh: Node = get_script().new()
	for key in SAVED:
		set(key, fresh.get(key))
	fresh.free()
	paint = []
	slot = i
	just_finished = ""
	activity = ""


func save_game() -> void:
	var data := {}
	for key in SAVED:
		data[key] = get(key)
	var dabs := []
	for dab in paint:
		dabs.append([dab[0].x, dab[0].y, dab[1].to_html(), dab[2]])
	data["paint"] = dabs
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


## What's saved in a slot (empty if nothing is saved there)
func read_slot(i: int) -> Dictionary:
	if not FileAccess.file_exists(_slot_path(i)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(i)))
	return data if data is Dictionary else {}


func load_game(i: int) -> bool:
	var data := read_slot(i)
	if data.is_empty():
		return false
	new_game(i)
	for key in SAVED:
		if data.has(key):
			set(key, type_convert(data[key], typeof(get(key))))
	for dab in data.get("paint", []):
		paint.append([Vector2(dab[0], dab[1]), Color.html(dab[2]), float(dab[3])])
	return true


func erase_slot(i: int) -> void:
	if FileAccess.file_exists(_slot_path(i)):
		DirAccess.remove_absolute(_slot_path(i))
	forget_friends(i)


## Online Play sends a cat-less kid to the save slots to make their first cat. When that is
## done we go back to the online lobby instead of starting the story.
func back_to_online_if_asked() -> bool:
	if not return_to_online:
		return false
	return_to_online = false
	Transition.go("res://scenes/online_lobby.tscn")
	return true


## Go to wherever this save left off
func continue_game() -> void:
	if back_to_online_if_asked():
		return
	if met_clan or is_grown():
		Transition.go("res://scenes/camp.tscn")
	else:
		start_step()


## Name, looks and progress of a saved cat, for the save slot screen (empty if no save)
func describe_slot(i: int) -> Dictionary:
	if read_slot(i).is_empty():
		return {}
	var saved: Node = get_script().new()
	saved.load_game(i)
	var progress: String = saved.rank_title() + "!" if saved.is_grown() else str(saved.current().get("title", ""))
	var info := {"name": saved.cat_name(), "look": saved.look(), "paint": saved.paint,
			"progress": progress, "size": saved.cat_size(), "kittypet": saved.is_kittypet(),
			"slot": i, "title": saved.rank_title(), "grown": saved.is_grown(), "rank": saved.rank,
			"medicine": saved.is_medicine(), "leader": saved.is_leader(), "prefix": saved.prefix(),
			"suffix": saved.name_suffix()}
	saved.free()
	return info


## Changes some saved things for the cat in slot i, like {"rank": "deputy"}
## (when something happens to them in the two-player world)
func edit_slot(i: int, changes: Dictionary) -> void:
	var saved: Node = get_script().new()
	if saved.load_game(i):
		for key in changes:
			saved.set(key, changes[key])
		saved.save_game()
	saved.free()


# --- friends from other save slots ----------------------------------------------------------
# Everyone who plays on this computer has their own save slot. Their cats visit each other's
# camps, and can become friends. Friendships are shared by all the slots.

const FRIENDS_PATH := "user://friends.json"


## Every friendship, as pairs of slots like [0, 2]
func friend_pairs() -> Array:
	if not FileAccess.file_exists(FRIENDS_PATH):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(FRIENDS_PATH))
	return data if data is Array else []


func _save_friend_pairs(pairs: Array) -> void:
	var file := FileAccess.open(FRIENDS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(pairs))


func are_friends(a: int, b: int) -> bool:
	return friends_of(a).has(b)


func make_friends(a: int, b: int) -> void:
	if a == b or are_friends(a, b):
		return
	var pairs := friend_pairs()
	pairs.append([a, b])
	_save_friend_pairs(pairs)


## The slots that are friends with slot i
func friends_of(i: int) -> Array:
	var friends := []
	for pair in friend_pairs():
		if int(pair[0]) == i:
			friends.append(int(pair[1]))
		elif int(pair[1]) == i:
			friends.append(int(pair[0]))
	return friends


## A cat was erased (or a new cat starts in its slot), so its friendships go too
func forget_friends(i: int) -> void:
	_save_friend_pairs(friend_pairs().filter(func(pair): return int(pair[0]) != i and int(pair[1]) != i))


## Puts prey on the fresh-kill pile of the cat saved in slot i (after playing together)
func add_prey_to_slot(i: int, amount: int) -> void:
	var saved: Node = get_script().new()
	if saved.load_game(i):
		saved.fresh_kill += amount
		saved.save_game()
	saved.free()


## Every saved cat (for picking who plays together)
func all_saved_cats() -> Array:
	var cats := []
	for i in SAVE_SLOTS:
		var info := describe_slot(i)
		if not info.is_empty():
			cats.append(info)
	return cats


## Cats from the other save slots who have joined ThunderClan (they visit your camp)
func visiting_cats() -> Array:
	var cats := []
	for i in SAVE_SLOTS:
		if i == slot:
			continue
		var info := describe_slot(i)
		if not info.is_empty() and not info.kittypet:
			cats.append(info)
	return cats
