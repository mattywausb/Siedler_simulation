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
var extention_list={-1:false}

const upgrade_price_town=[0,3,0,2,0]


const sunpoint_color="f0f000"

enum {WOOD,WOOL,CLAY,WEED,IRON}
enum {XT_TOWER=10, XT_SCHOOL=20, XT_UNIVERSITY, XT_CHAPEL=30, XT_MONASTERY, XT_CHURCH, XT_MARKET=40, XT_STOCK_MARKET, XT_TOWN=100}

const extention_catalog= {
		 XT_TOWER:{name="TOWER",price=[2,0,0,0,2],needs_town=false,needed_extention=null,
					color="040404",slot=8},
		 XT_SCHOOL:{name="SCHOOL",price=[1,2,1,0,0],needs_town=false,needed_extention=null,
					color="8000A0",slot=6},
		 XT_UNIVERSITY:{name="UNIVERSITY",price=[2,2,0,0,1],needs_town=true,needed_extention=XT_SCHOOL,
					color="a000f0",slot=6},
		 XT_CHAPEL:{name="CHAPEL",price=[1,1,2,0,0],needs_town=false,needed_extention=null,
					color="006060",slot=5} ,
		 XT_MONASTERY:{name="MONASTERY",price=[0,1,2,2,0],needs_town=false,needed_extention=XT_CHAPEL,
					color="00A0A0",slot=5},
		 XT_CHURCH:{name="CHURCH",price=[1,0,3,1,3],needs_town=true,needed_extention=XT_MONASTERY,
					color="40F0F0",slot=5},
		 XT_MARKET:{name="MARKET",price=[0,2,0,1,1],needs_town=false,needed_extention=null,
					color="006000",slot=3},
		 XT_STOCK_MARKET:{name="STOCK_MARKET",price=[3,0,2,2,1],needs_town=true,needed_extention=XT_MARKET,
					color="08F008",slot=3}	
						}

# main functions and representations functions

func _ready():
	$Flag.visible=false
	$MainShape/TownSymbol.visible=false
	update_inventory_display()
	#print(extention_catalog)
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
		
		for extention_type in extention_list:
			if extention_type==-1:
				continue
			var extention=extention_catalog[extention_type]
			inventory_display.get_child(extention.slot).color=Color(extention.color)
			inventory_display.get_child(extention.slot).visible=true
			
	else: # not taken yet, show costs
		var slot_index=0
		for r in range(0,settlement_price.size()):
			for i in range (0,settlement_price[r]):
				if slot_index<inventory_display.get_child_count():
					inventory_display.get_child(slot_index).visible=true
					inventory_display.get_child(slot_index).color=Color(Global.get_resource_color(r))
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

static func get_extention_name(extention_id):
	return extention_catalog[extention_id].name

static func get_extention_price(extention_id):
	return extention_catalog[extention_id].price
	
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

func set_settlement_price(price):
	for r in range(0,settlement_price.size()):
		settlement_price[r]=price[r]
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
	$Sign.color=Color(Global.get_resource_color(settlement_resource))

func get_sun_point_sum():
	return current_sun_points
	
func get_upgrade_price_town():
	return upgrade_price_town
		

# evaluations

func is_extention_buildable(extention_id):
	if extention_id==null:
		return false
	if extention_id==XT_TOWN:
		return !is_town()
	if extention_list.has(extention_id):
		return false
	if !extention_catalog.has(extention_id):
		#prints("WARNING-is_extention_buildable: Bad extention id: ",extention_id)
		return false
	if extention_catalog[extention_id].needs_town and !is_town:
		return false
	if extention_catalog[extention_id].needed_extention:
		if !extention_list.has(extention_catalog[extention_id].needed_extention):
			return false
	else:
		if extention_list.size()>=2:
			return false
	return true

func is_town():
	return is_town

# Operations

func build_extention(extention_id):
	if !is_extention_buildable(extention_id):
		return false
	if extention_id==XT_TOWN:
		is_town=true
	else:
		if extention_catalog[extention_id].needed_extention!=null:
			extention_list.erase(extention_catalog[extention_id].needed_extention)
		extention_list[extention_id]=true
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
