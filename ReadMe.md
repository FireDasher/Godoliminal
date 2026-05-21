# Godotliminal
The superliminial gimick but it's made in Godot

Also, this actually implements it properly almost the exact same way the original game does, because all unofficial implementations of this gimmick I've seen so far are poorly coded and buggy.

This implementation uses the correct algorithm so the effect is very smooth and seemless and there is almost no clipping.
However, if you position a cube so that all corners are not on top of another object but the points between the corners are, it will go through the object. The real superliminal has this problem too, they just hide it better by using more rays.

## Game
your goal is to get on the platform I guess, more instructions in-game

## How it works
- When you grab an objects, it caches all the model-space coordinates of the vertexes of the collision.
- Then, every frame while your holding an object, it casts a ray from the player's camera to each vertex.
- Then, some complicated math that I don't understand is used to correct the ray's length to account for the vertex's position. (you can see it in player.gd)
- Then the smallest of all these corrected ray lengths is taken and the object moves back that far (`object_position = camera_position + camera_forward * target_distance`), also scaling proportional to the distance. (`basis = initial_basis * (target_distance / initial_distance`)
- The object position is smoothed by getting the direction from the camera to the object when you first pick it up then it moves towards forward over time, and this direction is used to rotate `forward` variable which determines `center`
- A sound is played using an AudioStreamPlayer when you pick up an object. Grab sound is Scratch's pop sound pitched up two semitones and drop sound is Scratch's pop sound pitched up one semitone.
