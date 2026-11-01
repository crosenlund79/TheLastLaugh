# The Last Laugh

Low-poly first-person survival horror prototype set in a night carnival. Built with Godot 4.3 and GDScript.

Open the folder in Godot 4.3+ and press F5. The game uses the Forward+ renderer, which it needs for the volumetric purple fog.

**Controls:** WASD to move · mouse to look · Shift to sprint · Ctrl/C to crouch · Space to jump · LMB to shoot · R to reload · 1-3 or the mouse wheel to switch weapons · E to interact · Esc to pause

**Loop:**
1. Get the revolver from the shooting gallery (west).
2. Get into the maintenance shed (north-east). Every maintenance worker carries a shed key, so there are several ways in:
   - Escort a worker there and he unlocks it.
   - Knock while the crew is sheltering inside and they let you in.
   - Take the key an infected worker always drops when defeated.
   - Kill an innocent worker for his key, which costs you score.
3. The shed holds the shotgun, the main gate key and an emergency broadcast screen.
4. Unlock the gate (south). Walk out right away, or stay and escort survivors through it. Taking a guard's SMG is optional, and escaping without one earns a bonus.

**Fog and corruption:** Purple fog banks start drifting in after about 40 s. Only fog exposure ever makes someone hostile. Everything the fog touches is corrupted permanently and only in that spot (`scripts/corruptible.gd`):
- veined violet overlays and crooked, stretched geometry (visual only, collision never changes)
- lights turn violet or crimson, then flicker or die
- signs rewrite themselves
- rides lurch and run backwards, gallery ducks hang upside down, balloons deflate
- detuned attraction music and a drone
- stained ground with violet crystals growing out of it

You can stand on an untouched, cheerful street and look straight at a ruined one. The lighting, sky, music and post-processing follow whatever is around you.

**Staff:** There are 3 maintenance workers and 3 security guards, each group with its own refuge (the maintenance shed and the security office). When the first person in a group is infected, they send one cut-off radio call, and that group's survivors walk to their refuge and barricade it. The fog can't get inside, clowns can't open the doors, and the staff talk about the colleague they lost. Guards only ever shoot infected people. If you shoot a guard, he runs; he never fights back.

Code layout: the scenes and world are built procedurally in `scripts/`. `game.gd` runs the match, `person.gd` covers every NPC, `player.gd` is the player, `carnival.gd` builds the level and `game_state.gd` is the autoload.
