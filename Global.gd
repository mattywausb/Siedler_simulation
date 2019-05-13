extends Node

enum {WOOD,WOOL,CLAY,WEED,IRON}
enum {XT_TOWER=10, XT_SCHOOL=20, XT_UNIVERSITY, XT_CHAPEL=30, XT_MONASTERY, XT_CHURCH, XT_MARKET=40, XT_STOCK_MARKET, XT_TOWN=100}

const resource_color=[	
					"25cb17", # wood
					"d0d0d0", # wool
					"cb0b0b", # clay
					"e0a000", # weed
					"000010", # iron
					] 

const ACCELERATION_FACTOR=6
const SETTLEMENT_INCOME=3
const TOWN_INCOME=4
const RESOURCE_GROW_TIME=90


var current_scene = null

func _ready():
    var root = get_tree().get_root()
    current_scene = root.get_child(root.get_child_count() - 1)


#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
static func get_acceleration_factor():
	return ACCELERATION_FACTOR

static func get_price_for_town():
	return [0,0,0,2,3]
	
static func get_price_miss_limit():
	return 2
	
static func get_resource_color(resource_index):
	return resource_color[resource_index]