%ifndef BASE_INC
%define BASE_INC

; Print - Prints a null-terminated string
; Parameters:
;   SI - Null-terminated string to print
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

%endif
