# ASM-IFTOP

A lightweight x86_64 assembly network monitor for GNU/Linux.

Vibe coded with Claude 4.5 Opus (Thinking) via Google Antigravity.

```
╔══════════════════════════════════════════════════════╗
║              ASM-IFTOP Network Monitor               ║
╠══════════════════════════════════════════════════════╣
║  Interface: eth0                                     ║
║  MAC:       ab:cd:ef:01:23:45                        ║
║  IP:        192.168.0.69                             ║
║  MTU:       1500                                     ║
║  Speed:     1000 Mbps                                ║
║  Driver:    e1000e                                   ║
╠══════════════════════════════════════════════════════╣
║  ▼ Download:     0.00 Mbps                           ║
║    [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]    0%            ║
║  ▲ Upload:       0.00 Mbps                           ║
║    [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]    0%            ║
╚══════════════════════════════════════════════════════╝
```

## Features

- **Tiny footprint** - ~13KB statically-linked binary, no libc
- Live download/upload speed in Mbps with colored progress bars
- Shows interface info: name, MAC, IP, MTU, link speed, driver
- Clean exit with **q** key
- Handles terminal resize gracefully

## Quick install (x86_64 GNU/Linux)

```bash
wget https://github.com/c0m4r/asm-iftop/releases/download/v1.0/asm-iftop
echo "13315343e4a8354a145cfd2b1cdc7408df7655e9c61b9edcfa57f74a6fa7bede  asm-iftop" | sha256sum -c || rm -f asm-iftop
sudo mv asm-iftop /usr/local/bin/
sudo chmod +x /usr/local/bin/asm-iftop
asm-iftop
```

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
