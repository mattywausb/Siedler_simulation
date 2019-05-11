extends Node

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

const team_color=["ff0000","00ff00","08D8D8","d0d000"]

enum {WOOD,WOOL,CLAY,WEED,IRON}
enum {XT_TOWER=10, XT_SCHOOL=20, XT_UNIVERSITY, XT_CHAPEL=30, XT_MONASTERY, XT_CHURCH, XT_MARKET=40, XT_STOCK_MARKET, XT_TOWN=100}

const settlement_price_list=[
		{resource=CLAY,price=[2,1,0,0,0]},
		{resource=WEED,price=[2,0,1,0,0]},
		{resource=IRON,price=[2,0,0,1,0]},
		
		{resource=WEED,price=[0,2,1,0,0]},
		{resource=IRON,price=[1,2,0,0,0]},
		{resource=WOOD,price=[0,2,0,0,1]},
		
		{resource=IRON,price=[0,0,2,1,0]},
		{resource=WOOD,price=[0,0,2,0,1]},
		{resource=WOOL,price=[1,0,2,0,0]},
		
		{resource=WOOD,price=[0,0,0,2,1]},
		{resource=WOOL,price=[1,0,0,2,0]},
		{resource=CLAY,price=[0,1,0,2,0]},
		
		{resource=WOOL,price=[0,0,0,1,2]},
		{resource=CLAY,price=[0,1,0,0,2]},
		{resource=WEED,price=[0,0,1,0,2]},
		
		{resource=WEED,price=[2,2,0,0,0]},
		{resource=IRON,price=[0,2,2,0,0]},
		{resource=WOOD,price=[0,0,2,2,0]},
		{resource=WOOL,price=[0,0,0,2,2]},
		{resource=CLAY,price=[2,0,0,0,2]},
		
		{resource=WOOL,price=[3,0,2,0,0]},
		{resource=CLAY,price=[0,3,0,0,2]},
		{resource=WEED,price=[0,2,3,0,0]},
		{resource=IRON,price=[2,0,0,3,0]},
		{resource=WOOD,price=[0,0,0,2,3]},
		
		{resource=WOOL,price=[3,0,2,0,1]},
		{resource=CLAY,price=[1,3,0,2,0]},
		{resource=WEED,price=[0,1,3,0,2]},
		{resource=IRON,price=[2,0,2,3,0]},
		{resource=WOOD,price=[0,2,0,2,3]},
		
		{resource=WOOL,price=[3,0,3,2,0]},
		{resource=IRON,price=[2,3,0,3,0]},
		{resource=WEED,price=[0,2,3,0,3]},
		{resource=WOOD,price=[0,0,2,3,3]},
		{resource=CLAY,price=[0,3,0,2,3]}
		]

var start_time=0

var log_file

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	randomize()
	start_time=OS.get_system_time_secs()

	for c in range(0,$Teams.get_child_count()):
		$Teams.get_child(c).set_teamColor(team_color[c])
	
	var distance_list=[]
	
	for s in range (0,$settlements.get_child_count()):
		var lowest_distance=3000
		for w in range(0,$Warehouses.get_child_count()):
			var warehouse_distance=$settlements.get_child(s).get_global_position().distance_to($Warehouses.get_child(w).get_global_position())
			lowest_distance=min(lowest_distance,warehouse_distance)
		distance_list.append(lowest_distance)

	var highest_priced_distance=10000
	var best_settlement_index=0
	for p in range(0,settlement_price_list.size()):
		best_settlement_index=-1
		var currently_best_distance=0
		for s in range (0,$settlements.get_child_count()):
			if (distance_list[s]<highest_priced_distance 
				and distance_list[s]>currently_best_distance):
					best_settlement_index=s
					currently_best_distance=distance_list[s]
		if best_settlement_index>=0:
			$settlements.get_child(best_settlement_index).set_settlement_resource(settlement_price_list[p]["resource"])
			$settlements.get_child(best_settlement_index).set_settlement_price(settlement_price_list[p]["price"])
			highest_priced_distance=currently_best_distance
		else:
			prints("Could not assign price",p)
			var badValue=0
			print(1/badValue)
			
		
		
	

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass


func _on_Timer_timeout():
	var game_time=(OS.get_system_time_secs()-start_time)*Global.get_acceleration_factor()
	prints("Time:",OS.get_system_time_secs()-start_time, "Game time:",int(game_time/60),":",game_time%60)
	for t in range (0,$Teams.get_child_count()):
		$Teams.get_child(t).log_status(game_time)
