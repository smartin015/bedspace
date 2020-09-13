extends Spatial

var attr = {}

onready var gauges = {
  S.MONEY: $Money,
  S.FUEL: $Fuel,
  S.WARP: $Warp,
}

func redraw():
  for k in gauges:
    var v = attr[k]
    var g = gauges[k]
    if v == null or g == null:
      continue
    g.mesh.size.x = v

