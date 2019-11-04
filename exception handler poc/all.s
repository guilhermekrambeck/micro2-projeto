        .equ KEY1, 0
        .equ KEY2, 1
        .equ REDLED_BASEADDRESS,        0x10000000
        .equ STACK,                     0x00002000

            .org 0x20
        EXCEPTION_HANDLER:
            subi	sp, sp, 16	            /* make room on the stack */
            stw	et, 0(sp)	
            rdctl	et, ctl4	
            beq	et, r0, SKIP_EA_DEC	        /* interrupt is not external */
            subi	ea, ea, 4	            /* must decrement ea by one instruction */
                                            /* for external interrupts, so that the */
                                            /* interrupted instruction will be run after eret */
        SKIP_EA_DEC:		
            stw	ea, 4(sp)	                /* save all used registers on the Stack */
            stw	ra, 8(sp)	                /* needed if call inst is used */
            stw	r22, 12(sp)	
            rdctl	et, ctl4	
            bne	et, r0, CHECK_LEVEL_0	    /* exception is an external interrupt */

        NOT_EI:		                        /* exception must be unimplemented instruction or TRAP */
            br	END_ISR	                    /* instruction. This code does not handle those cases */

        CHECK_LEVEL_0:		                /* interval timer is interrupt level 0 */	
            andi	r22, et, 0b1		
            beq	r22, r0, CHECK_LEVEL_1		
            call	INTERVAL_TIMER_ISR		
            br	END_ISR	

        CHECK_LEVEL_1:		                /* pushbutton port is interrupt level 1 */	
            andi	r22, et, 0b10		
            beq	r22, r0, END_ISR	        /* other interrupt levels are not handled in this code */	
            call	PUSHBUTTON_ISR		

        END_ISR:			
            ldw	et, 0(sp)	                /* restore all used register to previous values */	
            ldw	ea, 4(sp)		
            ldw	ra, 8(sp)	                /* needed if call inst is used */	
            ldw	r22, 12(sp)		
            addi	sp, sp, 16		
        eret 

            .global	INTERVAL_TIMER_ISR
        INTERVAL_TIMER_ISR:
            subi sp, sp, 40	                /* reserve space on the stack */
            stw	ra, 0(sp)
            stw	r4, 4(sp)
            stw	r5, 8(sp)
            stw	r6, 12(sp)

            movia	r10, 0x10002000	        /* interval timer base address */
            sthio	r0, 0(r10)	            /* clear the interrupt */

            movia	r20, REDLED_BASEADDRESS	        /* HEX3_HEX0 base address */
            movia	r21, REDLED_BASEADDRESS	        /* HEX7_HEX4 base address */
            addi	r5, r0, 1	            /* set r5 to the constant value 1 */
            movia	r22, PATTERN        	/* set up a pointer to the pattern for HEX displays */
            movia	r23, KEY_PRESSED	    /* set up a pointer to the key pressed */

            ldw	r6, 0(r22)	                /* load pattern for HEX displays */
            stwio	r6, 0(r20)	            /* store to HEX3 ... HEX0 */


            movia   r23, 0x10000040
            ldwio	r4, 0(r23)	                /* check which key has been pressed */
            movia   r8, 0x00018000

            beq	r4, r8, LEFT	            /* for KEY1 pressed, shift right */
            rol	r6, r6, r5	                /* else (for KEY2) pressed, shift left */
            br	END_INTERVAL_TIMER_ISR	


        LEFT:		
            ror	r6, r6, r5	                /* rotate the displayed pattern right */

        END_INTERVAL_TIMER_ISR:		
            stw	r6, 0(r22)	                /* store HEX display pattern */
            ldw	ra, 0(sp)	                /* Restore all used register to previous */
            ldw	r4, 4(sp)	
            ldw	r5, 8(sp)	
            ldw	r6, 12(sp)	
            ldw	r8, 16(sp)	
            ldw	r10, 20(sp)	
            ldw	r20, 24(sp)	
            ldw	r21, 28(sp)	
            ldw	r22, 32(sp)	
            ldw	r23, 36(sp)	
            addi	sp, sp, 40	            /* release the reserved space on the stack */

        ret		

            .text                               /* executable code follows */
            .global _start 
        _start:
            /* set up stack pointer */ 
            movia sp, 0x007FFFFC                /* stack starts from highest memory address in SDRAM */
            movia r16, 0x10002000               /* internal timer base address */

            /* set the interval timer period for scrolling the HEX displays */
            movia r12, 0x989680                  /* 1/(50 MHz) × (0x989680) = 200 msec */
            sthio r12, 8(r16)                   /* store the low halfword of counter start value */
            srli r12, r12, 16 
            sthio r12, 0xC(r16)                 /* high halfword of counter start value */
            
            /* start interval timer, enable its interrupts */
            movi r15, 0b0111                    /* START = 1, CONT = 1, ITO = 1 */ 
            sthio r15, 4(r16)

            /* write to the pushbutton port interrupt mask register */
            movia r15, 0x10000040               /* switch base address */
            movi r7, 0b01110                    /* set 3 interrupt mask bits (bit 0 is Nios II reset) */ 
            stwio r7, 8(r15)                    /* interrupt mask register is (base + 8) */

            /* enable Nios II processor interrupts */
            movi r7, 0b011                      /* set interrupt mask bits for levels 0 (interval */ 
            wrctl ienable, r7                   /* timer) and level 1 (pushbuttons) */
            movi r7, 1 
            wrctl status, r7                    /* turn on Nios II interrupt processing */

        IDLE:
            br IDLE                             /* main program simply idles */

        /* The two global variables used by the interrupt service routines for the interval timer and the
        * pushbutton keys are declared below */
            .data
            .global PATTERN 
        PATTERN:
            .word 0x0000001                    /* pattern to show on the HEX displays */

            .global KEY_PRESSED 
        KEY_PRESSED:
            .word KEY2                          /* stores code representing pushbutton key pressed */


            .global PUSHBUTTON_ISR 
        PUSHBUTTON_ISR:
            subi	sp, sp, 20	            /* reserve space on the stack */
            stw	ra, 0(sp)	
            stw	r10, 4(sp)	
            stw	r11, 8(sp)	
            stw	r12, 12(sp)	
            stw	r13, 16(sp)	
            movia	r10, 0x10000040	        /* base address of pushbutton KEY parallel port */
            ldwio	r11, 0xC(r10)	        /* read edge capture register */
            stwio	r0, 0xC(r10)	        /* clear the interrupt */
            movia	r10, KEY_PRESSED	    /* global variable to return the result */

        CHECK_KEY1:		
            andi	r13, r11, 0b0010	    /* check KEY1 */
            beq	r13, zero, CHECK_KEY2	
            movi	r12, KEY1	
            stw	r12, 0(r10)	                /* return KEY1 value */
            br	END_PUSHBUTTON_ISR	

        CHECK_KEY2:		
            andi	r13, r11, 0b0100	    /* check KEY2 */
            beq	r13, zero, DO_KEY3	
            movi	r12, KEY2	
            stw	r12, 0(r10)	                /* return KEY2 value */
            br	END_PUSHBUTTON_ISR	

        DO_KEY3:		
            movia	r13, 0x10000040	        /* SW slider switch base address */
            ldwio	r11, 0(r13)	            /* load slider switches */
            movia	r13, PATTERN	        /* address of pattern for HEX displays */
            stw	r11, 0(r13)	                /* save new pattern */

        END_PUSHBUTTON_ISR:			
            ldw	ra, 0(sp)	                /* Restore all used register to previous values */	
            ldw	r10, 4(sp)		
            ldw	r11, 8(sp)		
            ldw	r12, 12(sp)		
            ldw	r13, 16(sp)		
            addi	sp, sp, 20		

        ret 
        .end