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