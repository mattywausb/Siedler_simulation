extends Node

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	randomize()
	get_node("Teams/Team1").set_teamColor("ff0000")
	get_node("Teams/Team2").set_teamColor("00ff00")
	#get_node("Teams/Team3").set_teamColor("00E8E8")
	
	var trace_high=0
	var trace_low=10000
	
	for s in range (0,$settlements.get_child_count()):
		$settlements.get_child(s).set_settlement_resource(s%5)
		var lowest_distance=3000
		for w in range(0,$Warehouses.get_child_count()):
			var warehouse_distance=$settlements.get_child(s).get_global_position().distance_to($Warehouses.get_child(w).get_global_position())
			lowest_distance=min(lowest_distance,warehouse_distance)
#		prints($settlements.get_child(s).get_name(),"distance is",lowest_distance)
		$settlements.get_child(s).set_settlement_price(lowest_distance)
		trace_high=max(trace_high,lowest_distance)
		trace_low=min(trace_low,lowest_distance)
		
	prints("Distance rage",trace_low,"-",trace_high)
		
	

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
