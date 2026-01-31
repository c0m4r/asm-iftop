; ============================================================================
; ASM-IFTOP String Parsing
; Utilities for parsing numbers and strings
; ============================================================================

%include "constants.inc"

section .text

; ----------------------------------------------------------------------------
; parse_uint64 - Parse unsigned 64-bit integer from string
; Input: rdi = string pointer
; Output: rax = parsed value
;         rdi = pointer to first non-digit character
; ----------------------------------------------------------------------------
global parse_uint64
parse_uint64:
    xor     rax, rax            ; result = 0
    xor     rcx, rcx            ; temp for digit
    
.loop:
    movzx   rcx, byte [rdi]
    cmp     cl, '0'
    jb      .done
    cmp     cl, '9'
    ja      .done
    
    ; result = result * 10 + digit
    imul    rax, 10
    sub     cl, '0'
    add     rax, rcx
    inc     rdi
    jmp     .loop
    
.done:
    ret

; ----------------------------------------------------------------------------
; uint64_to_str - Convert unsigned 64-bit integer to string
; Input: rdi = value
;        rsi = buffer (must be at least 21 bytes)
; Output: rax = length of string
;         Buffer contains null-terminated string
; ----------------------------------------------------------------------------
global uint64_to_str
uint64_to_str:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    
    mov     rax, rdi            ; value
    mov     r12, rsi            ; buffer start
    mov     rbx, rsi            ; current position
    
    ; Handle zero case
    test    rax, rax
    jnz     .convert
    mov     byte [rbx], '0'
    inc     rbx
    jmp     .terminate
    
.convert:
    ; Convert digits in reverse order
    mov     rcx, 10
.digit_loop:
    test    rax, rax
    jz      .reverse
    xor     rdx, rdx
    div     rcx                 ; rax = quotient, rdx = remainder
    add     dl, '0'
    mov     [rbx], dl
    inc     rbx
    jmp     .digit_loop
    
.reverse:
    ; Reverse the string in place
    mov     rdi, r12            ; start
    lea     rsi, [rbx - 1]      ; end
.reverse_loop:
    cmp     rdi, rsi
    jge     .terminate
    mov     al, [rdi]
    mov     cl, [rsi]
    mov     [rdi], cl
    mov     [rsi], al
    inc     rdi
    dec     rsi
    jmp     .reverse_loop
    
.terminate:
    mov     byte [rbx], 0
    mov     rax, rbx
    sub     rax, r12            ; length = end - start
    
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; skip_whitespace - Skip spaces and tabs
; Input: rdi = string pointer
; Output: rdi = pointer to first non-whitespace character
; ----------------------------------------------------------------------------
global skip_whitespace
skip_whitespace:
.loop:
    movzx   rax, byte [rdi]
    cmp     al, ' '
    je      .next
    cmp     al, 9               ; tab
    je      .next
    ret
.next:
    inc     rdi
    jmp     .loop

; ----------------------------------------------------------------------------
; skip_to_whitespace - Skip until whitespace or end
; Input: rdi = string pointer
; Output: rdi = pointer to first whitespace character
; ----------------------------------------------------------------------------
global skip_to_whitespace
skip_to_whitespace:
.loop:
    movzx   rax, byte [rdi]
    test    al, al
    jz      .done
    cmp     al, ' '
    je      .done
    cmp     al, 9               ; tab
    je      .done
    cmp     al, 10              ; newline
    je      .done
    inc     rdi
    jmp     .loop
.done:
    ret

; ----------------------------------------------------------------------------
; skip_to_newline - Skip to next line
; Input: rdi = string pointer
; Output: rdi = pointer to start of next line (after newline)
; ----------------------------------------------------------------------------
global skip_to_newline
skip_to_newline:
.loop:
    movzx   rax, byte [rdi]
    test    al, al
    jz      .done
    inc     rdi
    cmp     al, 10              ; newline
    je      .done
    jmp     .loop
.done:
    ret

; ----------------------------------------------------------------------------
; find_char - Find character in string
; Input: rdi = string pointer, sil = character to find
; Output: rdi = pointer to character or end of string
;         rax = 1 if found, 0 if not
; ----------------------------------------------------------------------------
global find_char
find_char:
.loop:
    movzx   rax, byte [rdi]
    test    al, al
    jz      .not_found
    cmp     al, sil
    je      .found
    inc     rdi
    jmp     .loop
.found:
    mov     rax, 1
    ret
.not_found:
    xor     rax, rax
    ret

; ----------------------------------------------------------------------------
; copy_until_newline - Copy string until newline or null
; Input: rdi = destination, rsi = source
; Output: rax = bytes copied (excluding null terminator)
;         Destination is null-terminated
; ----------------------------------------------------------------------------
global copy_until_newline
copy_until_newline:
    push    rbx
    xor     rbx, rbx            ; counter
.loop:
    movzx   rax, byte [rsi + rbx]
    test    al, al
    jz      .done
    cmp     al, 10              ; newline
    je      .done
    cmp     al, 13              ; carriage return
    je      .done
    mov     [rdi + rbx], al
    inc     rbx
    jmp     .loop
.done:
    mov     byte [rdi + rbx], 0
    mov     rax, rbx
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; str_compare - Compare two strings
; Input: rdi = string1, rsi = string2, rdx = max length
; Output: rax = 0 if equal, non-zero otherwise
; ----------------------------------------------------------------------------
global str_compare
str_compare:
    xor     rcx, rcx
.loop:
    cmp     rcx, rdx
    jge     .equal
    movzx   r8, byte [rdi + rcx]
    movzx   r9, byte [rsi + rcx]
    cmp     r8b, r9b
    jne     .not_equal
    test    r8b, r8b
    jz      .equal
    inc     rcx
    jmp     .loop
.equal:
    xor     rax, rax
    ret
.not_equal:
    mov     rax, 1
    ret

; ----------------------------------------------------------------------------  
; format_speed_mbps - Format bytes/sec as Mbps with 2 decimal places
; Input: rdi = bytes per second
;        rsi = buffer (at least 16 bytes)
; Output: rax = length of formatted string
; Formula: Mbps = (bytes * 8) / 1,000,000
; ----------------------------------------------------------------------------
global format_speed_mbps
format_speed_mbps:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    
    mov     r12, rsi            ; buffer
    
    ; Calculate bits = bytes * 8
    shl     rdi, 3
    
    ; Calculate integer part: bits / 1,000,000
    mov     rax, rdi
    xor     rdx, rdx
    mov     rcx, 1000000
    div     rcx                 ; rax = integer Mbps, rdx = remainder
    
    mov     r13, rdx            ; Save remainder for decimal
    
    ; Convert integer part
    mov     rdi, rax
    mov     rsi, r12
    call    uint64_to_str
    mov     rbx, rax            ; Length of integer part
    
    ; Add decimal point
    mov     byte [r12 + rbx], '.'
    inc     rbx
    
    ; Calculate 2 decimal places: (remainder * 100) / 1,000,000  
    mov     rax, r13
    imul    rax, 100
    xor     rdx, rdx
    mov     rcx, 1000000
    div     rcx
    
    ; Ensure 2 digits (pad with leading zero if needed)
    cmp     rax, 10
    jge     .no_pad
    mov     byte [r12 + rbx], '0'
    inc     rbx
.no_pad:
    ; Convert decimal part
    mov     rdi, rax
    lea     rsi, [r12 + rbx]
    call    uint64_to_str
    add     rbx, rax
    
    mov     rax, rbx            ; Return total length
    
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
