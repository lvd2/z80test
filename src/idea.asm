
opsize      equ     4+postccf
datasize    equ     16
vecsize     equ     opsize+datasize

test:       ld      (.spptr+1),sp

            if      maskflags
            ld      a,(hl)
            ld      (.flagptr+1),a
            endif

            inc     hl

            ld      de,vector
            ld      bc,vecsize
            call    .copy

            add     hl,bc

            call    .copy

            call    .copy
            
            add     hl,bc

            ld      (.valptr+1),de

            inc     de

            call    .clear

            ld      (.maskptr+1),de

            xor     a
            ld      (de),a
            inc     de

            call    .copy
            
            ld      a,0x07
            out     (0xfe),a

            ld      a,0xa9
            ld      i,a
            ld      r,a
            or      a
            ex      af,af

            ld      bc,65535
            ld      d,b
            ld      e,c
            exx

            ld      sp,data.regs

            ; sequence combinator

.loop       ld      hl,counter
            ld      de,shifter+1
            ld      bc,vector
            
            macro   combine base,count,offset:0,last:1
            repeat  count
            ld      a,(bc)
            xor     (hl)
            ex      de,hl
            xor     (hl)
            ld      (base+offset+@#),a
            if      ( @# < count-1 ) | ! last
            inc     c
            inc     e
            inc     l
            endif
            endrepeat
            endm

            ld      a,(bc)
            xor     (hl)
            ex      de,hl
            xor     (hl)
            cp      0x76        ; halt
            jp      z,.next
            ld      (.opcode),a
            inc     c
            inc     e
            inc     l

            ld      a,(bc)
            xor     (hl)
            ex      de,hl
            xor     (hl)
            ld      (.opcode+1),a
            cp      0x76        ; halt
            jp      nz,.ok
            ld      a,(.opcode)
            and     0xdf        ; IX/IY prefix.
            cp      0xdd
            jp      z,.next
.ok         inc     c
            inc     e
            inc     l

            combine .opcode,opsize-2,2,0
            combine data,datasize

            ; test itself

            pop     af
            pop     bc
            pop     de
            pop     hl
            pop     ix
            pop     iy
            ld      sp,(data.sp)

.opcode     ds      opsize
.continue
            if      memptr
            ld      hl,data
            bit     0,(hl)
            endif

            ld      (data.sp),sp
            ld      sp,data.regstop
            push    iy
            push    ix
            push    hl
            push    de
            push    bc
            push    af
            
            ld      hl,data

            if      maskflags
            ld      a,(hl)
.flagptr    and     0xff

            if      ! onlyflags
            ld      (hl),a
            endif

            endif

            ; crc update

            if      ! onlyflags
            ld      b,datasize
            endif

            if      ! ( onlyflags & maskflags )
.crcloop    ld      a,(hl)
            endif

            exx
            xor     e

            ld      l,a
            ld      h,crctable/256
            
            ld      a,(hl)
            xor     d
            ld      e,a
            inc     h

            ld      a,(hl)
            xor     c
            ld      d,a
            inc     h

            ld      a,(hl)
            xor     b
            ld      c,a
            inc     h

            ld      b,(hl)

            exx

            if      ! onlyflags
            inc     hl
            djnz    .crcloop
            endif

            ; multibyte counter with arbitrary bit mask


.next       ld      hl,countmask
            ld      de,counter
            ld      b,vecsize
.countloop  ld      a,(de)
            or      a
            jr      z,.countnext
            dec     a
            and     (hl)
            ld      (de),a
            jp      .loop
.countnext  ld      a,(hl)
            ld      (de),a
            inc     l
            inc     e
            djnz    .countloop

            ; multibyte shifter with arbitrary bit mask

.maskptr    ld      hl,shiftmask
.valptr     ld      de,shifter
            ld      a,(de)
            add     a,a
            neg
            add     (hl)
            xor     (hl)
            and     (hl)
            ld      (de),a
            jp      nz,.loop
.shiftloop  inc     l
            inc     e
            ld      a,e
            cp      shiftend % 256
            jr      z,.exit
            ld      a,(hl)
            dec     a
            xor     (hl)
            and     (hl)
            jr      z,.shiftloop
            ld      (de),a
            ld      (.maskptr+1),hl
            ld      (.valptr+1),de
            jp      .loop

.exit       exx
.spptr      ld      sp,0
            ret

            ; misc helper routines

.copy       push    hl
            push    bc
            ldir
            pop     bc
            pop     hl
            ret

.clear      push    hl
            push    bc
            ld      h,d
            ld      l,e
            ld      (hl),0
            inc     de
            dec     bc
            ldir
            pop     bc
            pop     hl
            ret

            align   256

            include crctab.asm

; If this moves from 0x8800, all tests which use this address
; will need to have their CRCs updated, so don't move it.

            align   256
data
.regs       ds      datasize-4
.regstop
.mem        ds      2
.sp         ds      2

.jump
            if      postccf
            ccf
            else
            inc     bc
            endif
            jp      test.continue

; This entire workspace must be kept within one 256 page.

vector      ds      vecsize
counter     ds      vecsize
countmask   ds      vecsize
shifter     ds      1+vecsize
shiftend
shiftmask   ds      1+vecsize

; EOF ;
