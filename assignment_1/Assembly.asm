MVI A, 4
STA 1000H
LOOP0: LDA 1000H
MOV B, A
MVI C, 6
MOV H, B
MOV L, C
PUSH H 
PUSH PSW 
MOV A, H 
CMP L 
MVI A, 1 
JNC COMPARE0 
MVI A, 0
COMPARE0: MVI H, 0
CMP H
JNZ LOOP1
POP PSW 
POP H
LDA 1000H
MVI C, 1
ADD C
STA 1000H
JMP LOOP0
LOOP1: POP PSW
POP H
POPPED-1: HLT
