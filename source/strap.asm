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
  mov byte[fs.driveNumber], dl ; We moved the drive number to DL before exiting our bootloader

  push cs                      ; Set CS to DS
  pop ds

  pusha

  mov bx, _bootsector
  call LoadBootsector          ; Load our bootsector to _bootsector in memory
                               ; TODO: Make this a pointer pointer or something (so we don't store 512 literally empty bytes)

  popa

  mov si, motd                 ; Print our MOTD
  call Print

  .start:
    mov bx, command     ; Prepare the command buffer

    mov si, prompt      ; Print the command prompt
    call Print

    .loop:
      mov ah, 01h       ; 01h is the 'check for key in the buffer' method
      int 16h           ; of the 16h int
      jz .loop          ; Loop until we have a keypress in the buffer

      mov ah, 00h       ; 01h doesn't /remove/ the key from the buffer, though
      int 16h           ; 00h/16h reads the key into AL /and/ removes it from the buffer!

      cmp al, 0x0d      ; Was the enter key pressed?
      je .command       ; Then interpret the user's command

      mov ah, 0eh       ; Otherwise, just print the key character
      int 10h

      mov byte[bx], al  ; Also, copy the key into the command buffer (BX)
      inc bx            ; The next key will be loaded into the next byte of the command buffer

      jmp .loop

    .command:
      mov si, prefix    ; First, print our newline and pseudo-tab
      call Print
      mov si, nocommand ; We don't have /any/ commands, so print an error,
      call Print
      mov si, command   ; Followed by the command the user entered
      call Print

      .printCommands:
        mov ah, 0eh                      ; Add 2 newlines
        mov al, 0x0d                     ; TODO: Add a newline variable\subroutine
        int 10h
        mov al, 0x0a
        int 10h
        mov al, 0x0d
        int 10h
        mov al, 0x0a
        int 10h

        mov bx, binaries                 ; Prepare the list of our binaries for printing
        mov di, 11
        jmp .printCommands.printLoop

        .printCommands.loop:
          mov al, 0x0d                   ; Print a newline between each binary name
          int 10h
          mov al, 0x0a
          int 10h

          mov di, 11                     ; Each array is composed of an 11-character filename
          add bx, 2                      ; followed by a pointer to the file's cluster (we don't print the latter)

          cmp byte[bx], 0                ; We still have a null character to indicate the end of our array
          je .printCommands.done         ; If we reach it, we're done

          .printCommands.printLoop:
            mov al, byte[bx]             ; Print the character byte[BX] (which contains the next character to print)
            int 10h

            inc bx                       ; Go to the next character,
            dec di                       ; and indicate that we've printed one more out of the 11 we need to

            cmp di, 0                    ; If we've finished printing all 11,
            je .printCommands.loop       ; Then we're done (with this binary

            jmp .printCommands.printLoop ; Otherwise, keep going!

        .printCommands.done:

      ; We need to clear out the command buffer; otherwise, if the current command is shorter
      ; than the last, the end of the last will still be shown:
      ;   > copy
      ;      (copy is in the buffer)
      ;   > cp
      ;      (cpcy is in the buffer)
      .eraseCommand:
        mov bx, command          ; Get BX ready to erase

        .eraseCommand.loop:
          cmp byte[bx], 0xff     ; We use 0xFF as a 'null-character', we are replacing everything with 0's!
                                 ; TODO: This could be made more efficient by using the null character anyway: it would only remove the nonzero region
          je .start              ; We're done if we've reached it

          mov byte[bx], 0x00     ; Clear out byte[BX]
          inc bx                 ; Go to the next character in the buffer
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
  mov di, 5                    ; We'll use the usual 5 attempts to read from the disk

  mov bx, _bootsector          ; This is where we'll read the bootsector to
  mov ah, 02h                  ; 02h/13h reads from the disk
  mov al, 1                    ; We only want to read the bootsector (which is 1 sector)
  mov ch, 0                    ; The bootsector is the first track,
  mov cl, 1                    ; and the first sector,
  mov dh, 0                    ; AND the first head!
  mov dl, byte[fs.driveNumber] ; Read from the current disk, obviously

  LoadBootsector.loop:
    int 13h                    ; Read from the disk now, using our parameters from above
    jnc LoadBootsector.success ; We're done if we read the data in successfully
    dec di                     ; Otherwise, we need to try again

    jnz LoadBootsector.loop    ; Unless we've already tried again!
    jmp LoadBootsector.fail    ; RED ALERT
  LoadBootsector.success:
    popa
    ret
  LoadBootsector.fail:
    ; TODO: Leave the part up to the caller (set a flag or something)
    mov si, error
    call Print

    cli
    hlt
