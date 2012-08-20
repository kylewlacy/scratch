org 0
bits 16

jmp _main

_data:
  motd db "Hello, World!", 0x0d, 0x0a, 0
  prompt db 0x0d, 0x0a, "> ", 0
  command db 0x0a, 0x07, "   No such command!", 0
  equal db "Equal", 0
  notEqual db "Not equal", 0

  ; This is where we will copy the BPB to in memory
  _bpb:
    _bpb.oem                db  "        "    ; OEM name or version
    _bpb.bytesPerSector     dw  0x0000        ; Bytes per Sector (512)
    _bpb.sectorsPerCluster  db  0x00          ; Sectors per cluster (usually 1)
    _bpb.reservedSectors    dw  0x0000        ; Reserved sectors
    _bpb.totalFATs          db  0x00          ; FAT copies
    _bpb.rootEntries        dw  0x0000        ; Root directory entries
    _bpb.fat12.totalSectors dw  0x0000        ; Sectors in filesystem (0 for FAT16)
    _bpb.mediaDescriptor    db  0x00          ; Media descriptor type (f0 for floppy or f8 for HDD)
    _bpb.sectorsPerFAT      dw  0x0000        ; Sectors per FAT
    _bpb.sectorsPerTrack    dw  0x0000        ; Sectors per track
    _bpb.headsPerCylinder   dw  0x0000        ; Heads  per cylinder
    _bpb.hiddenSectors      dd  0x00000000    ; Number of hidden sectors (0)
    _bpb.totalSectors       dd  0x00000000    ; Number of sectors in the filesystem
    _bpb.driveNumber        db  0x00          ; Sectors per FAT
    _bpb.currentHead        db  0x00          ; Reserved (used to be current head)
    _bpb.signature          db  0x00          ; Extended signature (indicates we have serial, label, and type)
    _bpb.serial             dd  0x00000000    ; Serial number of partition
    _bpb.diskLabel          db  "           " ; Volume label
    _bpb.fileSystem         db  "        "    ; Filesystem type

  fs.driveNumber db 0 ; Stores the drive number
  fs.dataSector dw 0  ; Stores our data sector

  chs.track db 0      ; Stores the track\cylinder for LBAToCHS
  chs.head db 0       ; Stores the head for LBAToCHS
  chs.sector db 0     ; Stores the sector for LBAToCHS
 

_main:
  cli
  push cs
  pop ds

  .loadBpb:
    pusha
    push ds
    push di

    mov bx, 0x7c03
    mov cx, _bpb
    mov di, 62
    mov ax, 0
    mov ds, ax

    mov ah, 0eh
    .loadBpb.loop:
      mov al, byte[bx]
      xchg bx, cx
      mov byte[bx], al
      xchg cx, bx
      
      add al, 34
      int 10h
      sub al, 34

      inc bx
      inc cx

      dec di

      jnz .loadBpb.loop

    pop di
    pop ds
    popa

  cmp word[_bpb.bytesPerSector], 0
  jne .not
  jmp .equal

  .equal:
  mov si, equal
  call Print
  jmp .start

  .not:
  mov si, notEqual
  call Print
  jmp .start

  .start:
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

%include "lib/base.inc"
