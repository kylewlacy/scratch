org 0
bits 16

jmp _main

_bpb:
  _bpb.oem                db  "SCRATCH "    ; OEM name or version
  _bpb.bytesPerSector     dw  0x0200        ; Bytes per Sector (512)
  _bpb.sectorsPerCluster  db  0x04          ; Sectors per cluster (usually 1)
  _bpb.reservedSectors    dw  0x0001        ; Reserved sectors
  _bpb.totalFATs          db  0x02          ; FAT copies
  _bpb.rootEntries        dw  0x00e0        ; Root directory entries
  _bpb.fat12.totalSectors dw  0x0000        ; Sectors in filesystem (0 for FAT16)
  _bpb.mediaDescriptor    db  0xf0          ; Media descriptor type (f0 for floppy or f8 for HDD)
  _bpb.sectorsPerFAT      dw  0x0009        ; Sectors per FAT
  _bpb.sectorsPerTrack    dw  0x0012        ; Sectors per track
  _bpb.headsPerCylinder   dw  0x0002        ; Heads  per cylinder
  _bpb.hiddenSectors      dd  0x00000000    ; Number of hidden sectors (0)
  _bpb.totalSectors       dd  0x00030d40    ; Number of sectors in the filesystem
  _bpb.driveNumber        db  0x00          ; Sectors per FAT
  _bpb.currentHead        db  0x00          ; Reserved (used to be current head)
  _bpb.signature          db  0x29          ; Extended signature (indicates we have serial, label, and type)
  _bpb.serial             dd  0x1337d327    ; Serial number of partition
  _bpb.diskLabel          db  "OS DEV     " ; Volume label
  _bpb.fileSystem         db  "FAT16   "    ; Filesystem type

_data:
  filename db 'BOOT       '
  fileCluster  dw 0         ; Stores the cluster of the strap file

  fs.dataSector dw 0        ; Stores our data sector
  fs.driveNumber db 0       ; Stores the actual drive number

  chs.track db 0            ; Stores the track\cylinder for LBAToCHS
  chs.head db 0             ; Stores the head for LBAToCHS
  chs.sector db 0           ; Stores the sector for LBAToCHS

_main:
  ; Set up our segment registers and stack
  cli                             ; We don't want our interrupts ATM
  mov ax, 0x07c0                  ; We're at 0000:7c000, so set our segment registers to that
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax

  mov ax, 0                       ; Set our stack to 0x0000 and create it
  mov ss, ax
  mov sp, 0xffff
  sti                             ; We can haz interrupts again!

  mov byte[fs.driveNumber], dl

  .loadRootDir:
    xor cx, cx
    xor dx, dx
    mov ax, 0x0020                ; Every directory\file entry is 32 bytes (or 0x20)
    mul word[_bpb.rootEntries]    ; Entry size * number of root entries = size of root (in clusters)
    div word[_bpb.bytesPerSector] ; Clusters / sectors per cluster = sectors of root
    xchg ax, cx
    
    ; Compute the location of the FAT
    mov al, byte[_bpb.totalFATs]
    mul word[_bpb.sectorsPerFAT]
    add ax, word[_bpb.reservedSectors]
    mov word[fs.dataSector], ax
    add word[fs.dataSector], cx
    
    ; ; DEBUG
    ; push ax
    ; mov ah, 0eh
    ; mov al, 'T'
    ; int 10h
    ; pop ax
    
    ; Read the FAT to [7C00:0200]
    mov bx, 0x0200
    call ReadSectors
    push ax
    
    ; ; DEBUG
    ; mov ah, 0eh
    ; mov al, 'D'
    ; int 10h
    ; pop ax
    
    mov cx, word[_bpb.rootEntries] ; We want to iterate through each entry
    mov di, 0x0200                 ; The first entry will be here (at [7C00:0200])
  
  .findFile:
    push cx
    mov cx, 0x000b
    mov si, filename
    push di
    rep cmpsb
    pop di
    je .loadFile
    pop cx
    add di, 0x0020
    loop .findFile
    jmp .fail
  
  ; DI + 0x001A now contains the file's first cluster
  .loadFile:
    ; ; DEBUG
    ; push ax
    ; mov ah, 0eh
    ; mov al, 0x0d
    ; int 10h
    ; mov al, 0x0a
    ; int 10h
    ; mov al, 'F'
    ; int 10h
    ; pop ax
    
    .load.fat:
      mov dx, word[di+0x001a]
      mov word[fileCluster], dx          ; Save the file's first cluster to file

      ; Store FAT size in AX (FAT size = Number of FATs + Sectors per FAT)
      xor ax, ax
      mov al, byte[_bpb.totalFATs]
      mul word[_bpb.sectorsPerFAT]
      mov cx, ax

      mov ax, word[_bpb.reservedSectors] ; Store number of reserved sectors in AX

      mov bx, 0x0200
      call ReadSectors                   ; Copy the FAT to 0x0200
      
      ; ; DEBUG
      ; push ax
      ; mov ah, 0eh
      ; mov al, 'D'
      ; int 10h
      ; mov al, 0x0d
      ; int 10h
      ; mov al, 0x0a
      ; int 10h
      ; pop ax
      
      ; Load the next stage to [0050:0000]
      mov ax, 0x0050
      mov es, ax
      mov bx, 0x0000
      push bx
    
    .load.file:
      mov ax, word[fileCluster]
      pop bx
      call ClusterToLBA
      xor cx, cx
      mov cl, byte[_bpb.sectorsPerCluster]
      call ReadSectors
      push bx
      
      mov ax, word[fileCluster]
      mov cx, ax
      mov dx, ax
      shr dx, 0x0001
      add cx, dx
      mov bx, 0x0200
      add bx, cx
      mov dx, word[bx]
      
      ; ; DEBUG
      ; push ax
      ; mov ah, 0eh
      ; mov al, 'L'
      ; int 10h
      ; pop ax
      
      mov word[fileCluster], dx
      cmp dx, 0xfff8
      jb .load.file
      
      ; ; DEBUG
      ; push ax
      ; mov ah, 0eh
      ; mov al, 0x0d
      ; int 10h
      ; mov al, 0x0a
      ; int 10h
      ; pop ax
      
      push word 0x0050
      push word 0x0000
      retf
              
      cli
      hlt
      
  .fail:
  
    ; ; DEBUG
    ; push ax
    ; mov ah, 0eh
    ; mov al, 'E'
    ; int 10h
    ; pop ax
    
    ; mov ah, 00h
    ; int 16h
    ; int 19h

Print:
  pusha
  Print.loop:
    lodsb          ; Load the next character from SI

    cmp al, 0      ; If the character is null,
    je Print.end   ; then we're done

    mov ah, 0eh    ; Use the 'print character' function
    int 10h        ; Call the 'video services' interrupt
    jmp Print.loop ; Print the next character as well

  Print.end:
    popa
    ret

; Cluster to LBA - Convert from a cluster- to LBA- addressing system
; Parameters:
; AX - Cluster address to convert
; Returns:
; AX - Start of LBA
; CX - Length of LBA
ClusterToLBA: ; Based on the conversion equation LBA = ((Cluster - 2) * SectorsPerCluster)
  sub ax, 2
  xor cx, cx
  mov cl, byte[_bpb.sectorsPerCluster]
  mul cx
  add ax, word[fs.dataSector]
  
  ret

; LBA to CHS - Convert from an LBA- to CHS- addressing system'
; Parameters:
;  AX - LBA address to convert
; Returns:
;  [chs.track]
;  [chs.head]
;  [chs.sector]
LBAToCHS: 
  ; Based on the equation Sector = (LBA % Sectors per Track) + 1
  xor dx, dx
  div word[_bpb.sectorsPerTrack]        ; Calculate the modulo (in DL)
  inc dl
  mov byte[chs.sector], dl          ; Store it
  
  ; Based on the equation Head = (LBA / Sectors per Track) % Heads per Cylinder
  xor dx, dx
  div WORD [_bpb.headsPerCylinder]        ; AX already contains LBA / Sectors per Track
  mov byte[chs.head], dl
  
  ; Based on the equation Track = LBA / (Sectors per Track * Number of Heads)
  mov byte[chs.track], al           ; Very conveniently-placed AX; it already contains the output!
  
  ret

; Read Sectors - Reads sectors from disk into memory
; Parameters:
;  CX - Number of sectors to read
;  AX - Starting sector to read
;  ES:BX - Address to read to
; Returns:
;  [ES:BX] - Data from disk
ReadSectors:
  mov di, 0x0005                ; How many times should we retry the read?
  
  ReadSectors.loop:
    ; ; DEBUG
    ; push ax
    ; mov ah, 0eh
    ; mov al, '-'
    ; int 10h
    ; pop ax
    
    push ax
    push bx
    push cx
    
    call LBAToCHS
    
    mov ah, 02h                  ; Set the interrupt to the 'read sector' function
    mov al, 1                    ; Only read one sector
    mov ch, byte[chs.track]      ; The track to read from
    mov cl, byte[chs.sector]     ; The sector to read from
    mov dh, byte[chs.head]       ; The head to read from
    mov dl, byte[fs.driveNumber] ; The drive to read from
    int 13h                      ; Call our 'disk IO' interrupt
    jnc ReadSectors.success      ; If we successfully read the data, we don't have to try again
    mov ah, 00h                  ; Set the interrupt to the 'reset disk' function
    int 13h                      ; Call our 'disk IO' interrupt
    dec di                       ; Decrement our error counter
    pop cx
    pop bx
    pop ax
    jnz ReadSectors.loop         ; Try again if we've failed
    jmp ReadSectors.fail         ; RED ALERT
  
  ReadSectors.success:
    ; ; DEBUG
    ; push ax
    ; mov ah, 0eh
    ; mov al, '_'
    ; int 10h
    ; pop ax
    
    pop cx
    pop bx
    pop ax
    
    add bx, word[_bpb.bytesPerSector] ; Go to the next memory location
    inc ax                            ; Read from the next sector
    loop ReadSectors
    
    ret
  ReadSectors.fail:
    ; ; DEBUG
    ; push ax
    ; mov ah, 0eh
    ; mov al, 'R'
    ; int 10h
    ; pop ax
    
    pop cx
    pop bx
    pop ax
    
    int 18h ; Call the interrupt indicating a boot failure
    ret

times 510-($-$$) db 0
dw 0xaa55
