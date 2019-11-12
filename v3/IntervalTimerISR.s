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