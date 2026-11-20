extends Node
## EventBus: señales globales. Nadie se conecta a nadie directamente; todo pasa por aquí.

# Reloj del turno
signal clock_tick(game_seconds: float)
signal hour_changed(hour: int)
signal block_changed(block: int)
signal shift_started()
signal shift_ended()

# AUX y métricas
signal aux_changed(new_aux: int, old_aux: int)
signal expected_aux_changed(expected_aux: int)
signal metric_color_changed(metric: String, color: String)
signal written_warning_issued(number: int, reason: String)
signal ack_window_opened(seconds: float)
signal ack_given()
signal ack_expired()
signal angry_streak(count: int)

# Contactos
signal contact_offered(contact: Dictionary)
signal contact_accepted(contact: Dictionary)
signal contact_ended(contact: Dictionary, resolved: bool, angry: bool)
signal hold_changed(on_hold: bool)
signal email_timer_tick(seconds_left: float)
signal email_over_time(contact_id: String, seconds: float)
signal email_sent(recipient: String, template: String)

# Jugador y espacio
signal player_seated(seat_id: String)
signal player_stood_up()
signal player_entered_zone(zone: String)
signal player_exited_zone(zone: String)
signal player_blinked()
signal player_floor_changed(floor: int)
signal player_rescued(fall_pos: Vector3, floor: int)  # red de seguridad: cayó por un hueco y volvió
signal player_jumped()  # v0.3.1 Q1 (F26, C15): despega (Q3 pone el sonido)
signal player_landed(fall_m: float)  # v0.3.1 Q1 (F26, C15): aterriza tras un salto o una caída; fall_m = altura caída
signal interact_hint(text: String)
signal show_message(text: String, seconds: float)
signal subtitle(speaker: String, text: String, seconds: float)

# Fatiga y distorsiones
signal fatigue_changed(value: float, level: int)
signal microsleep()
signal distortion_triggered(id: String)
signal screen_black(seconds: float)
signal settings_changed(key: String)  # pantalla a negro breve (parpadeo de transición)

# Shero, RTA, Vitzo
signal shero_state_changed(state: int)
signal shero_message(text: String, channel: String)
signal rta_tag(text: String)
signal rta_hunt_started()
signal vitzo_reminder(emoji: String, seconds: float)
signal vitzo_reacted()
signal coaching_requested(seconds: float)
signal coaching_joined()
signal scripted_event(id: String)  # eventos guionizados de los contactos (p. ej. shero_en_el_reflejo)

# v0.2: economía, tienda (expendedora / mostrador), Trainer, Mentor
signal turnstile_passed(entering: bool)
signal economy_changed(saldo: float, ganado_turno: float)
signal shop_opened(shop_id: String, title: String, items: Array)  # items: [{id, label, price, enabled}]
signal shop_closed(shop_id: String)
signal shop_bought(shop_id: String, item_id: String, price: float)
signal trainer_state_changed(state: int)
signal trainer_talk(seconds: float)  # charla de inducción (bloquea al jugador)
signal allocation_posted(aux: int, comply_s: float, until_clock: float)  # el Mentor cambia el AUX esperado
signal allocation_ended()
signal turno_unlocked(turno: int)

# Muerte y checkpoints
# Secuencia (v0.3): death_requested → death_sequence_started(causa, asesino, detalle) → si la mata un
# personaje: Screamers.play → screamer_finished; si es Fatiga/colapso (asesino "" o "fatiga"): sin screamer,
# DeathAnimations.play_collapse → death_animation_finished (tope 5 s en ambos casos) → death_shown →
# [Espacio] respawned. Para fijar el asesino usar Checkpoints.request_death(causa, detalle, asesino).
signal death_requested(cause_id: String, detail: String)
signal death_sequence_started(cause_id: String, killer: String, detail: String)
signal screamer_finished(cause_id: String)
signal death_animation_finished(cause_id: String)
signal death_shown(cause_id: String)
signal respawned(checkpoint_kind: String)
signal checkpoint_saved(kind: String)
signal calm_started(seconds: float)
signal calm_ended()

# --- v0.3: interfaces entre paquetes (PLAN_v0.3 §11; las crea P1, las usan P2-P6) -------------------
# Menú, partidas y dificultad
signal returned_to_menu()
signal slot_changed(agent: String)
signal difficulty_changed(level: int)
# Disciplina de Shero y persecuciones (P3)
signal discipline_step(track: String, step: int, info: Dictionary)
signal pursuit_started(hunter: String, cause: String)
signal pursuit_ended(hunter: String, reason: String)
signal hunter_entered_floor(hunter: String, floor: int)
signal freeze_discipline(on: bool, reason: String)
# Autorizaciones de AUX/zona (Metrics.authorize) y sala de PCs
signal authorization_granted(aux: int, source: String, zone: String, until_clock: float)
signal authorization_ended(source: String)
signal room_exited()
signal room_entered()
# Breaks y lunch (Metrics / GameState)
signal break_started(n: int)
signal break_ended(n: int)
signal lunch_window(open: bool)
# Dormir en el -1 (P2 objeto, P3 regla)
signal player_slept(spot: String)
signal player_woke()
# Contactos con árbol, Ezlaki y Portal Vitzo (P4)
signal contact_outcome(contact: Dictionary, outcome: String, csat: int)
## v0.3.2: el contacto en curso al morir se cerró como «desconectado» (vuelve a la cola; ni perdido ni AHT).
signal contact_disconnected(contact: Dictionary)
signal dialog_node(contact_id: String, node_id: String)
signal ezlak_post(channel: String, author: String, text: String, meta: Dictionary)
signal ezlak_quick_reply(channel: String, reply_id: String)
signal vitzo_portal_action(case_id: String, action: String)
# Personajes con reglas (P5)
signal topico_requested()
signal qa_feedback_called(n: int)
signal qa_feedback_started(n: int)
signal qa_feedback_ended(n: int)
signal training_called()
signal training_started()
signal quiz_answered(i: int, correct: bool)
signal training_ended(passed: bool)
signal guard_check(step: String)
