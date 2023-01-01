.eqv BMP_FILE_SIZE 90122
.eqv BYTES_PER_ROW 1800

	.data
#space for the 600x50px 24-bits bmp image
.align 4
res:	.space 2
turtle: .space 128
image:	.space BMP_FILE_SIZE


fname:	.asciz "output.bmp"
tname:  .asciz "input.bin"
	.text
main:
	jal read_bmp
	jal read_turtle
	
	li s3, 0#holds index of current address in turtle commands
	#register s4 holds number of bits inside turtle commands file
	lhu s5, turtle #holds current turte command
	li s7  0 #holds x coordinate of turtle commands
	li s8  0 #holds y coordinate of turtle commands
	li s9  1 #holds pen state for turtle commands. 1-pressed, 0-not presses
	li s2, 0x00000000	#color of pen - 00RRGGBB 
	li s10 0x0000 #holds direction for tutrle commands; 0x0000-right, 0x0100-up, 0x0200-left, 0x0300-down

	
	loop:
		bge s3,s4, loop_exit
		
		la t1, turtle
		add t1, t1, s3
		lhu s5, (t1)
		
		li t1 0x00c0 #value to check upper 2 bits
		and s6, s5, t1
	
		li t1 0x0000
		beq s6, t1, set_position
		
		li t1 0x0040
		beq s6, t1, set_direction
		
		li t1 0x0080
		beq s6, t1, move
		
		li t1 0x00c0
		beq s6, t1, set_pen_state
		
	j loop 
	loop_exit: 

	
	
	
	
	
	
	jal	save_bmp

exit:	li 	a7,10		#Terminate the program
	ecall


# ============================================================================
read_bmp:
#description: 
#	reads the contents of a bmp file into memory
#arguments:
#	none
#return value: none
	addi sp, sp, -4		#push $s1
	sw s1, 0(sp)
#open file
	li a7, 1024
        la a0, fname		#file name 
        li a1, 0		#flags: 0-read file
        ecall
	mv s1, a0      # save the file descriptor
	


#read file
	li a7, 63
	mv a0, s1
	la a1, image
	li a2, BMP_FILE_SIZE
	ecall

#close file
	li a7, 57
	mv a0, s1
        ecall
	
	lw s1, 0(sp)		#restore (pop) s1
	addi sp, sp, 4
	jr ra

# ============================================================================
save_bmp:
#description: 
#	saves bmp file stored in memory to a file
#arguments:
#	none
#return value: none
	addi sp, sp, -4		#push s1
	sw s1, (sp)
#open file
	li a7, 1024
        la a0, fname		#file name 
        li a1, 1		#flags: 1-write file
        ecall
	mv s1, a0      # save the file descriptor
	
#check for errors - if the file was opened
#...

#save file
	li a7, 64
	mv a0, s1
	la a1, image
	li a2, BMP_FILE_SIZE
	ecall

#close file
	li a7, 57
	mv a0, s1
        ecall
	
	lw s1, (sp)		#restore (pop) $s1
	addi sp, sp, 4
	jr ra
	
	
# ============================================================================
put_pixel:
#description: 
#	sets the color of specified pixel
#arguments:
#	a0 - x coordinate
#	a1 - y coordinate - (0,0) - bottom left corner
#	a2 - 0RGB - pixel color
#return value: none

	la t1, image	#adress of file offset to pixel array
	addi t1,t1,10
	lw t2, (t1)		#file offset to pixel array in $t2
	la t1, image		#adress of bitmap
	add t2, t1, t2	#adress of pixel array in $t2
	
	#pixel address calculation
	li t4,BYTES_PER_ROW
	mul t1, a1, t4 #t1= y*BYTES_PER_ROW
	mv t3, a0		
	slli a0, a0, 1
	add t3, t3, a0	#$t3= 3*x
	add t1, t1, t3	#$t1 = 3x + y*BYTES_PER_ROW
	add t2, t2, t1	#pixel address 
	
	#set new color
	sb a2,(t2)		#store B
	srli a2,a2,8
	sb a2,1(t2)		#store G
	srli a2,a2,8
	sb a2,2(t2)		#store R

	jr ra
# ============================================================================
read_turtle:
#description: 
#	reads the contents of a turtle command file and puts it into buffer
#arguments:
#	none
#return value: none
	addi sp, sp, -4		#push $s1
	sw s1, 0(sp)
#open file
	li a7, 1024
        la a0, tname		#file name 
        li a1, 0		#flags: 0-read file
        ecall
	mv s1, a0      # save the file descriptor
	


#read file
	li a7, 63
	mv a0, s1
	la a1, turtle
	li a2, 128
	ecall
	mv s4, a0 #s4 will hold number of bits in turtle commands
	
#close file
	li a7, 57
	mv a0, s1
        ecall
	
	lw s1, 0(sp)		#restore (pop) s1
	addi sp, sp, 4
	jr ra
# ============================================================================
set_position:
#description: 
#	interprets and executes turtle commands written in register s5
#arguments:
#	none
#return value: none
	addi sp, sp, -4		#push $s1
	sw s1, 0(sp)
	
	li s11, 3
	
	addi s3, s3, 2
	la t1, turtle
	add t1, t1, s3
	lhu s5, (t1)
	
	li t1, 0xff03 #Loading x coordinate
	and s7, s5, t1 # loading half words writes bytes in reverse order, so they need to be swapped
	
	#swapping bytes of s7, x-coordinate
	li t1, 0xff00
	and t2, s7, t1
	srli t2, t2, 8
	
	li t1 0x00ff
	and t3, s7, t1
	slli t3, t3, 8
	
	li s7, 0
	or s7, s7, t2
	or s7, s7, t3
	
	#loading y coordinate
	li t1, 0x00fc
	and s8, t1, s5
	srli s8, s8, 2
	
	addi s3, s3, 2
	
	#drawing at position if pen is pressed
	beqz s9, loop
	mv	a0, s7 #x
	mv	a1, s8 #y
	mv	a2, s2
	jal	put_pixel
	

	
	j loop
# ============================================================================
set_direction:
#description: 
#	interprets and executes turtle commands written in register s5
#arguments:
#	none
#return value: none
	addi sp, sp, -4		#push $s1
	sw s1, 0(sp)
	
	
	li t1, 0x0300
	and s10, s5, t1
	
	srli s10, s10, 8
	
	addi s3, s3, 2
	j loop
# ============================================================================
move:
#description: 
#	interprets and executes turtle commands written in register s5
#arguments:
#	none
#return value: none
	addi sp, sp, -4		#push $s1
	sw s1, 0(sp)
	
	li t6, 69
	
	li t1, 0xff03 #last 10 bits of the half-word
	and s11, t1, s5
	
	#swapping bytes of s11-movement direction
	li t1, 0xff00
	and t2, s11, t1
	srli t2, t2, 8
	
	li t1 0x00ff
	and t3, s11, t1
	slli t3, t3, 8
		
	li s11, 0
	or s11, s11, t2
	or s11, s11, t3
	
	
	move_loop:
	blez s11, end_move_loop
		mv t1, s10
		beqz t1, step_right
		addi t1, t1, -1
		beqz t1, step_up
		addi t1, t1, -1
		beqz t1, step_left
		addi t1, t1, -1
		beqz t1, step_down
		
		step_right:
			addi s7, s7, 1
			j end_step
		step_up:
			addi s8, s8, 1
			j end_step
		step_left:
			addi s7, s7, -1
			j end_step
		step_down:
			addi s8, s8, -1
			j end_step
		end_step:
		
		li t1, 600
		bge s7, t1, right_b
		bltz s7, left_b
		li t1, 50
		bge s8, t1, top_b
		bltz s8, bottom_b
		
		#drawing at position if pen is pressed
		beqz s9, move_loop
		mv	a0, s7 #x
		mv	a1, s8 #y
		mv	a2, s2
		jal	put_pixel
		
		addi s11, s11, -1
		j move_loop
	end_move_loop:	
		
	addi s3, s3, 2
	j loop
	
	right_b:
	li s7, 599
	j loop
	left_b:
	li s7, 0
	j loop
	top_b:
	li s8, 49
	j loop
	bottom_b:
	li s8, 0
	j loop
	
# ============================================================================
set_pen_state:
#description: 
#	interprets and executes turtle commands written in register s5
#arguments:
#	none
#return value: none
	addi sp, sp, -4		#push $s1
	sw s1, 0(sp)
	
	
	li t1, 0x0020
	and s9, s5, t1
	srli s9, s9 5
	
	li t1, 0x0f00 #loading color red
	and t1, s5, t1
	slli t1, t1, 12
	or s2, s2, t1
	
	li t1, 0xf000 #loading color green
	and t1, s5, t1
	or s2, s2, t1
	
	li t1, 0x000f
	and t1, s5, t1
	slli t1, t1, 4
	or s2, s2, t1
	


	addi s3, s3, 2
	j loop
# ============================================================================