; ============================================================================
; ASM-IFTOP Display Functions
; Terminal output and formatting
; ============================================================================

%include "constants.inc"

section .data
    ; ANSI escape sequences
    ansi_clear:         db ESC, "[2J", ESC, "[H", 0
    ansi_clear_len:     equ $ - ansi_clear - 1
    ansi_hide_cursor:   db ESC, "[?25l", 0
    ansi_show_cursor:   db ESC, "[?25h", 0
    ansi_move_home:     db ESC, "[H", 0
    ansi_bold:          db ESC, "[1m", 0
    ansi_reset:         db ESC, "[0m", 0
    ansi_green:         db ESC, "[32m", 0
    ansi_cyan:          db ESC, "[36m", 0
    ansi_yellow:        db ESC, "[33m", 0
    
    ; Box drawing (UTF-8)
    box_tl:     db 0xE2, 0x95, 0x94, 0  ; ╔
    box_tr:     db 0xE2, 0x95, 0x97, 0  ; ╗
    box_bl:     db 0xE2, 0x95, 0x9A, 0  ; ╚
    box_br:     db 0xE2, 0x95, 0x9D, 0  ; ╝
    box_h:      db 0xE2, 0x95, 0x90, 0  ; ═
    box_v:      db 0xE2, 0x95, 0x91, 0  ; ║
    box_lm:     db 0xE2, 0x95, 0xA0, 0  ; ╠
    box_rm:     db 0xE2, 0x95, 0xA3, 0  ; ╣
    
    ; Progress bar characters
    bar_full:   db 0xE2, 0x96, 0x88, 0  ; █
    bar_empty:  db 0xE2, 0x96, 0x91, 0  ; ░
    
    ; Arrows
    arrow_down: db 0xE2, 0x96, 0xBC, 0  ; ▼
    arrow_up:   db 0xE2, 0x96, 0xB2, 0  ; ▲
    
    ; Labels
    title_text:     db "ASM-IFTOP Network Monitor", 0
    lbl_interface:  db "  Interface: ", 0
    lbl_mac:        db "  MAC:       ", 0
    lbl_ip:         db "  IP:        ", 0
    lbl_mtu:        db "  MTU:       ", 0
    lbl_speed:      db "  Speed:     ", 0
    lbl_driver:     db "  Driver:    ", 0
    lbl_download:   db "  ", 0
    lbl_upload:     db "  ", 0
    lbl_mbps:       db " Mbps", 0
    space_pad:      db "                                        ", 0
    newline:        db 10, 0

section .bss
    line_buffer:    resb 128
    orig_termios:   resb 60         ; Original terminal settings
    new_termios:    resb 60         ; Modified terminal settings

section .text

extern sys_write
extern sys_ioctl

; ----------------------------------------------------------------------------
; print_str - Print null-terminated string
; Input: rdi = string pointer
; Output: none
; ----------------------------------------------------------------------------
global print_str
print_str:
    push    rbx
    mov     rbx, rdi
    
    ; Find length
    xor     rcx, rcx
.len_loop:
    cmp     byte [rbx + rcx], 0
    je      .print
    inc     rcx
    jmp     .len_loop
    
.print:
    mov     rdi, STDOUT
    mov     rsi, rbx
    mov     rdx, rcx
    call    sys_write
    
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; print_newline - Print newline character
; ----------------------------------------------------------------------------
global print_newline
print_newline:
    mov     rdi, STDOUT
    lea     rsi, [rel newline]
    mov     rdx, 1
    call    sys_write
    ret

; ----------------------------------------------------------------------------
; clear_screen - Clear terminal and move cursor home
; ----------------------------------------------------------------------------
global clear_screen
clear_screen:
    mov     rdi, STDOUT
    lea     rsi, [rel ansi_clear]
    mov     rdx, ansi_clear_len
    call    sys_write
    ret

; ----------------------------------------------------------------------------
; hide_cursor - Hide terminal cursor
; ----------------------------------------------------------------------------
global hide_cursor
hide_cursor:
    lea     rdi, [rel ansi_hide_cursor]
    call    print_str
    ret

; ----------------------------------------------------------------------------
; show_cursor - Show terminal cursor
; ----------------------------------------------------------------------------
global show_cursor
show_cursor:
    lea     rdi, [rel ansi_show_cursor]
    call    print_str
    ret

; ----------------------------------------------------------------------------
; move_cursor_home - Move cursor to top-left
; ----------------------------------------------------------------------------
global move_cursor_home
move_cursor_home:
    lea     rdi, [rel ansi_move_home]
    call    print_str
    ret

; ----------------------------------------------------------------------------
; setup_terminal - Set terminal to raw mode (non-canonical, no echo)
; Saves original settings for later restoration
; ----------------------------------------------------------------------------
global setup_terminal
setup_terminal:
    push    rbx
    
    ; Get current terminal settings
    mov     rdi, STDIN
    mov     rsi, TCGETS
    lea     rdx, [rel orig_termios]
    call    sys_ioctl
    
    ; Copy to new settings
    lea     rsi, [rel orig_termios]
    lea     rdi, [rel new_termios]
    mov     rcx, 60                 ; termios struct size
    rep     movsb
    
    ; Modify c_lflag (offset 12): clear ICANON and ECHO
    mov     eax, [rel new_termios + 12]
    and     eax, ~(ICANON | ECHO)
    mov     [rel new_termios + 12], eax
    
    ; Set new terminal settings
    mov     rdi, STDIN
    mov     rsi, TCSETS
    lea     rdx, [rel new_termios]
    call    sys_ioctl
    
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; restore_terminal - Restore original terminal settings
; ----------------------------------------------------------------------------
global restore_terminal
restore_terminal:
    mov     rdi, STDIN
    mov     rsi, TCSETS
    lea     rdx, [rel orig_termios]
    call    sys_ioctl
    ret

section .text

; ----------------------------------------------------------------------------
; print_horizontal_line - Print horizontal box line
; Input: rdi = left char, rsi = right char
; ----------------------------------------------------------------------------
print_horizontal_line:
    push    rbx
    push    r12
    push    r13
    
    mov     r12, rdi            ; Left char
    mov     r13, rsi            ; Right char
    
    ; Print left corner
    mov     rdi, r12
    call    print_str
    
    ; Print 54 horizontal chars
    mov     rbx, 54
.loop:
    lea     rdi, [rel box_h]
    call    print_str
    dec     rbx
    jnz     .loop
    
    ; Print right corner
    mov     rdi, r13
    call    print_str
    
    call    print_newline
    
    pop     r13
    pop     r12
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; print_box_line - Print text line with box borders
; Input: rdi = text to print
; ----------------------------------------------------------------------------
global print_box_line
print_box_line:
    push    rbx
    push    r12
    
    mov     r12, rdi
    
    lea     rdi, [rel box_v]
    call    print_str
    
    mov     rdi, r12
    call    print_str
    
    ; Pad to width (calculate remaining space)
    ; We want total 54 chars between borders
    mov     rdi, r12
    xor     rcx, rcx
.len:
    cmp     byte [rdi + rcx], 0
    je      .pad
    inc     rcx
    jmp     .len
    
.pad:
    mov     rbx, 54
    sub     rbx, rcx
    jle     .end_border
    
.pad_loop:
    mov     rdi, STDOUT
    lea     rsi, [rel space_pad]
    mov     rdx, 1
    push    rbx
    call    sys_write
    pop     rbx
    dec     rbx
    jnz     .pad_loop
    
.end_border:
    lea     rdi, [rel box_v]
    call    print_str
    call    print_newline
    
    pop     r12
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; print_header - Print the interface info header
; Input: rdi = interface name
;        rsi = mac address  
;        rdx = ip address
;        rcx = mtu
;        r8 = speed
;        r9 = driver
; ----------------------------------------------------------------------------
global print_header
print_header:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 128
    
    ; Save all parameters
    mov     [rsp], rdi          ; interface
    mov     [rsp + 8], rsi      ; mac
    mov     [rsp + 16], rdx     ; ip
    mov     [rsp + 24], rcx     ; mtu
    mov     [rsp + 32], r8      ; speed
    mov     [rsp + 40], r9      ; driver
    
    ; Top border
    lea     rdi, [rel box_tl]
    lea     rsi, [rel box_tr]
    call    print_horizontal_line
    
    ; Title line (centered)
    lea     rdi, [rel box_v]
    call    print_str
    lea     rdi, [rel space_pad]
    mov     rsi, rdi
    mov     rdx, 14             ; Padding for centering
    mov     rdi, STDOUT
    call    sys_write
    lea     rdi, [rel ansi_bold]
    call    print_str
    lea     rdi, [rel ansi_cyan]
    call    print_str
    lea     rdi, [rel title_text]
    call    print_str
    lea     rdi, [rel ansi_reset]
    call    print_str
    mov     rdi, STDOUT
    lea     rsi, [rel space_pad]
    mov     rdx, 15
    call    sys_write
    lea     rdi, [rel box_v]
    call    print_str
    call    print_newline
    
    ; Middle separator
    lea     rdi, [rel box_lm]
    lea     rsi, [rel box_rm]
    call    print_horizontal_line
    
    ; Interface line
    lea     rdi, [rsp + 64]
    lea     rsi, [rel lbl_interface]
    call    .build_info_line
    mov     rsi, [rsp]          ; interface name
    call    .append_str
    mov     byte [rdi], 0
    lea     rdi, [rsp + 64]
    call    print_box_line
    
    ; MAC line
    lea     rdi, [rsp + 64]
    lea     rsi, [rel lbl_mac]
    call    .build_info_line
    mov     rsi, [rsp + 8]
    call    .append_str
    mov     byte [rdi], 0
    lea     rdi, [rsp + 64]
    call    print_box_line
    
    ; IP line
    lea     rdi, [rsp + 64]
    lea     rsi, [rel lbl_ip]
    call    .build_info_line
    mov     rsi, [rsp + 16]
    call    .append_str
    mov     byte [rdi], 0
    lea     rdi, [rsp + 64]
    call    print_box_line
    
    ; MTU line
    lea     rdi, [rsp + 64]
    lea     rsi, [rel lbl_mtu]
    call    .build_info_line
    mov     rsi, [rsp + 24]
    call    .append_str
    mov     byte [rdi], 0
    lea     rdi, [rsp + 64]
    call    print_box_line
    
    ; Speed line
    lea     rdi, [rsp + 64]
    lea     rsi, [rel lbl_speed]
    call    .build_info_line
    mov     rsi, [rsp + 32]
    call    .append_str
    ; Check if speed is numeric (not N/A)
    mov     rsi, [rsp + 32]
    movzx   rax, byte [rsi]
    cmp     al, 'N'
    je      .skip_mbps_label
    lea     rsi, [rel lbl_mbps]
    call    .append_str
.skip_mbps_label:
    mov     byte [rdi], 0
    lea     rdi, [rsp + 64]
    call    print_box_line
    
    ; Driver line
    lea     rdi, [rsp + 64]
    lea     rsi, [rel lbl_driver]
    call    .build_info_line
    mov     rsi, [rsp + 40]
    call    .append_str
    mov     byte [rdi], 0
    lea     rdi, [rsp + 64]
    call    print_box_line
    
    ; Middle separator before speeds
    lea     rdi, [rel box_lm]
    lea     rsi, [rel box_rm]
    call    print_horizontal_line
    
    add     rsp, 128
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; Helper: build info line start
.build_info_line:
    push    rcx
    xor     rcx, rcx
.copy_label:
    movzx   rax, byte [rsi + rcx]
    test    al, al
    jz      .label_done
    mov     [rdi + rcx], al
    inc     rcx
    jmp     .copy_label
.label_done:
    add     rdi, rcx
    pop     rcx
    ret

; Helper: append string
.append_str:
    push    rcx
    xor     rcx, rcx
.copy_str:
    movzx   rax, byte [rsi + rcx]
    test    al, al
    jz      .str_done
    mov     [rdi + rcx], al
    inc     rcx
    jmp     .copy_str
.str_done:
    add     rdi, rcx
    pop     rcx
    ret

; ----------------------------------------------------------------------------
; print_speed_line - Print a speed line with progress bar
; Input: rdi = is_download (1=download, 0=upload)
;        rsi = speed string (Mbps formatted)
;        rdx = percentage (0-100)
; ----------------------------------------------------------------------------
global print_speed_line
print_speed_line:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    sub     rsp, 128
    
    mov     r12, rdi            ; is_download
    mov     r13, rsi            ; speed string
    mov     r14, rdx            ; percentage
    
    ; Line 1: Arrow + label + speed
    lea     rdi, [rel box_v]
    call    print_str
    lea     rdi, [rel lbl_download]
    call    print_str
    
    ; Print arrow
    test    r12, r12
    jz      .upload_arrow
    lea     rdi, [rel ansi_green]
    call    print_str
    lea     rdi, [rel arrow_down]
    jmp     .print_arrow
.upload_arrow:
    lea     rdi, [rel ansi_yellow]
    call    print_str
    lea     rdi, [rel arrow_up]
.print_arrow:
    call    print_str
    lea     rdi, [rel ansi_reset]
    call    print_str
    
    ; Print label
    test    r12, r12
    jz      .upload_label
    mov     rdi, STDOUT
    lea     rsi, [rel download_lbl]
    mov     rdx, 11
    call    sys_write
    jmp     .print_speed_value
.upload_label:
    mov     rdi, STDOUT
    lea     rsi, [rel upload_lbl]
    mov     rdx, 11
    call    sys_write
    
.print_speed_value:
    ; Print speed value (right-aligned in 8 chars)
    mov     rdi, r13
    xor     rcx, rcx
.speed_len:
    cmp     byte [rdi + rcx], 0
    je      .speed_pad
    inc     rcx
    jmp     .speed_len
.speed_pad:
    mov     rbx, 8
    sub     rbx, rcx
    jle     .print_speed_str
.pad_speed:
    mov     rdi, STDOUT
    lea     rsi, [rel space_pad]
    mov     rdx, 1
    push    rbx
    push    rcx
    call    sys_write
    pop     rcx
    pop     rbx
    dec     rbx
    jnz     .pad_speed
    
.print_speed_str:
    mov     rdi, r13
    call    print_str
    lea     rdi, [rel lbl_mbps]
    call    print_str
    
    ; Padding to border (54 - 2 - 1 - 11 - 8 - 5 = 27 spaces)
    mov     rdi, STDOUT
    lea     rsi, [rel space_pad]
    mov     rdx, 27
    call    sys_write
    
    lea     rdi, [rel box_v]
    call    print_str
    call    print_newline
    
    ; Line 2: Progress bar
    lea     rdi, [rel box_v]
    call    print_str
    mov     rdi, STDOUT
    lea     rsi, [rel space_pad]
    mov     rdx, 4
    call    sys_write
    
    ; Print [ 
    mov     rdi, STDOUT
    lea     rsi, [rel bracket_open]
    mov     rdx, 1
    call    sys_write
    
    ; Calculate filled blocks (30 blocks total)
    mov     rax, r14            ; percentage
    imul    rax, 30
    xor     rdx, rdx
    mov     rcx, 100
    div     rcx                 ; rax = filled blocks
    mov     rbx, rax
    
    ; Print filled blocks
    test    rbx, rbx
    jz      .empty_blocks
.fill_loop:
    test    r12, r12
    jz      .upload_color
    lea     rdi, [rel ansi_green]
    jmp     .print_fill
.upload_color:
    lea     rdi, [rel ansi_yellow]
.print_fill:
    call    print_str
    lea     rdi, [rel bar_full]
    call    print_str
    lea     rdi, [rel ansi_reset]
    call    print_str
    dec     rbx
    jnz     .fill_loop
    
.empty_blocks:
    ; Calculate and print empty blocks
    mov     rax, r14
    imul    rax, 30
    xor     rdx, rdx
    mov     rcx, 100
    div     rcx
    mov     rbx, 30
    sub     rbx, rax
    jle     .close_bracket
    
.empty_loop:
    lea     rdi, [rel bar_empty]
    call    print_str
    dec     rbx
    jnz     .empty_loop
    
.close_bracket:
    mov     rdi, STDOUT
    lea     rsi, [rel bracket_close]
    mov     rdx, 1
    call    sys_write
    
    ; Print percentage
    mov     rdi, STDOUT
    lea     rsi, [rel space_pad]
    mov     rdx, 2
    call    sys_write
    
    ; Format percentage
    mov     rax, r14
    lea     rdi, [rsp]
    call    .format_percentage
    lea     rdi, [rsp]
    call    print_str
    mov     rdi, STDOUT
    lea     rsi, [rel percent_sign]
    mov     rdx, 1
    call    sys_write
    
    ; Padding to border (54 - 4 - 1 - 30 - 1 - 2 - 3 - 1 = 12 + 2 extra for UTF-8 blocks = 14)
    mov     rdi, STDOUT
    lea     rsi, [rel space_pad]
    mov     rdx, 12
    call    sys_write
    
    lea     rdi, [rel box_v]
    call    print_str
    call    print_newline
    
    add     rsp, 128
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; Helper: format percentage (right-aligned, 3 chars)
.format_percentage:
    push    rbx
    push    r12
    mov     r12, rdi
    mov     rbx, rax            ; percentage value
    
    ; Pad with spaces if < 100
    cmp     rbx, 100
    jge     .no_pad100
    mov     byte [rdi], ' '
    inc     rdi
.no_pad100:
    cmp     rbx, 10
    jge     .no_pad10
    mov     byte [rdi], ' '
    inc     rdi
.no_pad10:
    ; Convert number
    test    rbx, rbx
    jnz     .convert_pct
    mov     byte [rdi], '0'
    inc     rdi
    jmp     .pct_done
    
.convert_pct:
    mov     rax, rbx
    xor     rcx, rcx
.pct_div:
    test    rax, rax
    jz      .pct_reverse
    xor     rdx, rdx
    push    rdx
    mov     r8, 10
    div     r8
    add     dl, '0'
    mov     [rsp], dl
    inc     rcx
    jmp     .pct_div
    
.pct_reverse:
    test    rcx, rcx
    jz      .pct_done
    pop     rdx
    mov     [rdi], dl
    inc     rdi
    dec     rcx
    jmp     .pct_reverse
    
.pct_done:
    mov     byte [rdi], 0
    pop     r12
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; print_footer - Print bottom border
; ----------------------------------------------------------------------------
global print_footer
print_footer:
    lea     rdi, [rel box_bl]
    lea     rsi, [rel box_br]
    call    print_horizontal_line
    ret

section .rodata
    download_lbl:   db " Download: ", 0
    upload_lbl:     db " Upload:   ", 0
    bracket_open:   db "[", 0
    bracket_close:  db "]", 0
    percent_sign:   db "%", 0
