# Dice.gd
extends Node
class_name Dice

# Roll dice notation like "1d6", "2d8+3", "1d20", etc.
static func roll(notation: String) -> int:
	var parts = notation.split("+")
	var dice_part = parts[0]
	var modifier = 0
	
	if parts.size() > 1:
		modifier = int(parts[1])
	
	var dice_split = dice_part.split("d")
	if dice_split.size() != 2:
		push_error("Invalid dice notation: " + notation)
		return 0
	
	var num_dice = int(dice_split[0])
	var die_size = int(dice_split[1])
	
	var total = 0
	for i in range(num_dice):
		total += randi_range(1, die_size)
	
	return total + modifier

# Roll with advantage (roll twice, take higher)
static func roll_advantage(notation: String) -> int:
	var roll1 = roll(notation)
	var roll2 = roll(notation)
	return max(roll1, roll2)

# Roll with disadvantage (roll twice, take lower)
static func roll_disadvantage(notation: String) -> int:
	var roll1 = roll(notation)
	var roll2 = roll(notation)
	return min(roll1, roll2)

# Roll a d20 check with modifier
static func d20_check(modifier: int = 0) -> int:
	return randi_range(1, 20) + modifier

# Check if a d20 roll is a critical (nat 20)
static func is_critical(roll: int) -> bool:
	return roll == 20

# Check if a d20 roll is a critical fail (nat 1)
static func is_critical_fail(roll: int) -> bool:
	return roll == 1
