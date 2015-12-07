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
.align 2
fruit_data: .space 260 # fruit_data = malloc(260);
count: .word 0 #count = 0
SMASH_TOTAL: .word 1 #SMASH_TOTAL = 1
puzzle_grid: .space 8192
puzzle_word: .space 128
node_memory: .space 4096
new_node_address: .word node_memory

.globl num_rows
num_rows: .word 64
.globl num_cols
num_cols: .word 64

#all the text for the code
.text

############################################################

#ALL THE PUZZLE CODE

############################################################
#All the code for allocate_new_node
.globl allocate_new_node
allocate_new_node:
	lw	$v0, new_node_address
	add	$t0, $v0, NODE_SIZE
	sw	$t0, new_node_address
	jr	$ra

.globl set_node
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

.globl remove_node #remove all nodes
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


.globl search_neighbors
search_neighbors:
	sub $sp $sp 36

	sw $ra, 0($sp) #return address
	sw $s0, 4($sp) #puzzle
	sw $s1, 8($sp) #word
	sw $s2, 12($sp) #row
	sw $s3, 16($sp) #col
	sw $s4, 20($sp) #i
	sw $s5, 24($sp) #next_row
	sw $s6, 28($sp) #next_col
	sw $s7, 32($sp) #next_node

	beq $a1, 0, ret2 #if (word == NULL)

	move $s0, $a0 #s0 = puzzle
	move $s1, $a1 #s1 = word
	move $s2, $a2 #s2 = row
	move $s3, $a3 #s3 = col

	li $s4, 0 #s4 = i

loop2:
	li $t0, 4 #just the number 4
	bge $s4, $t0, ret2 #for (int i = 0; i < 4;

	mul $t1, $s4, 4 #i*4bits
	mul $t7, $t1, 2 #i*4bits*2cols
	la $t0, directions #store directions
	add $t2, $t7, $t0 #directions[i]
	lw $t3, 0($t2) #directions[i][0]
	add $s5, $s2, $t3 #setting next_row
	lw $t4, 4($t2) #directions[i][1]
	add $s6, $s3, $t4 #set next_col

	li $t1, -1 #store -1
	lw $t0, num_rows #store num_rows
	lw $t9, num_cols #store num_cols

	ble $s5, $t1, iterate #next_row > -1
	bge $s5, $t0, iterate #next_row < num_rows
	ble $s6, $t1, iterate #next_col > -1
	bge $s6, $t9, iterate #next_col < num_cols

	mul $t5, $s5, $t9 #next_row * num_cols
	add $t5, $t5, $s6 #next_row * num_cols + next_col
	add $t6, $t5, $s0 #puzzle[next_row * num_cols + next_col]

	lb $t7, 0($s1) #*word
	lb $t5, 0($t6) #get the char at puzzle[next_row * num_cols + next_col]
	bne $t5, $t7, iterate #puzzle[next_row * num_cols + next_col] == *word

	add $t7, $s1, 1 #word + 1
	lb $t8, 0($t7) #*(word + 1)
	beq $t8, $0, if1 #*(word + 1) == '\0'

	li $t9, '*' #puzzle[next_row * num_cols + next_col] = '*'
	sb $t9, 0($t6)

	move $a0, $s0 #set puzzle
	move $a1, $t7 #set word + 1
	move $a2, $s5 #set next_row
	move $a3, $s6 #set next_col
	jal search_neighbors #call search_neighbors

	move $s7, $v0 #set next_node

	lw $t9, num_cols #store num_cols
	mul $t5, $s5, $t9 #next_row * num_cols
	add $t5, $t5, $s6 #next_row * num_cols + next_col
	add $t6, $t5, $s0 #puzzle[next_row * num_cols + next_col]

	lb $t7, 0($s1) #*word
	sb $t7, 0($t6) #puzzle[next_row * num_cols + next_col] = *word

	bne $s7, $0, if2 #if (next_node)
	j iterate

if1:
	move $a0, $s5 #set next_row
	move $a1, $s6 #set next_col
	move $a2, $0 #set NULL
	jal set_node #set the node
	lw $ra, 0($sp); #bring back register address

	lw $ra, 0($sp) #return address
	lw $s0, 4($sp) #puzzle
	lw $s1, 8($sp) #word
	lw $s2, 12($sp) #row
	lw $s3, 16($sp) #col
	lw $s4, 20($sp) #i
	lw $s5, 24($sp) #next_row
	lw $s6, 28($sp) #next_col
	lw $s7, 32($sp) #next_node

	add $sp, $sp, 36 #fix stack
	jr $ra #return the v0 stored from the jal set_node

if2: 
	move $a0, $s5 #set next_row
	move $a1, $s6 #set next_col
	move $a2, $s7 #set next_node
	jal set_node #set the node

	lw $ra, 0($sp) #return address
	lw $s0, 4($sp) #puzzle
	lw $s1, 8($sp) #word
	lw $s2, 12($sp) #row
	lw $s3, 16($sp) #col
	lw $s4, 20($sp) #i
	lw $s5, 24($sp) #next_row
	lw $s6, 28($sp) #next_col
	lw $s7, 32($sp) #next_node

	add $sp, $sp, 36 #fix stack
	jr $ra #return the v0 stored from the jal set_node

iterate:
	add $s4, $s4, 1 #increment i
	j loop2 #return to loop

ret2:
	li $v0, 0 #make v0 NULL

	lw $ra, 0($sp) #return address
	lw $s0, 4($sp) #puzzle
	lw $s1, 8($sp) #word
	lw $s2, 12($sp) #row
	lw $s3, 16($sp) #col
	lw $s4, 20($sp) #i
	lw $s5, 24($sp) #next_row
	lw $s6, 28($sp) #next_col
	lw $s7, 32($sp) #next_node

	add $sp, $sp, 36 #fix stack
	jr	$ra #return NULL

############################################################

#END OF PUZZLE CODE

############################################################

############################################################

#ALL THE FRUIT SMASH CODE

############################################################
main:

	
	sub $sp $sp 36

	sw $ra, 0($sp) #return address
	sw $s0, 4($sp) #puzzle
	sw $s1, 8($sp) #word
	sw $s2, 12($sp) #row
	sw $s3, 16($sp) #col
	sw $s4, 20($sp) #i
	sw $s5, 24($sp) #next_row
	sw $s6, 28($sp) #next_col
	sw $s7, 32($sp) #next_node

	#Enable the interrupts
	la $t0, fruit_data
	sw $t0, FRUIT_SCAN
	
	la $s0, puzzle_grid
	la $s1, puzzle_word
	la $s2, node_memory

	sw $s0, REQUEST_PUZZLE
	#sw $s1, REQUEST_WORD 

	# enable interrupts
	li	$t4, FRUIT_SMOOSHED_INT_MASK # timer interrupt enable bit
	or	$t4, $t4, BONK_MASK	 			#bonk interrupt bit
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
	bgt $t3, $t1, main

	#la $a0, puzzle_grid
	#lw $a0, 0($a0)
	#la $a1, puzzle_word
	#lw $a1, 0($a1)
	#li $a2, 0
	#li $a3, 0
	#j search_neighbors

left:

	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	li $t2, 180
	sw $t2, ANGLE #angle 180 (left)
	lw $t1, BOT_X
	beq $t3, $t1, wait
	blt $t3, $t1, main

	#la $a0, puzzle_grid
	#lw $a0, 0($a0)
	#la $a1, puzzle_word
	#lw $a1, 0($a1)
	#li $a2, 0
	#li $a3, 0
	#j search_neighbors

wait:
	la $t0, fruit_data
	sw $t0, FRUIT_SCAN
	sw $zero, VELOCITY #velocity 0
	lw $t5, 0($t0) #id
	bne $t4, $t5, find_fruit
	j wait


.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for two registers
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
	li $t8, 0

request_puzzle:
	
	la $a0, puzzle_grid
	lw $a0, 0($a0)
	la $a1, puzzle_word
	lw $a1, 0($a1)
	li $a2, 0
	li $a3, 0
	la $a2, node_memory
	jal search_neighbors

	sw $v0, SUBMIT_SOLUTION

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
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret