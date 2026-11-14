extends StaticBody2D

# Collision layers: cowboys' feet bump into Core (layer 2), which covers the whole
# drawing, so a cowboy cannot walk into the tree but its upper body can still pass
# behind the top. Bullets bounce on BulletHitbox, same size (layer 1).

## Cowboys of this colour reload their gun by touching this tree.
var color: Color = Color.WHITE:
	set(value):
		color = value
		modulate = value
