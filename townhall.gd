extends StaticBody2D

# class member variables go here, for example:
# var a = 2
# var b = "textvar"
var exchange_partner=null

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

func _process(delta):
	if exchange_partner:
		get_node("MainShape").self_modulate=Color(1,0,0)
	else:
		get_node("MainShape").self_modulate=Color(1,1,1)


func connect_transaction_player(partner):
	if exchange_partner:
		return false
	exchange_partner=partner
	return true
	
func disconnect_transaction_player(partner):
	if partner==exchange_partner:
		exchange_partner=null