org 0x00
bits 16

jmp _main

_data:
    motd db "Hello, World!", 0
    
_main:
    cli
    push cs
    pop ds
    mov si, motd
    call Print
    
    cli
    hlt

Print:
    pusha
    print.loop:
        lodsb
        cmp al, 0
        je print.end
        mov ah, 0eh
        int 10h
        jmp print.loop
    print.end:
        popa
        ret
