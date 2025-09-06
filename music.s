    include inc/ay8910.inc
    include inc/music.inc

    section	code,text

    global music_init, music_loop
    global current_music_data_base_address, current_music_instructions_count, music_animation_not_first_run
    global music_animation_counter, music_animation_speed

music_animation_speed
    dc.b 0

music_animation_not_first_run:
    dc.b 0

music_animation_counter:
    dc.b 0

music_pointer:
    dc.b 0

current_music_data_base_address:
    dc.w $ffff

current_music_instructions_count:
    dc.b $ff

music_commands: ; These should follow constants MUSIC_COMMAND_XXX in inc/music.inc
    dc.w 0 ; Do nothing
    dc.w music_play_chord_EM4 ; 1
    dc.w music_play_chord_AM3 ; 2
    dc.w music_play_chord_BM3 ; 3
    dc.w music_play_chord_GM4 ; 4
    dc.w music_play_chord_AM4 ; 5
    dc.w music_play_chord_BM4 ; 6
    dc.w music_play_percussion ; 7
    dc.w music_play_bass ; 8
    dc.w music_play_tone_G4S ; 9
    dc.w music_play_tone_C5S ; 10
    dc.w music_play_tone_C5 ; 11
    dc.w music_play_tone_A4S ; 12
    dc.w music_play_tone_F4 ; 13
    dc.w music_play_tone_F5 ; 14
    dc.w music_play_tone_F3S ; 15
    dc.w music_play_tone_C3S ; 16
    dc.w music_play_tone_E3 ; 17
    dc.w music_play_tone_B2 ; 18
    dc.w music_play_chord_A3 ; 19
    dc.w music_play_chord_B3 ; 20
    dc.w music_play_chord_CS4 ; 21
    dc.w music_play_chord_B3x1 ; 22
    dc.w music_play_chord_B3M ; 23
    dc.w music_play_chord_C4Sx1 ; 24
    dc.w music_play_tone_B1 ; 25

; Music number in register [a]
music_init:
    cp MUSIC_NUMBER_INTRO
    jp nz,.not_music_intro
    call music_init_intro
    jp .common
.not_music_intro:
    cp MUSIC_NUMBER_END_OF_RACE
    jp nz,.not_music_end_of_race
    call music_init_end_of_race
    jp .common
.not_music_end_of_race:
    cp MUSIC_NUMBER_CIRCUIT_PICKER
    jp nz,.not_music_circuit_picker
    call music_init_circuit_picker
    jp .common
.not_music_circuit_picker:
    cp MUSIC_NUMBER_GREETINGS
    jp nz,.not_music_greetings
    call music_init_greetings
    jp .common
.not_music_greetings:

.common:
    call ay8910_init_music
    ld a,$ff ; ensure we trigger the carry flag on next round
    ld (music_animation_counter),a
    xor a
    ld (music_pointer),a
    ret

music_loop:
    ; increment counter
    ld a,(music_animation_speed)
    ld b,a
    ld a,(music_animation_counter)
    add b
    jr nc,.update_counter
    ; overflow here, reset counter
    ld a,0 ; don't optimize this, as we don't want to loose the carry flag

    jr .update_counter

.update_counter:
    ld (music_animation_counter),a
    ; return if nothing to be done
    dc.b $d0 ; "ret nc" not assembled correctly by VASM!
    ; Play current pointer position
    ld a,(music_pointer)
    ld b,0
    ld c,a
    ld hl,(current_music_data_base_address)
    add hl,bc
    ld a,(hl)
    or a
    jr z,.skip_instructions
    call .exec_instructions ; need an intermediate function call in order to have a return address in the stack
.skip_instructions
    ; Update pointer position
    ld a,(current_music_instructions_count)
    ld b,a
    ld a,(music_pointer)
    inc a
    cp b
    jr nz,.update_pointer
    ld a,1
    ld (music_animation_not_first_run),a ; not the first run anymore
    ld a,0  ; don't optimize this, as we don't want to loose the carry flag
.update_pointer    
    ld (music_pointer),a
    ret
.exec_instructions
    ; [a] contains instruction number
    ld b,0
    ld c,a
    ld hl,music_commands
    add hl,bc
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp (hl)

; [a] contains the note frequency (lower byte)
set_lower_frequency_registers_1_voice_and_play
    ld c,a
    ld a,AY8910_REGISTER_FREQUENCY_A_LOWER
    AY_PUSH_REG
    ld a,c
    AY_PUSH_VAL
    ld hl,.settings
    ld b,(.settings_end-.settings)/2
    jp ay8910_read_command_sequence
.settings
    dc.b AY8910_REGISTER_VOLUME_A, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_ENVELOPPE_SHAPE, AY_ENVELOPPE_TYPE_SINGLE_DECAY_THEN_OFF
.settings_end    

prepare_registers_for_notes_1_voice:
    ld hl,.commands_begin
    ld b,(.commands_end-.commands_begin)/2
    jp ay8910_read_command_sequence
.commands_begin:
    dc.b AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_TONE_A&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN
    dc.b AY8910_REGISTER_FREQUENCY_A_UPPER, $00
.commands_end:

prepare_registers_for_notes_3_voices:
    ld hl,.commands_begin
    ld a,(music_animation_not_first_run)
    or a
    jr nz,.first_run
    ld b,(.commands_end-.commands_begin)/2
    jp ay8910_read_command_sequence
.first_run
    ld b,(.commands_end-.commands_begin)/2-1 ; don't play the last command
    jp ay8910_read_command_sequence
    ; music_animation_not_first_run
.commands_begin:
    dc.b AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_TONE_A&AY8910_MASK_MIXER_TONE_B&AY8910_MASK_MIXER_TONE_C&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN
    dc.b AY8910_REGISTER_FREQUENCY_A_UPPER, $00
    dc.b AY8910_REGISTER_FREQUENCY_B_UPPER, $00
    dc.b AY8910_REGISTER_FREQUENCY_C_UPPER, $00
    ; shut voices A and B
    dc.b AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_TONE_C&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN
.commands_end:

; [hl] points to the notes, expecting 3 notes
set_lower_frequency_registers_3_voices_and_play:
    ld a,AY8910_REGISTER_FREQUENCY_A_LOWER
    call .load_and_push
    ld a,AY8910_REGISTER_FREQUENCY_B_LOWER
    call .load_and_push
    ld a,AY8910_REGISTER_FREQUENCY_C_LOWER
    call .load_and_push
    ld hl,.settings
    ld b,(.settings_end-.settings)/2
    jp ay8910_read_command_sequence
.settings
    dc.b AY8910_REGISTER_VOLUME_A, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_VOLUME_B, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_VOLUME_C, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_ENVELOPPE_SHAPE, AY_ENVELOPPE_TYPE_SINGLE_DECAY_THEN_OFF
.settings_end    
.load_and_push
    AY_PUSH_REG 
    ld a,(hl)
    inc hl
    AY_PUSH_VAL
    ret

music_play_chord_EM4: ; E4 G4# B4
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jr set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $be, $96, $7f

music_play_chord_AM3: ; A3 C4# E4
    call prepare_registers_for_notes_3_voices
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER,$01
    ld hl,.notes
    jr set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $1c, $e1, $be

music_play_chord_BM3: ; B3 D4# F4#
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jr set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $fd, $c9, $a9

music_play_chord_GM4: ; G4 B4 D5
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jr set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $9f, $7f, $6a

music_play_chord_AM4: ; A4 C5# E5
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jr set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $8e, $71, $5f

music_play_chord_BM4: ; B4 D5# F5#
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jr set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $7f, $64, $54

music_play_percussion:
    ld a,(music_animation_not_first_run)
    or a
    dc.b $c8 ; "ret z" not assembled correctly by VASM!
    AYOUT AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_NOISE_A&AY8910_MASK_MIXER_TONE_B&AY8910_MASK_MIXER_TONE_C&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN 
    ret

music_play_bass:
    ld hl,.settings
    ld b,(.settings_end-.settings)/2
    jp ay8910_read_command_sequence
.settings ; E2
    dc.b AY8910_REGISTER_FREQUENCY_B_UPPER, $02
    dc.b AY8910_REGISTER_FREQUENCY_B_LOWER, $f6
    dc.b AY8910_REGISTER_VOLUME_B, 12
.settings_end    
    ret

music_play_tone_G4S: ; G4#
    call prepare_registers_for_notes_1_voice
    ld a,$96
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_C5S: ; C5#
    call prepare_registers_for_notes_1_voice
    ld a,$71
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_C5: ; C5
    call prepare_registers_for_notes_1_voice
    ld a,$77
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_A4S: ; A4#
    call prepare_registers_for_notes_1_voice
    ld a,$86
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_F4: ; F4
    call prepare_registers_for_notes_1_voice
    ld a,$B3
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_F5: ; F5
    call prepare_registers_for_notes_1_voice
    ld a,$59
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_F3S: ; F3#
    call prepare_registers_for_notes_1_voice
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER, 1
    ld a,$52
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_C3S: ; C3#
    call prepare_registers_for_notes_1_voice
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER, 1
    ld a,$c3
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_E3: ; E3
    call prepare_registers_for_notes_1_voice
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER, 1
    ld a,$7b
    jp set_lower_frequency_registers_1_voice_and_play

music_play_tone_B2: ; B2
    call prepare_registers_for_notes_1_voice
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER, 1
    ld a,$fa
    jp set_lower_frequency_registers_1_voice_and_play

music_play_chord_A3: ; A3 C#4 F#4
    call prepare_registers_for_notes_3_voices
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER, 1
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $1c, $e1, $a9

music_play_chord_B3: ; B3 D4 G#4
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $fd, $d5, $96

music_play_chord_CS4: ; C#4 E4 A4
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $e1, $be, $8e

music_play_chord_B3x1: ; B3 E4 G4#
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $fd, $be, $96

music_play_chord_B3M: ; B3 D4# F4#
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $fd, $c9, $a9

music_play_chord_C4Sx1: ; C4# F4# A4
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $e1, $a9, $8e

music_play_tone_B1: ; B1
    call prepare_registers_for_notes_1_voice
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER, 3
    ld a,$f4
    jp set_lower_frequency_registers_1_voice_and_play
