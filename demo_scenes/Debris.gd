extends RigidBody
var world
onready var collision = $Collision

var item_type = null
var item_value = 0.0
var debris = false

const MAX_DIST_SQUARED = 10*10
  
func _ready():
  world = find_parent("World")
  var mat = SpatialMaterial.new()
  $MeshInstance.material_override = mat
  # TODO change size based on value
  match item_type:
    S.FUEL:
      mat.albedo_color = Color(0,0,1)
    S.MONEY:
      mat.albedo_color = Color(1,1,0)
    S.WARP:
      mat.albedo_color = Color(0,1,0)
    _:
      debris = true
      mat.albedo_color = Color(0.8, 0.5, 0.2)

func _process(_delta):
  if transform.origin.length_squared() >  MAX_DIST_SQUARED:
    self.queue_free()

func _integrate_forces(state):
  add_central_force(world.get_gravity(self) * state.step)

func _on_Debris_body_entered(body):
  if body.get('planet'):
    queue_free()
  else:
    collision.play()
