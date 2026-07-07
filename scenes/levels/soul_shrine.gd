extends "res://scenes/levels/interact_zone.gd"
## Seelenschrein (plan.md Punkt 1 Seelen-Ökonomie, Schritt 3): tauscht echte
## Seelen gegen run-gebundene Boons -- Run-Power jetzt vs. Meta-Fortschritt
## später. [E] öffnet eine pausierte Wahl-UI (LoadoutChoice-Muster) mit 2-3
## zufälligen Angeboten; EIN Kauf erschöpft die Station, Abbrechen nicht.
## Optik: `soul_altar.png` = Blutschrein-Altar mit cyan umgefärbtem Kristall
## (Hue-Shift, 0 Gens); Interim-Sound über den "boon"-Key in sfx.gd (audio-spec §3).

const BOONS := [
	{"kind": "potion", "label": "Trankfüllung", "desc": "Füllt den Trank-Gürtel auf", "cost": 25},
	{"kind": "max_hp", "label": "Seelenpanzer", "desc": "+2 Max-HP diesen Run", "cost": 40, "value": 2.0},
	{"kind": "skill_cd", "label": "Fokus", "desc": "-20% Skill-Cooldown diesen Run", "cost": 50, "value": 0.8},
	{"kind": "damage", "label": "Zorn", "desc": "+1 Schaden diesen Run", "cost": 60, "value": 1.0},
]
const DAMAGE_OFFER_CHANCE := 0.5  # "Zorn" ist das seltene Angebot
const OFFER_COUNT := 3

var _used := false
var _ui: CanvasLayer


func _activate(body: Node2D) -> void:
	if _used or _ui != null or not body.has_method("add_boon"):
		return
	_open_ui(body)


func _open_ui(body: Node2D) -> void:
	var offers: Array = []
	for boon in BOONS:
		if boon["kind"] == "potion" and body.potion_charges >= body.potion_max:
			continue  # sinnloses Angebot bei vollem Gürtel
		if boon["kind"] == "damage" and randf() > DAMAGE_OFFER_CHANCE:
			continue
		offers.append(boon)
	offers.shuffle()
	offers = offers.slice(0, OFFER_COUNT)
	_ui = CanvasLayer.new()
	_ui.layer = 15  # über PauseMenu (10), wie LoadoutChoice
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	var dim := ColorRect.new()  # Modal: Klicks schlucken ist hier Absicht
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = "Seelenschrein — %d Seelen" % GameManager.souls
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Ein Boon für diesen Run, bezahlt aus deinen Seelen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.85
	box.add_child(hint)
	for boon in offers:
		var b := Button.new()
		b.text = "%s — %s (%d Seelen)" % [boon["label"], boon["desc"], boon["cost"]]
		b.custom_minimum_size = Vector2(420, 36)
		b.disabled = GameManager.souls < int(boon["cost"])
		b.pressed.connect(_buy.bind(boon, body))
		box.add_child(b)
	var cancel := Button.new()
	cancel.text = "Später (nichts kaufen)"
	cancel.custom_minimum_size = Vector2(420, 36)
	cancel.pressed.connect(_close)
	box.add_child(cancel)
	get_tree().paused = true


func _buy(boon: Dictionary, body: Node2D) -> void:
	if not GameManager.spend_souls(int(boon["cost"])):
		return
	body.add_boon(boon["kind"], float(boon.get("value", 0.0)), boon["label"])
	_used = true
	_close()
	modulate = Color(0.5, 0.5, 0.55)
	$Glow.energy = 0.1
	if has_node("Hint"):  # interim scene had a label; the sprite version doesn't
		$Hint.text = "erschöpft"


func _close() -> void:
	get_tree().paused = false
	if _ui:
		_ui.queue_free()
		_ui = null
