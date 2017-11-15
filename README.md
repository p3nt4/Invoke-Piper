# Piper
 Creates a local or remote port forwarding through SMB pipes.

## EXAMPLES

```
SERVER: Invoke-PiperServer -bindPipe testPipe -destHost 127.0.0.1 -destPort 3389
CLIENT: net use \\serverIP /USER:User (OPTIONAL)
CLIENT: Invoke-PiperClient -destPipe testPipe -pipeHost serverIP -bindPort 33389
```

Creates a local port forwarding through pipe testPipe: -L 33389:127.0.0.1:3389

```
SERVER: Invoke-PiperServer -remote -bindPipe testPipe  -bindPort 33389 -security Administrators
CLIENT: net use \\serverIP /USER:User (OPTIONAL)
CLIENT: Invoke-PiperClient -remote -destPipe testPipe -pipeHost serverIP -destHost 127.0.0.1 -destPort 3389
```
Creates an admin only remote port forwarding through pipe testPipe: -R 33389:127.0.0.1:3389

## Issues
Protocols requiring a big amount of parallel connections may exhaust all named pipes.
