extends StaticBody2D

# class member variables go here, for example:
# var a = 2
# var b = "textvar"
var transaction_partner=null

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

func _process(delta):
	if transaction_partner:
		get_node("MainShape").self_modulate=Color(1,0,0)
	else:
		get_node("MainShape").self_modulate=Color(1,1,1)


func bind_transaction_partner(partner):
	if transaction_partner==partner:
		return true
	if transaction_partner!=null:
		prints("Townhall already in transaction with",transaction_partner.get_instance_id())
		return false
	transaction_partner=partner
	return true
		
func unbind_transaction_partner(partner):
	if transaction_partner!=null and transaction_partner==partner:
		transaction_partner=null