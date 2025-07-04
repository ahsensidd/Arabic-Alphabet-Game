extends Control

@onready var word_label = $WordLabel
@onready var prompt_label = $PromptLabel
@onready var answer_display = $AnswerDisplay
@onready var choices_container = $ChoicesContainer 
@onready var sound_input = $SoundInput
@onready var submit_button = $SubmitButton
@onready var instructions_label = $InstructionsLabel # Your Instructions Label
@onready var show_instructions_button = $ShowInstructionsButton # Your new button for instructions

var words = []

var current_word_index = 0
var current_letter_index = 0
var current_step = "letter" # "letter", "harakah", "shadda_harakah_selection", "sound", "final_sound"
var first_harakah_selected = "" 

func _ready():
	# Ensure word_label has "Use BBCode" checked in the Inspector
	# This line is good to keep to ensure BBCode is always enabled for highlighting.
	word_label.bbcode_enabled = true 

	submit_button.visible = false
	sound_input.visible = false
	instructions_label.visible = false # Instructions hidden by default
	
	# Setting font size for Instructions Label - keep this here for code control
	instructions_label.add_theme_font_size_override("font_size", 30)

	submit_button.pressed.connect(_on_SubmitButton_pressed)
	show_instructions_button.pressed.connect(_on_ShowInstructionsButton_pressed) # Connect button signal

	# --- Updated Instructions Text ---
	instructions_label.text = """
How to Type Sounds Phonetically:

- General: Enter sounds as they appear phonetically (e.g., 'ka', 'mi', 'ru'). Answers are case-insensitive.

- Tanween (ً, ٍ, ٌ): For these endings, enter the short vowel sound followed by 'n' (e.g., Ba fathatain 'ban', Dal dammatain 'dun', Ta kasratain 'tin').

- Sukoon (ْ): Enter the sound the letter makes without a vowel. Example: 't' in 'bint', 'm' in 'qamar'.

- Hamza / Alif with Sukoon (ءْ, أْ, إْ): If Hamza has a Sukoon, enter 'a'.

- Shadda (ّ): Double the consonant sound (e.g., 'bba' for بّ, 'tta' for تّ).

- Madd (Long Vowels - ا, و, ي and symbols like ٓ): These indicate a long vowel sound. Enter the vowel doubled (e.g., 'aa', 'ee', 'oo'). For example, for "Ba long fatha", enter 'baa'.

- Heavy Letters (ص, ط, ض, ظ, ق, خ, غ): For these letters, enter only the first letter followed by the vowel sound. Example: For 'ص' (Suad) with Fatha, enter 'sa'.

- Final Word Sound: Type the complete phonetic sound of the word, combining all previous letter sounds (e.g., for بدر, enter 'badr').
"""
	instructions_label.text = instructions_label.text.strip_edges() # Clean up leading/trailing whitespace

	var file = FileAccess.open("res://arabic_words.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		# Use JSON.parse_string directly for Godot 4.x
		var parse_result = JSON.parse_string(content) 
		
		# Godot 4.x JSON.parse_string returns the parsed data directly or null on error
		if parse_result == null:
			push_error("Failed to load arabic_words.json. JSON parsing returned null. The JSON file might be malformed or empty.")
		elif parse_result is Array:
			words = parse_result
			if words.size() > 0:
				current_word_index = randi() % words.size()
				print("DEBUG: Initial current_word_index set to: ", current_word_index, " (words.size(): ", words.size(), ")")
			else:
				push_error("arabic_words.json is empty! No words loaded.")
				current_word_index = 0 
		else:
			push_error("Unexpected data structure in arabic_words.json after parsing. Expected an Array but got: %s" % typeof(parse_result))

	else:
		push_error("Failed to open arabic_words.json. File not found or inaccessible at res://arabic_words.json")

	load_step()


func load_step():
	print("DEBUG: Entering load_step(). current_word_index: ", current_word_index, ", words.size(): ", words.size())

	if words.is_empty():
		prompt_label.text = "No words loaded. Please ensure 'arabic_words.json' exists and is correctly formatted."
		push_error("Error: 'words' array is empty in load_step(). Cannot proceed.")
		instructions_label.visible = false 
		show_instructions_button.visible = false # Hide button if no words
		return 

	# Defensive check for current_word_index
	if current_word_index < 0 or current_word_index >= words.size():
		push_error("Error: current_word_index (%d) is out of bounds for words array (size: %d) in load_step(). Attempting recovery." % [current_word_index, words.size()])
		current_word_index = 0 
		if words.is_empty(): 
			prompt_label.text = "Critical error: words array became empty during recovery. Cannot proceed."
			instructions_label.visible = false 
			show_instructions_button.visible = false # Hide button if critical error
			return
		
		prompt_label.text = "Recovered from index error. Loading first word."
		await get_tree().create_timer(0.5).timeout 


	var word = words[current_word_index] 
	var letter = null
	if current_letter_index < word["letters"].size():
		letter = word["letters"][current_letter_index]
	else:
		push_error("Warning: current_letter_index (%d) out of bounds for current word's letters (size: %d). Forcing final_sound step." % [current_letter_index, word["letters"].size()])
		current_step = "final_sound"

	for child in choices_container.get_children():
		child.queue_free()
	sound_input.text = ""
	sound_input.visible = false
	submit_button.visible = false
	instructions_label.visible = false # Instructions are hidden by default for all steps
	show_instructions_button.visible = false # Hide button by default for all steps
	sound_input.modulate = Color.WHITE

	match current_step:
		"letter":
			if letter: 
				prompt_label.text = "Select the correct name for the letter: %s" % letter["char"]
				show_letter_buttons()
				sound_input.placeholder_text = ""
				first_harakah_selected = ""
			else:
				prompt_label.text = "Error: Cannot display letter. Advancing to final sound."
				await get_tree().create_timer(0.5).timeout
				current_step = "final_sound"
				load_step() 
				return
		"harakah":
			if letter: 
				prompt_label.text = "Select the correct harakah for: %s" % letter["char"]
				show_harakah_buttons(false)
				sound_input.placeholder_text = ""
			else:
				prompt_label.text = "Error: Cannot display harakah. Advancing to final sound."
				await get_tree().create_timer(0.5).timeout
				current_step = "final_sound"
				load_step()
				return
		"shadda_harakah_selection":
			if letter: 
				prompt_label.text = "Select the harakah on the shadda for: %s" % letter["char"]
				show_harakah_buttons(true)
				sound_input.placeholder_text = ""
			else:
				prompt_label.text = "Error: Cannot display shadda harakah. Advancing to final sound."
				await get_tree().create_timer(0.5).timeout
				current_step = "final_sound"
				load_step()
				return
		"sound":
			if letter: 
				prompt_label.text = "Type the sound made by: %s" % letter["char"]
				sound_input.visible = true
				submit_button.visible = true
				show_instructions_button.visible = true # Show the button when sound input is active
				sound_input.placeholder_text = "e.g. ba, ta, ra..."
			else:
				prompt_label.text = "Error: Cannot display sound prompt. Advancing to final sound."
				await get_tree().create_timer(0.5).timeout
				current_step = "final_sound"
				load_step()
				return
		"final_sound":
			prompt_label.text = "Type the full sound for the word: %s" % word["arabic"]
			sound_input.visible = true
			submit_button.visible = true
			show_instructions_button.visible = true # Show the button for final sound input
			sound_input.placeholder_text = "e.g. badra"

	# --- Corrected Godot 4.x Highlighting Logic using BBCode effectively ---
	var full_arabic_word = word["arabic"]
	var highlighted_bbcode_text = ""
	
	var current_string_index = 0 # This will track our position in the full_arabic_word string
	var current_logical_letter_processed = 0 # This tracks which logical letter (from words["letters"]) we are on

	while current_string_index < full_arabic_word.length():
		var char_segment_start_index = current_string_index
		var is_highlighted_segment = false

		if current_step != "final_sound" and current_logical_letter_processed == current_letter_index:
			is_highlighted_segment = true
			highlighted_bbcode_text += "[color=#3CB371]" # Start highlight color

		# Find the end of the current logical letter segment (base char + all its diacritics)
		# This is crucial for Arabic to keep ligatures intact.
		var current_char = full_arabic_word[current_string_index]
		var unicode_value = current_char.unicode_at(0)

		# Append the base character
		highlighted_bbcode_text += current_char
		current_string_index += 1

		# Append all combining diacritics that follow this base character
		# Unicode ranges for Arabic Presentation Forms and Arabic Supplement
		# 0x0600-0x06FF (Arabic, Arabic Supplement)
		# 0xFB50-0xFDFF (Arabic Presentation Forms-A)
		# 0xFE70-0xFEFF (Arabic Presentation Forms-B)
		# These ranges contain combining marks like harakat, shadda, sukoon, madd.
		while current_string_index < full_arabic_word.length():
			var next_char = full_arabic_word[current_string_index]
			var next_unicode_value = next_char.unicode_at(0)
			
			# Check if the next character is an Arabic combining mark (diacritic)
			if (next_unicode_value >= 0x064B && next_unicode_value <= 0x0652) || \
			   (next_unicode_value == 0x0670) || (next_unicode_value == 0x06D6) || \
			   (next_unicode_value == 0x06D7) || (next_unicode_value == 0x06D8) || \
			   (next_unicode_value == 0x06D9) || (next_unicode_value == 0x06DA) || \
			   (next_unicode_value == 0x06DB) || (next_unicode_value == 0x06DC) || \
			   (next_unicode_value == 0x06DF) || (next_unicode_value == 0x06E0) || \
			   (next_unicode_value == 0x06E1) || (next_unicode_value == 0x06E2) || \
			   (next_unicode_value == 0x06E3) || (next_unicode_value == 0x06E4) || \
			   (next_unicode_value == 0x06E7) || (next_unicode_value == 0x06E8) || \
			   (next_unicode_value == 0x06EA) || (next_unicode_value == 0x06EB) || \
			   (next_unicode_value == 0x06EC) || (next_unicode_value == 0x06ED):
				highlighted_bbcode_text += next_char
				current_string_index += 1
			else:
				# If it's not a combining mark, it's a new base letter or non-Arabic char, so break.
				break
		
		if is_highlighted_segment:
			highlighted_bbcode_text += "[/color]" # End highlight color
		
		current_logical_letter_processed += 1 # Advance to the next logical letter

	word_label.bbcode_text = highlighted_bbcode_text
	# --- END Corrected Godot 4.x Highlighting Logic ---

	update_answer_display()

func show_letter_buttons():
	var letter_names = [
		"alif", "ba", "ta", "tha", "jeem", "Ha", "kha", "dal",
		"dhal", "ra", "zay",
		"seen", "sheen", "Suad", "Duad", "Tua", "Dhua", "ayn",
		"ghayn", "fa", "qaf",
		"kaf", "lam", "meem", "noon", "ha", "waw", "Hamza","ya"
	]
	
	$ChoicesContainer.columns = 5 # Example: 5 columns for letter buttons
	
	var button_width = 100 

	for name in letter_names:
		var btn = Button.new()
		btn.text = name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL 
		btn.custom_minimum_size = Vector2(button_width, 70)
		btn.add_theme_font_size_override("font_size", 50)
		btn.pressed.connect(on_letter_button_pressed.bind(name, btn))
		choices_container.add_child(btn)


func show_harakah_buttons(is_shadda_second_harakah: bool):
	var harakahs = []
	if is_shadda_second_harakah:
		harakahs = ["fatha", "kasra", "damma", "fathatain", "kasratain", "dammatain", "fatha madd", "kasra madd", "damma madd"]
	else:
		harakahs = ["fatha", "kasra", "damma", "fathatain", "kasratain", "dammatain", "fatha madd", "kasra madd", "damma madd","sukoon", "shadda", "madd","silent"]
	
	$ChoicesContainer.columns = 3 # Example: 3 columns for harakah buttons
	
	var button_width = 100 
	
	for h in harakahs:
		var btn = Button.new()
		btn.text = h
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(button_width, 70)
		btn.add_theme_font_size_override("font_size", 50)
		if is_shadda_second_harakah:
			btn.pressed.connect(on_shadda_harakah_button_pressed.bind(h, btn))
		else:
			btn.pressed.connect(on_harakah_button_pressed.bind(h, btn))
		choices_container.add_child(btn)

# NEW: Function to toggle instructions visibility
func _on_ShowInstructionsButton_pressed():
	instructions_label.visible = not instructions_label.visible # Toggles visibility

func on_letter_button_pressed(selected_name, button):
	var correct_name = words[current_word_index]["letters"][current_letter_index]["name"]
	var current_char = words[current_word_index]["letters"][current_letter_index]["char"]

	var is_hamza_or_alif_char = current_char == "أ" or current_char == "ا" or current_char == "إ" or current_char == "ء"
	var selected_is_hamza_or_alif = (selected_name.to_lower() == "hamza" or selected_name.to_lower() == "alif")
	var correct_is_hamza_or_alif = (correct_name.to_lower() == "hamza" or correct_name.to_lower() == "alif")

	var is_correct = false
	if is_hamza_or_alif_char and selected_is_hamza_or_alif and correct_is_hamza_or_alif:
		is_correct = true
	elif selected_name == correct_name:
		is_correct = true

	if is_correct:
		button.modulate = Color.GREEN
		current_step = "harakah"
		await get_tree().create_timer(0.5).timeout 
		load_step()
	else:
		button.modulate = Color.RED

func on_harakah_button_pressed(selected_harakah, button):
	var correct_harakah = words[current_word_index]["letters"][current_letter_index]["harakah"]

	if selected_harakah == correct_harakah:
		button.modulate = Color.GREEN
		if selected_harakah == "shadda":
			first_harakah_selected = selected_harakah
			current_step = "shadda_harakah_selection"
		else:
			current_step = "sound"
		await get_tree().create_timer(0.5).timeout
		load_step()
	else:
		button.modulate = Color.RED

func on_shadda_harakah_button_pressed(selected_harakah_on_shadda, button):
	var correct_harakah_on_shadda = words[current_word_index]["letters"][current_letter_index].get("harakah_shadda", "") 

	if selected_harakah_on_shadda == correct_harakah_on_shadda:
		button.modulate = Color.GREEN
		first_harakah_selected = ""
		current_step = "sound"
		await get_tree().create_timer(0.5).timeout
		load_step()
	else:
		button.modulate = Color.RED

func _on_SubmitButton_pressed():
	var word = words[current_word_index] 

	if current_step == "sound":
		var correct_sound = word["letters"][current_letter_index]["sound"] 
		if sound_input.text.strip_edges().to_lower() == correct_sound.strip_edges().to_lower(): 
			sound_input.modulate = Color.GREEN
			current_letter_index += 1
			current_step = "letter" if current_letter_index < word["letters"].size() else "final_sound"
			await get_tree().create_timer(0.5).timeout
			load_step()
		else:
			sound_input.modulate = Color.RED

	elif current_step == "final_sound":
		var correct_full_sound = word["full_sound"] 
		if sound_input.text.strip_edges().to_lower() == correct_full_sound.strip_edges().to_lower(): 
			sound_input.modulate = Color.GREEN
			prompt_label.text = "Correct! Loading next word..."
			await get_tree().create_timer(1.5).timeout
			
			print("DEBUG: Before next word calculation: current_word_index = ", current_word_index, ", words.size() = ", words.size())
			current_word_index = (current_word_index + 1) % words.size()
			current_letter_index = 0
			current_step = "letter"
			print("DEBUG: After next word calculation: new current_word_index = ", current_word_index)

			load_step()
		else:
			sound_input.modulate = Color.RED

func update_answer_display():
	# First, clear any existing labels in the container
	for child in answer_display.get_children():
		child.queue_free()
	if words.is_empty():
		return
	var word = words[current_word_index]
	for i in range(current_letter_index):
		if i < word["letters"].size(): 
			var l = word["letters"][i]
			var label = Label.new() # Create a new Label node for each piece of info
			var harakah_info = l["harakah"]
			if l.has("harakah_shadda"): 
				harakah_info += " (%s)" % l["harakah_shadda"]
			label.text = "%s - %s - %s" % [l["name"], harakah_info, l["sound"]]			
			
			# Apply the font size override directly to the Label
			label.add_theme_font_size_override("font_size", 40) 
			
			# Add the configured Label to your VBoxContainer
			answer_display.add_child(label)
