extends RigidBody
var world
  
const MAX_DIST_SQUARED = 10*10
  
func _ready():
  world = find_parent("World")

func _process(_delta):
  if transform.origin.length_squared() >  MAX_DIST_SQUARED:
    self.queue_free()

func _integrate_forces(state):
  add_central_force(world.get_gravity(self) * state.step)

