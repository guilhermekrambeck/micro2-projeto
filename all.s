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
.equ PUSHBUTTON_BASE_ADDRESS,	  0x10000050
.equ ADRESS_LCD, 				        0x10003050
.equ ADRESS_DATA, 				      0x10003051
.equ SET_FIRST_LINE, 			      0b10000000
.equ SET_SECOND_LINE, 			    0b11000000
.equ CLEAR_DISPLAY, 			      0x1

/********************** MEMORY STORAGE **********************/
.equ STACK,                     0x00002000

.org 0x20
/*********************************************************/
/**********************INTERRUP***************************/
/*********************************************************/

/* Exception Handler */
	rdctl et, ipending
	beq 	et, r0, OTHER_EXCEPTIONS

HARDWARE_EXCEPTION:										# Standardized code

	subi 	ea, ea, 4

	andi 	r13, et, 0b10
	bne 	r13, r0, HANDLE_BUTTON
	andi 	r13, et, 0b1 									# interval timer is interrupt level 0
	beq 	r13, r0, END_HANDLER

	movia r14, TIMER_BASEADRESS
	sthio r0, 0(r14) 										# clear Time Out ( clear the interrupt )

	addi 	r14, r0, 2										# R14 = 2
	bge 	r15, r14, DISPLAY

/********************** LED FLASH **********************/
	movia r16, REDLED_BASEADDRESS
	beq		r15, r0, OFF									# If R15 == 0, turn LEDs off

	ON:
		stwio r7, 0(r16)									# turn LED on
		add 	r15, r0, r0									# set R15 to zero
 		br 		END_HANDLER

	OFF:
		stwio r0, 0(r16)									# turn LED off
		addi 	r15, r0, 1									# set R15 to 1
		br 		END_HANDLER

/********************* DISPLAY ROTATE *****************/
	DISPLAY:
		movia r16, MSG_DISPLAY1
		movia r14, DISPLAY_BASE_ADDRESS1
		ldw 	r17, 0(r16)									# Load the array value on r17
		stwio r17, 0(r14)									# Set Display value

		movia r16, MSG_DISPLAY2
		movia r14, DISPLAY_BASE_ADDRESS2
		ldw 	r18, 0(r16)									# Load the array value on r18
		stwio r18, 0(r14)									# Set Display value

		addi 	r19, r0, 2									# R19 = 2
		beq 	r15, r19, SHIFTR						# If R15 == 2, shift right
		addi 	r19, r0, 4									# R19 = 4
		beq 	r15, r19, SHIFTL						# If R15 == 4, shift left
		br 		END_HANDLER

# ROTATION: changes the first letter of a message to the last of the other message
#r17 has first message: "  oi"
#r18 has second message: "2016"

	SHIFTL:
		# Message 2
		srli 	r19, r17, 24								# shifts 24 bits to the right to place message in the least significant part of the register
		slli 	r20, r18, 8									# 8-bit-space in the other message
		or 		r20, r20, r19								# OR in both shifted messages
		stw 	r20, 0(r16)

		# Message 1
		movia r16, MSG_DISPLAY1
		# Does the same as explained above, but for the other message.
		srli 	r19, r18, 24
		slli 	r20, r17, 8
		or 		r20, r20, r19
		stw 	r20, 0(r16)

		br 		END_HANDLER

	SHIFTR:
		#	Now, shifting to the right, not left...
		# Follows the same logic explained in SHIFTL, but instead of srli and slli we have slli and srli
		# Message 2
		andi 	r19, r17, 0xFF
		slli 	r19, r19, 24
		srli 	r20, r18, 8
		or 		r20, r20, r19
		stw 	r20, 0(r16)

		# Message 1
		movia r16, MSG_DISPLAY1
		andi 	r19, r18, 0xFF
		slli 	r19, r19, 24
		srli 	r20, r17, 8
		or 		r20, r20, r19
		stw 	r20, 0(r16)

		br 		END_HANDLER

/**************** HANDLE PUSHBUTTON PRESS ***************/
	HANDLE_BUTTON:
		addi 	r12, r0, 2
		blt 	r15, r12, CLEAR_BTN

		movia r12, PUSHBUTTON_BASE_ADDRESS
		ldwio r13, 12(r12)								# Word to buttons flags
		andi 	r13, r13, 0x06

		movi 	r14, 0x2
		beq 	r13, r14, INVERT_ROTATION
		movi 	r14, 0x4
		beq 	r13, r14, PAUSE_ROTATION
		br 		CLEAR_BTN

	INVERT_ROTATION:
		addi 	r19, r0, 2									# R19 = 2
		beq 	r15, r19, INVERT_L					# If R15 == 2, shift left (not right)
		addi 	r19, r0, 4									# R19 = 4
		beq 	r15, r19, INVERT_R					# If R15 == 4, shift right (not left)
		br 		CLEAR_BTN

		INVERT_L:
			addi 	r15, r0, 4								# R15 = 4
			br 		CLEAR_BTN									# clear push button

		INVERT_R:
			addi 	r15, r0, 2								# R15 = 4
			br 		CLEAR_BTN									# clear push button

	PAUSE_ROTATION:
			addi 	r19, r0, 3								# R19 = 3 (1 more then right rotation)
			beq 	r15, r19, RESUME_ROTATION
			addi 	r19, r0, 5								# R19 = 5 (1 more then left rotation)
			beq 	r15, r19, RESUME_ROTATION

			addi 	r15, r15, 1								# R15 ++ when not to resume rotation
			br 		CLEAR_BTN

			RESUME_ROTATION:
				subi 	r15, r15, 1							# R15 = R15 - 1
				br 		CLEAR_BTN

	CLEAR_BTN:
		movia r12, PUSHBUTTON_BASE_ADDRESS
		stwio r0, 12(r12)									# Set interruption to button
		br 		END_HANDLER

OTHER_EXCEPTIONS:
END_HANDLER:
	eret

.global SET_INTERRUPTION
SET_INTERRUPTION:

/*********************************************************/
/**********************PROLOGUE***************************/
/*********************************************************/

# Adjust the stack pointer
  addi  sp, sp, -8                		# make a 8-byte frame

# Store registers to the frame
  stw   ra, 4(sp)                 		# store the return address
  stw   fp, 0(sp)                 		# store the frame pointer

# Set the new frame pointer
  addi  fp, sp, 0

/**********************SET INTERRUPTION*******************/
	movia r9,  MASK_CPU_INTERRUP
	movia r12, TIMER_BASEADRESS
	movia r13, TIME_COUNTERH
	movia r17, TIME_COUNTERL
	movia r14, MASK_START

	addi 	r16, r0, 2										# R16 = 2
	bne 	r15, r16, SKIP_DISPLAY_TIMER	# if 15 != 2, skip timer
	movia r13, TIME_COUNTERH_ROTATE
	movia r17, TIME_COUNTERL_ROTATE

	SKIP_DISPLAY_TIMER:

	######****** Start interval timer, enable its interrupts ******######
	sthio r17, 8(r12)  									# Set to low value
	sthio r13, 12(r12)  								# Set to high Value
	sthio r14, 4(r12)										# Set, START, CONT, E ITO = 1

	movia r12, PUSHBUTTON_BASE_ADDRESS
	movi 	r14, 0x06											# Mask to set button
	stwio r14, 8(r12)										# Set interruption to button

	######******enable Nios II processor interrupts******######
	wrctl ienable, r9 		  						# Set IRQ bit 0
	movi 	r9, 0x1
	wrctl status, r9 		  							# turn on Nios II interrupt processing ( SET PIE = 1 )

/********************************************************/
/*********************EPILOGUE***************************/
/********************************************************/

# Restore ra, fp, sp, and registers
	mov 	sp, fp												# sp points to fp
	ldw 	ra, 4(sp)											# loads back ra
	ldw 	fp, 0(sp)											# loads back fp
	addi 	sp, sp, 0											# sp for the empty stack
	ret

MSG_DISPLAY1:
.byte 0b00010000, 0b00111111, 0b00000000, 0b00000000 #iO

.skip 1000

MSG_DISPLAY2:
.byte 0b01111101, 0b00000110, 0b00111111, 0b01011011 #6102

.global PRINTF
PRINTF:

/*********************************************************/
/**********************PROLOGUE***************************/
/*********************************************************/

# Adjust the stack pointer
  addi  sp, sp, -8          # make a 8-byte frame

# Store registers to the frame
  stw   ra, 4(sp)           # store the return address
  stw   fp, 0(sp)           # store the frame pointer

# Set the new frame pointer
  addi  fp, sp, 0

/**********************PRINT******************************/

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

/*********************************************************/
/**********************EPILOGUE***************************/
/*********************************************************/

# Restore ra, fp, sp, and registers
	mov 	sp, fp							# sp points to fp
	ldw 	ra, 4(sp)						# loads back ra
	ldw 	fp, 0(sp)						# loads back fp
	addi 	sp, sp, 0						# sp for the empty stack
	ret

MSG_SIZE:
.word 21
MSG:
.word 'E', 'N', 'T', 'R', 'E', ' ', 'C', 'O', 'M', ' ', 'O', ' ', 'C', 'O', 'M', 'A', 'N', 'D', 'O', ':', 0xA

.include "consts.s"
.global _start
_start:

/********************** PRINT **********************/

	movia sp, STACK 									# Set stack registers and
  mov		fp, sp	      							# frame pointer.
	call 	PRINTF

BEGIN:
	movia r8, LASTCMD									# After ENTER rewrite these addresses

READ:																# Reading from keyboard using polling technique
	movia r2, MASK_WSPACE
	movia r3, MASK_RVALID
	movia r4, MASK_DATA
	movia r5, KEYBOARD

	ldwio r9, 0(r5)										# R9 <- JTAG UART
	and 	r10, r9, r3									# Verify availability [RVALID]
	beq 	r10, r0, READ 							# If not avaiable, wait...

	and 	r10, r9, r4									# Get data from input when RVALID is available

WRITE:															# Writing keyboard's input using polling technique
	ldwio r6, 4(r5)										# Read control register
	and 	r3, r2, r6									# Verify space availability [WSPACE]
	beq 	r0, r3, WRITE								# While theres no space, wait...

	stwio r10, 0(r5)									# Print char on the terminal (using Data Register)

	movia r4, ENTER_ASCII
	beq 	r10, r4, EXECUTE						# If ENTER is hit, execute COMMAND
	movia r4, BACKSPACE_ASCII
	beq 	r10, r4, ERASE							# If BACKSPACE is hit, erase last char from memory

	stw 	r10, 0(r8)									# Keep command value on memory
	addi 	r8, r8, 4

	br 		READ

ERASE:
	subi 	r8, r8, 4										# Erase char
	br 		READ												# Read input again...

/* ASCII <--> INT
Convert X (int) to ‘X’...
X = X + 48 (0x30)
Convert 'X' to X(int)...
X = X - 48 (0x30)
*/

EXECUTE:
	movia r8, LASTCMD
	ldw 	r9, 0(r8)										# Get the last command (first bit) in r9 (ASCII)
	subi 	r9, r9, 0x30								# Convert from ASCII to integer
	ldw 	r10, 4(r8)									# Get the last command (second bit) in r10 (ASCII)
	subi 	r10, r10, 0x30							# Convert from ASCII to integer

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
	addi 	r10, r0, 10
	beq 	r9, r10, TRIANG_NUM
	addi 	r10, r0, 20
	beq 	r9, r10, DISPLAY_MSG
	addi 	r10, r0, 21
	beq 	r9, r10, CANCEL_ROT
	addi 	r10, r0, 30
	beq 	r9, r10, POW_OF_TWO

	br 		BEGIN

/********************** FUNCTIONS **********************/

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
	movia sp, STACK     							# Set stack registers and
	mov 	fp, sp         							# frame pointer.
	call 	SET_INTERRUPTION						#	Call Function to set INTERRUPTION

	br 		BEGIN

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

	add 	r15, r0, r0								# R15 = 0 means the LED needs to be turned OFF
	movia sp, STACK     							# Set stack registers and
	mov 	fp, sp         							# frame pointer.
	call 	SET_INTERRUPTION						#	Call Function to set INTERRUPTION

	br 		BEGIN

TRIANG_NUM:
	movia r4, DISPLAY_BASE_ADDRESS1
	stwio r0, 0(r4)										# Clear display
	movia r4, DISPLAY_BASE_ADDRESS2
	stwio r0, 0(r4)										# Clear display

	movia r10, SWITCH_BASE_ADDRESS
	movia r11, MAP

# Calculating Triangular Number...
	ldwio r6, 0(r10)									# Read SWITCH number on r6
	addi 	r5, r6, 1										# R5 = R6 + 1
	mul 	r6, r6, r5									# R6 = R6 * R5 [n * (n+1)]
	srli 	r6, r6, 1										# R6 = R6 / 2

	add 	r5, r0, r0									# R5 = 0
	add 	r12, r0, r0									# R12 = 0
	addi 	r10, r0, 10									# R10 = 10

	LOOP:
		div 	r8, r6, r10								# R8 = R6 / R10
		mul 	r9, r8, r10								# R9 = R8 * R10
		sub 	r9, r6, r9								# R9 = R6 - R9
    add 	r6, r8, r0								# R6 = R8

		add 	r2, r11, r9			 					# Add base address to map
		ldb 	r2, 0(r2)									# Load the array value on R2

		sll 	r2, r2, r5								# Shift to save value at the right position

		addi 	r5, r5, 8									# Increment to the next display (number of shift)
		or 		r12, r12, r2							# This OR is used to preserve previous value

		stwio r12, 0(r4)								# Set Display value

		bne 	r6, r0, LOOP 							# Compare R6 to 0, if R6 == 0, the number is over

	br 		BEGIN

DISPLAY_MSG:
	addi 	r15, r0, 2									# R15 = 2 means the MESSAGE DISPLAYED is going to rotate to the LEFT
	movia sp, STACK     							# Set stack registers and
	mov 	fp, sp         							# frame pointer
	call 	SET_INTERRUPTION						# Call Function to set INTERRUPTION

	br 		BEGIN

CANCEL_ROT:
	addi 	r9, r0, 2
	blt 	r15, r9, BEGIN							# Only cancel if rotating

	add 	r9, r0, r0
	wrctl status, r9 		  						# turn off Nios II interrupt processing ( SET PIE = 0 )

	br 		BEGIN

POW_OF_TWO:

	# Get number (0x30 is the ASCII base value)
	ldw 	r9, 8(r8)										# get first bit
	subi 	r9, r9, 0x30								# convert from ASCII to INT

	ldw 	r6, 12(r8)									# get second bit
	subi 	r6, r6, 0x30								# convert from ASCII to INT

	ldw 	r5, 16(r8)									# get third bit
	subi 	r5, r5, 0x30								# convert from ASCII to INT

	# Getting right decimal value...

	/*
	bit 1 | bit 2 | bit 3
	RIGHT VALUE = (bit 1 * 100) + (bit 2 * 10) + bit 3
	*/

	addi 	r10, r0,0x64 								# Multiply to 100
	mul 	r9, r9, r10

	addi 	r10, r0,0xA 								# Multiply to  10
	mul  	r6, r6, r10

	add 	r4, r9, r6   								# (bit 1 * 100) + (bit 2 * 10)
	add 	r4, r4, r5   								# + bit 3

	movia sp, STACK     							# Set stack registers and
	mov 	fp, sp         							# frame pointer
	call 	POW_TWO											# Call thefunction

	movia r5, ADRESS_LCD
	movia r6, ADRESS_DATA
	movia r3, SET_FIRST_LINE
	movia r9, CLEAR_DISPLAY
	addi  r10, r0, 0xD								# 14 positions for the N_POW message (first line)

	stbio r9, 0(r5)     							# Clear the display
	stbio r3, 0(r5)	    							# Set cursor 0 Location

	addi 	r11, r0, -1									# Start the counter
	bne 	r2, r0, POW_DISPLAY 				# if is pow

	N_POW_LOOP:
		addi 	r11, r11, 0x1
		movia r8, N_POW									# R8 gets adress N_POW
		add 	r8, r8, r11
		ldbio r8, 0(r8)   							# R8 gets the right position
		stbio r8, 0(r6)     						# Write P in display
	bne 	r11, r10, N_POW_LOOP				# If not equal 14 positions for the message, continue writing in display

   	movia r3, SET_SECOND_LINE  			# MASK to set second line
   	stbio r3, 0(r5)	    						# Set cursor second line
   	addi  r10, r0, 0x12							# 4 positions for the rest of the message (N_POW message (second line))

   	addi 	r11, r11, 0x1
 	N_POW_LOOP2:
 		movia r8, N_POW									# R8 gets adress N_POW
 		add 	r8, r8, r11
 		ldbio r8, 0(r8)   							# R8 gets the right position
		stbio r8, 0(r6)    							# Write P in display
		addi 	r11, r11, 0x1
	bne 	r11, r10, N_POW_LOOP2				# If not equal 14 positions for the message, continue writing in display

	br BEGIN

POW_DISPLAY:

	movia r8, POW
	addi  r10, r0, 0xE								# 15 positions for the POW message
	POW_LOOP:
		addi 	r11, r11, 0x1
		movia r8, POW										# R8 gets adress N_POW
		add 	r8, r8, r11
		ldbio r8, 0(r8)   							# R8 gets the right position
		stbio r8, 0(r6)     						# Write P in display
	bne 	r11, r10, POW_LOOP					# If not equal 14 positions for the message, continue writing in display

	br 		BEGIN

/* Numbers for 7-segments display */
MAP:
.byte 0b00111111,0b110,0b1011011,0b1001111,0b1100110,0b1101101,0b1111101,0b111,0b1111111,0b1100111

.skip 0x100

/* Space to store last command */
LASTCMD:

.skip 0x100

/* Message for extra command */
POW:
.ascii "E potencia de 2"
N_POW:
.ascii "Nao e potenciade 2"

.global POW_TWO
POW_TWO:

/*********************************************************/
/**********************PROLOGUE***************************/
/*********************************************************/

# Adjust the stack pointer
  addi  sp, sp, -8                # make a 8-byte frame

# Store registers to the frame
  stw   ra, 4(sp)                 # store the return address
  stw   fp, 0(sp)                 # store the frame pointer

# Set the new frame pointer
  addi  fp, sp, 0

/**********************POW_TWO**********************/

addi  r3, r0, 0x1                 # r3 <-  1
addi  r5, r0, 0x20                # r5 Controls amount of shifts (32 shifts is the max)
add   r8, r0, r0                  # r8 is  acumulator (start with 0)

LOOP:
  andi  r6, r4, 0x1
  bne   r6, r3, NAO_INCREMENTA    # If (r4 AND 0x1) == 0,  doesn't inc r8
  addi  r8, r8, 0x1               # Increments
  bgt   r8, r3, END_LOOP
NAO_INCREMENTA:
  srli  r4, r4, 0x1               # shift right 1
  subi  r5, r5, 0x1               # DEC 1 from control register
  beq   r5, r0, END_LOOP
  br    LOOP                      # Checks the next bit (shift)
END_LOOP:

beq   r8, r3, POW                 # If r8 has only one 1, the input is power of 2
addi  r2, r0, 0x0
br    END1

POW:
	addi  r2,r0, 0x1

END1:

/********************************************************/
/*********************EPILOGUE***************************/
/********************************************************/

# Restore ra, fp, sp, and registers
	mov 	sp, fp							      # sp points to fp
	ldw 	ra, 4(sp)						      # loads back ra
	ldw 	fp, 0(sp)						      # loads back fp
	addi 	sp, sp, 0						      # sp for the empty stack
	ret