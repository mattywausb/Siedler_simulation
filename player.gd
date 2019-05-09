extends KinematicBody2D



# class member variables go here, for example:
	
# game parameters for player

const PLAYER_STRAIGHT_SPEED=260
const PLAYER_CATCH_SPEED=300
const PLAYER_STROLL_SPEED=200  
const PLAYER_TRADE_TIME=0.2
const PLAYER_BUY_TIME=0.2
const PLAYER_DODGE_TIME=1
const PLAYER_WAIT_TIME=2
const PLAYER_COLLECT_TIME=0.1

enum {WOOD,WOOL,CLAY,WEED,IRON}
enum {XT_TOWER=10, XT_SCHOOL=20, XT_UNIVERSITY, XT_CHAPEL=30, XT_MONASTERY, XT_CHURCH, XT_MARKET=40, XT_STOCK_MARKET, XT_TOWN=100}

	
var ressource_inventory=[0,0,0,0,0]
#var ressource_inventory=[2,2,2,2,2]  # DEBUG VERSION
var sunpoint_inventory=[0,0,0,0,0]
var my_team

var strategic_target_price=[0,0,0,0,0]
var strategic_target=ST_IDLE
var strategic_target_settlement
var strategic_target_asset="SETTLEMENT"

var last_seen_settlement
var last_player_exchanged_with
var last_seen_player
var last_vision_time=0

var player_mission_id=null
var player_task=PT_IDLE
var player_state=PS_NORMAL
var player_operation=PO_IDLE
var player_move_speed=0

var target_of_operation

var transaction_partner=null

var task_target_object=null

var player_move_vector
var last_collider
var player_team_color_index=0

var target_of_sidestep
var sidestep_minimal_distance=10
var remaining_pause_time =0
var settlement_candidate  #settlement, that has been found


const zero_price=[0,0,0,0,0]

enum {ST_IDLE,ST_BUY_SETTLEMENT,ST_BUY_EXTENTION,
	ST_GATHER_INFORMATION,ST_GATHER_RESOURCES}
const ST_str=["ST_IDLE","ST_BUY_SETTLEMENT","ST_BUY_EXTENTION",
	"ST_GATHER_INFORMATION","ST_GATHER_RESOURCES"]

enum {PS_NORMAL,PS_SIDESTEP}
enum 	    {PO_IDLE,  PO_GOTO_TARGET,  PO_EXCHANGE_MASTER,  PO_EXCHANGE_CLIENT,  PO_PAUSE,  PO_GO_RANDOM_POSITION,  PO_EXCHANGE_WITH_STATION}
const PO_str=["PO_IDLE","PO_GOTO_TARGET","PO_EXCHANGE_MASTER","PO_EXCHANGE_CLIENT","PO_PAUSE","PO_GO_RANDOM_POSITION","PO_EXCHANGE_WITH_STATION"]

enum {PE_TARGET_MET,PE_INTERRUPT_BY_EXCHANGE, 
      PE_INIT, PE_TIMER_TIMEOUT,PE_REACHED_POSITION,
	  PE_EXCHANGE_COMPLETE,PE_SEE_OTHER_PLAYER,
	  PE_SEE_SETTLEMENT}

const PE_str=["PE_TARGET_MET","PE_INTERRUPT_BY_EXCHANGE", 
      "PE_INIT", "PE_TIMER_TIMEOUT","PE_REACHED_POSITION",
	  "PE_EXCHANGE_COMPLETE","PE_SEE_OTHER_PLAYER",
	  "PE_SEE_SETTLEMENT"]

enum {PT_IDLE,PT_EXCHANGE_WITH_TEAMMATE, PT_STROLL_AROUND,
	PT_DISCOVER_SETTLEMENT,PT_EXCHANGE_WITH_SETTLEMENT,
	PT_EXCHANGE_WITH_WAREHOUSE,
	PT_BUY_SETTLEMENT,PT_BUY_EXTENTION,PT_EXCHANGE_WITH_OPPONENT
	PT_EXCHANGE_CLIENT}
	
const PT_str=["PT_IDLE","PT_EXCHANGE_WITH_TEAMMATE", "PT_STROLL_AROUND",
	"PT_DISCOVER_SETTLEMENT,","PT_EXCHANGE_WITH_SETTLEMENT","PT_EXCHANGE_WITH_WAREHOUSE",
	"PT_BUY_SETTLEMENT","PT_BUY_EXTENTION","PT_EXCHANGE_WITH_OPPONENT",
	"PT_EXCHANGE_CLIENT"]

					
const sunpoint_color="f0f000"

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	get_node("ID").set_text(String(get_instance_id()))
	my_team=get_parent().get_parent()
	update_inventory_display()
	pass

func _process(delta):
	# Called every frame. Delta is time since last frame.
	# Update game logic here.
		process_operation(delta)
		process_visual_update(delta)
		

func _on_Timer_timeout():
	#print_trace_with_note("timed out")
	if player_operation==PO_EXCHANGE_MASTER or player_operation==PO_EXCHANGE_CLIENT or player_operation==PO_EXCHANGE_WITH_STATION:
		manage_task(PE_EXCHANGE_COMPLETE)
		return
	manage_task(PE_TIMER_TIMEOUT)

func _on_Vision_area_entered(area):
	if  OS.get_system_time_secs()-last_vision_time<1: # only trigger one event in a second
		return
	last_vision_time=OS.get_system_time_secs() # 
	if transaction_partner!=null:  
		return # dont get distracted when in a transaction
	match area.get_name():
		"SettlementVision":
			#prints(get_instance_id(),"now seeing",area.get_instance_id(),area.get_name())
			var settlement=area.get_parent()
			if settlement!=last_seen_settlement: # never go to same settlement twice
				last_seen_settlement=settlement
				manage_task(PE_SEE_SETTLEMENT)

		"PlayerVision":
			if last_seen_player!=area.get_parent():
				last_seen_player=area.get_parent()
				#prints(get_instance_id(),"sees",last_seen_player.get_instance_id())
				manage_task(PE_SEE_OTHER_PLAYER)
				

func print_trace_start_mission(mission_name):
	return
	prints(get_instance_id(),"-",mission_name,
							"mission_id=",player_mission_id,
							"settlment=",strategic_target_settlement,
							"asset=",strategic_target_asset)


func print_trace_with_target(target):
	return
	prints(get_instance_id(),"-",PT_str[player_task],
							PO_str[player_operation],"target:",target.get_instance_id())

func print_trace_with_note(note):
	return
	prints(get_instance_id(),"-",PT_str[player_task],
							"-",PO_str[player_operation],"note:",note)

func print_trace():
	return
	prints(get_instance_id(),"-",PT_str[player_task],
							PO_str[player_operation])

func print_trace_event(event):
	return
	prints(get_instance_id(),"-",
							PE_str[event],
							">>",
							PT_str[player_task])


# ###############################################################
#   Determine next task to fullfill the current strategic target
# ###############################################################
func choose_task():  
	#print_trace_with_note("choosing next task for "+ST_str[strategic_target])
	player_operation=PO_IDLE

	if strategic_target==ST_BUY_SETTLEMENT:
	# can we go, and buy the settlement ?
		if get_amount_missing(strategic_target_price)==0:  # Player cam afford settlement
			manage_PT_BUY_SETTLEMENT(PE_INIT)
			return
		
		if my_team.get_amount_missing(strategic_target_settlement.settlement_price)==0:
			manage_PT_EXCHANGE_WITH_TEAMMATE(PE_INIT)  # get more resources by exchange
			return
		if my_team.get_amount_missing(strategic_target_settlement.settlement_price)<= Global.get_price_miss_limit():
			manage_PT_STROLL_AROUND(PE_INIT) # hope for trading, stroll around
			return
		else:  # Target not reachable any more
			strategic_target=ST_IDLE
			strategic_target_settlement=null
			player_mission_id=null
			update_inventory_display()
			my_team.cancel_old_mission(self)
			my_team.determine_next_mission(self)
			
	if strategic_target==ST_BUY_EXTENTION:
		if get_amount_missing(strategic_target_price)==0:  # we can afford it
			manage_PT_BUY_EXTENTION(PE_INIT)
			return
			
		if my_team.get_amount_missing(strategic_target_price)==0: # need to get resources from teammate
			manage_PT_EXCHANGE_WITH_TEAMMATE(PE_INIT)
			return
		elif my_team.get_amount_missing(strategic_target_price)<= Global.get_price_miss_limit(): # Team might get it by trading
			manage_PT_STROLL_AROUND(PE_INIT)
			return
		else: # resources are far from getting available
			my_team.determine_next_mission(self)
			manage_PT_STROLL_AROUND(PE_INIT)
			return

	# should go to warehouse urgent
	if get_sunpoint_sum()>=3:
			manage_PT_EXCHANGE_WITH_WAREHOUSE(PE_INIT)
			return
	
	if strategic_target==ST_GATHER_RESOURCES:
		if strategic_target_settlement:  # we already have a target
				task_target_object=strategic_target_settlement
				manage_PT_EXCHANGE_WITH_SETTLEMENT(PE_INIT)		
				return			
		if get_sunpoint_sum()>=2:  # we should change sun into resource
			manage_PT_EXCHANGE_WITH_WAREHOUSE(PE_INIT)
			return
	
		var try_index=randi()%my_team.get_owned_settlement_count() # choose a random owned settlement
		if last_seen_settlement!=my_team.get_owned_settlement(try_index):	
				task_target_object=my_team.get_owned_settlement(try_index)	
				manage_PT_EXCHANGE_WITH_SETTLEMENT(PE_INIT)		
				return

	if get_sunpoint_sum()>0: # nothing really to do, but get rid of sunpoints
			manage_PT_EXCHANGE_WITH_WAREHOUSE(PE_INIT)
			return
			
	# without any plan:
	manage_PT_STROLL_AROUND(PE_INIT)
	


func modify_sunpoint_add(delta_array):
	for i in range (0,delta_array.size()):
		sunpoint_inventory[i]+=delta_array[i]
	update_inventory_display()

func modify_inventory_slot(slot_index,delta):
	ressource_inventory[slot_index]+= delta
	if(ressource_inventory[slot_index]<0):
		ressource_inventory[slot_index]=0
	update_inventory_display()

func modify_inventory_add(delta_array):
	for i in range(0,ressource_inventory.size()):
		ressource_inventory[i]+= delta_array[i]
		if(ressource_inventory[i]<0):
			ressource_inventory[i]=0
	update_inventory_display()

func modify_inventory_subtract(delta_array):
	for i in range(0,ressource_inventory.size()):
		ressource_inventory[i]-= delta_array[i]
		if(ressource_inventory[i]<0):
			ressource_inventory[i]=0
	update_inventory_display()

func update_inventory_display():
	var inventory_display=get_node("LowerInventory")
	# color resources
	for i in range (0,inventory_display.get_child_count()):
		if ressource_inventory[i%5]>=int(i/5)+1:
			inventory_display.get_child(i).visible=true
			inventory_display.get_child(i).color=Color(Global.get_resource_color(i%5))
		else:
			inventory_display.get_child(i).visible=false
	# color sunpoints
	inventory_display=get_node("Sunpoints")
	var sun_point_sum=get_sunpoint_sum()
	for i in range(0,inventory_display.get_child_count()):
		if sun_point_sum> i:
			inventory_display.get_child(i).visible=true
			inventory_display.get_child(i).color=Color(sunpoint_color)
		else:
			inventory_display.get_child(i).visible=false
	# color target price
	inventory_display=get_node("UpperInventory")
	for i in range (0,inventory_display.get_child_count()):
		if strategic_target_price[i%5]>=int(i/5)+1:
			inventory_display.get_child(i).visible=true
			inventory_display.get_child(i).color=Color(Global.get_resource_color(i%5))
		else:
			inventory_display.get_child(i).visible=false

func set_strategic_target_price(new_price_setting):
	for r in range(0,strategic_target_price.size()):
		strategic_target_price[r]=new_price_setting[r]
	update_inventory_display()

func process_visual_update(delta):
	
	for i in range(0,get_node("OperationIndicators").get_child_count()):
		var slot=get_node("OperationIndicators").get_child(i)
		slot.visible=false
		
	if player_state==PS_SIDESTEP :
		get_node("OperationIndicators/SIDESTEP").visible=true
	else:
		match player_operation:
			PO_GOTO_TARGET:
				get_node("OperationIndicators/GOTO_TARGET").visible=true
			PO_EXCHANGE_WITH_STATION:
				get_node("OperationIndicators/EXCHANGE").visible=true
			PO_EXCHANGE_CLIENT:
				get_node("OperationIndicators/EXCHANGE_CLIENT").visible=true
			PO_EXCHANGE_MASTER:
				get_node("OperationIndicators/EXCHANGE_MASTER").visible=true
			PO_PAUSE  :
				get_node("OperationIndicators/PAUSE").visible=true
			
	for i in range(0,get_node("StrategyIndicators").get_child_count()):
		var slot=get_node("StrategyIndicators").get_child(i)
		slot.visible=false
		
	match strategic_target:
		ST_BUY_SETTLEMENT:
			get_node("StrategyIndicators/ST_BUY_SETTLEMENT").visible=true
		ST_BUY_EXTENTION:
			get_node("StrategyIndicators/ST_BUY_EXTENTION").visible=true
		ST_GATHER_RESOURCES:
			get_node("StrategyIndicators/ST_GATHER_RESOURCES").visible=true
		ST_GATHER_INFORMATION:
			get_node("StrategyIndicators/ST_GATHER_INFORMATION").visible=true

			


func process_operation(delta):
	
	if player_state==PS_SIDESTEP:
		if target_of_sidestep.distance_to(get_global_position())>10:
			player_move_vector=(target_of_sidestep - get_global_position()).normalized()
			var collision=move_and_collide(player_move_vector * player_move_speed/2 * delta)
			if collision != null:
				enter_PS_SIDESTEP(collision)
				#print(get_instance_id(),"- PS_SIDESTEP -###collision###")
			return
		else:
			player_state=PS_NORMAL
			#print(get_instance_id(),"- PS_NORMAL")
			sidestep_minimal_distance=10

	if player_operation == PO_IDLE:
		manage_task(PE_INIT)


	if player_operation==PO_GOTO_TARGET:
		player_move_vector=(target_of_operation.get_global_position() - get_global_position()).normalized()
		var collision=move_and_collide(player_move_vector * player_move_speed * delta)
		if collision:
			if collision.get_collider()==target_of_operation:
				manage_task(PE_TARGET_MET)
				return
			if collision.get_collider()==last_collider:
				enter_PS_SIDESTEP(collision)
			else:
				last_collider=collision.get_collider()
		else:
			last_collider=null

	if player_operation==PO_EXCHANGE_MASTER or player_operation==PO_EXCHANGE_CLIENT or player_operation==PO_EXCHANGE_WITH_STATION:
		return # will be managed by timeout event
		
	if player_operation==PO_PAUSE:
		return # will be managed by timeout event
			
	if player_operation==PO_GO_RANDOM_POSITION:
		player_move_vector=(target_of_operation - get_global_position()).normalized()
		if target_of_operation.distance_to(get_global_position())>25:
			var collision=move_and_collide(player_move_vector * PLAYER_STROLL_SPEED * delta)
			if collision:
					enter_PS_SIDESTEP(collision)
		else:
			manage_task(PE_REACHED_POSITION)
			
########## implementation of simple operations ############


func enter_PO_GOTO_TARGET(new_target, speed):
	player_move_speed=speed
	target_of_operation=new_target
	player_operation=PO_GOTO_TARGET
	#print_trace_with_target(target_of_operation)


func enter_PO_PAUSE(waittime):
	player_operation=PO_PAUSE
	#print_trace()
	get_node("Timer").set_wait_time(waittime)
	get_node("Timer").start()
	
func enter_PO_EXCHANGE_MASTER():
	if !begin_transaction(target_of_operation):
		return false
	if target_of_operation.enter_PO_EXCHANGE_CLIENT(self):
		player_operation=PO_EXCHANGE_MASTER
		last_player_exchanged_with=target_of_operation
		#print_trace_with_target(target_of_operation)
		get_node("Timer").set_wait_time(2.5)
		get_node("Timer").start()
		return true
	else:
		end_transaction()
		return false
	
func enter_PO_EXCHANGE_CLIENT(partner):
		assert transaction_partner==partner
			
		player_operation=PO_EXCHANGE_CLIENT
		target_of_operation=partner
		last_player_exchanged_with=partner
		player_state=PS_NORMAL
		player_task=PT_EXCHANGE_CLIENT
		#print_trace_with_target(target_of_operation)
		get_node("Timer").set_wait_time(2)
		get_node("Timer").start()
		return true




func enter_PO_EXCHANGE_WITH_STATION(duration):
	if begin_transaction(target_of_operation):
			player_operation=PO_EXCHANGE_WITH_STATION
			#print_trace_with_target(target_of_operation)
			get_node("Timer").set_wait_time(duration)
			get_node("Timer").start()
			return true
	else:
			return false


func enter_PO_GO_RANDOM_POSITION(distance):
	player_operation=PO_GO_RANDOM_POSITION
	#print_trace()
	var x=max(min(get_global_position().x+randi()%distance*2-distance,int(get_viewport().size.x-20)),20)
	var y=max(min(get_global_position().y+randi()%distance*2-distance,int(get_viewport().size.y-20)),20)
	target_of_operation=Vector2(x,y)
	player_move_speed=PLAYER_STROLL_SPEED
	
func enter_PS_SIDESTEP(collision):
	var sidestep_direction=collision.get_remainder().bounce(collision.get_normal()).normalized().rotated(randf()*PI-PI/2)
	target_of_sidestep=get_global_position()+sidestep_direction*(sidestep_minimal_distance+randi()%60)
	sidestep_minimal_distance+=5
	if(sidestep_minimal_distance>50):
		sidestep_minimal_distance=50
	#print(get_instance_id(),"- PS_SIDESTEP from",get_global_position().x,",",get_global_position().y," to ",target_of_sidestep.x,",",target_of_sidestep.y , " because of ",collision.get_collider().get_instance_id())
	player_state=PS_SIDESTEP



func manage_PT_BUY_SETTLEMENT(event):
	match event:
		PE_INIT :
			player_task=PT_BUY_SETTLEMENT
			print_trace_event(event)
			task_target_object=get_node("/root/Spiel/Townhall")
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)
			return

		PE_SEE_OTHER_PLAYER:
			return # we dont trade, when we have the money
			
		PE_SEE_SETTLEMENT:
			return  # ignore this, during buy of building

		PE_TARGET_MET:
			print_trace_event(event)
			if task_target_object==strategic_target_settlement: #final touch of settlement
				last_seen_settlement=target_of_operation
				my_team.determine_next_mission(self)
				return
			
			# we are at the townhall	
			if(strategic_target_settlement.get_owner_team()): # already bought
				my_team.determine_next_mission(self)
				return
			if begin_transaction(target_of_operation):
				enter_PO_EXCHANGE_WITH_STATION(PLAYER_BUY_TIME) #sets timer
				return
			else:
				enter_PO_GO_RANDOM_POSITION(200)
			return

		PE_REACHED_POSITION:
			enter_PO_PAUSE(PLAYER_DODGE_TIME)
	
		PE_TIMER_TIMEOUT:
			print_trace_event(event)
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)
			return
		
		PE_EXCHANGE_COMPLETE:
			if(task_target_object==get_node("/root/Spiel/Townhall")): #when at townhall
				print_trace_event(event)
				end_transaction()
				if my_team.take_posession(strategic_target_settlement,player_mission_id):
					modify_inventory_subtract(strategic_target_price)
					my_team.modify_team_score(1)
					for r in range(0,strategic_target_price.size()):
						strategic_target_price[r]=0
					modify_sunpoint_add(strategic_target_settlement.give_sun_points())
					task_target_object=strategic_target_settlement
					enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)			
				else:
					my_team.determine_next_mission(self)
			else:
				end_transaction()
				my_team.determine_next_mission(self)
				return

func manage_PT_BUY_EXTENTION(event): # go to town hall, buy extention, goto settlement
	match event:
		PE_INIT :
			player_task=PT_BUY_EXTENTION
			print_trace_event(event)
			task_target_object=get_node("/root/Spiel/Townhall")
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)

		PE_SEE_OTHER_PLAYER:
			return # we dont trade, when we have the money
			
		PE_SEE_SETTLEMENT:
			return  # ignore this, when going to buy an extentions

		PE_TARGET_MET:
			print_trace_event(event)
			if task_target_object==strategic_target_settlement: #final touch of settlement
				my_team.determine_next_mission(self)
				return
			
			# we are at the townhall
			if begin_transaction(target_of_operation):	
				if !strategic_target_settlement.is_extention_buildable(strategic_target_asset):
					# but cant finish our plan, since preferences are not met any more
					end_transaction()
					my_team.discard_mission(player_mission_id)
					my_team.determine_next_mission(self) 
					return
				
				enter_PO_EXCHANGE_WITH_STATION(PLAYER_BUY_TIME)  # start trade with townhall
			else:
				enter_PO_GO_RANDOM_POSITION(200)

		PE_REACHED_POSITION:
			enter_PO_PAUSE(2)
			
		PE_TIMER_TIMEOUT:
			#print_trace_event(event)
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)

		PE_EXCHANGE_COMPLETE:
			if(task_target_object==get_node("/root/Spiel/Townhall")): 
				#print_trace_event(event)
				if strategic_target_settlement.build_extention(strategic_target_asset):
					modify_inventory_subtract(strategic_target_price)
					my_team.modify_team_score(1)
					my_team.complete_mission(player_mission_id)
					set_strategic_target_price(zero_price)
					strategic_target_asset=null
					task_target_object=strategic_target_settlement
					end_transaction()
					manage_PT_EXCHANGE_WITH_SETTLEMENT(PE_INIT)
				else:
					strategic_target_asset=null
					my_team.discard_mission(player_mission_id)
					end_transaction()
					my_team.determine_next_mission(self)
			else:
				#print_trace_event(event)
				end_transaction()
				my_team.determine_next_mission(self)

func manage_PT_DISCOVER_SETTLEMENT(event):
	# walk to an unknown settlement to check it out
	match event:
		PE_INIT :
			player_task=PT_DISCOVER_SETTLEMENT
			print_trace_event(event)
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)

		PE_SEE_OTHER_PLAYER:
			return # ignore other settlement during discovery
			
		PE_SEE_SETTLEMENT:
			return  # ignore this, when going to specific settlement

		PE_TARGET_MET:
			print_trace_event(event)
			player_mission_id=my_team.decide_on_settlement(target_of_operation,self)
			if player_mission_id!=null:
				#prints(get_instance_id(),"tries to buy settlement",target_of_operation.get_instance_id())
				strategic_target_settlement=target_of_operation
				set_strategic_target_price(strategic_target_settlement.settlement_price)
				strategic_target=ST_BUY_SETTLEMENT
				choose_task()
				return
			my_team.determine_next_mission(self)

func manage_PT_EXCHANGE_CLIENT(event):
	match event:
		PE_INIT:
			player_task=PT_EXCHANGE_CLIENT  # we got called for a trade, so we walt to the caller
			enter_PO_GOTO_TARGET(transaction_partner,PLAYER_STROLL_SPEED)
		PE_EXCHANGE_COMPLETE :
			choose_task()  # continue with current target
		PE_SEE_SETTLEMENT:
			return  # ignore this, when trading
		PE_SEE_OTHER_PLAYER:
			return  # ignore this when trading
		PE_TARGET_MET:
			enter_PO_PAUSE(1) # wait for initiator to manage transaction
		PE_TIMER_TIMEOUT: # continue with current target, when max wait time is over
			choose_task()  
		"_":
			print(get_instance_id(),"- manage_PT_EXCHANGE_CLIENT unhandled event",event)

func manage_PT_EXCHANGE_WITH_OPPONENT(event):
	match event:
		PE_INIT:
			player_task=PT_EXCHANGE_WITH_OPPONENT
			print_trace_event(event)
			task_target_object.manage_PT_EXCHANGE_CLIENT(PE_INIT)
			enter_PO_GOTO_TARGET(transaction_partner,PLAYER_CATCH_SPEED)
			
		PE_SEE_OTHER_PLAYER:
			return # ignore this, when trading
			
		PE_SEE_SETTLEMENT:
			return  # ignore this, when trading
			
		PE_TARGET_MET:
			try_to_trade(transaction_partner)
			end_transaction()
			choose_task()   # resume strategic target
			

func manage_PT_EXCHANGE_WITH_TEAMMATE(event):
	match event:
		PE_INIT :
			player_task=PT_EXCHANGE_WITH_TEAMMATE
			print_trace_event(event)
			if determine_best_change_partner():
				enter_PO_GOTO_TARGET(task_target_object,PLAYER_CATCH_SPEED)
				return
			manage_PT_STROLL_AROUND(PE_INIT)  # will be triggerd if none suits needs

		PE_SEE_OTHER_PLAYER:
			if try_to_trade(last_seen_player):
				choose_task()
		
		PE_SEE_SETTLEMENT:
			return  # ignore this, when trading
		
		PE_TARGET_MET:
			#print_trace_event(event)
			if ! enter_PO_EXCHANGE_MASTER(): # establishes transaction and timer
				enter_PO_GO_RANDOM_POSITION(100)
		
		PE_REACHED_POSITION:
			enter_PO_PAUSE(2)
	
		PE_TIMER_TIMEOUT:		# Pause ended 
			#print_trace_event(event)
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_CATCH_SPEED)

		PE_EXCHANGE_COMPLETE:
			#print_trace_event(event)
			# get resources wanted and available
			for r in range(0,ressource_inventory.size()):
				if (ressource_inventory[r]<strategic_target_price[r]):
					var amount=0
					if task_target_object.ressource_inventory[r]>task_target_object.strategic_target_price[r]:
						amount=task_target_object.ressource_inventory[r]-task_target_object.strategic_target_price[r]
					#print_trace_with_note("Receiving ressource")
					task_target_object.modify_inventory_slot(r,-amount)
					modify_inventory_slot(r,amount)
					
			# if only 1 resource is missing try to get it even partner needs it but is not finished
			if (task_target_object.get_amount_missing(task_target_object.strategic_target_price)>0
				and get_amount_missing(strategic_target_price)==1):
					for r in range(0,ressource_inventory.size()):
						if (ressource_inventory[r]<strategic_target_price[r] and
							task_target_object.ressource_inventory[r]>0):
							task_target_object.modify_inventory_slot(r,-1)
							modify_inventory_slot(r,1)
			end_transaction()
			choose_task()
			return
		"_":
			print(get_instance_id(),"- PT_EXCHANGE_WITH_TEAMMATE unhandled event",event)
		





func manage_PT_EXCHANGE_WITH_SETTLEMENT(event):
	match event:
		PE_INIT :
			player_task=PT_EXCHANGE_WITH_SETTLEMENT
			print_trace_event(event)
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)
			
		PE_SEE_OTHER_PLAYER:
			if !my_team.has_member(last_seen_player):
				if begin_transaction(last_seen_player):
					task_target_object=last_seen_player
					manage_PT_EXCHANGE_WITH_OPPONENT(PE_INIT)
			
		PE_SEE_SETTLEMENT:
			return  # ignore this, when going to specific settlement
			
		PE_TARGET_MET:
			print_trace_event(event)
			last_seen_settlement=target_of_operation
			if target_of_operation.get_sun_point_sum()>0:
				if begin_transaction(task_target_object):
					enter_PO_EXCHANGE_WITH_STATION(PLAYER_COLLECT_TIME)
					return
			my_team.determine_next_mission(self)

		PE_TIMER_TIMEOUT:
			#print_trace_event(event)
			enter_PO_GOTO_TARGET(task_target_object,PLAYER_STRAIGHT_SPEED)
			
		PE_EXCHANGE_COMPLETE:
			print_trace_event(event)
			modify_sunpoint_add(task_target_object.give_sun_points())
			end_transaction()
			if task_target_object==strategic_target_settlement:
				my_team.determine_next_mission(self)
				return
			choose_task()

func manage_PT_EXCHANGE_WITH_WAREHOUSE(event):
	match event:
		PE_INIT :
			player_task=PT_EXCHANGE_WITH_WAREHOUSE
			print_trace_event(event)
			var warehouse_list=get_node("/root/Spiel/Warehouses")
			var best_distance=9999
			var best_warehouse
			for i in range(0,warehouse_list.get_child_count()):
				var warehouse=warehouse_list.get_child(i)
				if warehouse.get_global_position().distance_to(get_global_position())<best_distance:
					best_warehouse=warehouse
					best_distance=warehouse.get_global_position().distance_to(get_global_position())
			enter_PO_GOTO_TARGET(best_warehouse,PLAYER_STRAIGHT_SPEED)
			return
			
		PE_SEE_OTHER_PLAYER:
			try_to_trade(last_seen_player)
		
		PE_SEE_SETTLEMENT:
			return  # ignore this, when going to warehouse
			
		PE_TARGET_MET:
			print_trace_event(event)
			if begin_transaction(target_of_operation):
				enter_PO_EXCHANGE_WITH_STATION(PLAYER_COLLECT_TIME)
				return
			else:
				enter_PO_PAUSE(2)
			return
	
		PE_TIMER_TIMEOUT:
			#print_trace_event(event)
			enter_PO_GOTO_TARGET(target_of_operation,PLAYER_STRAIGHT_SPEED)
			return
		
		PE_EXCHANGE_COMPLETE:
			print_trace_event(event)
			for r in range (0,ressource_inventory.size()):
				ressource_inventory[r]+=sunpoint_inventory[r]
				sunpoint_inventory[r]=0
			update_inventory_display()
			end_transaction()
			last_player_exchanged_with=null
			my_team.determine_next_mission(self)
			return



func manage_PT_STROLL_AROUND(event):
	match event:
		PE_INIT,PE_TIMER_TIMEOUT:
			player_task=PT_STROLL_AROUND
			print_trace_event(event)
			enter_PO_GO_RANDOM_POSITION(600)
	#		
	# Vision Detection might swith to a GO_TO_TARGET Operation, when settelmen in sight
	# see _on_Vision_area_entered
	#
		PE_SEE_OTHER_PLAYER:
			if !my_team.has_member(last_seen_player):
				if begin_transaction(last_seen_player):
					task_target_object=last_seen_player
					task_target_object.enter_PO_PAUSE(PLAYER_WAIT_TIME)
					manage_PT_EXCHANGE_WITH_OPPONENT(PE_INIT)
		
		PE_SEE_SETTLEMENT:
			if (last_seen_settlement.get_owner_team()==null) :
				task_target_object=last_seen_settlement
				manage_PT_DISCOVER_SETTLEMENT(PE_INIT)
				return
			if(last_seen_settlement.get_owner_team()==my_team):
				task_target_object=last_seen_settlement
				manage_PT_EXCHANGE_WITH_SETTLEMENT(PE_INIT)
	
		PE_REACHED_POSITION:
			print_trace_event(event)
			my_team.determine_next_mission(self)
			return


func manage_task(event):
	match player_task:
		PT_BUY_SETTLEMENT:
			manage_PT_BUY_SETTLEMENT(event)
		PT_BUY_EXTENTION:
			manage_PT_BUY_EXTENTION(event)
		PT_DISCOVER_SETTLEMENT:
			manage_PT_DISCOVER_SETTLEMENT(event)
		PT_EXCHANGE_CLIENT:
			manage_PT_EXCHANGE_CLIENT(event)
		PT_EXCHANGE_WITH_OPPONENT:
			manage_PT_EXCHANGE_WITH_OPPONENT(event)
		PT_EXCHANGE_WITH_SETTLEMENT:
			manage_PT_EXCHANGE_WITH_SETTLEMENT(event)
		PT_EXCHANGE_WITH_TEAMMATE:
			manage_PT_EXCHANGE_WITH_TEAMMATE(event)
		PT_EXCHANGE_WITH_WAREHOUSE:
			manage_PT_EXCHANGE_WITH_WAREHOUSE(event)
		PT_STROLL_AROUND:
			manage_PT_STROLL_AROUND(event)
		_:
			my_team.determine_next_mission(self)


func start_collect_ressources():
	player_mission_id=null
	strategic_target_settlement=null
	strategic_target=ST_GATHER_RESOURCES
	set_strategic_target_price(zero_price)
	choose_task()
	print_trace_start_mission("start_collect_resources")
	
func start_search_for_settlement():
	strategic_target=ST_GATHER_INFORMATION
	strategic_target_settlement=null
	player_mission_id=null
	set_strategic_target_price(zero_price)
	choose_task()
	print_trace_start_mission("start_search_for_settlement")
	
func start_buy_extention(mission_id,extention_id,target_settlement):
	player_mission_id=mission_id
	strategic_target=ST_BUY_EXTENTION
	strategic_target_asset=extention_id
	strategic_target_settlement=target_settlement
	set_strategic_target_price(target_settlement.get_extention_price(extention_id))
	choose_task()	
	print_trace_start_mission("start_buy_extention")

func start_buy_town(mission_id,target_settlement):
	player_mission_id=mission_id
	strategic_target=ST_BUY_EXTENTION
	strategic_target_asset=XT_TOWN
	strategic_target_settlement=target_settlement
	set_strategic_target_price(Global.get_price_for_town())
	choose_task()
	print_trace_start_mission("start_buy_town_extention")
	

func determine_best_change_partner():
	var best_teammate
	var best_score=0
	var candidate_count=0
	for p in range(0,get_parent().get_child_count()):
		var teammate=get_parent().get_child(p)
		var this_score=0
		if teammate== self or teammate==last_player_exchanged_with:
			continue
		for r in range(0, ressource_inventory.size()):
			if(ressource_inventory[r]<strategic_target_price[r] and
				teammate.ressource_inventory[r]>0): # candidate has missing ressource
				this_score+=1
				candidate_count+=1
				if(teammate.ressource_inventory[r]>teammate.strategic_target_price[r]): # candidate has more then he needs
					this_score+=1
					if(teammate.strategic_target_price[r]==0 ): # candidate does not need it at all
						this_score+=1
			if teammate==last_player_exchanged_with:
				this_score-=1
		if this_score>best_score or (this_score>0 and this_score==best_score and randi()%get_parent().get_child_count()==0):
			best_teammate=teammate
	if best_teammate:
		task_target_object=best_teammate
		return true
	else:
		return false
		
					
					
func enter_into_trade(offer,demand):
	if ressource_inventory[demand] <= strategic_target_price[offer]: # dont own it or need it
		return false

	var need_score = my_team.get_resource_need_score()
	if need_score[demand]<=0:  # team needs demanded resource it
		return false
	
	if need_score[offer]>0: # team has plenty of offered resource for its own
		return false
		
	# deal
	ressource_inventory[demand]-=1
	ressource_inventory[offer]+=1
	update_inventory_display()
	return true
	
					
func want_to_trade():
	var need_score = my_team.get_resource_need_score()
	var have_an_offer=false
	var have_demand=false
	for r in range (0,need_score.size()):
		if need_score[r]>=1 and ressource_inventory[r]> strategic_target_price[r]:
			have_an_offer=true
		if need_score[r]<0:
			have_demand=true
	return have_an_offer and have_demand

func try_to_trade(trade_partner):
	if !want_to_trade():
		return false
	if transaction_partner!=trade_partner: # we expect to have an established transaction
		return false
	var need_score = my_team.get_resource_need_score()
	prints(get_instance_id(),"Trying to trade with",trade_partner.get_instance_id())
	for offer in range (0,need_score.size()):
		if need_score[offer]>=1 and ressource_inventory[offer]> strategic_target_price[offer]:
			for demand in range (0,need_score.size()):
				if need_score[demand]<0:
					if trade_partner.enter_into_trade(offer,demand):
						ressource_inventory[offer]-=1
						ressource_inventory[demand]+=1
						prints(get_instance_id(),"traded",offer,"for",demand,"with",trade_partner.get_instance_id())
						update_inventory_display()
						return true # we only trade one resource in a offer
	return false # could not negotiate


func is_gathering_resources():
	return (strategic_target==ST_GATHER_RESOURCES)

func is_trying_to_buy():
	return (strategic_target==ST_BUY_EXTENTION or strategic_target==ST_BUY_SETTLEMENT )

func begin_transaction(partner):
	if transaction_partner==partner:
		return true
	if transaction_partner!=null:
		print_trace_with_note("already in transaction with other")
		return false
	if !partner.bind_transaction_partner(self):
		return false
	transaction_partner=partner
	return true

func bind_transaction_partner(partner):
	if transaction_partner==partner:
		return true
	if transaction_partner!=null:
		print_trace_with_note("already in transaction with other")
		return false
	transaction_partner=partner
	return true

func end_transaction():
	if transaction_partner!=null:
		transaction_partner.unbind_transaction_partner(self)
		transaction_partner=null
		
func unbind_transaction_partner(partner):
	if transaction_partner==partner:
		transaction_partner=null
	else:
		print_trace_with_note("transaction unbind request from wrong partner")

func verify_transaction_partner(partner):
	if transaction_partner==partner:
		return true
	return false



func get_amount_missing(target_price):
	var deviation=0
	for r in range(0,ressource_inventory.size()):
		if ressource_inventory[r]<target_price[r]:
			deviation+=target_price[r]-ressource_inventory[r]
	return deviation


func get_last_missing_resource_index():
	var missing_count=0
	var missing_index=-1
	for i in range (0, strategic_target_price.size()):
		if strategic_target_price[i]>ressource_inventory[i]:
			missing_count+=strategic_target_price[i]-ressource_inventory[i]
			missing_index=i
	if missing_count==1:
		return missing_index
	else:
		return -1
		
func get_resource_count():
	var total_count=0
	for r in range(0,ressource_inventory.size()):
		total_count+=ressource_inventory[r]
	return total_count



func get_sunpoint_sum():
	var sun_point_sum=0
	for i in range (0,sunpoint_inventory.size()):
		sun_point_sum+=sunpoint_inventory[i]
	return sun_point_sum		
	
func get_team():
	return my_team
