# Code Review: asm-iftop

**Repository:** https://github.com/c0m4r/asm-iftop  
**Description:** A lightweight x86_64 assembly network monitor for GNU/Linux  
**Language:** x86_64 Assembly (NASM syntax)  
**License:** CC0 (Public Domain)

---

## Executive Summary

asm-iftop is a well-structured, minimal network monitoring tool written in pure x86_64 assembly. It demonstrates solid understanding of Linux system programming, proper use of syscalls, and clean modular design. The codebase is impressively compact (~13KB binary) while providing a polished terminal UI with real-time network statistics.

**Overall Assessment:** Good quality code with minor areas for improvement.

---

## Project Structure

```
asm-iftop/
├── Makefile
├── include/
│   └── constants.inc      # System call numbers and constants
└── src/
    ├── main.asm           # Entry point and main loop
    ├── syscalls.asm       # Linux syscall wrappers
    ├── io.asm             # File I/O helpers
    ├── parse.asm          # String/number parsing utilities
    ├── net.asm            # Network interface discovery and statistics
    └── display.asm        # Terminal UI and output formatting
```

The modular organization is excellent, with clear separation of concerns:
- **syscalls.asm**: Low-level kernel interface
- **io.asm**: File system abstractions
- **parse.asm**: Data transformation utilities
- **net.asm**: Network-specific logic
- **display.asm**: User interface
- **main.asm**: Application orchestration

---

## Detailed File Analysis

### 1. constants.inc

**Purpose:** Centralizes all system constants and magic numbers.

**Strengths:**
- Excellent use of `%define` macros to eliminate magic numbers
- Well-organized with logical groupings (syscalls, flags, buffer sizes)
- Proper documentation for ioctl commands and termios flags

**Observations:**
- `SYS_POLL` is defined as literal `7` instead of using `%define` like other syscalls
- Missing comments for `AF_INET` and `SOCK_DGRAM` values

**Recommendation:**
```asm
; Add consistent define for poll syscall
%define SYS_POLL        7
```

---

### 2. syscalls.asm

**Purpose:** Thin wrappers around Linux system calls following x86_64 calling convention.

**Strengths:**
- Clean, minimal wrapper functions
- Proper adherence to System V AMD64 ABI (arguments in RDI, RSI, RDX, etc.)
- Correct use of `syscall` instruction for x86_64
- `sys_nanosleep` properly handles the optional `rem` parameter by passing NULL

**Code Quality:**
```asm
; Good: Simple, focused, no unnecessary operations
sys_exit:
    mov     rax, SYS_EXIT
    syscall
    ret
```

**Observations:**
- `sys_poll` uses hardcoded value `7` instead of a named constant
- All functions correctly preserve caller-saved registers as per ABI

---

### 3. io.asm

**Purpose:** File reading and path construction utilities.

**Strengths:**
- `read_file` properly null-terminates buffer (important for string parsing)
- Leaves room for null terminator (`dec rdx` before read)
- Proper error handling with early returns on negative values
- `build_sysfs_path` safely constructs paths with boundary checks

**Potential Issues:**

**Issue 1: Buffer Overflow Risk in `build_sysfs_path`**
```asm
; Current implementation doesn't check if the constructed path
; fits within PATH_MAX (256 bytes)
; Interface name + filename could exceed buffer if iface name is long
```

**Recommendation:** Add bounds checking:
```asm
; Before each copy operation, verify remaining space
; cmp rbx, PATH_MAX - 1
; jge .error_overflow
```

**Issue 2: `str_compare` in parse.asm is used without length validation**
```asm
; The interface name comparison in net.asm uses str_compare
; but doesn't ensure the source string is properly bounded
```

---

### 4. parse.asm

**Purpose:** String parsing and number formatting utilities.

**Strengths:**
- `parse_uint64` correctly handles digit validation
- `uint64_to_str` properly reverses digits after conversion
- `format_speed_mbps` correctly calculates Mbps with 2 decimal places
- Good use of helper functions for code reuse

**Code Review - `format_speed_mbps`:**
```asm
; Formula: Mbps = (bytes * 8) / 1,000,000
; Correctly handles the calculation order to maintain precision
shl     rdi, 3              ; bytes to bits (multiply by 8)
; ...
div     rcx                 ; rax = integer Mbps, rdx = remainder
```

**Minor Issue: Integer Overflow in `parse_uint64`**
```asm
parse_uint64:
    imul    rax, 10         ; No overflow check
    sub     cl, '0'
    add     rax, rcx        ; Could overflow for very large numbers
```

For network statistics this is unlikely to be a problem (64-bit max is ~18 exabytes), but worth noting.

**Strength: `skip_whitespace` and related functions**
- Clean, efficient loops
- Proper handling of both space and tab characters

---

### 5. net.asm

**Purpose:** Network interface discovery and information retrieval.

**Strengths:**
- Properly skips loopback interface (`lo`)
- Uses multiple data sources appropriately:
  - `/proc/net/dev` for statistics
  - `/sys/class/net/` for hardware info
  - `ioctl(SIOCGIFADDR)` for IP address
- Graceful degradation (returns "N/A" for virtual interfaces without drivers/speed)

**Code Quality - `get_interface_stats`:**
```asm
; Correctly skips 8 fields between RX and TX bytes
; Fields: bytes, packets, errs, drop, fifo, frame, compressed, multicast
mov     rcx, 8
skip_fields:
    call    skip_whitespace
    call    skip_to_whitespace
    dec     rcx
    jnz     .skip_fields
```

**Potential Issues:**

**Issue 1: Interface Name Length Not Validated**
```asm
; In find_main_interface, interface name is copied without
; checking IFNAMSIZ (16) limit
.copy_name:
    cmp     rcx, rbx
    jge     .copy_done
    ; No check against IFNAMSIZ - 1
```

**Issue 2: Race Condition in Statistics Reading**
```asm
; The RX and TX bytes are read at different times
; If traffic is heavy, this could cause slight inconsistencies
; (acceptable for this use case, but worth noting)
```

**Issue 3: `get_ip_address` Stack Usage**
```asm
; Uses 64 bytes for ifreq struct (actual size is 40 bytes)
; Good: provides padding for alignment
; The manual IP formatting is correct but could use inet_ntoa equivalent
```

**Strength: Proper socket cleanup**
```asm
; Always closes socket even on ioctl error
push    rax                 ; Save ioctl result
mov     rdi, rbx
call    sys_close
pop     rax
```

---

### 6. display.asm

**Purpose:** Terminal UI rendering with ANSI escape sequences and UTF-8 box drawing.

**Strengths:**
- Excellent use of UTF-8 box drawing characters for professional appearance
- Proper ANSI escape sequence handling
- Saves and restores terminal state (good citizen)
- Progress bar with color coding (green for download, yellow for upload)

**Code Quality - Terminal Handling:**
```asm
; Correctly modifies c_lflag to disable canonical mode and echo
mov     eax, [rel new_termios + 12]
and     eax, ~(ICANON | ECHO)
mov     [rel new_termios + 12], eax
```

**Potential Issues:**

**Issue 1: Magic Numbers in Layout Calculations**
```asm
; Multiple hardcoded values for padding calculations
mov     rdx, 14             ; Padding for centering
; ...
mov     rbx, 54             ; Box width
; ...
mov     rdx, 27             ; Padding to border
```

**Recommendation:** Define constants for layout dimensions:
```asm
%define BOX_WIDTH       54
%define TITLE_PADDING   14
```

**Issue 2: `print_str` Inefficiency**
```asm
; Recalculates string length on every call
; For known strings, this is unnecessary overhead
.len_loop:
    cmp     byte [rbx + rcx], 0
    je      .print
    inc     rcx
    jmp     .len_loop
```

**Alternative:** Create `print_str_len` for known-length strings.

**Issue 3: Progress Bar Percentage Calculation**
```asm
; Calculates percentage twice (once for filled, once for empty)
; Could be optimized to calculate once and reuse
```

**Strength: Proper Color Reset**
```asm
; Always resets ANSI attributes after colored output
lea     rdi, [rel ansi_reset]
call    print_str
```

---

### 7. main.asm

**Purpose:** Application entry point and main event loop.

**Strengths:**
- Clean initialization sequence
- Proper signal-less exit handling via keyboard polling
- Correct timing with 100ms poll + 10-cycle accumulation for 1-second updates
- Graceful cleanup on exit (restores terminal, shows cursor)

**Architecture:**
```
Initialize → Get Interface Info → Setup Terminal → Main Loop → Cleanup → Exit
                ↓                      ↓              ↓
           Read /sys files        Raw mode      Poll stdin + Update display
```

**Code Quality - Main Loop:**
```asm
; Good: Non-blocking poll allows responsive 'q' key handling
mov     rdx, 0              ; timeout = 0 (non-blocking)
call    sys_poll

; Good: Accumulates 100ms intervals for 1-second updates
mov     qword [rel refresh_counter], 10
; ...
dec     qword [rel refresh_counter]
jnz     .sleep
```

**Potential Issues:**

**Issue 1: No Error Handling for `sys_nanosleep` Interruption**
```asm
; If nanosleep is interrupted by signal, remaining time is not handled
; (though with 100ms intervals, this is minor)
```

**Issue 2: Percentage Calculation Precision**
```asm
; Formula used: (delta_bytes * 8 * 100) / (link_speed_mbps * 1000000)
; This is correct, but there's a potential divide-by-zero if link_speed is 0
; (handled with test/jz, so actually OK)
```

**Issue 3: Stack Imbalance Check**
```asm
; Multiple push/pop operations in speed calculation
; Manual review shows they are balanced, but this is error-prone
```

---

## Makefile Analysis

**Strengths:**
- Clean, standard Makefile structure
- Proper use of pattern rules
- Separate debug target with symbols
- Creates build directory automatically

**Observations:**
```makefile
# Debug target forces rebuild but doesn't preserve object files with symbols
debug: NASM_FLAGS = -f elf64 -g -F dwarf
debug: LD_FLAGS = 
debug: clean all
```

**Recommendation:** Consider preserving debug symbols in separate files:
```makefile
debug: $(TARGET)
    objcopy --only-keep-debug $(TARGET) $(TARGET).debug
```

---

## Security Considerations

### 1. Path Traversal
The `build_sysfs_path` function constructs paths from user-controlled interface names. While interface names are typically kernel-controlled, there's no validation for path traversal sequences (`../`).

**Risk:** Low (interface names are usually sanitized by kernel)  
**Recommendation:** Validate interface name contains only alphanumeric, hyphen, and dot characters.

### 2. Buffer Safety
Most buffer operations are bounded, but some edge cases exist:
- `build_sysfs_path` doesn't check total path length against `PATH_MAX`
- Interface name copying doesn't enforce `IFNAMSIZ` limit

**Risk:** Low to Medium  
**Recommendation:** Add explicit bounds checking.

### 3. Integer Overflow
`parse_uint64` doesn't check for overflow during multiplication. For network statistics this is unlikely to be exploitable.

**Risk:** Very Low  
**Recommendation:** Add overflow check for completeness.

---

## Performance Analysis

### Strengths:
1. **No libc dependency** - Direct syscalls minimize overhead
2. **Efficient polling** - 100ms intervals balance responsiveness and CPU usage
3. **Minimal memory footprint** - Small BSS/data sections
4. **No dynamic allocation** - All buffers are static

### Potential Optimizations:
1. **Batch file reads** - Currently reads `/proc/net/dev` twice per second
2. **String caching** - Interface info doesn't change; could cache formatted strings
3. **Avoid redundant calculations** - Progress bar percentage calculated twice

---

## Portability

### Current Platform Support:
- **Architecture:** x86_64 only
- **OS:** Linux only (uses Linux-specific syscalls and `/proc`, `/sys` filesystems)

### Portability Limitations:
1. Hardcoded syscall numbers (Linux-specific)
2. `/proc/net/dev` format is Linux-specific
3. `/sys/class/net/` is Linux sysfs
4. `ioctl(SIOCGIFADDR)` is POSIX but values are Linux-specific

**Assessment:** This is intentionally Linux-specific and makes no claims to portability. This is acceptable for a specialized system tool.

---

## Code Style and Documentation

### Strengths:
- Consistent header comments for each function
- Clear register usage documentation
- Logical section organization (.bss, .data, .text)
- Meaningful label names

### Areas for Improvement:
1. **Register conventions** - Some functions don't document which registers are preserved
2. **Magic numbers** - Several unexplained constants in display.asm
3. **Error handling** - Some functions return 0 on error, others return -1; could be more consistent

---

## Bugs and Issues

### Confirmed Issues:
None critical found.

### Potential Issues:
1. **Terminal restore on SIGTERM** - If program is killed with SIGTERM, terminal remains in raw mode
2. **Interface name buffer overflow** - Long interface names could overflow buffer
3. **Division by zero in percentage** - Handled but could be more explicit

### Recommendations:
1. Add signal handlers for SIGTERM/SIGINT to ensure terminal cleanup
2. Add explicit bounds checking for all string operations
3. Consider using `sigaction` for more robust signal handling

---

## Testing Recommendations

To thoroughly test this application:

1. **Interface scenarios:**
   - Test with multiple network interfaces
   - Test with virtual interfaces (docker, bridges)
   - Test with interface that has no IP address
   - Test with interface that has no driver info

2. **Terminal scenarios:**
   - Resize terminal during operation
   - Test with different terminal emulators
   - Test with limited color support

3. **Edge cases:**
   - Very high network throughput (approaching link speed)
   - Interface goes down during monitoring
   - Permission issues (run as non-root)

4. **Stress testing:**
   - Rapid key presses
   - Long-running stability test

---

## Conclusion

asm-iftop is a well-crafted assembly program that demonstrates:
- Solid understanding of Linux system programming
- Proper use of x86_64 assembly conventions
- Clean modular architecture
- Attention to user experience (responsive UI, graceful cleanup)

The code is production-ready with minor caveats around input validation and signal handling. The author clearly understands both assembly programming and Linux networking internals.

**Overall Grade: B+**

### Summary of Recommendations:

| Priority | Issue | Location |
|----------|-------|----------|
| Medium | Add signal handlers for cleanup | main.asm |
| Medium | Add bounds checking for interface names | net.asm, io.asm |
| Low | Define constants for layout magic numbers | display.asm |
| Low | Add SYS_POLL constant | constants.inc |
| Low | Optimize percentage calculation | display.asm |

---

*Review conducted on February 2026*
