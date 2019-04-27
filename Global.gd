extends Node

enum {TOWER=10, SCHOOL=20, UNIVERSITY, CHAPEL=30, MONASTERY, CHURCH, MARKET=40, STOCK_MARKET}


var current_scene = null

func _ready():
    var root = get_tree().get_root()
    current_scene = root.get_child(root.get_child_count() - 1)


#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
static func get_price_for_town():
	return [0,3,0,2,0]
	
static func get_price_miss_limit():
	return 2