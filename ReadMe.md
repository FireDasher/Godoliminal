# Godotliminal
The superliminial gimick but it's made in Godot

Also, this actually implements it properly almost the exact same way the original game does, because all unofficial implementations of this gimmick I've seen so far are poorly coded and buggy.

This implementation uses the correct algorithm so the effect is very smooth and seemless and there is almost no clipping.
However, sometimes the grabbing object can clip through other objects slightly due to having a limited number of rays, but this is unavoidable and the real Superliminal also has this problem.

## Game
your goal is to get on the platform I guess, more instructions in-game

## How it works
- When you grab an objects, it caches all the model-space coordinates of the vertexes of the collision.
- Then, every frame while your holding an object, it casts a ray from the player's camera to each vertex.
- Then, some complicated math is used to correct the ray's length to account for the vertex's position, specifically: `var axis := forward + grab_basis * point / grab_distance` and `var length: float = (result.position - camera.global_position).dot(axis) / axis.length_squared()` (where forward is the camera's look vector, grab_basis is the initial basis of the grabbing object, point is the point that is currently being tested in model-space, grab_distance is the initial distance from the camera to the grabbing object, result is the return value from the raycast, camera.global_position is the global position of the camera)
- This math was gotten from solving for D in `vertex = camera_pos + forward * D + grab_basis * point * (D / grab_distance)`
- Then the smallest of all these corrected ray lengths is taken and the object moves back that far (`object_position = camera_position + camera_forward * target_distance`), also scaling proportional to the distance. (`basis = initial_basis * (target_distance / initial_distance`)
- The object position is smoothed by getting the direction from the camera to the object when you first pick it up then it moves towards forward over time, and this direction is used to rotate `forward` variable which determines `center`
- A sound is played using an AudioStreamPlayer when you pick up an object. Grab sound is Scratch's pop sound pitched up two semitones and drop sound is Scratch's pop sound pitched up one semitone.
