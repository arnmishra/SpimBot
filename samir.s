# spimbot constants
VELOCITY      = 0xffff0010
ANGLE         = 0xffff0014
ANGLE_CONTROL = 0xffff0018
BOT_X         = 0xffff0020
BOT_Y         = 0xffff0024

OTHER_BOT_X = 0xffff00a0
OTHER_BOT_Y = 0xffff00a4

FRUIT_SMOOSHED_ACK = 0xffff0064
FRUIT_SMOOSHED_INT_MASK = 0x2000

FRUIT_SMASH = 0xffff0068
FRUIT_SCAN    = 0xffff005c

BONK_MASK     = 0x1000
BONK_ACK      = 0xffff0060

TIMER         = 0xffff001c
TIMER_MASK    = 0x8000
TIMER_ACK     = 0xffff006c

OUT_OF_ENERGY_ACK       = 0xffff00c4
OUT_OF_ENERGY_INT_MASK  = 0x4000

GET_ENERGY = 0xffff00c8

REQUEST_PUZZLE = 0xffff00d0
SUBMIT_SOLUTION = 0xffff00d4

REQUEST_PUZZLE_ACK = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800

REQUEST_WORD = 0xffff00dc

# Make sure space is aligned to 2^2 bits
.align 2 
fruit_data: .space 260

num_smooshed: .word 0

.text
main:
	# $t0 - for ANGLE and ANGLE_CONTROL
	# $t1 - for VELOCITY
	# $t2 - for BOT_X and BOT_Y
	# $t3 - for getting id of closest fruit
	# $t4 - x-coord of fruit 
	# $t5 - index of the fruit in the array
	# $t6 - temporary x-coord of the fruit in the array

	# Enable interrupts
	li 	$t0, BONK_MASK				# bonk interrupt bit
	or 	$t0, $t0, FRUIT_SMOOSHED_INT_MASK		# smoosh interrupt bit
	or	$t0, $t0, 1					# global interrupt enable
	mtc0 $t0, $12					# set interrupt mask (Status register)


move_bottom:
	lw $t0, BOT_Y
	bge $t0, 294, look_for_fruit
	
	# Orient SPIMbot
	li $t1, 90				# +y = 90
	sw $t1, ANGLE
	li $t1, 1 				# Absolute angle
	sw $t1, ANGLE_CONTROL

	# Set velocity
	li $t1, 10
	sw $t1, VELOCITY

	j move_bottom

look_for_fruit:
	# Stop moving
	# sw $zero, VELOCITY

	# Populate fruit_data with the array of fruit information
	la $s0, fruit_data
	sw $s0, FRUIT_SCAN

	## Check if fruit array is empty
	# Get id of first fruit
	lw $t3, 0($s0)
	# Check if first fruit is NULL
	beq $t3, $zero, look_for_fruit

	# Get x coordinate of first fruit and SPIMbot
	lw $t4, 8($s0)	# x-coord of first fruit
	lw $t2, BOT_X 	# x-coord of bot
	# If x-coord of fruit > x-coord of SPIMbot, move right. Else, move left.
	bgt $t4, $t2, move_right
	blt $t4, $t2, move_left
wait_to_smoosh_fruit:				# If the same x-coord, wait for fruit to smoosh
	## WAIT TO SMOOSH THE FRUIT ##
	sw $zero, VELOCITY

	lw $t0, num_smooshed			# get num_smooshed
	bge $t0, 5, smash_fruit			# Cause a bonk

	# Wait for fruit until it smashes
	la $s0, fruit_data
	sw $s0, FRUIT_SCAN

	# Get id of first fruit in the array
	lw $t9, 0($s0)
	# If the id = the id of the fruit we are smooshing, keep waiting
	beq $t3, $t9, wait_to_smoosh_fruit

smash_fruit:
	# Orient SPIMbot to face downwards
	li $t0, 90				# +y = 90
	sw $t0, ANGLE
	li $t0, 1 				# Absolute angle
	sw $t0, ANGLE_CONTROL
	# Move SPIMbot to the bottom of the screen
	li $t1, 10
	sw $t1, VELOCITY

	lw $t1, num_smooshed
	beq $t1, 0, look_for_fruit
	j smash_fruit

move_right: 				# Move right since x-coord of SPIMbot > x-coord of the fruit
	# Orient SPIMbot to the right
	li $t0, 0 				# +x = 0
	sw $t0, ANGLE
	li $t0, 1 				# Absolute angle
	sw $t0, ANGLE_CONTROL
	# Set SPIMbot velociy to +
	li $t1, 10
	sw $t1, VELOCITY
	# Check if reached the x-coord of the fruit
	lw $t2, BOT_X
	bge $t2, $t4, wait_to_smoosh_fruit
	j move_right

move_left:					# Move left while x-coord of SPIMbot < x-coord of the fruit
	# Orient SPIMbot to the left
	li $t0, 180				# -x = 180
	sw $t0, ANGLE
	li $t0, 1 				# Absolute angle
	sw $t0, ANGLE_CONTROL
	# Set SPIMbot velociy to +
	li $t1, 10
	sw $t1, VELOCITY
	# Check if reached the x-coord of the fruit
	lw $t2, BOT_X
	ble $t2, $t4, wait_to_smoosh_fruit
	j move_left

# ===== INTERRUPTS ===== #
.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for a register

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at				# Save $at
.set at
	la	$k0, chunkIH
	sw	$t0, 0($k0)					# Get some free registers
	sw	$t1, 4($k0)					# by storing them to a global variable

	mfc0	$k0, $13				# Get Cause register
	srl	$t0, $k0, 2
	and	$t0, $t0, 0xf				# ExcCode field                

interrupt_dispatch:					# Interrupt:                          
	mfc0	$k0, $13				# Get Cause register, again
	beq	$k0, 0, done				# handled all outstanding interrupts     

	and	$t0, $k0, BONK_MASK			# is there a bonk interrupt?                
	bne	$t0, 0, bonk_interrupt

	and $t0, $k0, FRUIT_SMOOSHED_INT_MASK		# is there a smoosh interrupt?
	bne $t0, 0, smoosh_interrupt

	j	done

smoosh_interrupt:
	# Increment num_smooshed
	lw $t0, num_smooshed			# $t0 = num_smooshed
	add $t0, $t0, 1					# $t0 += 1
	sw $t0, num_smooshed			# num_smooshed = $t0
	sw $t1, FRUIT_SMOOSHED_ACK			# acknowledge smoosh
	j interrupt_dispatch 			# Check if other interrupts are waiting

bonk_interrupt:
	sw	$zero, VELOCITY				# Stop the SPIMbot
keep_smashing:
	lw $t0, num_smooshed			# $t0 = num_smooshed
	beq $t0, $0, done_smashing		# if num_smooshed > 0
	sw $zero, FRUIT_SMASH			# Smash a fruit
	sub $t0, $t0, 1					# num_smooshed--
	sw $t0, num_smooshed
	j keep_smashing
done_smashing:
	# Acknowledge bonk interrupt after smashing fruits
	sw	$t1, BONK_ACK		# acknowledge bonk interrupt

	j	interrupt_dispatch	# see if other interrupts are waiting

done:
	la	$k0, chunkIH
	lw	$t0, 0($k0)		# Restore saved registers
	lw	$t1, 4($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret
