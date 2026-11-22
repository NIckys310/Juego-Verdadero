extends RefCounted
## Cámara de plataforma: se desplaza sólo al cruzar una zona central.
## La orientación y las animaciones nunca cambian la posición del mundo.
const VIEW_WIDTH = 960.0
const LEFT_EDGE = 400.0
const RIGHT_EDGE = 560.0

static func follow(current: float, feet_x: float, map_width: float) -> float:
 var target: float = current
 var screen_x: float = feet_x - current
 if screen_x > RIGHT_EDGE:
  target = feet_x - RIGHT_EDGE
 elif screen_x < LEFT_EDGE:
  target = feet_x - LEFT_EDGE
 return clampf(target, 0.0, maxf(0.0, map_width - VIEW_WIDTH))

static func reset_at(feet_x: float, map_width: float) -> float:
 return clampf(feet_x - VIEW_WIDTH / 2, 0.0, maxf(0.0, map_width - VIEW_WIDTH))
