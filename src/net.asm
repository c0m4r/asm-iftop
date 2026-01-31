; ============================================================================
; ASM-IFTOP Network Functions
; Interface discovery and info reading
; ============================================================================

%include "constants.inc"

section .bss
    path_buffer:    resb PATH_MAX
    temp_buffer:    resb BUFFER_SIZE

section .data
    proc_net_dev:   db "/proc/net/dev", 0
    lo_name:        db "lo", 0
    addr_file:      db "address", 0
    mtu_file:       db "mtu", 0
    speed_file:     db "speed", 0
    uevent_file:    db "device/uevent", 0
    driver_prefix:  db "DRIVER=", 0

section .text

extern read_file
extern build_sysfs_path
extern skip_whitespace
extern skip_to_whitespace
extern skip_to_newline
extern parse_uint64
extern copy_until_newline
extern str_compare
extern sys_socket
extern sys_ioctl
extern sys_close

; ----------------------------------------------------------------------------
; find_main_interface - Find first non-loopback interface
; Input: rdi = buffer to store interface name (at least IFNAMSIZ bytes)
; Output: rax = length of interface name, or 0 if not found
; ----------------------------------------------------------------------------
global find_main_interface
find_main_interface:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    sub     rsp, BUFFER_SIZE
    
    mov     r12, rdi            ; Interface name buffer
    
    ; Read /proc/net/dev
    lea     rdi, [rel proc_net_dev]
    lea     rsi, [rsp]
    mov     rdx, BUFFER_SIZE
    call    read_file
    test    rax, rax
    jle     .not_found
    
    ; Skip first two header lines
    lea     rdi, [rsp]
    call    skip_to_newline     ; Skip "Inter-|   Receive..."
    call    skip_to_newline     ; Skip " face |bytes..."
    
    mov     r13, rdi            ; Current position
    
.find_loop:
    ; Check for end of buffer
    movzx   rax, byte [r13]
    test    al, al
    jz      .not_found
    
    mov     rdi, r13
    call    skip_whitespace
    mov     r13, rdi
    
    ; Check for end
    movzx   rax, byte [r13]
    test    al, al
    jz      .not_found
    
    ; Find the colon (interface name ends at colon)
    mov     r14, r13            ; Start of interface name
    
.find_colon:
    movzx   rax, byte [r13]
    test    al, al
    jz      .not_found
    cmp     al, ':'
    je      .found_colon
    inc     r13
    jmp     .find_colon
    
.found_colon:
    ; Calculate interface name length
    mov     rbx, r13
    sub     rbx, r14            ; Length
    
    ; Skip "lo" interface
    cmp     rbx, 2
    jne     .check_interface
    mov     rdi, r14
    lea     rsi, [rel lo_name]
    mov     rdx, 2
    call    str_compare
    test    rax, rax
    jz      .skip_line          ; It's "lo", skip it
    
.check_interface:
    ; Copy interface name to output buffer
    xor     rcx, rcx
.copy_name:
    cmp     rcx, rbx
    jge     .copy_done
    mov     al, [r14 + rcx]
    mov     [r12 + rcx], al
    inc     rcx
    jmp     .copy_name
    
.copy_done:
    mov     byte [r12 + rbx], 0 ; Null terminate
    mov     rax, rbx            ; Return length
    jmp     .done
    
.skip_line:
    mov     rdi, r13
    call    skip_to_newline
    mov     r13, rdi
    jmp     .find_loop
    
.not_found:
    xor     rax, rax
    
.done:
    add     rsp, BUFFER_SIZE
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; get_interface_stats - Get RX and TX bytes for interface
; Input: rdi = interface name
;        rsi = pointer to store RX bytes (uint64)
;        rdx = pointer to store TX bytes (uint64)
; Output: rax = 0 on success, -1 on error
; ----------------------------------------------------------------------------
global get_interface_stats
get_interface_stats:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, BUFFER_SIZE + 32
    
    mov     r12, rdi            ; Interface name
    mov     r13, rsi            ; RX bytes pointer
    mov     r14, rdx            ; TX bytes pointer
    
    ; Read /proc/net/dev
    lea     rdi, [rel proc_net_dev]
    lea     rsi, [rsp]
    mov     rdx, BUFFER_SIZE
    call    read_file
    test    rax, rax
    jle     .error
    
    ; Skip header lines
    lea     rdi, [rsp]
    call    skip_to_newline
    call    skip_to_newline
    
    mov     r15, rdi            ; Current position
    
.search_loop:
    movzx   rax, byte [r15]
    test    al, al
    jz      .error
    
    mov     rdi, r15
    call    skip_whitespace
    mov     r15, rdi
    
    ; Check if this line matches our interface
    mov     rdi, r15
    mov     rsi, r12
    xor     rcx, rcx
.compare_name:
    movzx   rax, byte [rsi + rcx]
    test    al, al
    jz      .name_matched
    movzx   rbx, byte [rdi + rcx]
    cmp     al, bl
    jne     .next_line
    inc     rcx
    jmp     .compare_name
    
.name_matched:
    ; Check that next char is colon
    add     r15, rcx
    cmp     byte [r15], ':'
    jne     .next_line
    inc     r15                 ; Skip colon
    
    ; Parse RX bytes (first number after colon)
    mov     rdi, r15
    call    skip_whitespace
    call    parse_uint64
    mov     [r13], rax          ; Store RX bytes
    
    ; Skip to TX bytes (9th field after RX bytes)
    ; Fields: bytes, packets, errs, drop, fifo, frame, compressed, multicast
    ; Then TX: bytes, packets, errs, drop, fifo, colls, carrier, compressed
    mov     rcx, 8              ; Skip 8 fields to get to TX bytes
.skip_fields:
    call    skip_whitespace
    call    skip_to_whitespace
    dec     rcx
    jnz     .skip_fields
    
    ; Parse TX bytes
    call    skip_whitespace
    call    parse_uint64
    mov     [r14], rax          ; Store TX bytes
    
    xor     rax, rax            ; Success
    jmp     .done
    
.next_line:
    mov     rdi, r15
    call    skip_to_newline
    mov     r15, rdi
    jmp     .search_loop
    
.error:
    mov     rax, -1
    
.done:
    add     rsp, BUFFER_SIZE + 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; get_mac_address - Get MAC address for interface
; Input: rdi = interface name
;        rsi = buffer to store MAC (at least 18 bytes)
; Output: rax = length of MAC string, or 0 on error
; ----------------------------------------------------------------------------
global get_mac_address
get_mac_address:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    sub     rsp, PATH_MAX + BUFFER_SIZE
    
    mov     r12, rdi            ; Interface name
    mov     r13, rsi            ; Output buffer
    
    ; Build path: /sys/class/net/<iface>/address
    lea     rdi, [rsp + BUFFER_SIZE]
    mov     rsi, r12
    lea     rdx, [rel addr_file]
    call    build_sysfs_path
    
    ; Read the file
    lea     rdi, [rsp + BUFFER_SIZE]
    lea     rsi, [rsp]
    mov     rdx, BUFFER_SIZE
    call    read_file
    test    rax, rax
    jle     .error
    
    ; Copy to output (excluding newline)
    mov     rdi, r13
    lea     rsi, [rsp]
    call    copy_until_newline
    jmp     .done
    
.error:
    xor     rax, rax
    
.done:
    add     rsp, PATH_MAX + BUFFER_SIZE
    pop     r13
    pop     r12
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; get_mtu - Get MTU for interface
; Input: rdi = interface name
;        rsi = buffer to store MTU string (at least 8 bytes)
; Output: rax = length of MTU string, or 0 on error
; ----------------------------------------------------------------------------
global get_mtu
get_mtu:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    sub     rsp, PATH_MAX + BUFFER_SIZE
    
    mov     r12, rdi
    mov     r13, rsi
    
    lea     rdi, [rsp + BUFFER_SIZE]
    mov     rsi, r12
    lea     rdx, [rel mtu_file]
    call    build_sysfs_path
    
    lea     rdi, [rsp + BUFFER_SIZE]
    lea     rsi, [rsp]
    mov     rdx, BUFFER_SIZE
    call    read_file
    test    rax, rax
    jle     .error
    
    mov     rdi, r13
    lea     rsi, [rsp]
    call    copy_until_newline
    jmp     .done
    
.error:
    xor     rax, rax
    
.done:
    add     rsp, PATH_MAX + BUFFER_SIZE
    pop     r13
    pop     r12
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; get_link_speed - Get link speed for interface
; Input: rdi = interface name
;        rsi = buffer to store speed string (at least 16 bytes)
; Output: rax = length of speed string, or 0 on error
; ----------------------------------------------------------------------------
global get_link_speed
global get_link_speed_value
get_link_speed:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    sub     rsp, PATH_MAX + BUFFER_SIZE
    
    mov     r12, rdi
    mov     r13, rsi
    
    lea     rdi, [rsp + BUFFER_SIZE]
    mov     rsi, r12
    lea     rdx, [rel speed_file]
    call    build_sysfs_path
    
    lea     rdi, [rsp + BUFFER_SIZE]
    lea     rsi, [rsp]
    mov     rdx, BUFFER_SIZE
    call    read_file
    test    rax, rax
    jle     .error
    
    mov     rdi, r13
    lea     rsi, [rsp]
    call    copy_until_newline
    jmp     .done
    
.error:
    ; Return "N/A" if speed not available (e.g., virtual interfaces)
    mov     byte [r13], 'N'
    mov     byte [r13 + 1], '/'
    mov     byte [r13 + 2], 'A'
    mov     byte [r13 + 3], 0
    mov     rax, 3
    
.done:
    add     rsp, PATH_MAX + BUFFER_SIZE
    pop     r13
    pop     r12
    pop     rbp
    ret

; Get link speed as numeric value for percentage calculation
get_link_speed_value:
    push    rbp
    mov     rbp, rsp
    push    r12
    sub     rsp, PATH_MAX + BUFFER_SIZE
    
    mov     r12, rdi            ; Interface name
    
    lea     rdi, [rsp + BUFFER_SIZE]
    mov     rsi, r12
    lea     rdx, [rel speed_file]
    call    build_sysfs_path
    
    lea     rdi, [rsp + BUFFER_SIZE]
    lea     rsi, [rsp]
    mov     rdx, BUFFER_SIZE
    call    read_file
    test    rax, rax
    jle     .error
    
    ; Parse the speed value
    lea     rdi, [rsp]
    call    parse_uint64
    jmp     .done
    
.error:
    mov     rax, 100            ; Default to 100 Mbps if unknown
    
.done:
    add     rsp, PATH_MAX + BUFFER_SIZE
    pop     r12
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; get_driver - Get driver name for interface
; Input: rdi = interface name
;        rsi = buffer to store driver name (at least 32 bytes)
; Output: rax = length of driver string, or 0 on error
; ----------------------------------------------------------------------------
global get_driver
get_driver:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    sub     rsp, PATH_MAX + BUFFER_SIZE
    
    mov     r12, rdi
    mov     r13, rsi
    
    ; Build path: /sys/class/net/<iface>/device/uevent
    lea     rdi, [rsp + BUFFER_SIZE]
    mov     rsi, r12
    lea     rdx, [rel uevent_file]
    call    build_sysfs_path
    
    lea     rdi, [rsp + BUFFER_SIZE]
    lea     rsi, [rsp]
    mov     rdx, BUFFER_SIZE
    call    read_file
    test    rax, rax
    jle     .error
    
    ; Search for "DRIVER=" line
    lea     r14, [rsp]
.search_driver:
    movzx   rax, byte [r14]
    test    al, al
    jz      .error
    
    ; Compare with "DRIVER="
    mov     rdi, r14
    lea     rsi, [rel driver_prefix]
    mov     rdx, 7
    call    str_compare
    test    rax, rax
    jz      .found_driver
    
    ; Skip to next line
    mov     rdi, r14
    call    skip_to_newline
    mov     r14, rdi
    jmp     .search_driver
    
.found_driver:
    add     r14, 7              ; Skip "DRIVER="
    mov     rdi, r13
    mov     rsi, r14
    call    copy_until_newline
    jmp     .done
    
.error:
    ; Return "N/A" for virtual interfaces
    mov     byte [r13], 'N'
    mov     byte [r13 + 1], '/'
    mov     byte [r13 + 2], 'A'
    mov     byte [r13 + 3], 0
    mov     rax, 3
    
.done:
    add     rsp, PATH_MAX + BUFFER_SIZE
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ----------------------------------------------------------------------------
; get_ip_address - Get IPv4 address for interface using ioctl
; Input: rdi = interface name
;        rsi = buffer to store IP string (at least 16 bytes)
; Output: rax = length of IP string, or 0 on error
; ----------------------------------------------------------------------------
global get_ip_address
get_ip_address:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    sub     rsp, 64             ; struct ifreq is 40 bytes, align to 64
    
    mov     r12, rdi            ; Interface name
    mov     r13, rsi            ; Output buffer
    
    ; Copy interface name to ifreq.ifr_name
    xor     rcx, rcx
.copy_ifname:
    movzx   rax, byte [r12 + rcx]
    test    al, al
    jz      .ifname_done
    mov     [rsp + rcx], al
    inc     rcx
    cmp     rcx, IFNAMSIZ - 1
    jl      .copy_ifname
.ifname_done:
    mov     byte [rsp + rcx], 0
    
    ; Create socket
    mov     rdi, AF_INET
    mov     rsi, SOCK_DGRAM
    xor     rdx, rdx
    call    sys_socket
    test    rax, rax
    js      .error
    mov     rbx, rax            ; Save socket fd
    
    ; ioctl(sock, SIOCGIFADDR, &ifreq)
    mov     rdi, rbx
    mov     rsi, SIOCGIFADDR
    lea     rdx, [rsp]
    call    sys_ioctl
    
    push    rax                 ; Save ioctl result
    
    ; Close socket
    mov     rdi, rbx
    call    sys_close
    
    pop     rax
    test    rax, rax
    js      .error
    
    ; Extract IP from sockaddr_in at offset 16 (ifr_addr)
    ; sockaddr_in: family (2) + port (2) + addr (4)
    ; IP is at offset 16 + 4 = 20
    movzx   r8, byte [rsp + 20]
    movzx   r9, byte [rsp + 21]
    movzx   r10, byte [rsp + 22]
    movzx   r11, byte [rsp + 23]
    
    ; Format as "x.x.x.x"
    mov     rdi, r13
    
    ; First octet
    push    r9
    push    r10
    push    r11
    mov     rsi, r8
    call    .append_octet
    mov     byte [rdi], '.'
    inc     rdi
    pop     r11
    pop     r10
    pop     r9
    
    ; Second octet
    push    r10
    push    r11
    mov     rsi, r9
    call    .append_octet
    mov     byte [rdi], '.'
    inc     rdi
    pop     r11
    pop     r10
    
    ; Third octet
    push    r11
    mov     rsi, r10
    call    .append_octet
    mov     byte [rdi], '.'
    inc     rdi
    pop     r11
    
    ; Fourth octet
    mov     rsi, r11
    call    .append_octet
    
    mov     byte [rdi], 0
    mov     rax, rdi
    sub     rax, r13            ; Length
    jmp     .done
    
.error:
    ; Return "N/A" if no IP
    mov     byte [r13], 'N'
    mov     byte [r13 + 1], '/'
    mov     byte [r13 + 2], 'A'
    mov     byte [r13 + 3], 0
    mov     rax, 3
    
.done:
    add     rsp, 64
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; Helper: append octet to string
; Input: rdi = buffer pointer (updated), rsi = octet value
.append_octet:
    push    rbx
    mov     rax, rsi
    
    ; Handle 0
    test    rax, rax
    jnz     .not_zero
    mov     byte [rdi], '0'
    inc     rdi
    pop     rbx
    ret
    
.not_zero:
    ; Convert to decimal
    xor     rcx, rcx            ; digit count
    mov     rbx, 10
    
.div_loop:
    test    rax, rax
    jz      .reverse_digits
    xor     rdx, rdx
    div     rbx
    add     dl, '0'
    push    rdx
    inc     rcx
    jmp     .div_loop
    
.reverse_digits:
    test    rcx, rcx
    jz      .append_done
    pop     rdx
    mov     [rdi], dl
    inc     rdi
    dec     rcx
    jmp     .reverse_digits
    
.append_done:
    pop     rbx
    ret
