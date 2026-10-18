# Manual runtime validation — two local peers

This procedure is a test plan, **not evidence that a runtime test has passed**. It requires an installed Godot 4.3+ editor/runtime and should be recorded with real logs/screenshots when executed.

## Linux/macOS or Godot on PATH

1. In a terminal at the repository root, run `godot --path . --position 100,100`. In the menu click **HOSPEDAR PARTIDA** (default UDP 24560).
2. In another terminal run `godot --path . --position 700,100`. Leave address `127.0.0.1`, UDP `24560`, and click **ENTRAR NA PARTIDA**.

## Windows PowerShell

Open two PowerShell windows at the repository directory. Replace the path with the installed Godot **console** executable (4.3 or newer) so output remains visible:

```powershell
$godot = 'C:\Godot\Godot_v4.3-stable_win64_console.exe'
& $godot --path . --position 100,100
```

In the second PowerShell window:

```powershell
$godot = 'C:\Godot\Godot_v4.3-stable_win64_console.exe'
& $godot --path . --position 700,100
```

First window: click **HOSPEDAR PARTIDA**. Second window: connect to `127.0.0.1`, UDP `24560`.

## Checks

3. Confirm both windows enter the same sector and show two peer IDs. Move both players simultaneously with WASD while looking around. The other avatar should move; the local camera should be enabled only for that process's player.
4. Walk into walls and the visible GLB crate from both host and client; verify neither avatar passes through. Then move the two avatars into one another to check CharacterBody collision. The host simulates movement through `CharacterBody3D.move_and_slide`; client prediction should be corrected to server snapshots on wall impact.
5. Close the joining client window. Confirm its avatar disappears and the host roster returns to one peer. Reconnect and repeat with host closing the session; verify the remaining client returns to menu with a disconnect status. Confirm both terminal outputs contain no `SCRIPT ERROR` or critical physics/RPC errors.
6. Capacity check: run additional client processes with unique window positions. Three remote clients should connect (four players including host); the fifth total participant should be rejected/disconnected with a useful status or connection failure. Record actual outcome, engine version, output logs, and any console errors.

For separate computers on a LAN, use the host's private IP and allow inbound UDP 24560 on its firewall. Do not call the same-machine test an internet test. Internet operation requires reachable UDP hosting/port forwarding, and may fail behind CGNAT.

Automated structural checks remain `python3 -m unittest discover -s tests -p 'test_*.py' -v`; they do not replace any step above.
