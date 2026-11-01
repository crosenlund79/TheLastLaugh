# The Last Laugh

Low-poly first-person survival horror prototype set in a night carnival. Built with Godot 4.3 and GDScript.

Open the folder in Godot 4.3+ and press F5. The game uses the Forward+ renderer, which it needs for the volumetric purple fog.

**Controls:** WASD to move · mouse to look · Shift to sprint · Ctrl/C to crouch · Space to jump · LMB to shoot · R to reload · 1-3 or the mouse wheel to switch weapons · E to interact · Esc to pause

**Loop:** Get the revolver from the shooting gallery (west). Find the frightened maintenance worker behind the Fun House (north-west) and escort him to his shed (north-east). Take the shotgun and the gate key from the shed. Unlock the main gate (south). Escort survivors through the gate, or just walk out. Purple fog banks start drifting in after about 40 s and turn any human they touch hostile.

Code layout: the scenes and world are built procedurally in `scripts/`. `game.gd` runs the match, `person.gd` covers every NPC, `player.gd` is the player, `carnival.gd` builds the level and `game_state.gd` is the autoload.
