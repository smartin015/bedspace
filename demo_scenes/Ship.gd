extends RigidBody
var world = null
onready var body = $ShipBody
var last_accel = Vector3.ZERO
var impulse = Vector3.ZERO
# 6.67408e-11
const THRUST = 100.0
const TGRAV = 0.1
onready var trail = $Trail
onready var csgp = $Trail/CSGPolygon
const TINTERVAL = 0.1
const NTRAIL = 100
const TMOD = 10
  
func _ready():
  world = find_parent("World")
  for i in range(NTRAIL / TMOD):
    trail.curve.add_point(Vector3.ZERO)
  
func _get_thrust():
  if Input.is_action_pressed("fwd"):
    return body.transform.basis.z.normalized() * THRUST
  elif Input.is_action_pressed("brake"):
    return -body.transform.basis.z.normalized() * 0.5 * THRUST
  var mag = vr.get_controller_axis(vr.BUTTON.LEFT_GRIP_TRIGGER)
  if mag > 0.1:
    return body.transform.basis.z.normalized() * THRUST * mag
  return Vector3.ZERO
  
func _draw_trail():
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
      at = (world.get_gravity(self) + _get_thrust()) / mass * 0.01 
      trail.curve.set_point_position(i / TMOD, pt)
    vt += (at * TINTERVAL)
    pt += (vt * TINTERVAL)
  csgp._path_changed()
  
func _process(dt):
  if vr.button_just_pressed(vr.BUTTON.LEFT_THUMBSTICK) or Input.is_action_just_pressed("respawn"):
    var pv = world.gen_spawn_orbit()
    transform.origin = pv[0]
    linear_velocity = pv[1]
  
  _draw_trail()
    
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
  add_central_force(world.get_gravity(self) * state.step)
  add_central_force(_get_thrust() * state.step)
