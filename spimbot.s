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

NODE_SIZE = 12

.data
intro_str4: .asciiz "Find MEEEE\n"
.align 2
fruit_data: .space 260 # fruit_data = malloc(260);
count: .word 0 #count = 0
SMASH_TOTAL: .word 1 #SMASH_TOTAL = 1
puzzle_grid: .space 8192
puzzle_word: .space 128
node_memory: .space 4096
puzzle_received_flag: .word 0 #puzzle_received_flag = 0
new_node_address: .word node_memory
num_solves: .word 0

.globl num_rows
num_rows: .space 4
.globl num_cols
num_cols: .space 4

.globl directions
directions:
	.word -1  0
	.word  0  1
	.word  1  0
	.word  0 -1

#all the text for the code
.text

#ALL THE FRUIT SMASH CODE

############################################################
main:
	#Enable the interrupts
	la $t5, num_solves
	lw $t5, 0($t5)

	bge $t5, 20, start

	la $t0, puzzle_grid
	sw $t0, REQUEST_PUZZLE

	la $t5, num_solves
	lw $t0, 0($t5)
	add $t0, $t0, 1
	sw $t0, 0($t5)

	j start

start:	

	la $t0, fruit_data
	sw $t0, FRUIT_SCAN

	la $t4, puzzle_received_flag
	lw $t4, 0($t4)

	beq $t4, 1, solve_puzzle

	# enable interrupts
	li	$t4, FRUIT_SMOOSHED_INT_MASK #timer interrupt enable bit
	or	$t4, $t4, BONK_MASK	 			#bonk interrupt bit
	or $t4, $t4, REQUEST_PUZZLE_INT_MASK #request_puzzle interrupt bit
	or $t4, $t4, OUT_OF_ENERGY_INT_MASK #out_of_energy bit
	or	$t4, $t4, 1		 		    #global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)

bottom:
	lw $t1, BOT_Y
	bge $t1, 294, find_fruit
	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	li $t2, 90
	sw $t2, ANGLE #angle 90
	li $t2, 10
	sw $t2, VELOCITY #velocity 10

find_fruit:
	la $t6, count # count address
	lw $t7, 0($t6) # count value
	la $t6, SMASH_TOTAL
	lw $t6, 0($t6)
	bge $t7, $t6, get_bonked

	li $t2, 10
	sw $t2, VELOCITY #velocity 10
	lw $t4, 0($t0)
	lw $t3, 8($t0) #the x coordinate of the fruit
	lw $t1, BOT_X
	#lw $t8, BOT_Y
	beq $t3, $t1, wait
	bgt $t3, $t1, right
	blt $t3, $t1, left

get_bonked:
	li $t8, 1
	sw $t8, ANGLE_CONTROL #absolute angle
	li $t8, 90
	sw $t8, ANGLE #angle 90
	li $t8, 10
	sw $t8, VELOCITY #velocity 10
	
	la $t6, count # count address
	lw $t7, 0($t6) # count value
	beq $t7, $zero, find_fruit

	j get_bonked


right:

	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	sw $zero, ANGLE #angle 0 (turn right)
	lw $t1, BOT_X
	beq $t3, $t1, wait
	bgt $t3, $t1, start
	j right

	#jal search_neighbors

left:

	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	li $t2, 180
	sw $t2, ANGLE #angle 180 (left)
	lw $t1, BOT_X
	beq $t3, $t1, wait
	blt $t3, $t1, start
	j left

#Once the X-coordinates of the Bot matches the X-coordinate of the fruit
#It waits until the fruit falls down at the Bot

wait:
	
	#FRUIT STUFF
	la $t0, fruit_data
	sw $t0, FRUIT_SCAN
	sw $zero, VELOCITY #velocity 0
	lw $t6, 0($t0) #id
	bne $t4, $t6, find_fruit
	
	j wait



############################################################

#ALL THE PUZZLE CODE

############################################################
#All the code for allocate_new_node
#.globl allocate_new_node
allocate_new_node:
	lw	$v0, new_node_address
	add	$t0, $v0, NODE_SIZE
	sw	$t0, new_node_address
	jr	$ra

#.globl set_node
set_node:
	sub $sp, $sp, 16

	sw $ra, 0($sp)
	sw $a0, 4($sp)
	sw $a1, 8($sp)
	sw $a2, 12($sp)

	jal allocate_new_node
	lw $a0, 4($sp)
	lw $a1, 8($sp)
	lw $a2, 12($sp)


	# Your code goes here :)
	sw $a0, 0($v0)
	sw $a1, 4($v0)
	sw $a2, 8($v0)

	lw $ra, 0($sp)
	add $sp, $sp, 16
	jr	$ra

#.globl remove_node #remove all nodes
remove_node:
	move $t8, $a0
	loop1:
		lw $t0, 0($t8) # entry = *head
		beq $t0, $0, ret

		lw $t1, 0($t0) #addr of row

		lw $t2, 4($t0) #addr of col

		bne $t1, $a1, skip
		bne $t2, $a2, skip

		lw $t3, 8($t0) #$t3: entry->next
		sw $t3, 0($t8) #*curr = entry->next
		j ret

	skip: 
		add $t0, $t0, 8
		move $t8, $t0

		j loop1

	ret:
		jr	$ra


search_neighbors:
	bne	$a1, 0, sn_main		# !(word == NULL)
	li	$v0, 0			# return NULL (data flow)
	jr	$ra			# return NULL (control flow)

sn_main:
	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

	move	$s0, $a0		# puzzle
	move	$s1, $a1		# word
	move	$s2, $a2		# row
	move	$s3, $a3		# col
	li	$s4, 0			# i

sn_loop:
	mul	$t0, $s4, 8		# i * 8
	lw	$t1, directions($t0)	# directions[i][0]
	add	$s5, $s2, $t1		# next_row
	lw	$t1, directions+4($t0)	# directions[i][1]
	add	$s6, $s3, $t1		# next_col

	lw	$t0, num_cols
	lw	$t1, num_rows

	ble	$s5, -1, add_row	# !(next_row > -1)
	bge	$s5, $t0, mod		# !(next_row < num_rows)
	ble	$s6, -1, add_col	# !(next_col > -1)
	bge	$s6, $t1, mod		# !(next_col < num_cols)
	j continue

add_row:
	add $s5, $t1, $s5 #row + num_rows
	ble	$s6, -1, add_col
	bge	$s6, $t0, mod
	j continue

add_col:
	add $s6, $t0, $s6
	j continue

mod:
	div $s5, $t1 #next_row/num_rows
	mfhi $s5
	div $s6, $t0 #next_col/num_cols
	mfhi $s6
	j continue

continue:
	mul	$t0, $s5, $t0		# next_row * num_cols
	add	$t0, $t0, $s6		# next_row * num_cols + next_col
	add	$s7, $s0, $t0		# &puzzle[next_row * num_cols + next_col]
	lb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col]
	lb	$t1, 0($s1)		# *word
	bne	$t0, $t1, sn_next	# !(puzzle[next_row * num_cols + next_col] == *word)

	lb	$t0, 1($s1)		# *(word + 1)
	bne	$t0, 0, sn_search	# !(*(word + 1) == '\0')
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	li	$a2, 0			# NULL
	jal	set_node		# $v0 will contain return value
	j	sn_return

sn_search:
	li	$t0, '*'
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = '*'
	move	$a0, $s0		# puzzle
	add	$a1, $s1, 1		# word + 1
	move	$a2, $s5		# next_row
	move	$a3, $s6		# next_col
	jal	search_neighbors
	lb	$t0, 0($s1)		# *word
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = *word
	beq	$v0, 0, sn_next		# !next_node
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	move	$a2, $v0		# next_node
	jal	set_node
	j	sn_return

sn_next:
	add	$s4, $s4, 1		# i++
	blt	$s4, 4, sn_loop		# i < 4
	
	li	$v0, 0			# return NULL (data flow)

sn_return:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	lw	$s7, 32($sp)
	add	$sp, $sp, 36
	jr	$ra

#############################################################################
solve_puzzle:
	la $a0, puzzle_grid
	la $a1, puzzle_word

	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw  $s5, 24($sp)
	sw  $s6, 28($sp)
	sw  $s7, 32($sp)

	la $s3, num_rows
	lw $s5, 0($a0) #number of rows
	sw $s5, 0($s3) #store into num_rows
	move $s3, $s5 #load into s3

	la $s4, num_cols
	lw $s5, 4($a0) #number of columns
	sw $s5, 0($s4) #store into num_columns
	move $s4, $s5 #load into s3

	add		$s0, $a0, 8 	# puzzle
	move	$s1, $a1		# word

	lb	$t0, 0($s1)		# word[0]
	beq	$t0, 0, sp_true		# word[0] == '\0'

	li	$s2, 0			# row = 0

sp_row_for:
	la	$t0, num_rows
	lw 	$t0, 0($t0)
	bge	$s2, $t0, sp_false	# !(row < num_rows)

	li	$s3, 0			# col = 0

sp_col_for:
	la	$t0, num_cols
	lw 	$t0, 0($t0)
	bge	$s3, $t0, sp_row_next	# !(col < num_cols)

	li $s6, 0

	move	$a0, $s0		# puzzle
	move	$a1, $s2		# row
	move	$a2, $s3		# col
	jal	get_char		# $v0 = current_char
	lb	$t0, 0($s1)		# target_char = word[0]
	bne	$v0, $t0, sp_col_next	# !(current_char == target_char)

	bne $s6, $0, continue2

	add $s6, $s6, 1
	move $a0, $s2 #set next_row
	move $a1, $s3 #set next_col
	move $a2, $0 #set NULL
	jal set_node #set the node
	move $s7, $v0

continue2:

	move	$a0, $s0		# puzzle
	move	$a1, $s2		# row
	move	$a2, $s3		# col
	li	$a3, '*'
	jal	set_char

	move	$a0, $s0		# puzzle
	add 	$a1, $s1, 1		# word + 1
	move 	$a2, $s2	    # row
	move 	$a3, $s3		# col
	jal	search_neighbors
	move	$s4, $v0		# exist

	move	$a0, $s0		# puzzle
	move	$a1, $s2		# row
	move	$a2, $s3		# col
	lb	$a3, 0($s1)		# word[0]
	jal	set_char

	bne	$s4, 0, sp_true		# if (exist)

sp_col_next:
	add	$s3, $s3, 1		# col++
	j	sp_col_for

sp_row_next:
	add	$s2, $s2, 1		# row++
	j	sp_row_for

sp_false:
	li	$v0, 0			# false
	j	sp_done

sp_true:
	sw $s4, 8($s7)
	sw $s7, SUBMIT_SOLUTION
	#li	$v0, 1			# true

sp_done:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw  $s5, 24($sp)
	lw  $s6, 28($sp)
	lw  $s7, 32($sp)
	add	$sp, $sp, 36

	la $t4, puzzle_received_flag
	sw $zero, 0($t4) #puzzle hasn't been received yet

	la $t4, node_memory
	sw $t4, new_node_address
	j main


get_char:
	lw	$v0, num_cols
	mul	$v0, $a1, $v0	# row * num_cols
	add	$v0, $v0, $a2	# row * num_cols + col
	add	$v0, $a0, $v0	# &array[row * num_cols + col]
	lb	$v0, 0($v0)	# array[row * num_cols + col]
	jr	$ra

set_char:
	lw	$v0, num_cols
	mul	$v0, $a1, $v0	# row * num_cols
	add	$v0, $v0, $a2	# row * num_cols + col
	add	$v0, $a0, $v0	# &array[row * num_cols + col]
	sb	$a3, 0($v0)	# array[row * num_cols + col] = c
	jr	$ra

#END OF PUZZLE CODE

############################################################

############################################################


.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 16	# space for two registers

non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable  
	sw  $a2, 8($k0)   
	sw 	$a3, 12($k0)


	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and	$a0, $k0, FRUIT_SMOOSHED_INT_MASK	# is there a smoosh interrupt?
	bne	$a0, 0, fruit_smooshed_interrupt

	and	$a0, $k0, BONK_MASK	# is there a bonk interrupt?                
	bne	$a0, 0, bonk_interrupt 

	# add dispatch for other interrupt types here.
	and $a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne $a0, 0, request_puzzle_interrupt

	#li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

fruit_smooshed_interrupt:

	la $t6, count # count address
	lw $t7, 0($t6) # count value
	addi $t7, $t7, 1 #increment it
	sw $t7, 0($t6) #store it back in 

	la $t8, SMASH_TOTAL
	lw $t8, 0($t8)
	blt $t7, $t8, no_smash

	#li $t8, 1
	#sw $t8, ANGLE_CONTROL #absolute angle
	#li $t8, 90
	#sw $t8, ANGLE #angle 90
	#li $t8, 10
	#sw $t8, VELOCITY #velocity 10

	li $t9, 1 #flag to say you should smash

	#li $t8, 10000

	#j	stall	# see if other interrupts are waiting

#stall:
	#ble $t8, 0, interrupt_dispatch
	#sub $t8, $t8, 1
	#j stall
	sw $a1, FRUIT_SMOOSHED_ACK

	j interrupt_dispatch

no_smash:
	sw $a1, FRUIT_SMOOSHED_ACK

	j interrupt_dispatch

bonk_interrupt:

	beq $t9, 1, smash #check to see if its smash time

	la $t6, count # count address
	sw $zero, 0($t6) # count value

	sw	$a1, BONK_ACK		# acknowledge interrupt
	#sw	$zero, VELOCITY		# 0

	j	interrupt_dispatch	# see if other interrupts are waiting

smash:

	la $t6, FRUIT_SMASH
	sw $zero, 0($t6) #smash 1

	li $t9, 0

	j bonk_interrupt


request_puzzle_interrupt:
	
	la $a2, puzzle_received_flag
	lw $a2, 0($a2)
	bne $a2, $zero, interrupt_dispatch #if puzzle_received_flag != 0 don't do anything

	#Actually set puzzle_received_flag to 1
	li $a3, 1
	la $a2, puzzle_received_flag
	sw $a3, 0($a2)

	la $a3, puzzle_word
	sw $a3, REQUEST_WORD

	sw $a1, REQUEST_PUZZLE_ACK

	j interrupt_dispatch


smashing:
	sw $zero, 0($t6) #smash

	add $t8, $t8, 1

	la $t9, SMASH_TOTAL
	lw $t9, 0($t9)

	blt $t8, $t9, smashing #smash the total number we want

	li $t9, 0

	j bonk_interrupt

non_intrpt:				# was some non-interrupt
	#li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
	lw $a2, 8($k0)
	lw $a3, 12($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret