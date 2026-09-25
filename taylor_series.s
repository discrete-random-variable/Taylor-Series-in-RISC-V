.data
.word 2, 1, 0x3f800000, 5, 0, 0x40000000, 8 #  N, func1_code, func1_x, func1_terms,

.text 

lui x3, 0x10000

lw x18, 0(x3) # N 
addi x5, x0, 0

lui x31, 0x7fc00 # a NAN encoding in int register as we are saving in memory , for simplicity
addi x30, x3, 512 # store address
addi x3, x3, 4
#sw x31, 0(x30)
#flw f31, 0(x30) # f31 = NAN 
fmv.w.x f31, x31 # f31 = NAN

addi x7, x0, 1 # x7 = one
fcvt.s.w f1, x7 # f1 = one
fcvt.s.w f0, x0 # f0 = +zero

L1:

lw x19, 0(x3) # code
flw f10, 4(x3) # x
lw x10, 8(x3) # #of terms 
# f10 and x10 arg for functions
addi x3, x3, 12

bge x0, x10, nan
addi x6, x0, 0 # to check function code

beq x6, x19, expc #0
addi x6, x6, 1
beq x6, x19, sinc #1
addi x6, x6, 1
beq x6, x19, cosc #2
addi x6, x6, 1
beq x6, x19, lnc #3
addi x6, x6, 1
beq x6, x19, recpc

nan:
fadd.s f10, f31, f0 # we skip this NAN if correct function code was there
jal x0, store

expc:
addi x29, x0, 0
jal x1, exp
jal x0, store

sinc:
addi x29, x0, 0
beq x10, x7, store
jal x1, sin
jal x0, store

cosc:
addi x29, x0, 0
jal x1, cos 
jal x0, store

lnc:
fle.s x29, f10, f0
beq x29, x7, nan # x<=0 out of domain
addi x29, x0 , 0
jal x1, ln 
jal x0, store

recpc:
feq.s x29, f10, f0
beq x29, x7, nan # x != 0
addi x29, x0, 0
jal x1, recp 
jal x0, store # for consistency

store:
fsw f10, 0(x30)

skip:

addi x30, x30, 4

addi x5, x5, 1
bne x5, x18, L1
jal x0, Exit1

# functions
#--------

exp:
# converges in R 
fadd.s f3, f0, f1 # temp f3 = contain accumulated sun
fadd.s f4, f0, f1 # temp term x^(i-1)/(i-1)
fadd.s f5, f0, f1 # x/i
addi x10, x10, -1
beq x10, x0, ans1

L2:
addi x29, x29, 1

fcvt.s.w f6, x29
fdiv.s f5, f10, f6
fmul.s f4, f4, f5
fadd.s f3, f3, f4

bne x29, x10, L2

ans1:
fadd.s f10, f3, f0
jalr x0, 0(x1)

#-------

sin:
# converge in R 
fadd.s f6, f1, f1 # f6 = 2
fadd.s f7, f6, f1 # f7 = 3
fadd.s f3, f0, f10 # f3 = x
fadd.s f4, f0, f10
fadd.s f5, f0, f1
fmul.s f28, f10, f10 # x^2

L3:
addi x29, x29, 1
beq x29, x10 , ans2
andi x28, x29, 1
fmul.s f29, f6, f7
fdiv.s f5, f28, f29
fmul.s f4, f4, f5

beq x28, x7, o1
fadd.s f3, f3, f4
jal x0, e1

o1:
fsub.s f3, f3, f4
# if term even then skip fsub

e1:
fadd.s f6, f7, f1
fadd.s f7, f6, f1
jal x0, L3

ans2:
fadd.s f10, f3, f0
jalr x0, 0(x1)

#---------------

cos:
# converge in R 
fadd.s f6, f0, f1 # f6 = 1
fadd.s f7, f6, f1 # f7 = 2
fadd.s f3, f0, f1 # f3 = 1
fadd.s f4, f0, f1
fadd.s f5, f0, f1
fmul.s f28, f10, f10 # x^2

L4:
addi x29, x29, 1
beq x29, x10 , ans3
andi x28, x29, 1
fmul.s f29, f6, f7
fdiv.s f5, f28, f29
fmul.s f4, f4, f5

beq x28, x7, o2
fadd.s f3, f3, f4
jal x0, e2

o2:
fsub.s f3, f3, f4
# if term even then skip fsub

e2:
fadd.s f6, f7, f1
fadd.s f7, f6, f1
jal x0, L4

ans3:
fadd.s f10, f3, f0
jalr x0, 0(x1)

#---------------

ln:
fsub.s f3, f10, f1
fadd.s f6, f1, f1 # 2
fadd.s f4, f0, f3 
fadd.s f5, f0, f3 # x-1

L5:
addi x29, x29, 1
beq x29, x10, ans4
fmul.s f4, f4, f5
fdiv.s f7, f4, f6

andi x28, x29, 1
beq x28, x7, o3
fadd.s f3, f3, f7
jal x0, e3

o3:
fsub.s f3, f3, f7

e3:
fadd.s f6, f6, f1
jal x0, L5

ans4:
fadd.s f10, f3, f0
jalr x0, 0(x1)

#-------------------

recp:
fadd.s f3, f0, f1
fadd.s f4, f0, f1
fsub.s f5, f10, f1

L6:
addi x29, x29, 1
beq x29, x10, ans5
fmul.s f4, f4, f5

andi x28, x29, 1
beq x28, x7, o4
fadd.s f3, f3, f4
jal x0, e4

o4:
fsub.s f3, f3, f4

e4:
jal x0, L6

ans5:
fadd.s f10, f3, f0
jalr x0, 0(x1)

#------------------

Exit1:

