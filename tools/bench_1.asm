;Aleas de type irresolvable
;Aleas de rangement
addi  R1,R0,1
sw R1,2(R0)
;Aleas de chargement
addi  R1,R0,1
sw R1,2(R0)
lw R1,2(R0)
addi R2,R1,2
; aleas resolvable
;TypeR
; dependance ds l etage EX/MEM
addi R1,R0,2
addi R2,R1,3
; dependance ds l etage MEM/ER
addi R1,R0,2
addi R2,R0,3
addi R3,R1,3
; dependance ds l etage EX/MEM et MEM/ER
addi R1,R0,2
addi R2,R0,3
add R3,R1,R2
;Type JR ou JALR
;dependance ds l etage DI/EX
addi R1,R0,2
jr R1
addi R2,R0,0
addi R2,R1,3
addi R2,R1,4
addi R2,R1,5
;dependance ds l etage EX/MEM
addi R1,R0,2
addi R1,R0,3
jr R1
addi R2,R0,0
addi R2,R1,4
addi R2,R1,5
addi R2,R1,5
; aleas resolvable
; dependance ds l etage EX/MEM
addi R1,R0,2
addi R2,R1,3
; dependance ds l etage MEM/ER
addi R1,R0,2
addi R2,R0,3
addi R3,R1,3
; dependance ds l etage EX/MEM et MEM/ER
addi R1,R0,2
addi R2,R0,3
add R3,R1,R2
