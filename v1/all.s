/*************************** CONSTS ***************************/
.equ MASK_RVALID,               0x00008000
.equ MASK_DATA,                 0x000000FF
.equ MASK_WSPACE,               0xFFFF0000
.equ MASK_CPU_INTERRUP,         0x03
.equ MASK_START,                0x7

.equ KEYBOARD,                  0x10001000
.equ ENTER_ASCII,               0x0000000A
.equ BACKSPACE_ASCII,           0x00000008
.equ TIMER_BASEADRESS,          0x10002000
.equ TIME_COUNTERH,             0x017d 				# 25 MILION HIGH
.equ TIME_COUNTERL,             0x7840  			# 25 MILION LOW
.equ TIME_COUNTERH_ROTATE,      0x0098 				# 10 MILION HIGH
.equ TIME_COUNTERL_ROTATE,      0x9680  			# 10 MILION LOW
.equ REDLED_BASEADDRESS,        0x10000000
.equ SWITCH_BASE_ADDRESS,       0x10000040
.equ DISPLAY_BASE_ADDRESS1,     0x10000030
.equ DISPLAY_BASE_ADDRESS2,     0x10000020
.equ PUSHBUTTON_BASE_ADDRESS,	0x10000050
.equ ADRESS_LCD, 				0x10003050
.equ ADRESS_DATA, 				0x10003051
.equ SET_FIRST_LINE, 			0b10000000
.equ SET_SECOND_LINE, 			0b11000000
.equ CLEAR_DISPLAY, 			0x1

/********************** MEMORY STORAGE **********************/
.equ STACK,                     0x00002000

PRINTF:
  addi  sp, sp, -8          # make a 8-byte frame

# Store registers to the frame
  stw   ra, 4(sp)           # store the return address
  stw   fp, 0(sp)           # store the frame pointer

# Set the new frame pointer
  addi  fp, sp, 0

    movia r8, KEYBOARD
    movia r9, MASK_WSPACE
    movia r13, MSG
    movia r14, MSG_SIZE

    ldw 	r14, 0(r14)					# Get Message Size

PRINT:
	ldw 	r10, 0(r13)	 				# Load letter from memory

SPACE_LOOP:

	ldwio r11, 4(r8) 					# Read control register
	and 	r12, r9, r11	 			# Verify space availability [WSPACE]
	beq 	r0, r12, SPACE_LOOP	# While there's no space, wait...

	stwio r10, 0(r8) 					# Print on the terminal (using Data Register)

	addi 	r13, r13, 4					# Next letter
	subi 	r14, r14, 1					# Counter to word size
	bne 	r14, r0, PRINT

	mov 	sp, fp							# sp points to fp
	ldw 	ra, 4(sp)						# loads back ra
	ldw 	fp, 0(sp)						# loads back fp
	addi 	sp, sp, 0						# sp for the empty stack
	ret

.global _start
_start:

/********************** PRINT **********************/

	movia   sp, STACK 									# Set stack registers and
    mov		fp, sp	      							    # frame pointer.
	call 	PRINTF

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

	br 		BEGIN

LED_ON:
	# Get LED number (0x30 is the ASCII base value) in integer value
	# Logic is already explained above
	ldw 	r9, 8(r8)
	subi 	r9, r9, 0x30
	ldw 	r10, 12(r8)
	subi 	r10, r10, 0x30

	# Multiply R9 by 10 and add to R10 (making two (integer) bits into a decimal)
	# Logic is already explained above
	slli 	r11, r9, 3
	slli 	r12, r9, 1
	add 	r9, r11, r12
	add 	r9, r9, r10

	# Set bit to turn ON the LED
	addi 	r10, r0, 1
	sll 	r10, r10, r9
	or 		r7, r7, r10

	addi 	r15, r0, 1									# R15 = 1 means the LED needs to be turned ON
	movia   sp, STACK     							    # Set stack registers and
	mov 	fp, sp         							    # frame pointer.
	# call 	SET_INTERRUPTION						    #	Call Function to set INTERRUPTION
	movia r16, REDLED_BASEADDRESS
	stwio r7, 0(r16)									# turn LED on
	add 	r15, r0, r0									# set R15 to zero

	# br 		BEGIN
	br 		PRINTF

LED_OFF:
	# Get LED number (0x30 is the ASCII base value) in integer value
	# Logic is already explained above
	ldw 	r9, 8(r8)
	subi 	r9, r9, 0x30
	ldw 	r10, 12(r8)
	subi 	r10, r10, 0x30

	# Multiply R9 by 10 and add to R10 (making two (integer) bits into a decimal)
	# Logic is already explained above
	slli 	r11, r9, 3
	slli 	r12, r9, 1
	add 	r9, r11, r12
	add 	r9, r9, r10

	# Unset bit to turn OFF the LED
	addi 	r10, r0, 1
	sll 	r10, r10, r9
	nor 	r10, r10, r10
	and 	r7, r7, r10

	add 	r15, r0, r0								    # R15 = 0 means the LED needs to be turned OFF
	movia sp, STACK     							    #  Set stack registers and
	mov 	fp, sp         							    # frame pointer.
	# call 	SET_INTERRUPTION						    #	Call Function to set INTERRUPTION
	movia r16, REDLED_BASEADDRESS
	stwio r7, 0(r16)									# turn LED off
	# br 		BEGIN
	br 		PRINTF

MSG_SIZE:
.word 21
MSG:
.word 'E', 'N', 'T', 'R', 'E', ' ', 'C', 'O', 'M', ' ', 'O', ' ', 'C', 'O', 'M', 'A', 'N', 'D', 'O', ':', 0xA

/* Numbers for 7-segments display */
MAP:
.byte 0b00111111,0b110,0b1011011,0b1001111,0b1100110,0b1101101,0b1111101,0b111,0b1111111,0b1100111

.skip 0x100

/* Space to store last command */
LASTCMD:
.skip 0x100
