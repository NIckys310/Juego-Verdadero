extends Node
## Efectos sintéticos originales, generados una vez y reutilizados.
static var effects: Dictionary = {}
static var tracks: Dictionary = {}
var voices: Array = []
var cursor: int = 0
var music: AudioStreamPlayer
var music_theme: String = "_unset"

func _ready() -> void:
 for i in range(4):
  var voice = AudioStreamPlayer.new()
  voice.volume_db = -17
  add_child(voice)
  voices.append(voice)
 if effects.is_empty():
  for id in ["step", "jump", "land", "hurt", "work", "success", "rest", "pickup", "stomp"]:
   effects[id] = make_effect(id)
 music = AudioStreamPlayer.new()
 music.volume_db = -24
 add_child(music)

func _process(_delta: float) -> void:
 for voice in voices:
  voice.stream_paused = not get_parent().active
 if is_instance_valid(music):
  music.stream_paused = not get_node("/root/GameManager").audio_enabled or not get_parent().active

func set_theme(branch: String) -> void:
 if music_theme == branch:
  return
 music_theme = branch
 if not tracks.has(branch):
  tracks[branch] = make_music(branch)
 music.stream = tracks[branch]
 music.play()

func make_music(branch: String) -> AudioStreamWAV:
 var notes: Array = [72, 76, 79, 76, 74, 77, 81, 77, 72, 79, 76, 72, 74, 77, 69, 71, 72, 76, 79, 84, 81, 77, 74, 77, 79, 76, 72, 69, 71, 74, 76, 79]
 var bass: Array = [48, 53, 45, 55, 48, 53, 57, 55]
 var transpose: int = -3 if branch == "B" else -5 if branch == "C" else 0
 var step: float = 0.19 if branch == "" else 0.16
 var rate = 22050
 var count: int = int(notes.size() * step * rate)
 var bytes = PackedByteArray()
 bytes.resize(count * 2)
 var melody_phase: float = 0
 var bass_phase: float = 0
 var rng = RandomNumberGenerator.new()
 rng.seed = 83
 for i in range(count):
  var t: float = float(i) / rate
  var note_index: int = mini(int(t / step), notes.size() - 1)
  var local = fmod(t, step) / step
  var melody_hz = 440 * pow(2, (notes[note_index] + transpose - 69) / 12.0)
  var bass_hz = 440 * pow(2, (bass[note_index / 4] + transpose - 69) / 12.0)
  melody_phase += TAU * melody_hz / rate
  bass_phase += TAU * bass_hz / rate
  var envelope = minf(local * 24, 1) * pow(1 - local, 1.5)
  var square = 1.0 if fmod(melody_phase, TAU) < PI else -1.0
  var drum = rng.randf_range(-1, 1) * exp(-local * 22) * (0.1 if note_index % 2 == 0 else 0.04)
  var sample = square * envelope * 0.18 + sin(bass_phase) * (1 - local) * 0.22 + drum
  bytes.encode_s16(i * 2, int(sample * 26000))
 var stream = AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = rate
 stream.data = bytes
 stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
 stream.loop_end = count
 return stream

func make_effect(id: String) -> AudioStreamWAV:
 var length: float = {"step": 0.045, "jump": 0.14, "land": 0.08, "hurt": 0.2, "work": 0.08, "success": 0.35, "rest": 0.4, "pickup": 0.1, "stomp": 0.1}[id]
 var rate: int = 22050
 var samples = PackedByteArray()
 samples.resize(int(length * rate) * 2)
 var phase: float = 0
 var rng = RandomNumberGenerator.new()
 rng.seed = 17
 for i in range(int(length * rate)):
  var t: float = float(i) / rate
  var progress: float = t / length
  var frequency: float = {"step": 90, "jump": 260 + progress * 500, "land": 120, "hurt": 180 - progress * 100, "work": 550, "success": 440 + int(progress * 3) * 110, "rest": 330 + int(progress * 3) * 110, "pickup": 880 + int(progress * 2) * 440, "stomp": 200 - progress * 100}[id]
  phase += TAU * frequency / rate
  var envelope: float = minf(t * 250, 1) * pow(1 - progress, 2)
  var sample: float = sin(phase)
  if id in ["step", "land", "work"]:
   sample = sample * 0.3 + rng.randf_range(-1, 1) * 0.4
  samples.encode_s16(i * 2, int(sample * envelope * 22000))
 var stream = AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = rate
 stream.data = samples
 return stream

func play_effect(id: String) -> void:
 if not get_node("/root/GameManager").audio_enabled or not effects.has(id):
  return
 var voice: AudioStreamPlayer = voices[cursor]
 cursor = (cursor + 1) % voices.size()
 voice.stream = effects[id]
 voice.play()

func _exit_tree() -> void:
 if is_instance_valid(music):
  music.stop()
  music.stream = null
 for voice in voices:
  voice.stop()
  voice.stream = null
