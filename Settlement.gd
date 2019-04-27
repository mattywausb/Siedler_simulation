extends StaticBody2D



# class member variables go here, for example:
# var a = 2
# var b = "textvar"
var transaction_partner=null
var my_index=-1
var current_sun_points=2  #inital sun point you get, when buying the settlement
var owner_team
var settlement_price=[0,0,0,0,0]
var settlement_resource=-1
var is_town=false
var extention_list={"NULL":true}

const upgrade_price_town=[0,3,0,2,0]

const inventory_color=[	"cb0b0b", # 1 = brick
					"000010", # 4 = iron
					"d0d0d0", # 5 = wool
					"e0a000", # 5 = weed
					"25cb17"] # 6 = green

const sunpoint_color="f0f000"
const school_color="8000A0"
const university_color="a000f0"
const tower_color="040404"



enum {BRICK,IRON,WOOL,WEED,WOOD}

enum {TOWER=10, SCHOOL=20, UNIVERSITY, CHAPEL=30, MONASTERY, CHURCH, MARKET=40, STOCK_MARKET}


const extention_catalog= {
		 TOWER={price=[2,0,0,0,2],needs_town=false,needed_extention=null},
		 SCHOOL={price=[1,2,1,0,0],needs_town=false,needed_extention=null},
		 UNIVERSITY={price=[2,2,0,0,1],needs_town=true,needed_extention=SCHOOL} }

# main functions and representations functions

func _ready():
	$Flag.visible=false
	$MainShape/TownSymbol.visible=false
	update_inventory_display()
	pass

func _process(delta):
	if transaction_partner:
		get_node("MainShape").self_modulate=Color(1,0.2,0.2)
	else:
		get_node("MainShape").self_modulate=Color(1,1,1)
		
func update_inventory_display():
	var inventory_display=get_node("Inventory")
	if owner_team!=null:
		for i in range(0,inventory_display.get_child_count()):
			inventory_display.get_child(i).visible=false
		if current_sun_points==1:
			inventory_display.get_child(0).color=sunpoint_color
			inventory_display.get_child(0).visible=true
		elif current_sun_points==2:
			inventory_display.get_child(2).color=sunpoint_color
			inventory_display.get_child(1).color=sunpoint_color
			inventory_display.get_child(2).visible=true
			inventory_display.get_child(1).visible=true
		if extention_list.has("SCHOOL"):
			inventory_display.get_child(6).color=school_color
			inventory_display.get_child(6).visible=true
		if extention_list.has("UNIVERSITY"):
			inventory_display.get_child(6).color=university_color
			inventory_display.get_child(6).visible=true
		if extention_list.has("TOWER"):
			inventory_display.get_child(8).color=tower_color
			inventory_display.get_child(8).visible=true
			
			
	else: # not taken yet
		var slot_index=0
		for r in range(0,settlement_price.size()):
			for i in range (0,settlement_price[r]):
				if slot_index<inventory_display.get_child_count():
					inventory_display.get_child(slot_index).visible=true
					inventory_display.get_child(slot_index).color=Color(inventory_color[r])
					slot_index+=1
		for i in range (slot_index,inventory_display.get_child_count()):
			inventory_display.get_child(i).visible=false
	$MainShape/TownSymbol.visible=is_town
	$MainShape/SettlementSymbol.visible=!is_town

#  Events 

func _on_sun_point_trigger_timeout():

	if is_town:
		current_sun_points = 2
	else:
		current_sun_points = 1

	update_inventory_display()
	
# getter / Setter

func get_extention_price(extention_name):
	return extention_catalog[extention_name].price
	
func get_extention_name_list():
	return extention_catalog.keys()

func get_owner_team():
	return owner_team
	
func set_owner_team(team):
	if owner_team==null:
		owner_team=team
		$Flag/FlagFabric.color=owner_team.get_teamColor()
		$Flag.visible=true
		update_inventory_display()
		$sun_point_trigger.start()
		return true
	else:
		return false



func get_settlement_price():
	return settlement_price


const min_distance=138
const max_distance=450
const distance_range=max_distance-min_distance
const distance_factor=(distance_range)/5

func set_settlement_price(distance_to_station):
	var total_ressource_count=int(max(0,distance_range-(distance_to_station-min_distance))/distance_factor)+3
#	prints("Totel ressources",total_ressource_count)
	for i in range(0,total_ressource_count):
		var r=randi()%settlement_price.size()
		while r==settlement_resource:
			r=randi()%settlement_price.size()
		settlement_price[r]+=1
	update_inventory_display()

func get_settlement_price_count():
	var total_count=0
	for r in range(0,settlement_price.size()):
		total_count+=settlement_price[r]
	return total_count

func get_settlement_resource():
	return settlement_resource

func set_settlement_resource(r):
	settlement_resource=r
	$Sign.color=Color(inventory_color[settlement_resource])

func get_sun_point_sum():
	return current_sun_points
	
func get_upgrade_price_town():
	return upgrade_price_town
		

# evaluations

func is_extention_buildable(extention_name):
	if extention_name=="TOWN":
		return !is_town()
	if extention_list.has(extention_name):
		return false
	if extention_catalog[extention_name].needs_town and !is_town:
		return false
	if extention_catalog[extention_name].needed_extention:
		if !extention_list.has(extention_catalog[extention_name].needed_extention):
			return false
	else:
		if extention_list.size()>=2:
			return false
	return true

func is_town():
	return is_town

# Operations

func build_extention(extention_name):
	if !is_extention_buildable(extention_name):
		return false
	if extention_name=="TOWN":
		is_town=true
	else:
		if extention_catalog[extention_name].needed_extention!=null:
			extention_list.erase(extention_catalog[extention_name].needed_extention)
		extention_list[extention_name]=true
	update_inventory_display()

func bind_transaction_partner(partner):
	if transaction_partner:
		return false
	if owner_team and partner.get_team()!=owner_team: # only bind to owning team
		return false
	transaction_partner=partner
	return true
		
func unbind_transaction_partner(partner):
	if transaction_partner and transaction_partner==partner:
		transaction_partner=null


func give_sun_points():
	var points=[0,0,0,0,0]
	if current_sun_points>0:
		points[settlement_resource]=current_sun_points
		current_sun_points=0
		update_inventory_display()
	return points

func upgrade_to_town():
	is_town=true
	update_inventory_display()
