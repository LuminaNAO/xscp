# xscp

Interactive scp wrapper with transfer history, fuzzy matching, and TUI file browsing.

## Features

- **Interactive menu** — send, receive, or replay past transfers
- **Transfer history** — every scp is logged to `~/.xscp_history` with user, host, port, and paths
- **Fuzzy search** — find and replay past transfers by keyword
- **File browsing** — pick local/remote files with nnn
- **Remote browsing** — mounts remote filesystem via sshfs for interactive navigation, auto-unmounts on completion
- **Passthrough mode** — use as a drop-in scp replacement, transfers are silently logged
- **Smart defaults** — remembers ports per host, pulls targets from history and `~/.ssh/config`

## Usage

```
xscp                  Interactive menu (send/receive/history)
xscp send             Interactive send flow
xscp recv             Interactive receive flow
xscp history          Browse and replay past transfers
xscp <query>          Fuzzy search history
xscp [scp args...]    Passthrough to scp (logged to history)
```

### Examples

```bash
# Interactive mode - pick send/receive from menu
xscp

# Send a file interactively (browse local, pick target, browse remote dest)
xscp send

# Receive a file (browse remote via sshfs, pick local dest)
xscp recv

# Search history for transfers involving "myserver"
xscp myserver

# Use as regular scp (gets logged to history)
xscp -P 2222 ./file.tar.gz user@host:/tmp/
```

## Dependencies

| Dependency | Required | Purpose |
|------------|----------|---------|
| `scp`      | yes      | File transfer |
| `fzf`      | yes      | Fuzzy selection menus |
| `nnn`      | yes      | TUI file browser |
| `sshfs`    | yes      | Remote filesystem browsing |

## Install

```bash
git clone https://codeberg.org/LuminaNAO/xscp.git
cd xscp
./install.sh
```

## History Format

Transfers are logged to `~/.xscp_history` as pipe-delimited records:

```
timestamp|direction|user@host|port|remote_path|local_path
```

## Contributing

The **primary repository** is on [Codeberg](https://codeberg.org/LuminaNAO/xscp).
Pull requests, issues, and discussions should be directed there.

The [GitHub](https://github.com/LuminaNAO/xscp) mirror is read-only —
pull requests opened there will be ignored.

## License

AGPL-3.0-or-later
