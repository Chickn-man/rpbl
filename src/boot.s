;#
;#  Assembly code for RPBL
;#
;##############################################################################
;#
;#  Copyright (C) 2023 Keegan Powers
;#
;#  This file is part of RPBL
;#
;#  RPBL is free software: you can redistribute it
;#  and/or modify it under the terms of the GNU General Public
;#  License as published by the Free Software Foundation, either
;#  version 3 of the License, or (at your option) any later version.
;#
;#  This program is distributed in the hope that it will be useful,
;#  but WITHOUT ANY WARRANTY; without even the implied warranty of
;#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;#  GNU General Public License for more details.
;#
;#  You should have received a copy of the GNU General Public License
;#  along with this program. If not, see <https://www.gnu.org/licenses/>.
;#
;##############################################################################

!cpu 65EL02

*= $0 ; zero page
ret0: !word $0
arg0: !word $0 ; argument 0 for passing to functions
arg1: !word $0 ; argument 1 for passing to functions
arg2: !word $0 ; argument 2 for passing to functions      
loadaddr: !word $0
sector: !word $5454

*= $500 ; bootloader 
clc
xce 

rep #$30 ; 16 bit registers
!al
lda #$1 ; screen id
mmu #0
lda #windowaddr
mmu #1 ; map window to windowaddr
mmu #2 ; enable redbus

sep #$30 ; 8 bit registers
!as

stz cursorx ; cursor x
stz cursory ; cursor y
stz cursor ; reset cursor
jsr clearscreen

lda #$fe
sta $e000
lda #0
lda $e000
cmp #$fe
beq rampass

rep #$30
!al
lda #$3830
sta error_code_ascii
jmp error

rampass:
rep #$30
!al
lda #1
sta sector
lda #$700
sta sector_store_addr
jsr readsector
sep #$30
!as

lda mbr_type_1
cmp #$01
beq hasfs

rep #$30 ; 16 bit mode
!al
lda #$3130
sta error_code_ascii
jmp error

hasfs:
rep #$30
!al
lda mbr_lbas_1
sta sector
lda #sector_buffer
sta sector_store_addr
jsr readsector

jsr load_kernel
jmp error

hlt:
    jmp hlt

jmp $400

fatt: !text "FAT12   "
lablet: !text "RPOS BOOT  "
boott: !text "BOOT       "
kernelt !text "KERNEL     "
errort: !text "error 0x"
error_code_ascii: !text "00", 0


error:
    !al
    lda #errort
    sta arg0
    jsr print
    jmp hlt

clearscreen:
    php 
    sep #$30
    !as
    lda #1
    mmu #$00

    lda #' '
    ldx #49
clsss
    stx screenrow
    ldy #79
clsnl:
    sta screenline, Y
    dey 
    bpl clsnl
    dex 
    bpl clsss
clsret:
    plp 
    rts 

print:
    php 
    sep #$30
    !as
    !rs
    lda #1
    mmu #$00

    ldx cursorx
    ldy #0
printloop:
    lda (arg0), Y
    cmp #0
    beq printret
    sta screenline, X
    iny 
    inx 
    jmp printloop
printret:
    plp 
    rts 

readphysector:
    php 
    sep #30
    !as
    !rs
    ldx #3
retry_read:
    cpx #0
    bne nodiskerr
    rep #$30
    !al
    lda #$3630
    sta error_code_ascii
    jmp error
    !as
nodiskerr:
    dex 
    rep #$30
    !al
    lda #2
    mmu #0
    sep #$30
    !as
    lda #4
    sta diskcommand
    wai
    lda diskcommand
    cmp #$FF
    beq retry_read
    plp 
    rts 

readsector:
    php 
    phx 
    rep #$30
    !al
    !rl
    lda #2
    mmu #0
    ldx #0
    ldy #4
    lda #4
    sta 254
    lda sector
    mul 254
    sta disksector
rsloop:
    dey 
    phx 
    jsr readphysector
    rep #$30
    plx 
    rhy 
    ldy #0
    bra rscp
rscpr:
    rly 
    cpy #0
    beq rsret
    inc disksector
    bra rsloop
rscp:
    lda diskbuff, y
    !byte $9d
sector_store_addr: !word sector_buffer
    inx 
    inx 
    iny 
    iny 
    cpy #128
    beq rscpr
    bra rscp
rsret:
    plx 
    plp 
    rts

memcopy:
    php 
    sep #$30
    !as
    !rs
    ldy #0
mcploop:
    lda (arg0), Y
    sta (arg1), Y
    iny 
    cpy arg2
    bne mcploop
    plp 
    rts 

readfat:
    phy
    phx
    php
    rep #$30
    !al
    lda #2
    sta 254
    lda #3
    sta 252
    lda arg0
    div 254
    mul 252
    clc 
    adc #file_allocation_table
    sta 250
    lda arg0
    sep #$30
    !as
    !rs
    and #1
    cmp #1
    beq odd_entry
even_entry:
    lda (250)
    xba 
    ldy #1
    lda (250), y
    and #$0f
    xba
    bra exitrf
odd_entry:
    ldy #2
    lda (250), y
    xba
    ldy #1
    lda (250), y
    and #$f0
    xba
    rep #$30
    !al
    clc
    rol
    rol
    rol
    rol
    rol
exitrf:
    rep #$30
    plp
    plx
    ply
    rts 

*= $6be ; mbr entry 1
bootable_1: !byte $80 ; bootable
!byte $0 ; head
;     Sector| Cylinder
!word %0000100000000000
mbr_type_1: !byte $01 ; fat12
!byte $8 ; head
;     Sector| Cylinder
!word %0001110000000000
mbr_lbas_1: !32 $00000002 ; starts at $2
mbr_lbae_1: !32 $000001fe ; size of 510

*= $6fe
!word $aa55

*= $700 ; extended boot code
load_kernel:
    rep #$30
    !al
    !rl

    ; compare fs type
    lda #FS_TYPE
    sta arg0
    lda #fatt
    sta arg1
    lda #8
    sta arg2
    jsr memcmp
    and #$01
    cmp #0
    beq fat12

    lda #$3230
    sta error_code_ascii
    jmp error

fat12:
     ; compare fs lable
    lda #FS_LABLE
    sta arg0
    lda #lablet
    sta arg1
    lda #11
    sta arg2
    jsr memcmp
    and #$01
    cmp #0
    beq rposboot

    lda #$3330
    sta error_code_ascii
    jmp error

rposboot:
    ; copy serial number
    lda #FS_SERIAL
    sta arg0
    lda #fat_serial
    sta arg1
    lda #4
    sta arg2
    jsr memcopy

    sep #$30
    !as
    lda FS_SPC
    sta fat_spc
    stz fat_spc+1
    lda FS_COPIES
    sta fat_copies
    stz fat_copies+1
    rep #$30
    !al
    lda FS_RSRVD
    sta fat_rsrvd
    lda FS_ROOTE
    sta fat_roote
    lda FS_SPF
    sta fat_spf

    lda fat_spf
    mul fat_copies
    adc mbr_lbas_1
    sta fat_roots

    lda fat_rsrvd
    adc mbr_lbas_1
    sta sector
    lda #file_allocation_table
    sta sector_store_addr
    ldx #0
loadfatl:
    jsr readsector
    inc sector
    lda sector_store_addr
    adc #512
    sta sector_store_addr
    inx 
    cpx fat_spf
    bne loadfatl

    lda #32
    sta 254
    lda fat_roote
    ldx #32
    stx 254
    mul 254
    ldx #512
    stx 254
    div 254
    sta 252
    lda fat_roots
    sta sector
    lda #root_directory
    sta sector_store_addr
    ldx #0
loadrootl:
    jsr readsector
    inc sector
    lda sector_store_addr
    adc #512
    sta sector_store_addr
    inx 
    cpx #2
    bne loadrootl

    lda 252
    adc fat_roots
    sbc #$3
    sta fat_cluster

    lda #RE1_NAME
    sta arg0
    lda #boott
    sta arg1
    lda #11
    sta arg2
    jsr memcmp
    and #$01
    cmp #0
    beq boot_found
boot_not_found:
    lda #$3430
    sta error_code_ascii
    jmp error
boot_found:
    lda RE1_ATR
    and #$10
    cmp #$10
    bne boot_not_found

    lda RE1_CLUSTER
    adc fat_cluster
    sta sector
    lda #sector_buffer
    sta sector_store_addr
    jsr readsector

    lda #DE2_NAME
    sta arg0
    lda #kernelt
    sta arg1
    lda #11
    sta arg2
    jsr memcmp
    and #$01
    cmp #0
    beq kernel_found

    lda #$3530
    sta error_code_ascii
    jmp error

kernel_found:
    lda DE2_SIZE
    sta 246
    lda DE2_CLUSTER
    sta arg0
    clc 
    adc fat_cluster
    adc #1
    sta sector
    lda #sector_buffer
    sta sector_store_addr
    jsr readsector
    ldy #0
    ldx #0
    bra load_kernel_loop
g65djn7k:
    jsr readfat
    sta arg0
    clc
    adc fat_cluster
    adc #1
    sta sector
    sty 244
    jsr readsector
    ldy 244
    ldx #0
load_kernel_loop:
    lda sector_buffer, x
    sta kernel, y
    inx
    inx
    iny
    iny
    cpy 246
    bcs kernel_loaded
    cpx #512
    bcs g65djn7k
    bra load_kernel_loop
kernel_loaded:
    lda #kernel_magic
    sta arg0
    lda #magic
    sta arg1
    lda #5
    sta arg2
    jsr memcmp
    and #$01
    cmp #0
    beq kernel_good

    lda #$3530
    sta error_code_ascii
    jmp error

kernel_good:
    sep #$30
    jsr kernel_entry
    rep #$30
    lda #$3730
    sta error_code_ascii
    jmp error

memcmp:
    php 
    sep #$30
    !as
    !rs
    ldy #0
mcmploop:
    lda (arg0), Y
    cmp (arg1), Y
    bne mcmpne
    iny 
    cpy arg2
    bne mcmploop
    lda #0
    plp 
    rts  
mcmpne:
    lda #1
    plp 
    rts

magic: !text $fe, "RPOS"

*= $900 ; boot services memory
fat_serial:!32 $00000000
fat_spc:    !word $0000
fat_rsrvd:  !word $0000
fat_copies: !word $0000
fat_roote:  !word $0000
fat_spf:    !word $0000
fat_roots:  !word $0000
fat_cluster:!word $0000


*= $1000 ; kernel
kernel:
kernel_magic: !text "     "
kernel_entry:

*= $2000 ; ram

*= $f000
file_allocation_table:

*= $f400
root_directory:
RE0_NAME:      !text "        "
RE0_EXT:       !text "   "
RE0_ATR:       !byte $00
RE0_RSRVD:     !byte $00
RE0_MILLI:     !byte $00
RE0_CTIME:     !word $0000
RE0_CDATE:     !word $0000
RE0_LDATE:     !word $0000
RE0_RSRVD1:    !word $0000
RE0_WTIME:     !word $0000
RE0_WDATE:     !word $0000
RE0_CLUSTER:   !word $0000
RE0_SIZE:      !32   $00000000

RE1_NAME:      !text "        "
RE1_EXT:       !text "   "
RE1_ATR:       !byte $00
RE1_RSRVD:     !byte $00
RE1_MILLI:     !byte $00
RE1_CTIME:     !word $0000
RE1_CDATE:     !word $0000
RE1_LDATE:     !word $0000
RE1_RSRVD1:    !word $0000
RE1_WTIME:     !word $0000
RE1_WDATE:     !word $0000
RE1_CLUSTER:   !word $0000
RE1_SIZE:      !32   $00000000


*= $fc00 ; sector buffer
sector_buffer = $fc00
FS_SPC=sector_buffer+$d
FS_RSRVD=sector_buffer+$e
FS_COPIES=sector_buffer+$10
FS_ROOTE=sector_buffer+$11
FS_SPF=sector_buffer+$16
FS_SERIAL=sector_buffer+$27 
FS_LABLE=sector_buffer+$2b
FS_TYPE=sector_buffer+$36

DE0_NAME:      !text "        "
DE0_EXT:       !text "   "
DE0_ATR:       !byte $00
DE0_RSRVD:     !byte $00
DE0_MILLI:     !byte $00
DE0_CTIME:     !word $0000
DE0_CDATE:     !word $0000
DE0_LDATE:     !word $0000
DE0_RSRVD1:    !word $0000
DE0_WTIME:     !word $0000
DE0_WDATE:     !word $0000
DE0_CLUSTER:   !word $0000
DE0_SIZE:      !32   $00000000

DE1_NAME:      !text "        "
DE1_EXT:       !text "   "
DE1_ATR:       !byte $00
DE1_RSRVD:     !byte $00
DE1_MILLI:     !byte $00
DE1_CTIME:     !word $0000
DE1_CDATE:     !word $0000
DE1_LDATE:     !word $0000
DE1_RSRVD1:    !word $0000
DE1_WTIME:     !word $0000
DE1_WDATE:     !word $0000
DE1_CLUSTER:   !word $0000
DE1_SIZE:      !32   $00000000

DE2_NAME:      !text "        "
DE2_EXT:       !text "   "
DE2_ATR:       !byte $00
DE2_RSRVD:     !byte $00
DE2_MILLI:     !byte $00
DE2_CTIME:     !word $0000
DE2_CDATE:     !word $0000
DE2_LDATE:     !word $0000
DE2_RSRVD1:    !word $0000
DE2_WTIME:     !word $0000
DE2_WDATE:     !word $0000
DE2_CLUSTER:   !word $0000
DE2_SIZE:      !32   $00000000

*= $ff00 ; redbus window
windowaddr:
screenrow=windowaddr
cursorx=windowaddr+$1
cursory=windowaddr+$2
cursor=windowaddr+$3
keybuff=windowaddr+$4
keypos=windowaddr+$5
keylast=windowaddr+$6
screenline=windowaddr+$10

diskbuff=windowaddr
disksector=windowaddr+$80
diskcommand=windowaddr+$82