extends Node

# class member variables go here, for example:
# var a = 2
# var b = "textvar"
var team_index=-1
var team_score=0
var team_color
var leading_teammate
var owned_settlement=[]

func _ready():
	# initiate players (position, color, resources)
	for i in range(0,$Teammates.get_child_count()):
		randomize()
		var x=randi()%(int(get_viewport().size.x)-50)+25
		var y=randi()%(int(get_viewport().size.y)-50)+25
		$Teammates.get_child(i).set_position(Vector2(x,y))
		$Teammates.get_child(i).modify_inventory_slot(i%5,1)
		print("Place player to " ,x,",",y)
	for i in range(0,get_parent().get_child_count()):
		if get_parent().get_child(i)==self:
			team_index=i
	$Scoreboard.set_position(Vector2(team_index*200,10))
	get_node("Scoreboard/ScoreDisplay").set_text("%03d"%team_score)

func set_teamColor(color):
	team_color=color
	for i in range(0,$Teammates.get_child_count()):
		$Teammates.get_child(i).get_node("PlayerBody").set_color(team_color)
	get_node("Scoreboard/Teamcolor").set_color(team_color)

func get_teamColor():
	return team_color

func modify_team_score(delta):
	team_score+=delta
	if team_score<0:
		team_score=0
	get_node("Scoreboard/ScoreDisplay").set_text("%03d" % team_score)
	
func can_afford(target_settlement):
	var deviation=0
	var team_resources=summarize_team_resources()
	prints("checking_price",target_settlement.settlement_price)
	for i in range(0,team_resources.size()):
		if team_resources[i]<target_settlement.settlement_price[i]:
			deviation+=target_settlement.settlement_price[i]-team_resources[i]
	return deviation <= 0 
		
	
func has_interest_on_settlement(target_settlement,initiating_teammate):
	if(target_settlement.get_owner_team()!=null):
		return false
	if !can_afford(target_settlement):
		return false
	leading_teammate=initiating_teammate
	prints(initiating_teammate.get_instance_id(),"tries to buy settlement",target_settlement.get_instance_id())
	return true
	
func cancel_plan():
	leading_teammate=null
	
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
	
func get_owned_settlement(index):
	return owned_settlement[index]
	
func get_owned_settlement_count():
	return owned_settlement.size()
	
#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass

