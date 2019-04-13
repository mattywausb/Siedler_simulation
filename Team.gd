extends Node

# class member variables go here, for example:
# var a = 2
# var b = "textvar"
var team_index=-1
var team_score=0
var team_color
var leading_teammate
var owned_settlement=[]
const teamsize=7

func _ready():
	# initiate players (position, color, resources)
	var player_scene=load("res://player.tscn")
	randomize()
	
	for i in range(0,teamsize):
		var new_teammate=player_scene.instance()
		
		var x=randi()%(int(get_viewport().size.x/8))-get_viewport().size.x/16+get_viewport().size.x/2
		var y=randi()%(int(get_viewport().size.y/8))-get_viewport().size.y/16+get_viewport().size.y/2
		new_teammate.set_position(Vector2(x,y))
		new_teammate.modify_inventory_slot(i%5,1)
		print("Place player to " ,x,",",y)
		$Teammates.add_child(new_teammate)
	for i in range(0,get_parent().get_child_count()):
		if get_parent().get_child(i)==self:
			team_index=i
	$Scoreboard.set_position(Vector2(team_index*200,10))
	get_node("Scoreboard/ScoreDisplay").set_text("%03d"%team_score)
	


	
	
###### Presentation

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass


func set_teamColor(color):
	team_color=color
	for i in range(0,$Teammates.get_child_count()):
		$Teammates.get_child(i).get_node("PlayerBody").set_color(team_color)
	get_node("Scoreboard/Teamcolor").set_color(team_color)
	
	# DEBUG: capture some settlements
#	var settlements=get_node("/root/Spiel/settlements")
#	for s in range(0,settlements.get_child_count()/2):
#		settlements.get_child(s).set_owner_team(self)
#		owned_settlement.append(settlements.get_child(s))

func get_teamColor():
	return team_color

func modify_team_score(delta):
	team_score+=delta
	if team_score<0:
		team_score=0
	get_node("Scoreboard/ScoreDisplay").set_text("%03d" % team_score)


###### Functions for team decisions
	
func ask_for_order(teammember):
	prints("Asked for order")
	if get_total_resources()<5:
		teammember.start_collect_ressources()
		return

	if get_owned_settlement_count()<5:
		teammember.start_search_for_settlement()
		return
	
	if amount_missing(Global.get_price_for_town())<=0:
		for s in range(0,owned_settlement.size()):
			if !owned_settlement[s].is_town():
				teammember.start_buy_town_extention(owned_settlement[s])
				return
				
	teammember.start_search_for_settlement()
	

func has_interest_on_settlement(target_settlement,initiating_teammate):
	if(target_settlement.get_owner_team()!=null):
		return false
	if amount_missing(target_settlement.settlement_price)>0:
		return false
	leading_teammate=initiating_teammate
	return true
	
func cancel_plan():
	leading_teammate=null


###### simple operations and informatiosn
func amount_missing(target_price):
	var deviation=0
	var team_resources=summarize_team_resources()
	prints("checking_price",target_price)
	for i in range(0,team_resources.size()):
		if team_resources[i]<target_price[i]:
			deviation+=target_price[i]-team_resources[i]
	return deviation 
	
func take_posession(settlement):
	if owned_settlement.has(settlement):
			return true
	if settlement.set_owner_team(self):
		owned_settlement.append(settlement)
		return true
	return false
	
func summarize_team_resources():
	var team_resources=[0,0,0,0,0]
	for p in range(0,$Teammates.get_child_count()):
		for i in range(0,team_resources.size()):
			team_resources[i]+=$Teammates.get_child(p).ressource_inventory[i]
	prints("Team has:",team_resources)
	return team_resources

func get_total_resources():
	var total_resources=0
	for p in range(0,$Teammates.get_child_count()):
		total_resources+=$Teammates.get_child(p).get_resource_count()
	return total_resources
	
func get_owned_settlement(index):
	return owned_settlement[index]
	
func get_owned_settlement_count():
	return owned_settlement.size()

func get_member_count():
	return $Teammates.get_child_count()

func get_resource_collector_count():
	var collector_count=0
	for p in range(0,$Teammates.get_child_count()):
		if $Teammates.get_child(p).is_gathering_resources():
			collector_count+=1
	return collector_count

