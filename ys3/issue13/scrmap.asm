.ORG 30000

JOYSTICK2 .equ 63486

initialise:
	ld hl, tmap_tilemap			; Load the address of the tilemap into the right place.
	ld (swapaddr),hl
	ld (swapaddr2),hl
	ld hl, 16384				; Point HL at the screen

main:
	call tilemap				; Display the tilemap

main_loop:
	ld a, (scroll_x_old)
	ld b, a
	ld a, (scroll_x)
	cp b
	jp z, input_loop

	jp p, main_scroll_right


	ld a, (scroll_x_sub_pos)		; Increment scroll_x_sub_pos
	inc a
	ld (scroll_x_sub_pos), a

	cp 16
	jp nz, main_scroll_left

	ld a, 0					; Set scroll_x_sub_pos to 15 and decrement scroll_x_pos
	ld (scroll_x_sub_pos), a

	ld a, (scroll_x_pos)
	inc a
	ld (scroll_x_pos), a

main_scroll_left:
	ld a, (scroll_x_pos)
	add a, 16
	ld d, 0
	ld e, a
	ld hl, tmap_tilemap			; Load the address of the tilemap into the right place.
	add hl, de
	ld (swapaddr),hl

	ld hl, 16384				; Point HL at the screen
	call scrollmap_left			; Scroll what's on the screen
	
	jp input_loop

main_scroll_right:
	ld a, (scroll_x_sub_pos)		; Increment scroll_x_sub_pos
	dec a
	ld (scroll_x_sub_pos), a

	cp 255
	jp nz, do_scroll_right

	ld a, 15				; Set scroll_x_sub_pos to 15 and decrement scroll_x_pos
	ld (scroll_x_sub_pos), a

	ld a, (scroll_x_pos)
	dec a
	ld (scroll_x_pos), a


do_scroll_right:
	ld a, (scroll_x_pos)
	ld d, 0
	ld e, a
	ld hl, tmap_tilemap			; Load the address of the tilemap into the right place.
	add hl, de
	ld (swapaddr),hl

	ld hl, 20480				; Point HL at the screen
	call scrollmap_right			; Scroll what's on the screen

input_loop:
	ld a, 1
	ld (scroll_x_old), a
	ld (scroll_x), a

	ld bc, JOYSTICK2
	in a, (c)					; Get input from JOYSTICK1

input_right:
	bit 1,a
	jp nz, input_left				; Skip this section if bit 3 is not set

	ld a, (scroll_x)
	inc a
	ld (scroll_x),a

	jp input_done	

input_left:
	bit 0,a
	jp nz, input_loop				; Skip this section if bit 3 is not set

	ld a, (scroll_x)
	dec a
	ld (scroll_x),a

input_done:
	jp main_loop

	ret



get_tile_addr:
	ld de, (swapaddr)				; Load DE with the address in swapaddr

	push hl
	ld hl, 64					; Load A with the width of the tilemap
	add hl, de					; Add it to the current tilemap position
	ld (swapaddr), hl				; Store the updated position
	pop hl
	
	ld a, (de)					; Load A with a character from the tilemap and
							; compare it to get the address of the tile image

	cp 0
	jp nz, get_tile_addr_tile1			; If A is not zero, check next tile value

	ld de, _gfxtile00				; Point DE at tile 00
	jp get_tile_addr_end

get_tile_addr_tile1:
	cp 1
	jp nz, get_tile_addr_tile2
	ld de, _gfxtile01				; Point DE at tile 01
	jp get_tile_addr_end

get_tile_addr_tile2:
	cp 2
	jp nz, get_tile_addr_tile3
	ld de, _gfxtile02				; Point DE at tile 02
	jp get_tile_addr_end

get_tile_addr_tile3:
	ld de, _gfxtile03				; Point DE at tile 03, fall-through option

get_tile_addr_end:
	ld a, (scroll_x_sub_pos)
	cp 8
	jp m, get_tile_jump_1

	inc de
	sub 8

get_tile_jump_1:
	ld (swapbyte0), a

	ret



scrollmap_left:
	ld b, 128

scrollmap_l_loop:
	push bc

	ld a, (hl)					; Load A with screen byte
	inc hl						; Increment HL
	ld c, (hl)					; Load C with the next screen byte
	dec hl						; Decrement HL again
	ld b, 32					; Load B with loop counter

scrollmap_l_x_loop_inner:
	sla a						; Shift A left
	bit 7, c					; If bit 7 of C is not set...
	jp z, scrollmap_l_x_skip			; Jump past the next line...
	set 0, a					; Which zeros bit 0 of A

scrollmap_l_x_skip:
	ld (hl), a					; Load the current screen byte with A
	ld a, c						; Load A with C (the next screen byte)
	inc hl						; Shift a couple of screen bytes along
	inc hl
	ld c, (hl)					; Load the next byte into C
	dec hl						; Point HL back at the new current screen byte

	djnz scrollmap_l_x_loop_inner			; Decrement B and loop if not zero

scrollmap_l_end_loop:
	pop bc

scrollmap_l_loop_loop:
	djnz scrollmap_l_loop

scrollmap_l_newbit:
	ld hl, 16384+31
	ld b, 128
	ld c, 15

scrollmap_l_newbit_loop:
	inc c
	ld a, c
	cp 16
	jp nz, scrollmap_l_newbit_loop_2
	ld c, 0
	call get_tile_addr

scrollmap_l_newbit_loop_2:
	push bc
	ld a, (de)
	inc de
	inc de
	ld b, a

	ld a, (swapbyte0)				; Load A with the bit required

	jp scrollmap_l_choose

scrollmap_l_bit_c:
	jp z, scrollmap_l_bit_zero			; If it's zero, skip over this next bit...
	ld a, (hl)					; Otherwise, load A with a screen byte
	set 0, a					; and set bit 0
	jp scrollmap_l_bit_draw				; before skipping over the branch

scrollmap_l_bit_zero:
	ld a, (hl)					; Load A with a screen byte
	res 0, a					; and reset bit 0

scrollmap_l_bit_draw:
	ld (hl),a
	call _get_next_row

	pop bc
	djnz scrollmap_l_newbit_loop

	ret




scrollmap_l_choose:
	cp 0
	jp nz, scrollmap_l_bit_display_c1

	bit 7, b
	jp scrollmap_l_bit_c

scrollmap_l_bit_display_c1:
	cp 1
	jp nz, scrollmap_l_bit_display_c2

	bit 6, b
	jp scrollmap_l_bit_c

scrollmap_l_bit_display_c2:
	cp 2
	jp nz, scrollmap_l_bit_display_c3

	bit 5, b
	jp scrollmap_l_bit_c

scrollmap_l_bit_display_c3:
	cp 3
	jp nz, scrollmap_l_bit_display_c4

	bit 4, b
	jp scrollmap_l_bit_c

scrollmap_l_bit_display_c4:
	cp 4
	jp nz, scrollmap_l_bit_display_c5

	bit 3, b
	jp scrollmap_l_bit_c

scrollmap_l_bit_display_c5:
	cp 5
	jp nz, scrollmap_l_bit_display_c6

	bit 2, b
	jp scrollmap_l_bit_c

scrollmap_l_bit_display_c6:
	cp 6
	jp nz, scrollmap_l_bit_display_c7

	bit 1, b
	jp scrollmap_l_bit_c

scrollmap_l_bit_display_c7:
	bit 0, b
	jp scrollmap_l_bit_c






scrollmap_right:

	ld b, 128					; Load B with the number of rows to draw

scrollmap_r_loop:
	push bc						; Push the counter onto the stack
	ld a, (hl)					; Load A with a byte of screen data
	dec hl						; Point HL left one screen byte
	ld c, (hl)					; Get this byte too
	inc hl						; Point HL back where it was
	ld b, 32					; Load B with the number of columns

scrollmap_r_x_loop_inner:
	srl a						; Shift A right
	bit 0, c					; Check bit 0 of C (the next screen byte)
							;  and set bit 7 of A accordingly
	jp z, scrollmap_r_x_skip
	set 7, a

scrollmap_r_x_skip:
	ld (hl), a					; Load the modified data back to the screen
	ld a, c						; Load A with C (the next byte)
	dec hl						; Move HL left two screen bytes
	dec hl
	ld c, (hl)					; Put this next byte into C
	inc hl						; Point HL right one byte

	djnz scrollmap_r_x_loop_inner			; Decrement B and loop if there are still columns
							;  to draw

scrollmap_r_y_loop_outer:
	pop bc						; Get our counter off the stack

	djnz scrollmap_r_loop				; Decrement B and loop if there are still rows
							;  to draw

scrollmap_r_newbit:
	ld hl, 16384					; Load HL with the address of the top-left byte
							;  of the screen
	ld b, 128					; Load B with the number of rows to draw
	ld c, 15					; Load C with 15

scrollmap_r_newbit_loop:
	inc c						; Increment C, which counts how many rows of
							;  the tile image we have drawn
	ld a, c
	cp 16
	jp nz, scrollmap_r_newbit_loop_2		; If C is not 16, then skip ahead
	ld c, 0						; C is 16, so we'll reset it to zero
	call get_tile_addr				;  and we'll get the address of the next tile image

scrollmap_r_newbit_loop_2:
	push bc						; Push our counters onto the stack
	ld a, (de)					; Load A with a byte of tile image data
	inc de						; Point DE at the next row of tile image data
	inc de
	ld b, a						; Load A into B

	ld a, (swapbyte0)				; Load A with the bit required

	jp scrollmap_r_choose				; Compare the right bit

scrollmap_r_bit_c:
	jp z, scrollmap_r_bit_zero			; If it's zero, skip over this next bit...
	ld a, (hl)					; Otherwise, load A with a screen byte
	set 7, a					; and set bit 7
	jp scrollmap_r_bit_draw				; before skipping over the branch

scrollmap_r_bit_zero:
	ld a, (hl)					; Load A with a screen byte
	res 7, a					; and reset bit 7

scrollmap_r_bit_draw:
	ld (hl), a					; Load the modified data back to the screen
	call _get_next_row				; Move one row down

	pop bc						; Get our counters back off the stack
	djnz scrollmap_r_newbit_loop			; Decrement B and loop if there are still rows left

	ret




scrollmap_r_choose:
	cp 0
	jp nz, scrollmap_r_bit_display_c1

	bit 7, b
	jp scrollmap_r_bit_c

scrollmap_r_bit_display_c1:
	cp 1
	jp nz, scrollmap_r_bit_display_c2

	bit 6, b
	jp scrollmap_r_bit_c

scrollmap_r_bit_display_c2:
	cp 2
	jp nz, scrollmap_r_bit_display_c3

	bit 5, b
	jp scrollmap_r_bit_c

scrollmap_r_bit_display_c3:
	cp 3
	jp nz, scrollmap_r_bit_display_c4

	bit 4, b
	jp scrollmap_r_bit_c

scrollmap_r_bit_display_c4:
	cp 4
	jp nz, scrollmap_r_bit_display_c5

	bit 3, b
	jp scrollmap_r_bit_c

scrollmap_r_bit_display_c5:
	cp 5
	jp nz, scrollmap_r_bit_display_c6

	bit 2, b
	jp scrollmap_r_bit_c

scrollmap_r_bit_display_c6:
	cp 6
	jp nz, scrollmap_r_bit_display_c7

	bit 1, b
	jp scrollmap_r_bit_c

scrollmap_r_bit_display_c7:
	bit 0, b
	jp scrollmap_r_bit_c


tilemap:

	ld a, 0						; Set screen Y coordinate
	ld (swapbyte0), a

	ld a, 8					; Set number of rows to draw
	ld (swapbyte1), a

	ld a, 16					; Set number of columns to draw
	ld (swapbyte2), a

tilemap_1:
	ld bc, (swapaddr)
	ld a, (bc)					; Load A with new tile

	cp 0
	jp nz, tilemap_tile1				; If A is not zero, check next tile value

	ld de, _gfxtile00				; Point DE at tile 00
	jp tilemap_display

tilemap_tile1:
	cp 1
	jp nz, tilemap_tile2

	ld de, _gfxtile01				; Point DE at tile 01
	jp tilemap_display

tilemap_tile2:
	cp 2
	jp nz, tilemap_hloop
	ld de, _gfxtile02				; Point DE at tile 02
	jp tilemap_display


tilemap_display:
	push hl
	call display_tile
	pop hl


tilemap_hloop:						; Inner loop - cycle across screen

	ld a, (swapbyte2)				; Load A with number of columns remaining
	dec a						; Decrement A
	cp 0						; Compare A with zero
	jp z, tilemap_vloop				; If the comparison is true, then that was the last column -
							; jump out to the vertical loop. Otherwise...

	ld (swapbyte2), a				; Store the updated column counter

	inc hl						; Increment screen pointer
	inc hl

	ld bc, (swapaddr)				; Load BC with stored tilemap address
	inc bc						; Increment BC by one
	ld (swapaddr), bc				; Update stored tilemap address with contents of BC

	jp tilemap_1					; Draw next row


tilemap_vloop:						; Outer loop - cycle down screen

	ld a, 16					; Reset the horizontal counter
	ld (swapbyte2), a


	ld hl, (swapaddr2)				; Load HL with stored address of this row of tilemap
	ld de, 64					; Load DE with the width of the tilemap
	add hl, de
	ld (swapaddr), hl				; Update current tilemap address with contents of HL
	ld (swapaddr2), hl				; Update row tilemap address with contents of HL

	ld a, (swapbyte0)				; Load A with stored Y coordinate
	add a, 16					; Increment A by sixteen (the height of one tile)
	ld (swapbyte0), a				; Store the updated Y coordinate

	ld b,a						; Set row to request
	call get_screen_offset				; Set HL to point at requested screen position


	ld a, (swapbyte1)				; Load A with the number of rows remaining
	dec a						; Decrement A
	ld (swapbyte1), a				; Store the updated rows counter
	cp 0						; Compare A with zero
	jp nz, tilemap_1				; If it's a non-zero result, there are rows remaining -
							; Jump back to the start of the loop. Otherwise, it's
							; all over, so we...

	ret						; ...finally, return out of the tilemap program.


display_tile:
							; Tile Display Routine
							; 
							; Variables needed:
							; HL - screen address to write to
							; DE - graphic data to display
							; 

	ld b, 16						; Load B with number of rows

display_tile_loop:
	ld a,(de)					; Load A with a byte 
	inc de						; Shift DE to point at the next byte of graphic data
	ld (hl), a					; Load the current screen address with the contents of A
	inc hl

	ld a,(de)					; Load A with a byte 
	inc de						; Shift DE to point at the next byte of graphic data
	ld (hl), a					; Load the current screen address with the contents of A
	dec hl

	call _get_next_row				; Shift HL to point exactly one row down
	djnz display_tile_loop				; If B is not zero, decrement B and loop

	ret

_gfxtile00
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000

	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000
	.db %00000000, %00000000

_gfxtile01
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111

	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111
	.db %11111111, %11111111

_gfxtile02
	.db %10101010, %10101010
	.db %01010101, %01010101
	.db %10101010, %10101010
	.db %01010101, %01010101
	.db %10101010, %10101010
	.db %01010101, %01010101
	.db %10101010, %10101010
	.db %01010101, %01010101

	.db %10101010, %10101010
	.db %01010101, %01010101
	.db %10101010, %10101010
	.db %01010101, %01010101
	.db %10101010, %10101010
	.db %01010101, %01010101
	.db %10101010, %10101010
	.db %01010101, %01010101

_gfxtile03
	.db %11111111, %11111111
	.db %10000000, %00000001
	.db %10001111, %11110001
	.db %10001111, %11110001
	.db %10000000, %00110001
	.db %10000000, %00110001
	.db %10000000, %00110001
	.db %10000111, %11100001

	.db %10000111, %11100001
	.db %10000000, %00110001
	.db %10000000, %00110001
	.db %10001100, %01100001
	.db %10001111, %11000001
	.db %10000111, %11000001
	.db %10000000, %00000001
	.db %11111111, %11111111



tmap_width
	.db 64					; The length of one row in the tilemap

tmap_tilemap
.db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.db 1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,1,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,1
.db 2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,1,1,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,1
.db 0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,1,1,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,1
.db 0,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,1,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1
.db 2,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,1,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,1
.db 1,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,1,1,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,0,2,1,2,1
.db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; A quick hack to get the address of the next row down the screen
; Pass the current row address in HL, and it'll return into the same
; register pair
_get_next_row
	inc h
	ld a,h
	and 7
	ret nz
	ld a,l
	add a,32
	ld l,a
	ret c
	ld a,h
	sub 8
	ld h,a
	ret

swapaddr
	.dw 0
swapaddr2
	.dw 0
swapaddr3
	.dw 0

swapbyte0
	.db 0
swapbyte1
	.db 0
swapbyte2
	.db 0
swapbyte3
	.db 0


scroll_x_old
	.db 1

scroll_x
	.db 0

scroll_x_pos
	.db 255

scroll_x_sub_pos
	.db 15


scroll_bit
	.db 0


;
; Pass row and column in registers b and c
;
get_screen_offset:
    push de                         ; Store de safely on the stack

    ld de, y_lookup                 ; Point DE at the start of the look-up table
    ld h, 0
    ld l, b                         ; Load row into HL
    add hl, hl                      ; Multiply hl by two, because there are two bytes for every row
    add hl, de                      ; Add the address of table to HL

    ld e, (hl)                      ; Load de with the two-byte number stored in the LUT
    inc hl                          ; (2 byte numbers are stored least-significant byte first)
    ld d, (hl)                      ; 

    ld hl, 16384                    ; Load hl with the address of the screen
    add hl, de                      ; Add the offset taken from the LUT to hl
    
    pop de                          ; Retrieve de from the stack
    ret


y_lookup:
	.dw 0
	.dw 256
	.dw 512
	.dw 768
	.dw 1024
	.dw 1280
	.dw 1536
	.dw 1792

	.dw 32
	.dw 288
	.dw 544
	.dw 800
	.dw 1056
	.dw 1312
	.dw 1568
	.dw 1824

	.dw 64
	.dw 320
	.dw 576
	.dw 832
	.dw 1088
	.dw 1344
	.dw 1600
	.dw 1856

	.dw 96
	.dw 352
	.dw 608
	.dw 864
	.dw 1120
	.dw 1376
	.dw 1632
	.dw 1888

	.dw 128
	.dw 384
	.dw 640
	.dw 896
	.dw 1152
	.dw 1408
	.dw 1664
	.dw 1920

	.dw 160
	.dw 416
	.dw 672
	.dw 928
	.dw 1184
	.dw 1440
	.dw 1696
	.dw 1952

	.dw 192
	.dw 448
	.dw 704
	.dw 960
	.dw 1216
	.dw 1472
	.dw 1728
	.dw 1984

	.dw 224
	.dw 480
	.dw 736
	.dw 992
	.dw 1248
	.dw 1504
	.dw 1760
	.dw 2016


	.dw 2048
	.dw 2304
	.dw 2560
	.dw 2816
	.dw 3072
	.dw 3328
	.dw 3584
	.dw 3840

	.dw 2080
	.dw 2336
	.dw 2592
	.dw 2848
	.dw 3104
	.dw 3360
	.dw 3616
	.dw 3872

	.dw 2112
	.dw 2368
	.dw 2624
	.dw 2880
	.dw 3136
	.dw 3392
	.dw 3648
	.dw 3904

	.dw 2144
	.dw 2400
	.dw 2656
	.dw 2912
	.dw 3168
	.dw 3424
	.dw 3680
	.dw 3936

	.dw 2176
	.dw 2432
	.dw 2688
	.dw 2944
	.dw 3200
	.dw 3456
	.dw 3712
	.dw 3968

	.dw 2208
	.dw 2464
	.dw 2720
	.dw 2976
	.dw 3232
	.dw 3488
	.dw 3744
	.dw 4000

	.dw 2240
	.dw 2496
	.dw 2752
	.dw 3008
	.dw 3264
	.dw 3520
	.dw 3776
	.dw 4032

	.dw 2272
	.dw 2528
	.dw 2784
	.dw 3040
	.dw 3296
	.dw 3552
	.dw 3808
	.dw 4064


	.dw 4096
	.dw 4352
	.dw 4608
	.dw 4864
	.dw 5120
	.dw 5376
	.dw 5632
	.dw 5888

	.dw 4128
	.dw 4384
	.dw 4640
	.dw 4896
	.dw 5152
	.dw 5408
	.dw 5664
	.dw 5920

	.dw 4160
	.dw 4416
	.dw 4672
	.dw 4928
	.dw 5184
	.dw 5440
	.dw 5696
	.dw 5952

	.dw 4192
	.dw 4448
	.dw 4704
	.dw 4960
	.dw 5216
	.dw 5472
	.dw 5728
	.dw 5984

	.dw 4224
	.dw 4480
	.dw 4736
	.dw 4992
	.dw 5248
	.dw 5504
	.dw 5760
	.dw 6016

	.dw 4256
	.dw 4512
	.dw 4768
	.dw 5024
	.dw 5280
	.dw 5536
	.dw 5792
	.dw 6048

	.dw 4288
	.dw 4544
	.dw 4800
	.dw 5056
	.dw 5312
	.dw 5568
	.dw 5824
	.dw 6080

	.dw 4320
	.dw 4576
	.dw 4832
	.dw 5088
	.dw 5344
	.dw 5600
	.dw 5856
	.dw 6112
