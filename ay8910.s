    include inc/rammap.inc
    include inc/ay8910.inc

    section	code,text

    global ay8910_init, ay8910_init_cars, ay8910_init_music
    global ay8910_loop, ay8910_inject_single_chain_in_queue, ay8910_inject_chain_sequence_in_chain_queue
    global ay8910_queue_sequence_wall_collision
    global ay8910_read_command_sequence

ANIM_COUNTER_INCREMENT equ 32

init_sequence:
    dc.b AY8910_REGISTER_VOLUME_A, 0
    dc.b AY8910_REGISTER_VOLUME_B, 0
    dc.b AY8910_REGISTER_VOLUME_C, 0
    dc.b AY8910_REGISTER_MIXER, AY8910_MASK_MIXER_TONE_A&AY8910_MASK_MIXER_TONE_B&AY8910_MASK_MIXER_TONE_C&AY8910_MASK_MIXER_PORT_A_IN&AY8910_MASK_MIXER_PORT_B_IN
    dc.b AY8910_REGISTER_FREQUENCY_A_LOWER, 0
    dc.b AY8910_REGISTER_FREQUENCY_A_UPPER, 0
    dc.b AY8910_REGISTER_FREQUENCY_B_LOWER, 0
    dc.b AY8910_REGISTER_FREQUENCY_B_UPPER, 0
end_init_sequence:

car_sequence:
    dc.b AY8910_REGISTER_ENVELOPPE_SHAPE, AY_ENVELOPPE_TYPE_REPEATED_DECAY
    dc.b AY8910_REGISTER_VOLUME_A, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_VOLUME_B, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_FREQUENCY_A_UPPER, 1
    dc.b AY8910_REGISTER_FREQUENCY_A_LOWER, 0 
    dc.b AY8910_REGISTER_FREQUENCY_B_UPPER, 1
    dc.b AY8910_REGISTER_FREQUENCY_B_LOWER, 0
    dc.b AY8910_REGISTER_ENVELOPPE_DURATION_UPPER, 0
    dc.b AY8910_REGISTER_ENVELOPPE_DURATION_LOWER, 20
end_car_sequence:

music_sequence:
    dc.b AY8910_REGISTER_VOLUME_A, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_VOLUME_B, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_VOLUME_C, AY8910_FLAG_VOLUME_WITH_ENVELOPPE
    dc.b AY8910_REGISTER_ENVELOPPE_DURATION_UPPER, 10
    dc.b AY8910_REGISTER_ENVELOPPE_DURATION_LOWER, 0
    dc.b AY8910_REGISTER_ENVELOPPE_SHAPE, AY_ENVELOPPE_TYPE_SINGLE_DECAY_THEN_OFF
    dc.b AY8910_REGISTER_NOISE_PERIOD, 0
end_music_sequence:

audio_animation_counter:
    dc.w 0

command_chain_queue:
    dc.b 0,0,0,0,0,0
command_chain_queue_end:


chain_sequence_keyboard_beep:
    dc.b AY_SOUND_CHAIN_NUMBER_PLAY_TONE, AY_SOUND_CHAIN_NUMBER_SILENCE
chain_sequence_keyboard_beep_end:

chain_sequence_wall_collision:
    dc.b AY_SOUND_CHAIN_NUMBER_PLAY_CRASH, AY_SOUND_CHAIN_NUMBER_SILENCE
chain_sequence_wall_collision_end:

AY_SOUND_CHAIN_NUMBER_SILENCE equ 1
AY_SOUND_CHAIN_NUMBER_PLAY_TONE equ 2
AY_SOUND_CHAIN_NUMBER_PLAY_CRASH equ 3

command_chains:
    dc.w $ffff ; todo put the animation counter here! (maybe)
    dc.w ay8910_command_chain_silence
    dc.w ay8910_command_chain_play_tone
    dc.w ay8910_command_chain_play_crash_p1

ay8910_command_chain_silence:
    dc.b (ay8910_command_chain_silence_end-ay8910_command_chain_silence-1)/2
    dc.b AY8910_REGISTER_VOLUME_C, 0
ay8910_command_chain_silence_end:

ay8910_command_chain_play_tone:
    dc.b (ay8910_command_chain_play_tone_end-ay8910_command_chain_play_tone-1)/2
    dc.b AY8910_REGISTER_FREQUENCY_C_LOWER,150
    dc.b AY8910_REGISTER_FREQUENCY_C_UPPER,0
    dc.b AY8910_REGISTER_VOLUME_C, 15
ay8910_command_chain_play_tone_end:

ay8910_command_chain_play_crash_p1:
    dc.b (ay8910_command_chain_play_crash_p1_end-ay8910_command_chain_play_crash_p1-1)/2
    dc.b AY8910_REGISTER_FREQUENCY_C_LOWER,50
    dc.b AY8910_REGISTER_FREQUENCY_C_UPPER,2
    dc.b AY8910_REGISTER_VOLUME_C, 15
ay8910_command_chain_play_crash_p1_end:


ay8910_read_command_sequence:
.command_loop:
    ld a,(hl)
    inc hl
    AY_PUSH_REG
    ld a,(hl)
    inc hl
    AY_PUSH_VAL
    dec b
    jr nz,.command_loop
    ret

ay8910_init:
    ld hl,init_sequence
    ld b,(end_init_sequence-init_sequence)/2
    call ay8910_read_command_sequence
    call clear_chain_queue
    xor a
    ret

ay8910_init_cars:
    call ay8910_init
    ld hl,car_sequence
    ld b,(end_car_sequence-car_sequence)/2
    call ay8910_read_command_sequence
    ret

ay8910_init_music:
    call ay8910_init
    ld hl,music_sequence
    ld b,(end_music_sequence-music_sequence)/2
    call ay8910_read_command_sequence
    ret

; Chain number in [a]
execute_command_chain:
    add a
    ld c,a
    ld b,0
    ld hl,command_chains
    add hl,bc
    ld a,(hl)
    inc hl
    ld l,(hl)
    ld l,a
    ; hl points to the chain
    ld b,(hl) ; b points to actions count
    inc hl
    jr ay8910_read_command_sequence

ay8910_inject_single_chain_in_queue:
    ld (.tmp_command),a
    ld hl,.tmp_command
    ld b,0
    ld c,1
    jr ay8910_inject_chain_sequence_in_chain_queue
.tmp_command:
    dc.b 0

clear_chain_queue:
    ld hl,command_chain_queue
    ld de,command_chain_queue+1
    xor a
    ld (hl),a
    ld b,0
    ld c,command_chain_queue_end-command_chain_queue-1
    ldir
    ret

; [HL] points to the command list, bc contains count
ay8910_inject_chain_sequence_in_chain_queue:
    push hl
    push bc
    call clear_chain_queue
    ; copy chain
    pop bc
    pop hl
    ld de,command_chain_queue
    ldir
    ; Next command won't wait
    ld a,$ff
    ld (audio_animation_counter),a
    xor a
    ld (audio_animation_counter+1),a
    ret

; Return in [a]
peek_first_chain_in_list:
    ; shift the rest of the list
    ld de,command_chain_queue
    ld a,(de)
    ld hl,command_chain_queue+1
    ld bc,command_chain_queue_end-command_chain_queue-1
    ldir
    ex af,af' ; '
    xor a
    ld (de),a
    ex af,af' ; '
    ret

; Call this every frame
ay8910_loop:
    ld b,0
    ld c,ANIM_COUNTER_INCREMENT
    ld hl,(audio_animation_counter)
    add hl,bc
    ld a,h
    and 1
    jp z,.no_reset
    ld h,0
    ld l,0
    jp .no_reset
.no_reset
    ld (audio_animation_counter),hl
    ; Z flag is still valid
    dc.b $c8 ; "ret z" not assembled correctly by VASM!
    ; We should now animate
    call peek_first_chain_in_list
    or a
    dc.b $c8 ; "ret z" not assembled correctly by VASM!
    jr execute_command_chain

ay8910_queue_sequence_keyboard_beep:
    ld bc,chain_sequence_keyboard_beep_end-chain_sequence_keyboard_beep
    ld hl,chain_sequence_keyboard_beep
    jr ay8910_inject_chain_sequence_in_chain_queue

ay8910_queue_sequence_wall_collision:
    ld bc,chain_sequence_wall_collision_end-chain_sequence_wall_collision
    ld hl,chain_sequence_wall_collision
    jr ay8910_inject_chain_sequence_in_chain_queue
