# Code review — c0m4r/asm-iftop

Repository: c0m4r/asm-iftop  
Description: A lightweight x86_64 assembly network monitor for GNU/Linux.  
Languages: Assembly, Makefile

This review summarizes what I inspected, highlights strengths, identifies issues (grouped by severity), and gives concrete recommendations and suggested next steps.

---

## What I inspected

- README.md (project overview, features, build/run instructions)
- Makefile (build rules)
- include/constants.inc (syscall numbers, sizes, constants)
- src/*.asm (main.asm, syscalls.asm, io.asm, parse.asm, net.asm, display.asm)
- LICENSE (CC0)

I focused on the code paths that:
- read /proc/net/dev and sysfs files,
- parse interface names and numbers,
- format speeds and percentages for the terminal display,
- perform low-level syscalls and I/O.

---

## Summary / High-level impressions

- This is an impressive, compact, and focused project: a working network monitor written in hand-crafted x86_64 assembly with no libc dependency.
- Code organization is sensible: separated modules (io, net, parse, display), a small Makefile, and a constants include.
- Attention to size and minimalism is clear (static binary ~13KB, syscall-only approach).
- Readme is informative: shows features, build/run instructions, and a project structure.

---

## Strengths

- Minimal runtime dependencies (no libc) and a very small binary size.
- Good modular decomposition (clear separation of responsibilities: io, net, parse, display).
- README provides enough information to build and run, including quick-install and checksums.
- Use of direct syscalls keeps the binary self-contained and predictable.
- Many formatting and parsing routines are implemented carefully (e.g., fixed-width formatting, percent calculations).

---

## Issues and suggestions

I group issues by severity and give suggested fixes or mitigations.

### High priority ( correctness / stability )

1. Buffer bounds checks when copying strings (possible overflow)
   - Where: functions that copy interface names and file/path fragments (e.g., src/io.asm — the copy loops that write into a destination buffer pointed by r12 with index rbx).
   - Problem: Copies stop on newline/space or NUL, but I did not find explicit checks that ensure `rbx` stays below the destination buffer capacity before writing a byte and NUL-terminator.
   - Risk: If unexpected long interface names or sysfs contents occur, writes can overflow the buffer on the stack or heap, corrupting adjacent data and causing crashes or misbehavior.
   - Recommendation:
     - Add an explicit bound check in copy loops (compare rbx against BUFFER_SIZE-1 or an explicit `buf_len` argument) and stop/cut the string when the limit is reached.
     - Ensure the null terminator is always written within bounds.

2. Stack allocation and alignment when doing large local buffers
   - Where: functions that do `sub rsp, PATH_MAX + BUFFER_SIZE` (e.g., get_mtu in src/net.asm).
   - Problem: Large stack allocations are used; ensure 16-byte alignment is preserved before calling functions that expect the System V ABI alignment.
   - Risk: Misaligned stack before calls may break some instructions or cause undefined behavior when called functions expect aligned stack (especially if making library calls or some instructions that assume alignment).
   - Recommendation:
     - Document and check alignment adjustments. After `sub rsp, ...` ensure alignment by rounding the subtraction to a multiple of 16.
     - Alternatively, allocate a constant-size stack frame that maintains alignment.

3. Syscall error handling patterns
   - Where: multiple syscalls across modules (sys_read wrappers, read_file callers).
   - Problem: In places the code checks `test rax, rax`/`jle` or `jz` for errors, but negative syscall errors on Linux are returned as a signed negative errno inside rax. Some checks may not correctly distinguish between zero (OK/EOF) and negative error codes.
   - Risk: Misinterpreting negative return values as large unsigned positives could lead to incorrect branching.
   - Recommendation:
     - Use `cmp rax, 0` / `jl` to detect negative return (error) and `jle` or `je` for zero-length EOF as appropriate, and document the intended behavior.
     - Normalize and document the convention used (e.g., return `0` on error from helpers, or propagate negative errno properly).

### Medium priority (robustness / maintainability)

4. Lack of documented register conventions per function
   - Where: all global asm functions.
   - Problem: The code uses registers extensively for parameters and temporaries. While System V calling convention is followed, there is no per-function comment block describing input registers, clobbered registers, stack frame layout, and return values.
   - Recommendation:
     - Add a short comment header on each global routine (inputs, outputs, clobbered registers, required buffer sizes). This will aid future maintainers.

5. Hardcoded PATH_MAX and small stack buffers for sysfs paths
   - Where: include/constants.inc `PATH_MAX` = 256 and path-building logic in src/net.asm.
   - Problem: Although `/sys/class/net/<if>/...` paths are small, some sysfs files or device names could be longer on some systems.
   - Recommendation:
     - Either verify the actual constructed path length against provided buffer before writing, or use a larger PATH_MAX with checks, or compute length dynamically.

6. Repeated syscalls / performance
   - Where: reading multiple sysfs files repeatedly (speed, driver, mtu) every refresh.
   - Problem: The implementation reads several small files each refresh. For frequent updates (e.g., many times per second), this may cause extra overhead.
   - Recommendation:
     - Consider simple caching with an expiration time (e.g., re-read speed/driver less frequently than RX/TX counters).
     - If latency and realtime accuracy are less critical for these static fields, read them once at startup.

7. Partial or inconsistent error reporting to user
   - Where: main loop and display code.
   - Problem: When a resource (sysfs file, ioctl) fails, the current behavior is not always clear to users (e.g., silent failures, missing labels).
   - Recommendation:
     - Show clear placeholders or messages when fields are unavailable (e.g., "N/A") and log debug info if `debug` build is used.

### Low priority (style / docs / developer experience)

8. No automated tests or CI
   - Recommendation: Add simple CI to build and run smoke tests (build-only at minimum). Add unit/integration tests for parsing routines by using small test inputs processed by a test runner (could be a small harness executable or a test script).

9. Contribution and development docs
   - Recommendation: Add CONTRIBUTING.md, a brief developer guide explaining local build, debug, symbolized builds (how to use `make debug`), and how to run under `gdb` or `strace` for debugging.

10. Comments and inline documentation density
    - Recommendation: Some parts are well-commented; others can benefit from more comments explaining the algorithm (e.g., percent formatting, integer to string routines).

---

## Concrete suggestions / prioritized fixes

1. Add and enforce buffer bounds in copy loops
   - Example target locations:
     - src/io.asm (copying interface name and file name)
     - src/net.asm functions that call `read_file` and `copy_until_newline`
   - Action: check `rbx` vs a `max_len` before each `mov [r12 + rbx], al` and ensure termination.

2. Validate and preserve stack alignment
   - Action: when subtracting variable stack sizes, round up to maintain 16-byte alignment. Add a comment explaining the stack layout.

3. Improve syscall return checks
   - Action: replace ambiguous `jle`/`jz` patterns with explicit `cmp rax, 0` followed by `jl` for errors and `je` for empty results where appropriate.

4. Add a small CI job
   - Action: Add a GitHub Actions workflow that runs `make` on Ubuntu and a matrix for debug/release.

5. Add minimal testing harness
   - Action: Add a `tests/` directory with sample `/proc/net/dev` excerpts and a small runner (shell script or simple program) that invokes the binary on test data (or better, add small unit tests for parsing functions using a harness).

6. Document per-function ABI
   - Action: At the top of each src/*.asm function, add a short comment indicating parameters (rdi, rsi, rdx...), return (rax), stack/locals, and clobbers.

---

## Security and privileges

- The tool uses ioctls and sysfs reads; as implemented these are typical for gathering network interface info. Running as root is not required for most reads, but confirm expected permission requirements on target systems.
- Because the binary avoids libc, it also avoids some attack surface, but buffer overflows or stack corruption remain primary risks — see buffer-bounds suggestions above.

---

## Portability

- The code is explicitly Linux x86_64-specific (syscall numbers and ioctl constants). Porting to other architectures or OSes would require substantial rework.
- The Makefile targets `nasm`/`ld`. Consider documenting required tool versions.

---

## Suggested small roadmap / PR ideas

1. "Bounds-check copies" — implement and test buffer checks in src/io.asm and any other string copy helpers.
2. "Stack-alignment fix" — ensure stack frame sizes are aligned and add unit tests for functions that use local buffers.
3. "CI and smoke tests" — add GitHub Actions to build on push and run a few sample runs (or at least ensure build succeeds).
4. "DOC: Developer guide & function ABI comments" — improve maintainability by adding per-function documentation and CONTRIBUTING.md.

---

## Final notes

- This is a compact, well-focused project demonstrating strong low-level skill in assembly. The principal risks are typical for hand-written assembly: bounds/stack/alignment issues and limited test coverage.
- Fixing the buffer bounds checks and ensuring stack alignment would address the highest-impact risks and make the codebase safer and more maintainable.
- After addressing the critical fixes, adding CI and tests will make future changes safer and faster.

---
