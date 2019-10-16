.include "constants.s"

.global _start
_start:

	movia   sp, STACK 									# Set stack registers and
    mov		fp, sp	      							    # frame pointer.
	call 	PRINTF										# Print ENTRE COM O COMANDO

BEGIN:
	movia   r8, LASTCMD									# After ENTER rewrite these addresses

READ:													# Reading from keyboard using polling technique
	movia   r2, MASK_WSPACE
	movia   r3, MASK_RVALID
	movia   r4, MASK_DATA
	movia   r5, KEYBOARD

	ldwio   r9, 0(r5)									# R9 <- JTAG UART
	and 	r10, r9, r3									# Verify availability [RVALID]
	beq 	r10, r0, READ 							    # If not avaiable, wait...

	and 	r10, r9, r4									# Get data from input when RVALID is available

WRITE:													# Writing keyboard's input using polling technique
	ldwio   r6, 4(r5)									# Read control register
	and 	r3, r2, r6									# Verify space availability [WSPACE]
	beq 	r0, r3, WRITE								# While theres no space, wait...

	stwio   r10, 0(r5)									# Print char on the terminal (using Data Register)

	movia   r4, ENTER_ASCII
	beq 	r10, r4, EXECUTE						    # If ENTER is hit, execute COMMAND
	movia   r4, BACKSPACE_ASCII
	beq 	r10, r4, ERASE							    # If BACKSPACE is hit, erase last char from memory

	stw 	r10, 0(r8)									# Keep command value on memory
	addi 	r8, r8, 4

	br 		READ

ERASE:
	subi 	r8, r8, 4									# Erase char
	br 		READ										# Read input again...

EXECUTE:
	movia   r8, LASTCMD
    ldw 	r9, 0(r8)									# Get the last command (first bit) in r9 (ASCII)
	subi 	r9, r9, 0x30								# Convert from ASCII to integer
	ldw 	r10, 4(r8)									# Get the last command (second bit) in r10 (ASCII)
	subi 	r10, r10, 0x30							    # Convert from ASCII to integer

	# Multiply r9 by 10 and add to r10 (making two (integer) bits into a decimal)
	slli 	r11, r9, 3									# Since we are working with DE2 Media computer,
	slli 	r12, r9, 1									# we could use "mul" operations
	add 	r9, r11, r12
	add 	r9, r9, r10									# R9 <- Final value

	# Test which command user entered (simulation of c's switch structure)
	addi 	r10, r0, 00
	beq 	r9, r10, LED_ON
	addi 	r10, r0, 01
	beq 	r9, r10, LED_OFF
	addi	r10, r0, 10
	beq	r9, r10, START_LED_ANIMATION
	#addi	r10, r0, 11
	#beq 	r9, r10, STOP_LED_ANIMATION
	#addi	r10, r0, 20
	#beq	r9, r10, START_DISPLAY_TIMER
	#addi	r10, r0, 21
	#beq	r9, r10, STOP_DISPLAY_TIMER

	br 		BEGIN

START_LED_ANIMATION:
	addi r15, r0, 2
	movia sp, STACK
	mov fp, sp
	call SET_INTERRUPTION

	br BEGIN

/* Numbers for 7-segments display */
MAP:
.byte 0b00111111,0b110,0b1011011,0b1001111,0b1100110,0b1101101,0b1111101,0b111,0b1111111,0b1100111

.skip 0x100

/* Space to store last command */
LASTCMD:
.skip 0x100