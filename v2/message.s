.include "constants.s"


.global PRINTF
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

MSG_SIZE:
.word 21
MSG:
.word 'E', 'N', 'T', 'R', 'E', ' ', 'C', 'O', 'M', ' ', 'O', ' ', 'C', 'O', 'M', 'A', 'N', 'D', 'O', ':', 0xA