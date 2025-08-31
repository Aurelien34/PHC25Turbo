    include inc/ay8910.inc
    include inc/music.inc

    section	code,text

    global music_init_intro

music_instructions:
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_AM3
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_AM3
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_BM3
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_CHORD_BM3
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_GM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_GM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_AM4
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_CHORD_AM4
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_AM3
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_AM3
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_BM3
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_CHORD_BM3
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_PERCUSSION
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_EM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_GM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_GM4
    dc.b MUSIC_COMMAND_PLAY_BASS
    dc.b MUSIC_COMMAND_PLAY_CHORD_AM4
    dc.b 0
    dc.b MUSIC_COMMAND_PLAY_CHORD_BM4
    dc.b 0
music_instructions_end:

music_init_intro:
    ld hl,music_instructions
    ld (current_music_data_base_address),hl
    ld a,music_instructions_end-music_instructions
    ld (current_music_instructions_count),a
    ld a,37
    ld (music_animation_speed),a
    xor a
    ld (music_animation_not_first_run),a ; first run for this music
    ret