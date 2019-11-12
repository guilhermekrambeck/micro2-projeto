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