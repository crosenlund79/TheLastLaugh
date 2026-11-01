# The Last Laugh

Low-poly first-person survival horror prototype set in a night carnival. Built with Godot 4.3 and GDScript.

Open the folder in Godot 4.3+ and press F5. The game uses the Forward+ renderer, which it needs for the volumetric purple fog.

**Controls:** WASD to move · mouse to look · Shift to sprint · Ctrl/C to crouch · Space to jump · LMB to shoot · R to reload · 1-3 or the mouse wheel to switch weapons · E to interact · Esc to pause

**Loop:** Get the revolver from the shooting gallery (west). One of three maintenance workers carries the main gate key, and it's a different one each run (look for the gold keyring). Ask them for it. Then unlock the main gate (south) and walk out, bringing survivors if you can. The maintenance shed (north-east) holds a shotgun.

**Staff:** Three maintenance workers do repairs around the park and three security guards patrol it. When a staff member gets infected, they put out one desperate radio warning. Everyone else in the same job then finds their way on foot (navmesh) to their own safe house: the maintenance shed or the security office. Clowns can't open those doors, and the fog can't get inside. To get in, knock and the staff inside will open up, or use the shed key. If the keyholder is infected or killed, they drop the gate key where they fall. It shows a golden beacon so it can't be lost. Backup checks make sure the key and the shed can always be reached.

**Presentation:** The park starts out warm and colourful. As the fog takes more people, a "dread" level rises. The sky, ambient light and fog density shift, rides slow down, lights die, and a post-process pass adds desaturation, vignette, film grain and chromatic wobble.

Code layout: the scenes and world are built procedurally in `scripts/`. `game.gd` runs the match, `person.gd` covers every NPC, `player.gd` is the player, `carnival.gd` builds the level and `game_state.gd` is the autoload.
