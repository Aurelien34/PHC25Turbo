    include inc/ay8910.inc
    include inc/music.inc

    section	code,text

    global music_init_circuit_picker

music_instructions:
    dc.b MUSIC_COMMAND_PLAY_TONE_F3S
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_F3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_B2
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S

    dc.b MUSIC_COMMAND_PLAY_TONE_F3S
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_F3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_B2
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S

    dc.b MUSIC_COMMAND_PLAY_CHORD_A3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_CHORD_B3
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_B2
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S

    dc.b MUSIC_COMMAND_PLAY_CHORD_CS4
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_CHORD_B3
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_B2
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S

    dc.b MUSIC_COMMAND_PLAY_CHORD_A3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_CHORD_B3
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_B2
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S

    dc.b MUSIC_COMMAND_PLAY_CHORD_CS4
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_CHORD_B3
    dc.b MUSIC_COMMAND_PLAY_TONE_E3
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S
    dc.b MUSIC_COMMAND_PLAY_TONE_B2
    dc.b MUSIC_COMMAND_PLAY_TONE_C3S

    
music_instructions_end:

music_init_circuit_picker:
    ld hl,music_instructions
    ld (current_music_data_base_address),hl
    ld a,music_instructions_end-music_instructions
    ld (current_music_instructions_count),a
    ld a,14 ; 118 bpm
    ld (music_animation_speed),a
    ld a,1
    ld (music_animation_not_first_run),a ; no first run for this music
    ret