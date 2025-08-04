# Item.gd
extends Resource
class_name Item

var name: String
var type: String  # weapon, armor, consumable, scroll
var damage_dice: String = ""
var damage_bonus: int = 0
var ac_bonus: int = 0
var effect: String = ""
var rarity: String = "common"  # common, uncommon, rare, legendary
