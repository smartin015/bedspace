extends RigidBody
var world = null
onready var body = $ShipBody
var last_accel = Vector3.ZERO
var impulse = Vector3.ZERO
var needs_respawn = false
onready var thrust_sfx = $ThrustSFX
onready var thrust_particles = $ShipBody/ThrustParticles

signal ship_stats_change

# Default max values
var BASE_LIMITS = {
  S.FUEL: 100.0,
  S.EFFICIENCY: 0.1,
  S.THRUST: 400.0,
  S.WARP: 3,
  S.MONEY: 3,
}

var mult = {}
var attr = {}
func _attr(k, v):
  attr[k] = v
  emit_signal('ship_stats_change')

const MAX_DIST_SQUARED = 10*10
const TGRAV = 0.1
onready var trail = $Trail
onready var csgp = $Trail/CSGPolygon
const TINTERVAL = 0.1
const NTRAIL = 100
const TMOD = 10

func _init():
  for e in S.E:
    mult[e] = 1.0
    attr[e] = BASE_LIMITS[e]
  attr[S.MONEY] = 0.0

func _ready():
  thrust_particles.emitting = false
  world = find_parent("World")
  for i in range(NTRAIL / TMOD):
    trail.curve.add_point(Vector3.ZERO)
  
func _get_thrust_multiplier():
  if Input.is_action_pressed("fwd"):
    return 1.0
  elif Input.is_action_pressed("brake"):
    return -0.5
  else:
    var mult = vr.get_controller_axis(vr.BUTTON.LEFT_GRIP_TRIGGER)
    if mult < 0.05: # Dead band
      return null
    return mult
  
func _get_thrust_vector(m):
  if m == null:
    return Vector3.ZERO
  return (m * body.transform.basis.z.normalized() 
          * BASE_LIMITS[S.THRUST] * mult[S.THRUST])
  
func _draw_trail(thrust):
  var at = last_accel
  var pt = Vector3.ZERO
  var vt = linear_velocity
  var dp2 = 0.0
  if len(trail.get_signal_connection_list("curve_changed")) > 0:
    trail.disconnect("curve_changed", csgp, "_path_changed")
  if len(trail.get_signal_connection_list("tree_exited")) > 0:
    trail.disconnect("tree_exited", csgp, "_path_exited")
  for i in range(NTRAIL):
    if i % TMOD == 0:
      at = (world.get_gravity(self) + thrust) / mass * 0.01 
      trail.curve.set_point_position(i / TMOD, pt)
    vt += (at * TINTERVAL)
    pt += (vt * TINTERVAL)
  csgp._path_changed()
  
func _respawn():
  attr[S.FUEL] = BASE_LIMITS[S.FUEL]
  attr[S.MONEY] = 0.0
  emit_signal('ship_stats_change')
  var pv = world.gen_spawn_orbit()
  transform.origin = pv[0]
  linear_velocity = pv[1]
  needs_respawn = false
  print("Respawned %s heading %s" % pv)
  
func _process(dt):
  if (vr.button_just_pressed(vr.BUTTON.LEFT_THUMBSTICK) 
      or Input.is_action_just_pressed("respawn")
      or transform.origin.length_squared() >  MAX_DIST_SQUARED
      or needs_respawn):
    _respawn()
  
  var m = _get_thrust_multiplier()
  if m != null:
    # TODO set throttle sound
    attr[S.FUEL] -= abs(m)*attr[S.EFFICIENCY]
    emit_signal('ship_stats_change')
    if attr[S.FUEL] < 0.0:
      attr[S.FUEL] = 0.0
      m = 0.0
    thrust_sfx.unit_db = m - 1.0
    thrust_particles.initial_velocity = m
    if not thrust_sfx.playing:
      thrust_sfx.play()
      thrust_particles.emitting = true
  elif thrust_sfx.playing:
    thrust_sfx.stop()
    thrust_particles.emitting = false
  # TODO change brightness depending on multiplier
  _draw_trail(_get_thrust_vector(m))
    
  var stick_dir = Vector2(
    vr.get_controller_axis(vr.AXIS.LEFT_JOYSTICK_X),
    vr.get_controller_axis(vr.AXIS.LEFT_JOYSTICK_Y)
  )
  var theta = null
  var fwd = body.global_transform.basis.z
  fwd = Vector2(fwd.x, fwd.z)
  if stick_dir.length_squared() > 0.1:
    theta = fwd.angle_to(stick_dir)
  else:
    theta = fwd.angle_to(Vector2(linear_velocity.x, linear_velocity.z))

  if theta > PI:
    theta = 2*PI - theta
  body.rotate_y(-theta)
  
func _integrate_forces(state):
  var grav = world.get_gravity(self)
  add_central_force(grav * state.step)
  add_central_force(_get_thrust_vector(_get_thrust_multiplier()) * state.step)

func _on_DebrisCollider_area_entered(area):
  print("entered")
  area = area.get_parent()
  if area.get('debris') or area.get('planet'):
    print("KABOOM")
    needs_respawn = true
    # http://www.iforce2d.net/b2dtut/explosions
    # _spawn_explodey()
    return
  var type = area.get('item_type')
  var val = area.get('item_value')
  var total = 0
  var limit = 0
  if type != null:
    attr[type] = min(attr[type] + val, BASE_LIMITS[type] * mult[type])
    area.queue_free()
  else:
    print("Collided with unknown area!")
    print(area)
    return
  
  emit_signal('ship_stats_change')
