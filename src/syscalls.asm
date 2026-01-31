; ============================================================================
; ASM-IFTOP Syscall Wrappers
; Pure x86_64 Linux syscall implementations
; ============================================================================

%include "constants.inc"

section .text

; ----------------------------------------------------------------------------
; sys_exit - Exit program
; Input: rdi = exit code
; ----------------------------------------------------------------------------
global sys_exit
sys_exit:
    mov     rax, SYS_EXIT
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_open - Open a file
; Input: rdi = filename, rsi = flags, rdx = mode
; Output: rax = file descriptor or negative error
; ----------------------------------------------------------------------------
global sys_open
sys_open:
    mov     rax, SYS_OPEN
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_read - Read from file descriptor
; Input: rdi = fd, rsi = buffer, rdx = count
; Output: rax = bytes read or negative error
; ----------------------------------------------------------------------------
global sys_read
sys_read:
    mov     rax, SYS_READ
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_write - Write to file descriptor
; Input: rdi = fd, rsi = buffer, rdx = count
; Output: rax = bytes written or negative error
; ----------------------------------------------------------------------------
global sys_write
sys_write:
    mov     rax, SYS_WRITE
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_close - Close file descriptor
; Input: rdi = fd
; Output: rax = 0 on success or negative error
; ----------------------------------------------------------------------------
global sys_close
sys_close:
    mov     rax, SYS_CLOSE
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_nanosleep - Sleep for specified time
; Input: rdi = pointer to timespec (seconds, nanoseconds)
; Output: rax = 0 on success or negative error
; ----------------------------------------------------------------------------
global sys_nanosleep
sys_nanosleep:
    xor     rsi, rsi            ; rem = NULL
    mov     rax, SYS_NANOSLEEP
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_socket - Create a socket
; Input: rdi = domain, rsi = type, rdx = protocol
; Output: rax = socket fd or negative error
; ----------------------------------------------------------------------------
global sys_socket
sys_socket:
    mov     rax, SYS_SOCKET
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_ioctl - I/O control
; Input: rdi = fd, rsi = request, rdx = arg
; Output: rax = 0 on success or negative error
; ----------------------------------------------------------------------------
global sys_ioctl
sys_ioctl:
    mov     rax, SYS_IOCTL
    syscall
    ret

; ----------------------------------------------------------------------------
; sys_poll - Wait for events on file descriptors
; Input: rdi = pollfd array, rsi = nfds, rdx = timeout_ms
; Output: rax = number of fds with events, 0 on timeout, negative on error
; ----------------------------------------------------------------------------
global sys_poll
sys_poll:
    mov     rax, 7              ; SYS_poll
    syscall
    ret
