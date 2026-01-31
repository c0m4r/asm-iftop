; ============================================================================
; ASM-IFTOP - Network Interface Monitor
; Main entry point
; 
; A lightweight x86_64 assembly program that displays network interface
; information and live download/upload speeds in Mbps.
; ============================================================================

%include "constants.inc"

section .bss
    ; Interface info storage
    iface_name:     resb IFNAMSIZ
    mac_addr:       resb 32
    ip_addr:        resb 32
    mtu_val:        resb 16
    speed_val:      resb 16
    driver_name:    resb 64
    speed_buf:      resb 32
    key_buf:        resb 4
    
    ; Statistics
    prev_rx_bytes:  resq 1
    prev_tx_bytes:  resq 1
    curr_rx_bytes:  resq 1
    curr_tx_bytes:  resq 1
    link_speed:     resq 1          ; Link speed in Mbps

section .data
    timespec:
        tv_sec:     dq 0            ; 0 seconds  
        tv_nsec:    dq 100000000    ; 100ms (poll every 100ms for responsive 'q')
    
    ; pollfd structure for stdin
    pollfd:
        .fd:        dd 0            ; STDIN
        .events:    dw POLLIN       ; Wait for input
        .revents:   dw 0            ; Returned events
    
    poll_timeout:   dq 100          ; 100ms timeout
    refresh_counter: dq 0           ; Counter for 1-second refresh
    
    err_no_iface:   db "Error: No network interface found", 10, 0

section .text

extern sys_exit
extern sys_nanosleep
extern sys_write
extern sys_read
extern sys_poll

extern find_main_interface
extern get_interface_stats
extern get_mac_address
extern get_mtu
extern get_link_speed
extern get_link_speed_value
extern get_driver
extern get_ip_address

extern format_speed_mbps

extern clear_screen
extern hide_cursor
extern show_cursor
extern move_cursor_home
extern print_str
extern print_newline
extern print_header
extern print_speed_line
extern print_footer
extern setup_terminal
extern restore_terminal

global _start
_start:
    ; Find main network interface
    lea     rdi, [rel iface_name]
    call    find_main_interface
    test    rax, rax
    jz      .no_interface
    
    ; Get interface information
    ; MAC address
    lea     rdi, [rel iface_name]
    lea     rsi, [rel mac_addr]
    call    get_mac_address
    
    ; MTU
    lea     rdi, [rel iface_name]
    lea     rsi, [rel mtu_val]
    call    get_mtu
    
    ; Link speed (string for display)
    lea     rdi, [rel iface_name]
    lea     rsi, [rel speed_val]
    call    get_link_speed
    
    ; Link speed (numeric for percentage calculation)
    lea     rdi, [rel iface_name]
    call    get_link_speed_value
    mov     [rel link_speed], rax
    
    ; Driver
    lea     rdi, [rel iface_name]
    lea     rsi, [rel driver_name]
    call    get_driver
    
    ; IP address
    lea     rdi, [rel iface_name]
    lea     rsi, [rel ip_addr]
    call    get_ip_address
    
    ; Initialize previous stats
    lea     rdi, [rel iface_name]
    lea     rsi, [rel prev_rx_bytes]
    lea     rdx, [rel prev_tx_bytes]
    call    get_interface_stats
    
    ; Setup terminal for raw input
    call    setup_terminal
    
    ; Hide cursor and clear screen
    call    hide_cursor
    call    clear_screen
    
    ; Initialize refresh counter to 1 for immediate first display
    mov     qword [rel refresh_counter], 1
    
.main_loop:
    ; Check for keyboard input (non-blocking)
    lea     rdi, [rel pollfd]
    mov     rsi, 1              ; nfds = 1
    mov     rdx, 0              ; timeout = 0 (non-blocking)
    call    sys_poll
    
    ; If poll returned > 0, read the key
    test    rax, rax
    jle     .no_key
    
    ; Read the key
    mov     rdi, STDIN
    lea     rsi, [rel key_buf]
    mov     rdx, 1
    call    sys_read
    
    ; Check if 'q' or 'Q' was pressed
    movzx   rax, byte [rel key_buf]
    cmp     al, 'q'
    je      .exit_clean
    cmp     al, 'Q'
    je      .exit_clean
    
.no_key:
    ; Check refresh counter (refresh display every ~1 second = 10 * 100ms)
    dec     qword [rel refresh_counter]
    jnz     .sleep
    
    ; Reset counter
    mov     qword [rel refresh_counter], 10
    
    ; Clear screen completely to handle terminal resize
    call    clear_screen
    
    ; Print header with interface info
    lea     rdi, [rel iface_name]
    lea     rsi, [rel mac_addr]
    lea     rdx, [rel ip_addr]
    lea     rcx, [rel mtu_val]
    lea     r8, [rel speed_val]
    lea     r9, [rel driver_name]
    call    print_header
    
    ; Get current stats
    lea     rdi, [rel iface_name]
    lea     rsi, [rel curr_rx_bytes]
    lea     rdx, [rel curr_tx_bytes]
    call    get_interface_stats
    
    ; Calculate download speed (bytes/sec)
    mov     rax, [rel curr_rx_bytes]
    sub     rax, [rel prev_rx_bytes]
    push    rax                 ; Save RX delta
    
    ; Format download speed
    mov     rdi, rax
    lea     rsi, [rel speed_buf]
    call    format_speed_mbps
    
    ; Calculate download percentage
    ; Formula: pct = (delta_bytes * 8 * 100) / (link_speed_mbps * 1000000)
    pop     rax                 ; RX delta (bytes/sec)
    push    rax
    shl     rax, 3              ; bytes to bits
    imul    rax, 100            ; multiply by 100 FIRST to avoid truncation
    xor     rdx, rdx
    mov     rcx, [rel link_speed]
    imul    rcx, 1000000        ; Mbps to bps
    test    rcx, rcx
    jz      .dl_zero_pct
    div     rcx                 ; percentage = (bits * 100) / bps_capacity
    jmp     .dl_pct_done
.dl_zero_pct:
    xor     rax, rax
.dl_pct_done:
    cmp     rax, 100
    jle     .dl_pct_ok
    mov     rax, 100            ; Cap at 100%
.dl_pct_ok:
    mov     rdx, rax            ; percentage
    pop     rax                 ; discard saved RX delta
    
    ; Print download line
    mov     rdi, 1              ; is_download = 1
    lea     rsi, [rel speed_buf]
    call    print_speed_line
    
    ; Calculate upload speed (bytes/sec)
    mov     rax, [rel curr_tx_bytes]
    sub     rax, [rel prev_tx_bytes]
    push    rax                 ; Save TX delta
    
    ; Format upload speed
    mov     rdi, rax
    lea     rsi, [rel speed_buf]
    call    format_speed_mbps
    
    ; Calculate upload percentage
    ; Formula: pct = (delta_bytes * 8 * 100) / (link_speed_mbps * 1000000)
    pop     rax                 ; TX delta
    push    rax
    shl     rax, 3              ; bytes to bits
    imul    rax, 100            ; multiply by 100 FIRST to avoid truncation
    xor     rdx, rdx
    mov     rcx, [rel link_speed]
    imul    rcx, 1000000
    test    rcx, rcx
    jz      .ul_zero_pct
    div     rcx
    jmp     .ul_pct_done
.ul_zero_pct:
    xor     rax, rax
.ul_pct_done:
    cmp     rax, 100
    jle     .ul_pct_ok
    mov     rax, 100
.ul_pct_ok:
    mov     rdx, rax
    pop     rax
    
    ; Print upload line
    xor     rdi, rdi            ; is_download = 0
    lea     rsi, [rel speed_buf]
    call    print_speed_line
    
    ; Print footer
    call    print_footer
    
    ; Update previous stats
    mov     rax, [rel curr_rx_bytes]
    mov     [rel prev_rx_bytes], rax
    mov     rax, [rel curr_tx_bytes]
    mov     [rel prev_tx_bytes], rax

.sleep:
    ; Sleep 100ms
    lea     rdi, [rel timespec]
    call    sys_nanosleep
    
    ; Loop
    jmp     .main_loop

.no_interface:
    ; Print error and exit
    lea     rdi, [rel err_no_iface]
    call    print_str
    mov     rdi, 1
    call    sys_exit

.exit_clean:
    ; Restore terminal and show cursor
    call    restore_terminal
    call    show_cursor
    call    clear_screen
    xor     rdi, rdi
    call    sys_exit
