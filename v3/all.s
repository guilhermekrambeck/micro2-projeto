/*************************** Consts.s ***************************/
.equ MASK_RVALID,               		0x00008000
.equ MASK_DATA,                 		0x000000FF
.equ MASK_WSPACE,               		0xFFFF0000
.equ KEYBOARD,                  		0x10001000
.equ ENTER_ASCII,               		0x0000000A
.equ BACKSPACE_ASCII,           		0x00000008
.equ REDLED_BASEADDRESS,        		0x10000000
.equ INTERVAL_TIMER_BASEADDRESS,    	0x10002000
.equ SWITCH_BASE_ADDRESS,       		0x10000040
.equ STACK,                     		0x00002000
.equ HIGHEST_MEMORY_ADDEESS,        	0x007FFFFC
.equ INTERVAL_TIMER_VALUE,          	0x989680	# 1/(50 MHz) × (0x989680) = 200 msec

.equ SWITCH_ON,							0x00000001
.equ LED_ON_FUNCTION,					00
.equ LED_OFF_FUNCTION,					01
.equ START_LED_ANIMATION_FUNCTION,		10
.equ STOP_LED_ANIMATION_FUNCTION,		11
.equ START_DISPLAY_ANIMATION_FUNCTION,	20
.equ STOP_DISPLAY_ANIMATION_FUNCTION,	21
/*************************  ExceptionHandler.s  *********************************************/

.org 0x20
EXCEPTION_HANDLER:
	subi	sp, sp, 16	            	# make room on the stack
	stw	et, 0(sp)	
	rdctl	et, ctl4	
	beq	et, r0, SKIP_EA_DEC	        	# interrupt is not external
	subi	ea, ea, 4	            	# must decrement ea by one instruction
										# for external interrupts, so that the
										# interrupted instruction will be run after eret
SKIP_EA_DEC:		
	stw	ea, 4(sp)	                	# save all used registers on the Stack
	stw	ra, 8(sp)	                	# needed if call inst is used
	stw	r22, 12(sp)	
	rdctl	et, ctl4					# read the value from ctl
	bne	et, r0, CHECK_LEVEL_0	    	# exception is an external interrupt

NOT_EI:		                        	# exception must be unimplemented instruction or TRAP
	br	END_ISR	                    	# instruction. This code does not handle those cases

CHECK_LEVEL_0:		                	# interval timer is interrupt level 0	
	andi	r22, et, 0b1		
	beq	r22, r0, CHECK_LEVEL_1		
	call	INTERVAL_TIMER_ISR			# call function to handle interval timer exception
	br	END_ISR	

CHECK_LEVEL_1:		                	# pushbutton port is interrupt level 1
	andi	r22, et, 0b10		
	beq	r22, r0, END_ISR	        	# other interrupt levels are not handled in this code
	# call	PUSHBUTTON_ISR		

END_ISR:			
	ldw	et, 0(sp)	                	# restore all used register to previous values	
	ldw	ea, 4(sp)		
	ldw	ra, 8(sp)
	ldw	r22, 12(sp)		
	addi	sp, sp, 16		
eret 

/*************************  IntervalTimerISR.s  *********************************************/
	.text
	.global	INTERVAL_TIMER_ISR
INTERVAL_TIMER_ISR:
	subi sp, sp, 40	                	# reserve space on the stack
	stw	ra, 0(sp)
	stw	r4, 4(sp)
	stw	r5, 8(sp)
	stw	r6, 12(sp)

	movia	r10, INTERVAL_TIMER_BASEADDRESS	   # interval timer base address
	sthio	r0, 0(r10)	            	# clear the interrupt

	movia	r20, REDLED_BASEADDRESS	    # Red Led base address saved on register
	addi	r5, r0, 1	            	# set r5 to the constant value 1
	movia	r22, PATTERN        		# set up a pointer to the pattern for HEX displays

	ldw	r6, 0(r22)	                	# load pattern for red led
	stwio	r6, 0(r20)	            	# store the pattern to red led

	movia   r23, SWITCH_BASE_ADDRESS	# Switch base address saved on register
	ldwio	r4, 0(r23)	                # get the value of first switch

	movia   r18, SWITCH_ON			
	beq	r4, r18, LEFT	            	# for SWITCH_ON, shift right
	rol	r6, r6, r5	                	# else (for SWITCH_OFF), shift left
	br	END_INTERVAL_TIMER_ISR	

LEFT:		
	ror	r6, r6, r5	                	# rotate leds to right

END_INTERVAL_TIMER_ISR:		
	stw	r6, 0(r22)	                	# store display pattern
	ldw	ra, 0(sp)	               		# Restore all used register to previous
	ldw	r4, 4(sp)	
	ldw	r5, 8(sp)	
	ldw	r6, 12(sp)	
	ldw	r10, 20(sp)	
	ldw	r18, 16(sp)	
	ldw	r20, 24(sp)	
	ldw	r21, 28(sp)	
	ldw	r22, 32(sp)	
	ldw	r23, 36(sp)	
	addi	sp, sp, 40	            	# release the reserved space on the stack

ret		

/*************************  LedAnimation.s  *********************************************/
.text
.global START_LED_ANIMATION 
START_LED_ANIMATION:
	# set up stack pointer 
	movia sp, HIGHEST_MEMORY_ADDEESS    # stack starts from highest memory address in SDRAM
	movia r16, INTERVAL_TIMER_BASEADDRESS	# internal timer base address

	# set the interval timer period for scrolling the red leds
	movia r12, INTERVAL_TIMER_VALUE     # Time interval for Red Led Animation
	sthio r12, 8(r16)                   # store the low halfword of counter start value
	srli r12, r12, 16 
	sthio r12, 0xC(r16)                 # high halfword of counter start value
	
	# start interval timer, enable its interrupts
	movi r15, 0b0111                    # START = 1, CONT = 1, ITO = 1 
	sthio r15, 4(r16)

	# enable Nios II processor interrupts
	movi r7, 0b011                      # set interrupt mask bits for levels 0 (interval 
	wrctl ienable, r7                   # timer)
	movi r7, 1 
	wrctl status, r7                    # turn on Nios II interrupt processing

	br PRINTF

.global STOP_LED_ANIMATION 
STOP_LED_ANIMATION:
	movi r7, 0                      	# reset interrupt mask bits for levels 0 (interval
	wrctl ienable, r7                   # timer)
	movi r7, 0
	wrctl status, r7                    # turn on Nios II interrupt processing	
	br 		PRINTF

# The two global variables used by the interrupt service routines for the interval timer and the
#   pushbutton keys are declared below
	.data
	.global PATTERN 
PATTERN:
	.word 0x0000001                     # pattern to show on the Red Leds displays

/*************************  LedPower.s  *********************************************/
.text
.global LED_ON
LED_ON:
	# Get LED number (0x30 is the ASCII base value) in integer value
	# Logic is already explained above
	ldw 	r9, 8(r8)
	subi 	r9, r9, 0x30
	ldw 	r10, 12(r8)
	subi 	r10, r10, 0x30

	slli 	r11, r9, 3
	slli 	r12, r9, 1
	add 	r9, r11, r12
	add 	r9, r9, r10


	addi 	r10, r0, 1
	sll 	r10, r10, r9
	or 		r7, r7, r10

	addi 	r15, r0, 1						# R15 = 1 means the LED needs to be turned ON
	movia   sp, STACK     					# Set stack registers and
	mov 	fp, sp         					# frame pointer.
	
	movia r16, REDLED_BASEADDRESS
	stwio r7, 0(r16)						# turn LED on
	add 	r15, r0, r0						# set R15 to zero

	br 		PRINTF

.global LED_OFF
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

	add 	r15, r0, r0						# R15 = 0 means the LED needs to be turned OFF
	movia sp, STACK     					# Set stack registers and
	mov 	fp, sp         					# frame pointer.
	movia r16, REDLED_BASEADDRESS
	stwio r7, 0(r16)						# turn LED off

	br 		PRINTF

/*************************  Print.s  *********************************************/
.text
.global PRINTF
PRINTF:
	addi  sp, sp, -8          			# make a 8-byte frame

	# Store registers to the frame
	stw   ra, 4(sp)           			# store the return address
	stw   fp, 0(sp)           			# store the frame pointer

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
	beq 	r0, r12, SPACE_LOOP			# While there's no space, wait...

	stwio r10, 0(r8) 					# Print on the terminal (using Data Register)

	addi 	r13, r13, 4					# Next letter
	subi 	r14, r14, 1					# Counter to word size
	bne 	r14, r0, PRINT

	mov 	sp, fp						# sp points to fp
	ldw 	ra, 4(sp)					# loads back ra
	ldw 	fp, 0(sp)					# loads back fp
	addi 	sp, sp, 0					# sp for the empty stack
	ret

/*************************  Main.s  *********************************************/
.text
.global _start
_start:
	movia   sp, STACK 					# Set stack registers and
    mov		fp, sp	      				# frame pointer.
	call 	PRINTF

BEGIN:
	movia   r8, LASTCMD					# After ENTER rewrite these addresses

READ:									# Reading from keyboard using polling technique
	movia   r2, MASK_WSPACE
	movia   r3, MASK_RVALID
	movia   r4, MASK_DATA
	movia   r5, KEYBOARD

	ldwio   r9, 0(r5)					# R9 <- JTAG UART
	and 	r19, r9, r3					# Verify availability [RVALID]
	beq 	r19, r0, READ 				# If not avaiable, wait...

	and 	r19, r9, r4					# Get data from input when RVALID is available


WRITE:									# Writing keyboard's input using polling technique
	ldwio   r6, 4(r5)					# Read control register
	and 	r3, r2, r6					# Verify space availability [WSPACE]
	beq 	r0, r3, WRITE				# While theres no space, wait...

	stwio   r19, 0(r5)					# Print char on the terminal (using Data Register)

	movia   r4, ENTER_ASCII
	beq 	r19, r4, EXECUTE			# If ENTER is hit, execute COMMAND
	movia   r4, BACKSPACE_ASCII
	beq 	r19, r4, ERASE				# If BACKSPACE is hit, erase last char from memory

	stw 	r19, 0(r8)					# Keep command value on memory
	addi 	r8, r8, 4

	br 		READ

ERASE:
	subi 	r8, r8, 4					# Erase char
	br 		READ						# Read input again...

EXECUTE:
	movia   r8, LASTCMD
    ldw 	r9, 0(r8)					# Get the last command (first bit) in r9 (ASCII)
	subi 	r9, r9, 0x30				# Convert from ASCII to integer
	ldw 	r19, 4(r8)					# Get the last command (second bit) in r19 (ASCII)
	subi 	r19, r19, 0x30				# Convert from ASCII to integer

	# Multiply r9 by 10 and add to r19 (making two (integer) bits into a decimal)
	slli 	r11, r9, 3					# Since we are working with DE2 Media computer,
	slli 	r12, r9, 1					# we could use "mul" operations
	add 	r9, r11, r12
	add 	r9, r9, r19					# R9 <- Final value

	# Test which command user entered (simulation of c's switch structure)
	addi 	r10, r0, LED_ON_FUNCTION
	beq 	r9, r10, LED_ON

	addi 	r10, r0, LED_OFF_FUNCTION
	beq 	r9, r10, LED_OFF

	addi 	r10, r0, START_LED_ANIMATION_FUNCTION
	beq 	r9, r10, START_LED_ANIMATION

	addi 	r10, r0, STOP_LED_ANIMATION_FUNCTION
	beq 	r9, r10, STOP_LED_ANIMATION

/*
	addi 	r10, r0, START_DISPLAY_ANIMATION_FUNCTION
	beq 	r9, r10, START_DISPLAY_ANIMATION

	addi 	r10, r0, STOP_DISPLAY_ANIMATION_FUNCTION
	beq 	r9, r10, STOP_DISPLAY_ANIMATION
*/
	
	br 		BEGIN

MSG_SIZE:
.word 21

MSG:
.word 'E', 'N', 'T', 'R', 'E', ' ', 'C', 'O', 'M', ' ', 'O', ' ', 'C', 'O', 'M', 'A', 'N', 'D', 'O', ':', 0xA

# Space to store last command
LASTCMD:
.skip 0x100