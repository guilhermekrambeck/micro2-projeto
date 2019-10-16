.include "constants.s"	

.global LED_ON
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