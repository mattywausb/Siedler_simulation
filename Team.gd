extends Node

# constants 
const teamsize=8
const INITIALLY_STOCKED_MEMBERS=2


const price_for_town= [0,3,0,2,0]

# main properties

var team_index=-1
var team_score=0
var team_color
var leading_teammate
var owned_settlement=[]
var resource_needs=[0,0,0,0,0]


enum {WOOD,WOOL,CLAY,WEED,IRON}
enum {XT_TOWER=10, XT_SCHOOL=20, XT_UNIVERSITY, XT_CHAPEL=30, XT_MONASTERY, XT_CHURCH, XT_MARKET=40, XT_STOCK_MARKET, XT_TOWN=100}


# Strategy 
enum {MT_SETTLEMENT,MT_TOWN,MT_EXTENTION}  # Mission types
const mt_text=["MT_SETTLEMENT","MT_TOWN","MT_EXTENTION"]


var team_mission={1:{mission_type=MT_SETTLEMENT,resource=CLAY,is_done_by=false,price=[0,0,0,0,0]},
				   2:{mission_type=MT_SETTLEMENT,resource=IRON,is_done_by=false,price=[0,0,0,0,0]},
				   3:{mission_type=MT_SETTLEMENT,resource=WOOL,is_done_by=false,price=[0,0,0,0,0]},
				   4:{mission_type=MT_SETTLEMENT,resource=WEED,is_done_by=false,price=[0,0,0,0,0]},
				   5:{mission_type=MT_SETTLEMENT,resource=WOOD,is_done_by=false,price=[0,0,0,0,0]}}
				
				   # Other examples added later by the functions
				   # {mission_type=MT_TOWN,settlement=owned_settlement[s],is_done_by=false}
				   # {mission_type=MT_EXTENTION,settlement=owned_settlement[s],extention_type=SCHOOL,is_done_by=false}


var mission_sequence=team_mission.size()+1

func print_trace_with_note(note):
	return
	prints("Team",team_index,note)

func print_trace_team_missions():
	return
	prints("Team",team_index,"Mission Plan ----")
	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		prints(mission_id,mt_text[mission.mission_type],mission)
	prints("---------")


func _ready():
	# initiate players (position, color, resources)
	var player_scene=load("res://player.tscn")
	randomize()
	
	for i in range(0,teamsize):
		var new_teammate=player_scene.instance()
		
		var x=randi()%(int(get_viewport().size.x/8))-get_viewport().size.x/16+get_viewport().size.x/2
		var y=randi()%(int(get_viewport().size.y/8))-get_viewport().size.y/16+get_viewport().size.y/2
		new_teammate.set_position(Vector2(x,y))
		if i<INITIALLY_STOCKED_MEMBERS:
			new_teammate.modify_inventory_add([1,1,1,1,1])
		print("Place player to " ,x,",",y)
		$Teammates.add_child(new_teammate)
	for i in range(0,get_parent().get_child_count()):
		if get_parent().get_child(i)==self:
			team_index=i
	$Scoreboard.set_position(Vector2(team_index*100,10))
	get_node("Scoreboard/ScoreDisplay").set_text("%03d"%team_score)
	print_trace_team_missions()
	
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
func add_mission(new_mission):
	mission_sequence+=1
	team_mission[mission_sequence]=new_mission
	
func determine_next_mission(teammember):
	#prints(teammember,"- asked for mission")
	cancel_old_mission(teammember)
	
	if get_owned_settlement_count()==0 :
		teammember.start_search_for_settlement()
		return
	
	# assign new collector if necessary
	if get_resource_collector_count()< (get_member_count()-1)/2:
		if get_resource_collector_count()< (get_owned_settlement_count()/3+1):
			teammember.start_collect_ressources()
			return
	
	# restrict number of buyers to half of member count	
	if get_number_of_buying_members()>=get_member_count()/3:
		teammember.start_search_for_settlement()
		return

	# check if we should try to build an extention
	for mission_id in team_mission:
		if mission_id==null:
			continue
		var mission=team_mission[mission_id]
		if mission.is_done_by:
			continue
		match mission.mission_type:
			MT_TOWN:
				if seems_affordable(Global.get_price_for_town()):
					teammember.start_buy_town(mission_id,mission.settlement)
					mission.is_done_by=teammember
					return
			MT_EXTENTION:
				if seems_affordable(owned_settlement[0].get_extention_price(mission.extention_type)):	
					teammember.start_buy_extention(mission_id,mission.extention_type,mission.settlement)
					mission.is_done_by=teammember
					return

	#default behaviour:
	teammember.start_search_for_settlement()
	
	
func cancel_old_mission(teammember):
	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		if mission.is_done_by and mission.is_done_by==teammember:
			mission.is_done_by=false
			if mission.mission_type==MT_SETTLEMENT:
				mission.mission_price=[0,0,0,0,0]



func complete_mission(completed_mission_id):
	var mission=team_mission[completed_mission_id]
	prints("Team",team_index,"completed mission",completed_mission_id,mt_text[mission.mission_type],mission)
	# remove the completed mission from the list and add a new one to it
	team_mission.erase(completed_mission_id)
	do_mission_refinement()

func discard_mission(completed_mission_id):
	print_trace_with_note("Mission discarded. Mission id= "+str(completed_mission_id))
	# remove the completed mission from the list and add a new one to it
	team_mission.erase(completed_mission_id)
	do_mission_refinement()
	
func do_mission_refinement():
	
	# aggregate current mission types
	var current_mission_mission_type_count=[0,0,0]
	
	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		current_mission_mission_type_count[mission.mission_type]+=1
			
	if team_mission.size()>=5:
		return
	
	# decide new mission to add
	# add town extention mission
	if current_mission_mission_type_count[MT_TOWN]==0:
		for i in range (0,owned_settlement.size()):
			var s=owned_settlement.size()-i-1
			if !owned_settlement[s].is_town(): # at this settlement is not a town
				var new_mission={mission_type=MT_TOWN,settlement=owned_settlement[s],resource=owned_settlement[s].get_settlement_resource(), is_done_by=false,price=price_for_town}
				add_mission(new_mission)
				break
				
	if team_mission.size()>=5:
		print_trace_team_missions()
		return

	# add building extention mission
	if current_mission_mission_type_count[MT_EXTENTION]<4 and current_mission_mission_type_count[MT_EXTENTION]<owned_settlement.size()/2:
		for s in range (0,owned_settlement.size()):
			var base_idea=(randi()%4+1)*10 # Basic extentions are multiple of 10 between 10 and 40
			for idea in range (base_idea,base_idea+9):
				if owned_settlement[s].is_extention_buildable(idea):
					var new_mission={mission_type=MT_EXTENTION,
									settlement=owned_settlement[s],
									extention_type=idea,
									price=owned_settlement[s].get_extention_price(idea),
									is_done_by=false}
					add_mission(new_mission)
					break
			if team_mission.size()>=5:
				print_trace_team_missions()
				return
				
	if team_mission.size()>=5:
		print_trace_team_missions()
		return	

	# add mission to buy settlement for a resource
	var most_wanted=get_least_produced_resource()
	var new_mission={mission_type=MT_SETTLEMENT,resource=most_wanted,is_done_by=false,price=[0,0,0,0,0]}
	add_mission(new_mission)
		
	print_trace_team_missions()


func decide_on_settlement(target_settlement,initiating_teammate):
	#prints(initiating_teammate, "- wants a settlement buy evaluation")
	if(target_settlement.get_owner_team()!=null): # already owned
		return null
	if get_number_of_buying_members()>get_member_count()/2:	# team already occupied
		return null
	var price=target_settlement.get_settlement_price()
	if !seems_affordable(price):
		return null
	var price_sum=0
	for r in range(0,price.size()):
		price_sum+=price[r]
	if price_sum-3 > owned_settlement.size()/3: # dont buy high price without enough
		return null
	
	

	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		if (mission.mission_type==MT_SETTLEMENT 
		  and mission.resource==target_settlement.get_settlement_resource()
		  and !mission.is_done_by):
			mission.is_done_by=initiating_teammate
			mission.price=target_settlement.get_settlement_price()
			#prints(initiating_teammate.get_instance_id(), "- gets ok to buy settlement. Mission ID=",mission_id)
			return mission_id
	return null

func take_posession(settlement,mission_id):
	complete_mission(mission_id)
	if owned_settlement.has(settlement):
			return false
	if settlement.set_owner_team(self):
		owned_settlement.append(settlement)
		return true
	return false

# evaluators
func has_member(candidate):
	for p in range(0,$Teammates.get_child_count()):
		if $Teammates.get_child(p)==candidate:
			return true
	return false
	

# getter / Setter

func get_amount_missing(target_price):
	var deviation=0
	var team_resources=get_team_resources()
	#prints("checking_price",target_price)
	for i in range(0,team_resources.size()):
		if team_resources[i]<target_price[i]:
			deviation+=target_price[i]-team_resources[i]
	return deviation 

func get_resource_income():

	var income_matrix=[0,0,0,0,0]
	
	# collect available income
	for settlement in owned_settlement:
		if settlement.is_town():
			income_matrix[settlement.get_settlement_resource()]+=Global.TOWN_INCOME
		else:
			income_matrix[settlement.get_settlement_resource()]+=Global.SETTLEMENT_INCOME
	return income_matrix

func get_least_produced_resource():
	var income_matrix=get_resource_income()

	# add already planned income
	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		if mission.mission_type==MT_SETTLEMENT or mission.mission_type==MT_TOWN:
			income_matrix[mission.resource]+=1

	# search for resource with lowest score
	var min_income=income_matrix[0]
	var min_income_resource=0
	for i in range (1,income_matrix.size()):
		if income_matrix[i]<min_income:
			min_income=income_matrix[i]
			min_income_resource=i
			
	return min_income_resource

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

func get_resource_need_score():
	var need_score=get_team_resources()

	for mission_id in team_mission:
		var mission=team_mission[mission_id]
		if mission.price:
			var fac=0.25
			if mission.is_done_by:
				fac=0.5
			for r in range (0,need_score.size()):
					need_score[r]+=mission.price[r]*fac
	for r in range(0,need_score.size()):
		need_score[r]=int(need_score[r])
	return need_score
	

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
	#prints("Team has:",team_resources)
	return team_resources

func is_mission_still_valid(mission_id,player):
	if mission_id==null or !team_mission.has(mission_id):
		return false
	var mission=team_mission[mission_id]
	if mission.is_done_by and mission.is_done_by!=player:
		return false
	if !mission.has("price"):
		return true
	if !seems_affordable(mission.price):
		return false
	return true

func seems_affordable(price):
	var trade_tolerance=get_resource_count()/5+1
	return get_amount_missing(price)<=trade_tolerance
					
func _on_Timer_timeout():
	print_trace_team_missions()
	pass # replace with function body

func log_status (game_time):
	var income_matrix=[0,0,0,0,0]
	
	# collect available income
	for settlement in owned_settlement:
		if settlement.is_town():
			income_matrix[settlement.get_settlement_resource()]+=2
		else:
			income_matrix[settlement.get_settlement_resource()]+=1
			
	var output_columns=[]
	output_columns.append(game_time)
	output_columns.append(team_index)
	output_columns.append(team_score)
	for i in range(0, income_matrix.size()):
		output_columns.append(income_matrix[i])
	prints("zzzzzzz>",output_columns)
		
