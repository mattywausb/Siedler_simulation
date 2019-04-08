extends Node

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	randomize()
	get_node("Teams/Team1").set_teamColor("ff0000")
	#get_node("Teams/Team2").set_teamColor("00ff00")
	#get_node("Teams/Team3").set_teamColor("0000ff")
	
	for w in range (0,$settlements.get_child_count()):
		$settlements.get_child(w).set_settlement_ressource(w%5)

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
