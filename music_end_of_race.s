    include inc/ay8910.inc
    include inc/music.inc

    section	code,text

    global music_init_end_of_race

music_instructions:
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_A4S
    dc.b MUSIC_COMMAND_PLAY_TONE_F4
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_F4
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_A4S
    dc.b MUSIC_COMMAND_PLAY_TONE_F5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_F5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_A4S
    dc.b MUSIC_COMMAND_PLAY_TONE_F4
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_F4
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b MUSIC_COMMAND_PLAY_TONE_A4S
    dc.b MUSIC_COMMAND_PLAY_TONE_G4S
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5S
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_C5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_A4S
    dc.b MUSIC_COMMAND_PLAY_TONE_F5
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_TONE_F5
    dc.b 0


music_instructions_end:

music_init_end_of_race:
    ld hl,music_instructions
    ld (current_music_data_base_address),hl
    ld a,music_instructions_end-music_instructions
    ld (current_music_instructions_count),a
    ld a,37
    ld (music_animation_speed),a
    ld a,1
    ld (music_animation_not_first_run),a ; no first run for this music
    ret