# Piper
 Creates a local or remote port forwarding through named pipes.

## EXAMPLES

```
SERVER: Invoke-PiperServer -bindPipe testPipe -destHost 127.0.0.1 -destPort 3389
CLIENT: net use \\serverIP /USER:User (OPTIONAL)
CLIENT: Invoke-PiperClient -destPipe testPipe -pipeHost serverIP -bindPort 33389
```

Creates a local port forwarding through pipe testPipe: -L 33389:127.0.0.1:3389

```
SERVER: Invoke-PiperServer -remote -bindPipe testPipe  -bindPort 33389
CLIENT: net use \\serverIP /USER:User (OPTIONAL)
CLIENT: Invoke-PiperClient -remote -destPipe testPipe -pipeHost serverIP -destHost 127.0.0.1 -destPort 3389
```
Creates a remote port forwarding through pipe testPipe: -R 33389:127.0.0.1:3389

## Issues
Works well with  stateful protocols such as RDP and SSH. Still unstable with protocols requiring many paralel tcp connections such as HTTP.

Does not support access control yet, all pipes will be public or available to any authenticated user depending on the SMB configuration of the host.
