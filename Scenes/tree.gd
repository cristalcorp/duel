extends StaticBody2D

# Collision layers: cowboys' whole body bumps into Core (layer 2), which covers
# the whole drawing. Bullets bounce on BulletHitbox, same size (layer 1).

## Cowboys of this colour reload their gun by touching this tree.
var color: Color = Color.WHITE:
	set(value):
		color = value
		modulate = value
