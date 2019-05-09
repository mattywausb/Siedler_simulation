extends Node

enum {TOWER=10, SCHOOL=20, UNIVERSITY, CHAPEL=30, MONASTERY, CHURCH, MARKET=40, STOCK_MARKET}

enum {WOOD,WOOL,CLAY,WEED,IRON}

const resource_color=[	
					"25cb17", # wood
					"d0d0d0", # wool
					"cb0b0b", # clay
					"e0a000", # weed
					"000010", # iron
					] 

var current_scene = null

func _ready():
    var root = get_tree().get_root()
    current_scene = root.get_child(root.get_child_count() - 1)


#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
static func get_price_for_town():
	return [0,0,0,2,3]
	
static func get_price_miss_limit():
	return 2
	
static func get_resource_color(resource_index):
	return resource_color[resource_index]