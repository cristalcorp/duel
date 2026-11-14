extends StaticBody2D

# Collision layers: cowboys only bump into the small Core (layer 2), so they can
# overlap the foliage and squeeze between trees, like the original. Bullets bounce
# on BulletHitbox, which covers the whole drawing (layer 1).

## Cowboys of this colour reload their gun by touching this tree.
var color: Color = Color.WHITE:
	set(value):
		color = value
		modulate = value
