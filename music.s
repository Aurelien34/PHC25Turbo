    include inc/ay8910.inc

    section	code,text

    global music_init, music_loop

ANIM_COUNTER_INCREMENT equ 37 ; 125 BPM, yeah! (almost)

music_animation_first_run:
    dc.b 0

music_animation_counter:
    dc.b 0

music_pointer:
    dc.b 0

music_instructions:
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_bass
    dc.w play_chord_AM3
    dc.w play_bass
    dc.w play_chord_AM3
    dc.w play_bass
    dc.w play_chord_BM3
    dc.w 0
    dc.w play_chord_BM3
    dc.w 0
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_bass
    dc.w play_chord_GM4
    dc.w play_bass
    dc.w play_chord_GM4
    dc.w play_bass
    dc.w play_chord_AM4
    dc.w 0
    dc.w play_chord_AM4
    dc.w 0
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_bass
    dc.w play_chord_AM3
    dc.w play_bass
    dc.w play_chord_AM3
    dc.w play_bass
    dc.w play_chord_BM3
    dc.w 0
    dc.w play_chord_BM3
    dc.w 0
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_percussion
    dc.w play_bass
    dc.w play_chord_EM4
    dc.w play_bass
    dc.w play_chord_GM4
    dc.w play_bass
    dc.w play_chord_GM4
    dc.w play_bass
    dc.w play_chord_AM4
    dc.w 0
    dc.w play_chord_BM4
    dc.w 0
music_instructions_end:

music_init:
    call ay8910_init_music
    ld a,$ff ; ensure we trigger the carry flag on next round
    ld (music_animation_counter),a
    xor a
    ld (music_pointer),a
    ld (music_animation_first_run),a
    ret

music_loop:
    ; increment counter
    ld a,(music_animation_counter)
    add ANIM_COUNTER_INCREMENT
    jr nc,.update_counter
    ; overflow here, reset counter
    ld a,0 ; don't optimize this, as we don't want to loose the carry flag
.update_counter:
    ld (music_animation_counter),a
    ; return if nothing to be done
    dc.b $d0 ; "ret nc" not assembled correctly by VASM!
    ; Play current pointer position
    ld a,(music_pointer)
    add a
    ld b,0
    ld c,a
    ld hl,music_instructions
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    or h
    jr z,.skip_instructions
    call .exec_instructions ; need an intermediate function call in order to have a return address in the stack
.skip_instructions
    ; Update pointer position
    ld a,(music_pointer)
    inc a
    cp (music_instructions_end-music_instructions)/2
    jr nz,.update_pointer
    ld a,1
    ld (music_animation_first_run),a ; not the first run anymore
    ld a,0  ; don't optimize this, as we don't want to loose the carry flag
.update_pointer    
    ld (music_pointer),a
    ret
.exec_instructions
    jp (hl)

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

prepare_registers_for_notes_3_voices:
    ld hl,.commands_begin
    ld a,(music_animation_first_run)
    or a
    jr nz,.first_run
    ld b,(.commands_end-.commands_begin)/2
    jp ay8910_read_command_sequence
.first_run
    ld b,(.commands_end-.commands_begin)/2-1 ; don't play the last command
    jp ay8910_read_command_sequence
    ; music_animation_first_run
.commands_begin:
    dc.b AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_TONE_A&AY8910_MASK_MIXER_TONE_B&AY8910_MASK_MIXER_TONE_C&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN
    dc.b AY8910_REGISTER_FREQUENCY_A_UPPER, $00
    dc.b AY8910_REGISTER_FREQUENCY_B_UPPER, $00
    dc.b AY8910_REGISTER_FREQUENCY_C_UPPER, $00
    ; shut voices A and B
    dc.b AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_TONE_C&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN
.commands_end:

play_chord_EM4: ; E4 G4# B4
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $be, $96, $7f


play_chord_AM3: ; A3 C4# E4
    call prepare_registers_for_notes_3_voices
    AYOUT AY8910_REGISTER_FREQUENCY_A_UPPER,$01
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $1c, $e1, $be

play_chord_BM3: ; B3 D4# F4#
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $fd, $c9, $a9

play_chord_GM4: ; G4 B4 D5
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $9f, $7f, $6a

play_chord_AM4: ; A4 C5# E5
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $8e, $71, $5f

play_chord_BM4: ; B4 D5# F5#
    call prepare_registers_for_notes_3_voices
    ld hl,.notes
    jp set_lower_frequency_registers_3_voices_and_play
.notes:
    dc.b $7f, $64, $54

play_percussion:
    ld a,(music_animation_first_run)
    or a
    dc.b $c8 ; "ret z" not assembled correctly by VASM!
    AYOUT AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_NOISE_A&AY8910_MASK_MIXER_TONE_B&AY8910_MASK_MIXER_TONE_C&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN 
    ret

play_bass:
    ld hl,.settings
    ld b,(.settings_end-.settings)/2
    jp ay8910_read_command_sequence
.settings ; E2
    dc.b AY8910_REGISTER_FREQUENCY_B_UPPER, $02
    dc.b AY8910_REGISTER_FREQUENCY_B_LOWER, $f6
    dc.b AY8910_REGISTER_VOLUME_B, 12
.settings_end    
    ret
