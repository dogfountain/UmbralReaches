# The folk, the animals and the wanderer's life (r39-anim)

Every person and animal here moves by formulas of dt with eased weights; nothing steps, snaps or pops, and nothing runs for anyone beyond 100 m.

## The folk (core/life/folk: folk_stage.gd, folk_actor.gd, folk_roles.gd, folk_poses.gd)
Thirteen ambient people built once at start-up (one a frame once the Realm is up, a GenCache hit after the first run: **run the game once before measuring**, the first run builds
the meshes behind the loading cover), woken within 80 m and slept beyond 100 m. Each is a villager's own body (VillagerRig, 15 bones, two-bone arm IK) driven by a role:
- **sweeper** on the Keg's step: long broom strokes, the back bending into them, one foot forward; every thirty seconds she straightens and looks out;
- **fiddler** before the Keg: the fiddle under his chin, the bow drawn across, the foot tapping, the head tilted onto it; he plays forty seconds and rests twelve;
- **dancer** (a teen in a red dress): circles a small ring to the fiddle with knee lifts, a swaying body, raised arms; when the fiddler rests she stands and listens;
- **porter** with a sack and **water-bearer** with a bucket: walk the village's own nodes (forge to the road; well to Maud's door) and wait at each end; the carry leans the body and
  swings the load; the bucket-bearer's free arm goes out to balance;
- **three children**: tag round the green (the one who is it chases the nearest, the others dodge and flip direction when it comes near; a tag is a cheer and the tagged is it),
  alternating every seventy seconds with hide and seek (the seeker counts nine seconds with his eyes covered at a brazier; the others run to the braziers and crouch, peeking out now and then;
  the seeker visits each spot, waits, finds, the found one jumps out cheering; then tag begins again with a new one);
- **watchman**: a slow circuit of the green with a staff and a lantern, stopping at intervals to raise the lantern out and peer into the dark, the head sweeping;
- **mourner** at the graves: kneels, shoulders shaking, the hands going up to the face now and then; rises for a few seconds and kneels again;
- **net-mender** at the reeds: kneels with a woven net spread on her knees (a flat card with a generated texture), the hands drawing the cord;
- **two talkers** on logs by the green: the speaker's hands tell it (a word-beat from the villagers' own voice timing), the listener's rest on the knees and nod; they swap every four to seven seconds.
All of them: a **wave** at the wanderer when he comes near in front (thirty percent of the time with no regard, nearly always at full regard: the number of village restorations over six),
a **nod** to anyone passing, a **look up at the eclipse** (the head back, a hand to the chest and the mouth), and a **run for the Keg's door** when the Gloom tide rises (they vanish into it and are back on their marks when it breaks).
Every standing villager of the village's own cast (not only the folk) now has ten idle gestures (the four of villager_idle.gd and six new: scratching the neck, shading the eyes, hands on the hips, a yawn, blowing into cupped hands, tapping a foot)
and waves at the wanderer by the same regard rule; walking speed varies by 8 percent and the gait starts at its own phase, so no two walk in step.
- **Smoothness.** Speed and yaw ease with 1 - exp(-k dt); the pose is made at the villagers' distance rate (npc_life.gd interval) and eased between updates (blend_from / blend_to / blend_step); an act change is a 0.28 s crossfade
  (xfade_check / xfade_apply); the legs walk the heel-toe gait paced by the ground covered and turn on the spot in steps (turn_legs); the arms' IK targets are blended from the rest pose by each gesture's envelope.
- **Film.** The Keg's front at 20 m, 8 m, 2 m (street scene, wave when you approach, the eclipse); the green at night (tag, then seek: film a full 150 s cycle); the watchman's lantern at a brazier; the mourner at (-55.5, 42.2); the net-mender at the Reeds; the log pair by the green's west.
  Check no pops at act changes (the sweeper's rest, the fiddler's pause, the dancer standing) at 60 and 144 Hz, and no stepping at 15 to 30 m.
- **Cost.** Awake only within 80 m: at most a handful of people near any viewer, posed at 30/20/12 Hz with distance, no allocation per frame; the children's game is one small script.

## The animals (core/life/folk/pets.gd, core/world/mount/horse_paddock.gd)
- **Dogs (three).** One MultiMesh with the wildlife's creature shader (so the gait, head and tail are drawn by the GPU): each follows its person (the watchman, the porter, one of the talkers) at a trot, a run when far behind; sits or sniffs when they stop; the second
  comes to the wanderer when he is within 12 m, circles and sits; all bark at any foe within 28 m (the body turned to it, the head thrown up with the bark); during the eclipse they run for the Keg's door and are gone until the moon returns.
- **Cats (two).** On the roofs of the cottages nearest the green (found by a ray over each house's window centre): sit watching the wanderer with the head turning to follow, groom, stretch, and leap to the other roof when he runs close; in the eclipse they look at the moon.
  Dogs and cats wear the wildlife's fox body at 0.85 and 0.5 scale; their own meshes are a world-seat item.
- **Horses.** Unowned stock at a hitching post strolls the paddock (within 3.4 m of its post): picks a point, turns at the breed's easing, walks at 0.95 m/s with the rig's gait paced by the ground covered, grazes on arriving, goes again; a forward ray turns it from fences; the wanderer within 4.5 m
  (to buy) stops it and has it face him. Mounting or buying gives the physics interpolation back. (Birds scattering, crows at graves, foxes, deer, owls and bats are the wildlife system's.)
- **Film.** The dogs following the watchman round the green and barking at a foe led to the village; a cat leaping when you sprint under its roof; a stable at dusk (the horses strolling), approaching to buy.
- **Cost.** Five animals: one draw, a buffer write a frame only within 130 m; horses: one ray a few times a second within 40 m.

## The wanderer (core/player/wanderer_idles.gd, wanderer_life.gd, character_rig.gd)
Ten idle acts (look about, the lantern lifted, weight on the staff, a glance back, warming his hands at a fire he stands by, shivering in cold or rain or the eclipse, shaking the rain off, catching his breath after a sprint, looking at a landmark or a person, a stretch), chosen
by the night round him (WandererLife keeps `idle_ctx` twice a second from the registry and the weather); the condition overlays (a limp and a slump when the Wounds are high, the chest working after a sprint, the lantern carried higher and 40 percent brighter where nothing else is lit, a fine tremble in
the cold); the hand reaching to a fire (with embers rising to it) and toward the moths; his lantern swelling in the eclipse. Each act is an envelope of the rig's `_ia_k` (in at 6 per second, out at 5, cut by any movement), so none begins or ends with a snap.
- **Film.** Stand still: by a brazier (warm hands), in rain (the shake, the shiver), after a sprint (the breath), in the open dark (the lantern lifts), facing a lit tower (the look); low health walking (the limp).
- **Cost.** A few additive joint writes a frame; the context is twelve distance tests twice a second.
