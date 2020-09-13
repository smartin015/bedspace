extends Spatial

onready var gs = $GameSpace
onready var gravbodies = $GameSpace/GravityBodies.get_children()
onready var actors = $GameSpace/Actor
onready var ship = $GameSpace/Actor/Ship
onready var stats = $Stats
onready var Debris = load("res://Debris.tscn")

const NDEBRIS = 10
const G = 0.005

func _ready():
  for _i in range(NDEBRIS):
    _spawn_debris()

func _spawn_debris():
  var d = Debris.instance()
  d.mass = 100
  var pv = gen_spawn_orbit()
  d.transform.origin = pv[0]
  d.linear_velocity = pv[1]
  
  match randi() % 10:
    3, 4: 
      d.item_type = S.MONEY
      d.item_value = randi() % 10 + 5
    5, 6, 7, 8: 
      d.item_type = S.FUEL
      d.item_value = randi() % 10 + 5
    9: 
      d.item_type = S.WARP
      d.item_value = 1.0
  
  d.connect("tree_exiting", self, "_on_debris_will_exit", [d])
  actors.add_child(d)
  print("Spawned debris @ %s, vel %s" % [d.transform.origin, d.linear_velocity])
  

func _on_debris_will_exit(d):
  print("Debris exit @ %s" % d.transform.origin)
  _spawn_debris()

# Returns a random location & velocity for an 
# orbiting object.
# The orbit may not always be stable depending on 
# where gravitational bodies are located.
func gen_spawn_orbit():
  # Pick a gravitational body
  var b = gravbodies[randi() % len(gravbodies)]
  
  # Move some distance from its center
  var r = Vector3(
    rand_range(0.1, 1.0),
    0,
    rand_range(0.1, 1.0))
  var p = b.transform.origin + r
  
  # Randomly choose clockwise or counterclockwise
  var vnorm = r.rotated(Vector3.UP, (PI/2) * (1 - 2*(randi() % 2))).normalized()
  var orbit_speed = 2*sqrt(G * G * b.mass / r.length())
  
  return [p, vnorm*orbit_speed]

func get_gravity(s):
  var dir = Vector3.ZERO
  for b in gravbodies:
    var v = b.transform.origin - s.transform.origin
    var ls = v.length_squared()
    if ls < 0.01: # Bail if too close
      continue
    dir +=  v.normalized() * b.mass / ls
  return G * s.mass * dir


func _process(_delta):
  if vr.button_just_pressed(vr.BUTTON.A) or Input.is_action_just_pressed("spawn_debris"):
    _spawn_debris()


func _on_Ship_ship_stats_change():
  for g in stats.gauges:
    stats.attr[g] = ship.attr[g] / (ship.mult[g] * ship.BASE_LIMITS[g])
  stats.redraw()
