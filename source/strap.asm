org 0
bits 16

jmp _main

_data:
  motd db "Hello, World!", 0x0d, 0x0a, 0
  prompt db 0x0d, 0x0a, "> ", 0
  command db 0x0a, 0x07, "   No such command!", 0
  
_main:
  cli
  push cs
  pop ds
  mov si, motd
  call Print

  mov si, prompt
  call Print

  .loop:
    mov ah, 01h
    int 16h
    jz .loop

    mov ah, 00h
    int 16h

    cmp al, 0x0d
    mov ah, 0eh
    int 10h
    je .command
    jmp .loop

  .command:
    mov si, command
    call Print
    mov si, prompt
    call Print
    jmp .loop
  
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
