; ============================================================================
; ASM-IFTOP I/O Helpers
; File reading utilities
; ============================================================================

%include "constants.inc"

section .text

extern sys_open
extern sys_read
extern sys_close

; ----------------------------------------------------------------------------
; read_file - Read entire file content into buffer
; Input: rdi = filename (null-terminated)
;        rsi = buffer pointer
;        rdx = buffer size
; Output: rax = bytes read, or negative error
;         Buffer contains file content (null-terminated)
; ----------------------------------------------------------------------------
global read_file
read_file:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    
    mov     r12, rsi            ; Save buffer pointer
    mov     r13, rdx            ; Save buffer size
    
    ; Open file
    xor     rsi, rsi            ; O_RDONLY
    xor     rdx, rdx            ; mode = 0
    call    sys_open
    test    rax, rax
    js      .error              ; Jump if negative (error)
    
    mov     rbx, rax            ; Save fd
    
    ; Read file
    mov     rdi, rbx            ; fd
    mov     rsi, r12            ; buffer
    mov     rdx, r13
    dec     rdx                 ; Leave room for null terminator
    call    sys_read
    
    push    rax                 ; Save bytes read
    
    ; Null-terminate
    test    rax, rax
    js      .close_error
    mov     byte [r12 + rax], 0
    
    ; Close file
    mov     rdi, rbx
    call    sys_close
    
    pop     rax                 ; Restore bytes read
    jmp     .done

.close_error:
    mov     rdi, rbx
    call    sys_close
    pop     rax                 ; Return the error code

.error:
.done:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; build_sysfs_path - Build path like /sys/class/net/<iface>/<file>
; Input: rdi = destination buffer
;        rsi = interface name
;        rdx = file name (e.g., "address", "mtu")
; Output: rax = length of path
; ----------------------------------------------------------------------------
global build_sysfs_path
build_sysfs_path:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    
    mov     r12, rdi            ; dest buffer
    mov     r13, rsi            ; interface name
    mov     r14, rdx            ; file name
    
    ; Copy prefix: /sys/class/net/
    lea     rsi, [rel sysfs_prefix]
    mov     rdi, r12
    xor     rcx, rcx
.copy_prefix:
    mov     al, [rsi + rcx]
    test    al, al
    jz      .prefix_done
    mov     [rdi + rcx], al
    inc     rcx
    jmp     .copy_prefix
    
.prefix_done:
    mov     rbx, rcx            ; Current position
    
    ; Copy interface name
    mov     rsi, r13
    xor     rcx, rcx
.copy_iface:
    mov     al, [rsi + rcx]
    test    al, al
    jz      .iface_done
    cmp     al, 10              ; Stop at newline
    je      .iface_done
    cmp     al, ' '             ; Stop at space
    je      .iface_done
    mov     [r12 + rbx], al
    inc     rbx
    inc     rcx
    jmp     .copy_iface
    
.iface_done:
    ; Add slash
    mov     byte [r12 + rbx], '/'
    inc     rbx
    
    ; Copy file name
    mov     rsi, r14
    xor     rcx, rcx
.copy_file:
    mov     al, [rsi + rcx]
    test    al, al
    jz      .file_done
    mov     [r12 + rbx], al
    inc     rbx
    inc     rcx
    jmp     .copy_file
    
.file_done:
    ; Null terminate
    mov     byte [r12 + rbx], 0
    mov     rax, rbx            ; Return length
    
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

section .rodata
sysfs_prefix: db "/sys/class/net/", 0
