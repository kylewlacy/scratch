org 0
bits 16

jmp _main

_data:
  motd db "Hello, World!", 0x0d, 0x0a, 0
  prompt db 0x0d, 0x0a, "> ", 0
  prefix db 0x0d, 0x0a, "   ", 0
  nocommand db "No such command: ", 0
  error db "Fail", 0

  _bootsector:
    times 3 db 0

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

    times (512-62) db 0

  binaries:              ; This is where we will keep a list of binaries (debug data for now)
    db "CP         zzMV         zzLS         zz", 0
  command times 255 db 0 ; The command buffer
  db 0xff                ; Indicate the absolute end of our command buffer

  fs.driveNumber db 0    ; Stores the drive number
  fs.dataSector dw 0     ; Stores our data sector

  chs.track db 0         ; Stores the track\cylinder for LBAToCHS
  chs.head db 0          ; Stores the head for LBAToCHS
  chs.sector db 0        ; Stores the sector for LBAToCHS
 

_main:
  ; cli
  mov byte[fs.driveNumber], dl

  push cs
  pop ds

  pusha
  
  mov bx, _bootsector
  call LoadBootsector

  popa

  mov si, motd
  call Print

  .start:
    mov bx, command

    mov si, prompt
    call Print
    
    .loop:
      mov ah, 01h
      int 16h
      jz .loop

      mov ah, 00h
      int 16h

      cmp al, 0x0d
      je .command

      mov ah, 0eh
      int 10h

      mov byte[bx], al
      inc bx

      jmp .loop

    .command:
      mov si, prefix
      call Print
      mov si, nocommand
      call Print
      mov si, command
      call Print

      .printCommands:
        mov ah, 0eh
        mov al, 0x0d
        int 10h
        mov al, 0x0a
        int 10h
        mov al, 0x0d
        int 10h
        mov al, 0x0a
        int 10h

        mov bx, binaries
        mov di, 11
        jmp .printCommands.printLoop

        .printCommands.loop:
          mov al, 0x0d
          int 10h
          mov al, 0x0a
          int 10h

          mov di, 11
          add bx, 2

          cmp byte[bx], 0
          je .printCommands.done

          .printCommands.printLoop:
            mov al, byte[bx]
            int 10h

            inc bx
            dec di

            cmp di, 0
            je .printCommands.loop

            jmp .printCommands.printLoop

          .printCommands.donePrinting:
            
        .printCommands.done:

      .eraseCommand:
        mov bx, command

        .eraseCommand.loop:
          cmp byte[bx], 0xff
          je .start

          mov byte[bx], 0x00
          inc bx
          jmp .eraseCommand.loop

  
  cli
  hlt

%include "lib/base.inc"

; LoadBootsector - Loads the bootsector into memory
; Parameters:
;  ES:BX - Address to read to
;  byte[fs.driveNumber] - Drive number to use
; Returns:
;  [ES:BX] - The bootloader
LoadBootsector:
  pusha
  mov di, 5

  mov bx, _bootsector
  mov ah, 02h
  mov al, 1
  mov ch, 0
  mov cl, 1
  mov dh, 0
  mov dl, byte[fs.driveNumber]

  LoadBootsector.loop:
    int 13h
    jnc LoadBootsector.success
    dec di

    jnz LoadBootsector.loop
    jmp LoadBootsector.fail
  LoadBootsector.success:
    popa
    ret
  LoadBootsector.fail:
    mov si, error
    call Print

    cli
    hlt
