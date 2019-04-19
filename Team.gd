extends Node

# constants 
const teamsize=7

# main properties

var team_index=-1
var team_score=0
var team_color
var leading_teammate
var owned_settlement=[]



# Strategy 
enum {MT_SETTLEMENT,MT_TOWN,MT_EXTENTION}  # Mission types
enum {BRICK,IRON,WOOL,WEED,WOOD}


#var team_mission=[{mission_id=0,to_buy=SETTLEMENT,resource=BRICK,is_ordered_by=false},
#				  {mission_id=1,to_buy=SETTLEMENT,resource=IRON,is_ordered_by=false},
#				  {mission_id=2,to_buy=SETTLEMENT,resource=WEED,is_ordered_by=false},
#				  {mission_id=3,to_buy=SETTLEMENT,resource=WOOL,is_ordered_by=false},
#				  {mission_id=4,to_buy=SETTLEMENT,resource=WOOD,is_ordered_by=false}]

var team_mission={0:{to_buy=MT_SETTLEMENT,resource=BRICK,is_ordered_by=false},
				   1:{to_buy=MT_SETTLEMENT,resource=IRON,is_ordered_by=false},
				   2:{to_buy=MT_SETTLEMENT,resource=WOOL,is_ordered_by=false},
				   3:{to_buy=MT_SETTLEMENT,resource=WEED,is_ordered_by=false},
				   4:{to_buy=MT_SETTLEMENT,resource=WOOD,is_ordered_by=false}}
				
				   # Other examples added later by the functions
				   # {to_buy=MT_TOWN,settlement=owned_settlement[s],is_ordered_by=false}
				   # {to_buy=MT_EXTENTION,settlement=owned_settlement[s],extention_type=SCHOOL,is_ordered_by=false}


var mission_sequence=team_mission.size()


func _ready():
	# initiate players (position, color, resources)
	var player_scene=load("res://player.tscn")
	randomize()
	
	for i in range(0,teamsize):
		var new_teammate=player_scene.instance()
		
		var x=randi()%(int(get_viewport().size.x/8))-get_viewport().size.x/16+get_viewport().size.x/2
		var y=randi()%(int(get_viewport().size.y/8))-get_viewport().size.y/16+get_viewport().size.y/2
		new_teammate.set_position(Vector2(x,y))
		if i<=2:
			new_teammate.modify_inventory_add([1,1,1,1,1])
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


func modify_team_score(delta):
	team_score+=delta
	if team_score<0:
		team_score=0
	get_node("Scoreboard/ScoreDisplay").set_text("%03d" % team_score)


###### Operations

	
func ask_for_mission(teammember):
	prints("Asked for mission")
	if get_owned_settlement_count()==0 :
		teammember.start_search_for_settlement()
		return
		
	if get_resource_count()<5:
		teammember.start_collect_ressources()
		return

	if get_number_of_buying_members()>get_member_count()/2:
		if (get_resource_collector_count()<= get_member_count()/2 +1
		 	and get_resource_collector_count()<= get_owned_settlement_count()/3+1):
			teammember.start_collect_ressources()
		else:
			teammember.start_search_for_settlement()

	# check if we can build an extention
	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		if mission.is_ordered_by:
			continue
		match mission.to_buy:
			MT_TOWN:
				if get_amount_missing(Global.get_price_for_town())<=0:
					teammember.start_buy_town(mission_id,mission.settlement)
					return
			MT_EXTENTION:
				if get_amount_missing(owned_settlement[0].get_extention_price(mission.extention_type))<=0:	
					teammember.start_buy_town_extention(mission_id,mission.extention_type,mission.settlement)
					return
	teammember.start_search_for_settlement()


func cancel_mission(mission_id):
	if(team_mission.has(mission_id)):
		team_mission[mission_id].is_ordered_by=false


func complete_mission(mission_id):
	# remove the completed mission from the list
	var current_mission_to_buy_count=[0,0,0]
	for m in range(0,team_mission.size()):
		if team_mission[m].get("mission_id")==mission_id:
			team_mission.remove(m)
		else:
			current_mission_to_buy_count[team_mission[m].get("mission_id")]+=1
			
	if team_mission.size()>=5:
		return
	
	mission_sequence+=1
	# decide new mission to add
	if current_mission_to_buy_count[MT_TOWN]==0:
		for s in range (0,owned_settlement.size()):
			if !owned_settlement[s].is_town():
				var new_mission={to_buy=MT_TOWN,settlement=owned_settlement[s],is_ordered_by=false}
				team_mission.append(new_mission)
				break
				
	if team_mission.size()>=5:
		return
		
	## 2do Add more rules what to do here

func has_interest_on_settlement(target_settlement,initiating_teammate):
	if(target_settlement.get_owner_team()!=null): # already owned
		return false
	if get_number_of_buying_members()>get_member_count()/2:	# team already occupied
		return false
	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		if (mission.to_buy==MT_SETTLEMENT 
		  and mission.resource==target_settlement.get_settlement_resource()
		  and !mission.is_ordered_by):
			if get_amount_missing(target_settlement.settlement_price)>0:
				continue
			if target_settlement.get_settlement_price_count()-1>(get_resource_count()/2):
				continue
			mission.is_ordered_by=initiating_teammate
			return mission_id
	return false

func take_posession(settlement):
	if owned_settlement.has(settlement):
			return true
	if settlement.set_owner_team(self):
		owned_settlement.append(settlement)
		return true
	return false


# getter / Setter

func get_amount_missing(target_price):
	var deviation=0
	var team_resources=get_team_resources()
	prints("checking_price",target_price)
	for i in range(0,team_resources.size()):
		if team_resources[i]<target_price[i]:
			deviation+=target_price[i]-team_resources[i]
	return deviation 


func get_member_count():
	return $Teammates.get_child_count()

func get_number_of_buying_members():
	var buyer_count=0
	for p in range(0,$Teammates.get_child_count()):
		if $Teammates.get_child(p).is_trying_to_buy():
			buyer_count+=1
	return buyer_count

func get_owned_settlement(index):
	return owned_settlement[index]
	
func get_owned_settlement_count():
	return owned_settlement.size()

func get_resource_collector_count():
	var collector_count=0
	for p in range(0,$Teammates.get_child_count()):
		if $Teammates.get_child(p).is_gathering_resources():
			collector_count+=1
	return collector_count

func get_resource_count():
	var total_resources=0
	for p in range(0,$Teammates.get_child_count()):
		total_resources+=$Teammates.get_child(p).get_resource_count()
	return total_resources

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

func get_team_resources():
	var team_resources=[0,0,0,0,0]
	for p in range(0,$Teammates.get_child_count()):
		for i in range(0,team_resources.size()):
			team_resources[i]+=$Teammates.get_child(p).ressource_inventory[i]
	prints("Team has:",team_resources)
	return team_resources
