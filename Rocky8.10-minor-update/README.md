# Rocky8.10 Minor Update

Offline minor update script for Rocky Linux 8.x systems using the Rocky Linux 8.10 DVD ISO.

## Purpose

This script uses `/root/Rocky-8.10-x86_64-dvd1.iso` as a local repository and runs `dnf distro-sync` against Rocky Linux 8.10 BaseOS and AppStream repositories. It is intended for environments without internet access.

## Script

```text
Rocky8.10_minor_update.sh
```

## Version

```text
1.2.0
```

The same version is available in the script as `SCRIPT_VERSION`.

## Requirements

- Rocky Linux 8.x
- root privileges
- Rocky Linux 8.10 DVD ISO
- ISO path: `/root/Rocky-8.10-x86_64-dvd1.iso`
- Existing `/mnt` directory
- Required commands: `dnf`, `rpm`, `mount`, `umount`, `mountpoint`, `df`, `awk`

## Space Check

Before running the minor update, the script checks the following free space thresholds.

| Path | Minimum Free Space |
|---|---:|
| `/` | 3072 MB |
| `/var` | 5120 MB |
| `/boot` | 512 MB |

## Usage

```sh
sh /root/Rocky8.10_minor_update.sh
```

Select the required task from the menu.

```text
1. Check minor update environment
2. ISO mount management
3. Run minor update
4. Restore previous settings
5. Exit
```

## Menu

### 1. Check minor update environment

Checks the following items.

- root privilege
- Rocky Linux 8.x release
- current OS version
- current `rocky-release` package version
- ISO file existence
- free space for `/`, `/var`, and `/boot`
- ISO mount point status

### 2. ISO mount management

Manually checks or controls the ISO mount state.

```text
1. Show ISO mount status
2. Mount ISO
3. Unmount ISO
4. Back to main menu
```

`Mount ISO` mounts `/root/Rocky-8.10-x86_64-dvd1.iso` to `/mnt/rocky810_iso` as a read-only loop device and checks that `BaseOS` and `AppStream` directories exist.

### 3. Run minor update

Runs the update in the following order.

1. Check environment
2. Ask for user confirmation
3. Mount ISO as read-only loop device
4. Check `BaseOS` and `AppStream` directories in the ISO
5. Back up existing repo files
6. Temporarily disable existing repo files
7. Create ISO-based local repo file
8. Run `dnf clean all`
9. Check local repositories
10. Check available updates
11. Run `dnf distro-sync` against Rocky Linux 8.10 repositories
12. Check final OS version
13. Restore previous repo settings
14. Unmount ISO

### 4. Restore previous settings

Manual restore menu item.

It performs the following tasks.

- Remove the temporary ISO local repo file
- Restore backed-up repo files
- Unmount ISO

## Changed Paths

The script uses the following paths.

| Path | Purpose |
|---|---|
| `/root/Rocky-8.10-x86_64-dvd1.iso` | Rocky Linux 8.10 DVD ISO |
| `/mnt/rocky810_iso` | ISO mount point |
| `/etc/yum.repos.d/rocky-8.10-local.repo` | temporary local repo file |
| `/root/rocky810_minor_update_state/repo_backup` | original repo backup directory |

## Restore Behavior

When `Run minor update` succeeds, fails, or is interrupted, the script attempts to restore the following items before it exits.

- remove `/etc/yum.repos.d/rocky-8.10-local.repo`
- restore repo files from `/root/rocky810_minor_update_state/repo_backup`
- unmount `/mnt/rocky810_iso`

If manual restore is required, run `4. Restore previous settings` from the main menu.

## Notes

- Online repositories are not used.
- Only `BaseOS` and `AppStream` from the ISO are used.
- Packages that depend on EPEL, vendor repositories, or custom repositories need separate review.
- `dnf autoremove` is not run automatically.
- Validate on a test server before applying to production.
- Reboot is recommended after completion.

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.2.0 | 2026-04-20 | Convert script menus and output to English; move ISO mount management to menu item 2 |
| 1.1.0 | 2026-04-20 | Add ISO mount management menu for status, mount, and unmount |
| 1.0.0 | 2026-04-20 | Initial release for Rocky Linux 8.10 offline minor update |
