extends KinematicBody2D



# class member variables go here, for example:
	
# game parameters for player

const player_move_speed=80  
const player_stroll_speed=60  


enum {BRICK,IRON,WOOL,WEED,WOOD}
	
var ressource_inventory=[0,0,0,0,0]
var sunpoint_inventory=[0,0,0,0,0]
var my_team

var strategic_target_price=[0,0,0,0,0]
var strategic_target=ST_GATHER_INFORMATION
var strategic_target_settlement
var strategic_target_asset=SA_SETTLEMENT

enum {SA_SETTLEMENT,SA_TOWN}

var last_settlement_seen
var last_player_exchanged_with


var player_task=PT_IDLE
var player_state=PS_NORMAL
var player_operation=PO_IDLE
var target_of_operation

var player_move_vector
var last_collider
var player_team_color_index=0

var target_of_sidestep
var sidestep_minimal_distance=10
var remaining_pause_time =0
var settlement_candidate  #settlement, that has been found

const zero_price=[0,0,0,0,0]

enum {ST_BUY_SETTLEMENT,ST_BUY_EXTENTION,
	ST_GATHER_INFORMATION,ST_GATHER_RESOURCES}
const ST_str=["ST_BUY_SETTLEMENT","ST_BUY_EXTENTION",
	"ST_GATHER_INFORMATION","ST_GATHER_RESOURCES"]

enum {PS_NORMAL,PS_SIDESTEP}
enum 	    {PO_IDLE,  PO_GOTO_TARGET,  PO_EXCHANGE_MASTER,  PO_EXCHANGE_CLIENT,  PO_PAUSE,  PO_GO_POSITION,  PO_EXCHANGE_WITH_STATION}
const PO_str=["PO_IDLE","PO_GOTO_TARGET","PO_EXCHANGE_MASTER","PO_EXCHANGE_CLIENT","PO_PAUSE","PO_GO_POSITION","PO_EXCHANGE_WITH_STATION"]

enum {PE_TARGET_MET,PE_INTERRUPT_BY_EXCHANGE, 
      PE_IDLE, PE_TIMER_TIMEOUT,PE_REACHED_POSITION,
	  PE_EXCHANGE_COMPLETE}

const PE_str=["PE_TARGET_MET","PE_INTERRUPT_BY_EXCHANGE", 
      "PE_IDLE", "PE_TIMER_TIMEOUT","PE_REACHED_POSITION",
	  "PE_EXCHANGE_COMPLETE"]

enum {PT_IDLE,PT_EXCHANGE_WITH_TEAMMATE, PT_STROLL_AROUND,
	PT_EXCHANGE_WITH_SETTLEMENT,PT_EXCHANGE_WITH_WAREHOUSE,PT_BUY_BUILDING,PT_BUY_EXTENTION}
const PT_str=["PT_IDLE","PT_EXCHANGE_WITH_TEAMMATE", "PT_STROLL_AROUND",
	"PT_EXCHANGE_WITH_SETTLEMENT","PT_EXCHANGE_WITH_WAREHOUSE","PT_BUY_BUILDING","PT_BUY_EXTENTION"]


const inventory_color=[	"cb0b0b", # 1 = brick
					"000010", # 4 = iron
					"d0d0d0", # 5 = wool
					"e0a000", # 5 = weed
					"25cb17"] # 6 = green
					
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


func print_trace_with_target(target):
	#return
	prints(get_instance_id(),"-",PT_str[player_task],
							PO_str[player_operation],"target:",target.get_instance_id())

func print_trace_with_note(note):
	#return
	prints(get_instance_id(),"-",PT_str[player_task],
							"-",PO_str[player_operation],"note:",note)

func print_trace():
	#return
	prints(get_instance_id(),"-",PT_str[player_task],
							PO_str[player_operation])

func print_trace_event(event):
	#return
	prints(get_instance_id(),"-",PT_str[player_task],
							PO_str[player_operation],
							PE_str[event])

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
	var inventory_display=get_node("Inventory")
	# color resources
	for i in range (0,inventory_display.get_child_count()):
		if ressource_inventory[i%5]>=int(i/5)+1:
			inventory_display.get_child(i).visible=true
			inventory_display.get_child(i).color=Color(inventory_color[i%5])
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
	inventory_display=get_node("TargetPrice")
	for i in range (0,inventory_display.get_child_count()):
		if strategic_target_price[i%5]>=int(i/5)+1:
			inventory_display.get_child(i).visible=true
			inventory_display.get_child(i).color=Color(inventory_color[i%5])
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
		manage_task(PE_IDLE)


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
			
	if player_operation==PO_GO_POSITION:
		player_move_vector=(target_of_operation - get_global_position()).normalized()
		if target_of_operation.distance_to(get_global_position())>25:
			var collision=move_and_collide(player_move_vector * player_stroll_speed * delta)
			if collision:
					enter_PS_SIDESTEP(collision)
		else:
			manage_task(PE_REACHED_POSITION)
			
########## implementation of simple operations ############


func enter_PO_GOTO_TARGET(new_target):
	target_of_operation=new_target
	player_operation=PO_GOTO_TARGET
	print_trace_with_target(target_of_operation)


func enter_PO_PAUSE():
	player_operation=PO_PAUSE
	print_trace()
	get_node("Timer").set_wait_time(4)
	get_node("Timer").start()
	
func enter_PO_EXCHANGE_MASTER():
	if target_of_operation.enter_PO_EXCHANGE_CLIENT(self):
		player_operation=PO_EXCHANGE_MASTER
		last_player_exchanged_with=target_of_operation
		print_trace_with_target(target_of_operation)
		get_node("Timer").set_wait_time(2)
		get_node("Timer").start()
		return true
	else:
		return false
	
func enter_PO_EXCHANGE_CLIENT(partner):
	if(player_operation!=PO_EXCHANGE_CLIENT 
		and player_operation!=PO_EXCHANGE_MASTER 
		and player_operation!=PO_EXCHANGE_WITH_STATION
		and player_task!=PT_BUY_BUILDING ):
				player_operation=PO_EXCHANGE_CLIENT
				target_of_operation=partner
				last_player_exchanged_with=partner
				player_state=PS_NORMAL
				player_task=PT_EXCHANGE_WITH_TEAMMATE
				print_trace_with_target(target_of_operation)
				get_node("Timer").set_wait_time(2.5)
				get_node("Timer").start()
				return true
	else:
				return false

func enter_PO_EXCHANGE_WITH_STATION(duration):
	if target_of_operation.connect_exchange_partner(self):
			player_operation=PO_EXCHANGE_WITH_STATION
			print_trace_with_target(target_of_operation)
			get_node("Timer").set_wait_time(duration)
			get_node("Timer").start()
			return true
	else:
			return false


func enter_PO_GO_POSITION(position):
	player_operation=PO_GO_POSITION
	print_trace()
	target_of_operation=position
	
func enter_PS_SIDESTEP(collision):
	var sidestep_direction=collision.get_remainder().bounce(collision.get_normal()).normalized().rotated(randf()*PI-PI/2)
	target_of_sidestep=get_global_position()+sidestep_direction*(sidestep_minimal_distance+randi()%60)
	sidestep_minimal_distance+=5
	if(sidestep_minimal_distance>50):
		sidestep_minimal_distance=50
	#print(get_instance_id(),"- PS_SIDESTEP from",get_global_position().x,",",get_global_position().y," to ",target_of_sidestep.x,",",target_of_sidestep.y , " because of ",collision.get_collider().get_instance_id())
	player_state=PS_SIDESTEP

func _on_Timer_timeout():
	#print_trace_with_note("timed out")
	if player_operation==PO_EXCHANGE_MASTER or player_operation==PO_EXCHANGE_CLIENT or player_operation==PO_EXCHANGE_WITH_STATION:
		manage_task(PE_EXCHANGE_COMPLETE)
		return
	manage_task(PE_TIMER_TIMEOUT)

########## implementation of complex tasks ############
func choose_task():
	print_trace_with_note("choosing next task for "+ST_str[strategic_target])
	player_operation=PO_IDLE

	if strategic_target==ST_BUY_SETTLEMENT:
	# can we go, and buy the settlement ?
		if amount_missing(strategic_target_price)==0:  # yes
			manage_PT_BUY_BUILDING(PE_IDLE)
			return
		
		if my_team.amount_missing(strategic_target_settlement.settlement_price)==0:
			manage_PT_EXCHANGE_WITH_TEAMMATE(PE_IDLE)
			return
		else:
			strategic_target=ST_GATHER_RESOURCES
			strategic_target_settlement=null
			for r in range (0,strategic_target_price.size()):
				strategic_target_price[r]=0
			update_inventory_display()
			
	if strategic_target==ST_BUY_EXTENTION:
		if amount_missing(strategic_target_price)==0:  # we can afford it
			manage_PT_BUY_EXTENTION(PE_IDLE)
			return
			
		if my_team.amount_missing(strategic_target_price)==0: # need to get it from teammate
			manage_PT_EXCHANGE_WITH_TEAMMATE(PE_IDLE)
			return
		else: # resources are not available any more
			my_team.ask_for_order(self)
			return

	# should go to warehouse urgent
	if get_sunpoint_sum()>=3:
			manage_PT_EXCHANGE_WITH_WAREHOUSE(PE_IDLE)
			return
   
	if	(my_team.get_owned_settlement_count()>0 
	 	and my_team.get_resource_collector_count()<= my_team.get_member_count()/2 
	 	and my_team.get_resource_collector_count()<=my_team.get_owned_settlement_count()/3):
			strategic_target=ST_GATHER_RESOURCES
	else:
			strategic_target=ST_GATHER_INFORMATION
	
	if strategic_target==ST_GATHER_RESOURCES:
		if strategic_target_settlement:
				manage_PT_EXCHANGE_WITH_SETTLEMENT(PE_IDLE)		
				return			
		if get_sunpoint_sum()>=2:
			manage_PT_EXCHANGE_WITH_WAREHOUSE(PE_IDLE)
			return
	
			var try_index=randi()%my_team.get_owned_settlement_count()
			if last_settlement_seen!=my_team.get_owned_settlement(try_index):	
				strategic_target_settlement=my_team.get_owned_settlement(try_index)	
				manage_PT_EXCHANGE_WITH_SETTLEMENT(PE_IDLE)		
				return
	
	# ST_STROLL_AROUND
	
	return	manage_PT_STROLL_AROUND(PE_IDLE)

func manage_task(event):
	match player_task:
		PT_EXCHANGE_WITH_TEAMMATE:
			manage_PT_EXCHANGE_WITH_TEAMMATE(event)
		PT_STROLL_AROUND:
			manage_PT_STROLL_AROUND(event)
		PT_EXCHANGE_WITH_SETTLEMENT:
			manage_PT_EXCHANGE_WITH_SETTLEMENT(event)
		PT_EXCHANGE_WITH_WAREHOUSE:
			manage_PT_EXCHANGE_WITH_WAREHOUSE(event)
		PT_BUY_BUILDING:
			manage_PT_BUY_BUILDING(event)
		PT_BUY_EXTENTION:
			manage_PT_BUY_EXTENTION(event)
		_:
			my_team.ask_for_order(self)

func manage_PT_STROLL_AROUND(event):
	if event==PE_IDLE or event==PE_TIMER_TIMEOUT:
		player_task=PT_STROLL_AROUND
		var x=max(min(get_global_position().x+randi()%500-250,int(get_viewport().size.x-20)),20)
		var y=max(min(get_global_position().y+randi()%400-200,int(get_viewport().size.y-20)),20)
		#prints(get_instance_id(),"strolling to",x,y)
		enter_PO_GO_POSITION(Vector2(x,y))
		return
	#		
	# Vision Detection might swith to a GO_TO_TARGET Operation, when settelmen in sight
	# see _on_Vision_area_entered
	#
	
	if event==PE_TARGET_MET:
		if target_of_operation.get_name().begins_with("Settlement"):
			last_settlement_seen=target_of_operation
			if target_of_operation.get_owner_team()==null: # unoccupied
				if my_team.has_interest_on_settlement(target_of_operation,self):
					prints(get_instance_id(),"tries to buy settlement",target_of_operation.get_instance_id())
					strategic_target_settlement=target_of_operation
					set_strategic_target_price(strategic_target_settlement.settlement_price)
					strategic_target=ST_BUY_SETTLEMENT
					choose_task()
					return
			elif (target_of_operation.get_owner_team()==my_team
			    and target_of_operation.get_sun_point_sum()>0): # is our settlement with sun points				
				if enter_PO_EXCHANGE_WITH_STATION(2): 
					player_task=PT_EXCHANGE_WITH_SETTLEMENT
					return
			my_team.ask_for_order(self)
			return
		manage_PT_STROLL_AROUND(PE_IDLE)
	
	if event==PE_REACHED_POSITION:
		print_trace_event(event)
		my_team.ask_for_order(self)
		return

		
func manage_PT_EXCHANGE_WITH_TEAMMATE(event):
	if event==PE_IDLE :
		player_task=PT_EXCHANGE_WITH_TEAMMATE
		if determine_best_change_partner():
			enter_PO_GOTO_TARGET(target_of_operation)
			return
		manage_PT_STROLL_AROUND(PE_IDLE)  # will be triggerd if noone suits needs
		return
		
	if event==PE_TARGET_MET:
		print_trace_event(event)
		if enter_PO_EXCHANGE_MASTER(): # we have a conntection will trigger timer
			
			# get resoureces needed and available
			for r in range(0,ressource_inventory.size()):
				if (ressource_inventory[r]<strategic_target_price[r]):
					var amount=0
					if target_of_operation.ressource_inventory[r]>target_of_operation.strategic_target_price[r]:
						amount=target_of_operation.ressource_inventory[r]-target_of_operation.strategic_target_price[r]
					print_trace_with_note("Receiving ressource")
					target_of_operation.modify_inventory_slot(r,-amount)
					modify_inventory_slot(r,amount)
					
			# if only 1 resource is missing try to get it even partner needs it but is not finished
			if (target_of_operation.amount_missing(target_of_operation.strategic_target_price)>0
				and amount_missing(strategic_target_price)==1):
					for r in range(0,ressource_inventory.size()):
						if (ressource_inventory[r]<strategic_target_price[r] and
							target_of_operation.ressource_inventory[r]>0):
							target_of_operation.modify_inventory_slot(r,-1)
							modify_inventory_slot(r,1)
		else:
			enter_PO_PAUSE()
		return
	
	if event==PE_TIMER_TIMEOUT:
		print_trace_event(event)
		enter_PO_GOTO_TARGET(target_of_operation)
		return
		
	if event==PE_EXCHANGE_COMPLETE:
		print_trace_event(event)
		choose_task()
		return
	print(get_instance_id(),"- PT_EXCHANGE_WITH_TEAMMATE unhandled event",event)
		

func manage_PT_EXCHANGE_WITH_SETTLEMENT(event):
	match event:
		PE_IDLE :
			player_task=PT_EXCHANGE_WITH_SETTLEMENT
			enter_PO_GOTO_TARGET(strategic_target_settlement)
			
		PE_TARGET_MET:
			print_trace_event(event)
			last_settlement_seen=target_of_operation
			if target_of_operation.get_sun_point_sum()>0:
				if enter_PO_EXCHANGE_WITH_STATION(2):
					return
			my_team.ask_for_order(self)
	
		PE_TIMER_TIMEOUT:
			print_trace_event(event)
			enter_PO_GOTO_TARGET(target_of_operation)
			
		PE_EXCHANGE_COMPLETE:
			print_trace_event(event)
			modify_sunpoint_add(target_of_operation.give_sun_points())
			target_of_operation.disconnect_exchange_partner(self)
			if target_of_operation==strategic_target_settlement:
				my_team.ask_for_order(self)
				return
			choose_task()

func manage_PT_EXCHANGE_WITH_WAREHOUSE(event):
	if event==PE_IDLE :
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
		enter_PO_GOTO_TARGET(best_warehouse)
		return
		
	if event==PE_TARGET_MET:
		print_trace_event(event)
		if enter_PO_EXCHANGE_WITH_STATION(7):
			return
		else:
			enter_PO_PAUSE()
		return
	
	if event==PE_TIMER_TIMEOUT:
		print_trace_event(event)
		enter_PO_GOTO_TARGET(target_of_operation)
		return
		
	if event==PE_EXCHANGE_COMPLETE:
		print_trace_event(event)
		for r in range (0,ressource_inventory.size()):
			ressource_inventory[r]+=sunpoint_inventory[r]
			sunpoint_inventory[r]=0
		update_inventory_display()
		target_of_operation.disconnect_exchange_partner(self)
		last_player_exchanged_with=null
		my_team.ask_for_order(self)
		return

func manage_PT_BUY_BUILDING(event):
	if event==PE_IDLE :
		player_task=PT_BUY_BUILDING
		print_trace_event(event)
		enter_PO_GOTO_TARGET(get_node("/root/Spiel/Townhall"))
		return
		
	if event==PE_TARGET_MET:
		print_trace_event(event)
		last_settlement_seen=target_of_operation
		if(strategic_target_settlement.get_owner_team()): # already bought
			strategic_target_settlement=null
			strategic_target=ST_GATHER_INFORMATION
			choose_task()
			return
		if enter_PO_EXCHANGE_WITH_STATION(4):
			return
		else:
			enter_PO_PAUSE()
		return
	
	if event==PE_TIMER_TIMEOUT:
		print_trace_event(event)
		enter_PO_GOTO_TARGET(target_of_operation)
		return
		
	if event==PE_EXCHANGE_COMPLETE:
		if(target_of_operation==get_node("/root/Spiel/Townhall")): #when at
			print_trace_event(event)
			target_of_operation.disconnect_exchange_partner(self)
			if my_team.take_posession(strategic_target_settlement):
				modify_inventory_subtract(strategic_target_price)
				my_team.modify_team_score(1)
				for r in range(0,strategic_target_price.size()):
					strategic_target_price[r]=0
				modify_sunpoint_add(strategic_target_settlement.give_sun_points())
				enter_PO_GOTO_TARGET(strategic_target_settlement)			
			else:
				strategic_target=ST_GATHER_INFORMATION
				my_team.ask_for_order(self)
		else:
			target_of_operation.disconnect_exchange_partner(self)
			my_team.ask_for_order(self)
			return

func manage_PT_BUY_EXTENTION(event):
	if event==PE_IDLE :
		player_task=PT_BUY_EXTENTION
		print_trace_event(event)
		enter_PO_GOTO_TARGET(get_node("/root/Spiel/Townhall"))
		return
		
	if event==PE_TARGET_MET:
		print_trace_event(event)
		if target_of_operation==strategic_target_settlement: #final touch of settlement
			my_team.ask_for_order(self)
			return
		# we are at the townhall, so what should we buy
		match strategic_target_asset:
			SA_TOWN:
				if strategic_target_settlement.is_town():
					my_team.ask_for_order(self) 
					return
				if !enter_PO_EXCHANGE_WITH_STATION(4):
					enter_PO_PAUSE()
				return
		
	if event==PE_TIMER_TIMEOUT:
		print_trace_event(event)
		enter_PO_GOTO_TARGET(target_of_operation)
		return
		
	if event==PE_EXCHANGE_COMPLETE:
		if(target_of_operation==get_node("/root/Spiel/Townhall")): 
			print_trace_event(event)
			target_of_operation.disconnect_exchange_partner(self)
			strategic_target_settlement.upgrade_to_town()
			modify_inventory_subtract(strategic_target_price)
			my_team.modify_team_score(1)
			set_strategic_target_price(zero_price)
			enter_PO_GOTO_TARGET(strategic_target_settlement)
		else:
			print_trace_event(event)
			target_of_operation.disconnect_exchange_partner(self)
			my_team.ask_for_order(self)
			return


func start_collect_ressources():
	print_trace_with_note("start_collect_resources")
	strategic_target_settlement=null
	strategic_target=ST_GATHER_RESOURCES
	set_strategic_target_price(zero_price)
	choose_task()
	
func start_search_for_settlement():
	print_trace_with_note("start_search_for_settlement")
	strategic_target=ST_GATHER_INFORMATION
	strategic_target_settlement=null
	set_strategic_target_price(zero_price)
	choose_task()
	
func start_buy_town_extention(target_settlement):
	print_trace_with_note("start_buy_town_extention")
	strategic_target=ST_BUY_EXTENTION
	strategic_target_asset=SA_TOWN
	strategic_target_settlement=target_settlement
	set_strategic_target_price(Global.get_price_for_town())
	choose_task()
	

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
		target_of_operation=best_teammate
		return true
	else:
		return false
		
					
					
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



func _on_Vision_area_entered(area):
	if(area.get_name()!="SettlementVision"):
		return
	#prints(get_instance_id(),"now seeing",area.get_instance_id(),area.get_name())
	var settlement=area.get_parent()
	if settlement!=last_settlement_seen:
		if player_task==PT_STROLL_AROUND:
			if (settlement.get_owner_team()==null and strategic_target_settlement==null) or settlement.get_owner_team()==my_team:
				enter_PO_GOTO_TARGET(settlement)
		if settlement.get_owner_team()==my_team and strategic_target==ST_GATHER_RESOURCES:
			enter_PO_GOTO_TARGET(settlement)

func get_team():
	return my_team

func get_sunpoint_sum():
	var sun_point_sum=0
	for i in range (0,sunpoint_inventory.size()):
		sun_point_sum+=sunpoint_inventory[i]
	return sun_point_sum
	
func amount_missing(target_price):
	var deviation=0
	for r in range(0,ressource_inventory.size()):
		if ressource_inventory[r]<target_price[r]:
			deviation+=target_price[r]-ressource_inventory[r]
	return deviation

func is_gathering_resources():
	return (strategic_target==ST_GATHER_RESOURCES)

func get_resource_count():
	var total_count=0
	for r in range(0,ressource_inventory.size()):
		total_count+=ressource_inventory[r]
	return total_count
		

