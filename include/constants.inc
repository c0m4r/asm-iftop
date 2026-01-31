; ============================================================================
; ASM-IFTOP Constants
; Linux x86_64 system call numbers and constants
; ============================================================================

; System call numbers (x86_64)
%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_OPEN        2
%define SYS_CLOSE       3
%define SYS_NANOSLEEP   35
%define SYS_SOCKET      41
%define SYS_IOCTL       16
%define SYS_EXIT        60

; File open flags
%define O_RDONLY        0

; Standard file descriptors
%define STDIN           0
%define STDOUT          1
%define STDERR          2

; Socket constants
%define AF_INET         2
%define SOCK_DGRAM      2

; ioctl commands for network interfaces
%define SIOCGIFADDR     0x8915      ; Get interface address
%define SIOCGIFFLAGS    0x8913      ; Get interface flags

; Buffer sizes
%define BUFFER_SIZE     4096
%define PATH_MAX        256
%define IFNAMSIZ        16

; Time constants
%define ONE_SECOND_NS   1000000000

; Box drawing characters (UTF-8)
; ╔ = E2 95 94, ╗ = E2 95 97, ╚ = E2 95 9A, ╝ = E2 95 9D
; ║ = E2 95 91, ═ = E2 95 90, ╠ = E2 95 A0, ╣ = E2 95 A3

; Progress bar characters (UTF-8)  
; █ = E2 96 88 (full block)
; ░ = E2 96 91 (light shade)

; Arrow characters (UTF-8)
; ▼ = E2 96 BC (down arrow for download)
; ▲ = E2 96 B2 (up arrow for upload)

; ANSI escape sequences
%define ESC             0x1B

; Terminal ioctl commands
%define TCGETS          0x5401      ; Get terminal attributes
%define TCSETS          0x5402      ; Set terminal attributes  

; termios c_lflag bits
%define ICANON          0x0002      ; Canonical mode
%define ECHO            0x0008      ; Echo input

; Poll events
%define POLLIN          0x0001      ; Data to read
