# ASM-IFTOP

A lightweight x86_64 assembly network monitor for GNU/Linux.

Vibe coded with Claude 4.5 Opus (Thinking) via Google Antigravity.

![Screenshot](docs/screenshot.png)

## Features

- **Tiny footprint** - ~13KB statically-linked binary, no libc
- Live download/upload speed in Mbps with colored progress bars
- Shows interface info: name, MAC, IP, MTU, link speed, driver
- Clean exit with **q** key
- Handles terminal resize gracefully

## Build

```bash
make
```

Requires: `nasm`, `ld` (binutils)

## Run

```bash
./asm-iftop
```

Press **q** to exit.

## How It Works

| Info | Source |
|------|--------|
| RX/TX bytes | `/proc/net/dev` |
| MAC | `/sys/class/net/<if>/address` |
| MTU | `/sys/class/net/<if>/mtu` |
| Speed | `/sys/class/net/<if>/speed` |
| Driver | `/sys/class/net/<if>/device/uevent` |
| IP | `ioctl(SIOCGIFADDR)` |

## Project Structure

```
├── Makefile
├── include/
│   └── constants.inc    # Syscall numbers, flags
└── src/
    ├── main.asm         # Entry point, main loop
    ├── syscalls.asm     # Linux syscall wrappers
    ├── io.asm           # File reading helpers
    ├── parse.asm        # String/number parsing
    ├── net.asm          # Interface discovery & stats
    └── display.asm      # Terminal output, progress bars
```

## License

Public Domain (CC0)
