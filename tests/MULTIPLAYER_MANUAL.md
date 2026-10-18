# Manual runtime validation — two local peers

This procedure is a test plan, **not evidence that a runtime test has passed**. It requires an installed Godot 4.3+ editor/runtime and should be recorded with real logs/screenshots when executed.

1. In a terminal at the repository root, run `godot --path . --position 100,100`. In the menu click **HOSPEDAR PARTIDA** (default UDP 24560).
2. In another terminal run `godot --path . --position 700,100`. Leave address `127.0.0.1`, UDP `24560`, and click **ENTRAR NA PARTIDA**.
3. Confirm both windows enter the same sector and show two peer IDs. Move each client separately with WASD and rotate with mouse. The other avatar should move; the local camera should be enabled only for that process's player.
4. Walk into walls and the visible GLB crate from both host and client. Verify neither avatar passes through. The server simulates input through `CharacterBody3D.move_and_slide`; client prediction should be corrected to server snapshots on wall impact.
5. Close the joining client window. Confirm its avatar disappears and the host roster returns to one peer. Reconnect and repeat with host closing the session; verify the remaining client returns to menu with a disconnect status.
6. Capacity check: run additional client processes with unique window positions. Three remote clients should connect (four players including host); the fifth total participant should be rejected/disconnected. Record actual outcome, engine version, output logs, and any console errors.

For separate computers on a LAN, use the host's private IP and allow inbound UDP 24560 on its firewall. Do not call the same-machine test an internet test. Internet operation requires reachable UDP hosting/port forwarding, and may fail behind CGNAT.

Automated structural checks remain `python3 -m unittest discover -s tests -p 'test_*.py' -v`; they do not replace any step above.
