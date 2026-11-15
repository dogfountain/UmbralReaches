# The living Realm

Luke, 15 Nov 2026: across the doubled Realm and the eleven Far Reaches regions, make the world feel inhabited and
alive, not dotted. This is how life is laid out and why. Code: `core/life/wildlife/` and `core/life/wayfarers/`.

## What the first captures taught

- At night, in this grade, anything on the ground past ~12 m is lost in the knee-high grass: a dead horse in the
  heather read as a brown smudge, hares and lapwings in a meadow did not read at all. Life that reads is above the
  grass (birds against the sky, on crowns and stones), on bare ground (the worn verges of the ways, a trampled
  patch), in motion (a flock lifting, a hare bolting across the road), as a light, or as a person.
- So ground creatures are placed on the verges first (2-9 m off a way, where the grass is short and where the
  wanderer is looking), carrion lies 4-12 m off a way on trampled ground, and the strongest signals are the people
  on the roads and their lanterns.

## The rules

1. **Life gathers where the light and the people are; the dark country is quiet.** Travellers keep to the safe
   roads between lit places; a fire the wanderer kindles is a place they come to rest (pillar 2: warmth is earned,
   and the world answers it). The deep wild has its own life: carrion, ravens, eyes, howls, cold lights.
2. **The world teaches** (pillar 3). Ravens wheel over the dead and over the hollowed's camps out in the wild, seen
   against the sky from a long way off; travellers turn back from a hollowed thing on the road; fireflies, eyes and
   cold lights go out when one comes near; the Gloom tide stills all of it.
3. **Nothing new to read.** No tooltips, no markers: the signs are in the place.
4. **Existing systems, in-house assets.** Creatures are the life kit's (crows, owls, herons, frogs, hares, foxes,
   lapwings, bats, moths, fireflies, mice); people are the village's rigs (villager.gd in follow mode); the dead
   horse is the stables' horse model. No new ground beasts: the deer were cut for their look (14 Nov) and the
   unused boar is no better up close.

## Wildlife rosters (`life_reaches.gd`)

A roster per region (`ROSTER`): crow roosts on the region's places (structure tops round its place slots, else tree
crowns, else stones, with ground perches between), owl areas on big trunks with field mice under them, herons and
frog choruses at its pools, hare forms and foxes on the verges, lapwing flocks on wide open ground, firefly clusters
over its wet and wooded edges, bats over its places and crater. Off every camp (REALM_CAMPS, their patrols, the
camp slots the enemy session fills, elite haunts), fire, site and raid floor. Each region draws from its own stream:
nothing the old Realm or the Marches placed moves. Placement reads what the Realm built, so the places the region
sessions build are roosted on once they are merged.

## Signs (`life_signs.gd`)

- **Carrion**: a packhorse dead by a far track (greyfell, kingsbarrows, cairns, bellfall, siege, southwood, arches),
  its lantern out, the grass round it trampled, ravens on it and round it (they lift and wheel when you come and
  settle when you go), more wheeling high above.
- **Raven kettles** (shader-only, `orbit.gdshader` with the crow's body at a raven's size): over the carrion, over
  the keep, the barrow, the bell and the cairn tower, and over every camp beyond the old Realm in tier 2-3 ground.
- **Cold lights** (`marsh_light.gdshader`): marsh lights over the Reedmere's, the Nave's, the Mere's and
  Stillwater's water, barrow lights over the Kings' Barrows and the Barrow Field, the Lanternwood's cold lights
  among its trunks. Only ever seen from afar: they are gone inside ~15 m and back as you leave.
- **Eyes** (`eyeshine.gdshader`): pairs at the wood edges 14-34 m off the ways, the lantern caught in them; they
  blink, look away, shift, and are gone when you come within 13 m or a hollowed thing comes near.
- **Howls**: out in tier 2-3 country, every minute or two, a howl far off on the high ground (140-230 m, it may be
  beyond the edge: the Crowns, the fells) and an answer from another bearing, sometimes a third. Not in the tide, a
  boss fight or hard rain.

## Wayfarers (`core/life/wayfarers/`)

- The ways are one network (`road_graph.gd`: 689 vertices, T-junctions split, compressed to ~107 junction nodes).
  Stretches within 22 m of a camp's ground are not walked (a grunt chases 11-14 m).
- Havens: the towns' edges (Hearthward, Weirford, Saltmarket, Lastlight, Fallowmere, Reedholm), every brazier and
  outpost fire within 26 m of a way, the watch posts.
- Twelve parties (`wayfarer_db.gd`): pilgrims (three bands), the Watch's patrols (three), peddlers (two), a mother
  and her boy, fishers, a messenger, mourners. Each lives near a home and roams its safe ways: walking in file with
  the lantern first, resting at a lit fire (warming, watching, talking), kneeling at a dark one, going indoors in a
  town (never in view: in view they stop and talk at the town's edge), turning back from a hollowed thing (a patrol
  halts and faces it first), hurrying in the Gloom tide, greeting the wanderer with a few words of babble.
- LOD: far off a party is a point on its way and a lantern quad (`wayfarer_lamp.gdshader`, one MultiMesh for all of
  them), so a lit road reads across the valley; within 92 m the people are made real (their rigs were warmed on the
  village's worker threads at load) and walk with real feet; past 108 m they are put away again (no collider, no
  process). The lantern bearer carries a real light that fades out past 40-50 m.

## Budgets

- Build: the wildlife's placement adds ~0.5 s (the life kit's pool flood-fill, done three times a build before, is
  now done once); the wayfarers ~30 ms with their rigs warmed on threads.
- Frame: shader-only signs cost no script time; roster groups are ticked by the director's LOD like every other
  group; a far party costs a few multiplies a frame, a near one is two or three villagers in follow mode.
