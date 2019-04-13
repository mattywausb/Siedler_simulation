extends StaticBody2D

# class member variables go here, for example:
# var a = 2
# var b = "textvar"
var exchange_partner=null
var my_index=-1
var current_sun_points=2  #inital sun point you get, when buying the settlement
var owner_team
var settlement_price=[0,0,0,0,0]
var settlement_ressource=-1
var is_town=false

const upgrade_price_town=[0,3,0,2,0]

const inventory_color=[	"cb0b0b", # 1 = brick
					"000010", # 4 = iron
					"d0d0d0", # 5 = wool
					"e0a000", # 5 = weed
					"25cb17"] # 6 = green

const sunpoint_color="f0f000"

enum {BRICK,IRON,WOOL,WEED,WOOD}

func _ready():
	$Flag.visible=false
	$MainShape/TownSymbol.visible=false
	update_inventory_display()
	pass

func _process(delta):
	if exchange_partner:
		get_node("MainShape").self_modulate=Color(1,0.2,0.2)
	else:
		get_node("MainShape").self_modulate=Color(1,1,1)
	
func set_settlement_ressource(r):
	settlement_ressource=r
	$Sign.color=Color(inventory_color[settlement_ressource])
	
func set_settlement_price(distance_to_station):
	var total_ressource_count=int(max(0,500-distance_to_station)/40)+2
#	prints("Totel ressources",total_ressource_count)
	for i in range(0,total_ressource_count):
		var r=randi()%settlement_price.size()
		while r==settlement_ressource:
			r=randi()%settlement_price.size()
		settlement_price[r]+=1
	update_inventory_display()

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

func connect_exchange_partner(partner):
	if exchange_partner:
		return false
	if owner_team and partner.get_team()!=owner_team:
		return false
	exchange_partner=partner
	return true

func give_sun_points():
	var points=[0,0,0,0,0]
	if current_sun_points>0:
		points[settlement_ressource]=current_sun_points
		current_sun_points=0
		update_inventory_display()
	return points

func get_sun_point_sum():
	return current_sun_points

	
func disconnect_exchange_partner(partner):
	if partner==exchange_partner:
		exchange_partner=null

func _on_sun_point_trigger_timeout():
		
	if is_town:
		current_sun_points = 2
	else:
		current_sun_points = 1

	update_inventory_display()

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

func get_settlement_price_count():
	var total_count=0
	for r in range(0,settlement_price.size()):
		total_count+=settlement_price[r]
	return total_count
	
func get_owner_team():
	return owner_team

func get_settlement_price():
	return settlement_price
	
func is_town():
	return is_town

func get_upgrade_price_town():
	return upgrade_price_town	

func upgrade_to_town():
	is_town=true
	update_inventory_display()


