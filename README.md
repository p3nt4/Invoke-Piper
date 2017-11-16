# Piper
 Forward local or remote tcp ports through SMB pipes.

## EXAMPLES

### Local port forwarding through pipe testPipe: -L 33389:127.0.0.1:3389
```
SERVER: Invoke-PiperServer -bindPipe testPipe -destHost 127.0.0.1 -destPort 3389
CLIENT: net use \\serverIP /USER:User (OPTIONAL)
CLIENT: Invoke-PiperClient -destPipe testPipe -pipeHost serverIP -bindPort 33389
```

### Admin only remote port forwarding through pipe testPipe: -R 33389:127.0.0.1:3389
```
SERVER: Invoke-PiperServer -remote -bindPipe testPipe  -bindPort 33389 -security Administrators
CLIENT: net use \\serverIP /USER:User (OPTIONAL)
CLIENT: Invoke-PiperClient -remote -destPipe testPipe -pipeHost serverIP -destHost 127.0.0.1 -destPort 3389
```

### Dynamic port forwarding (using https://github.com/p3nt4/Invoke-SocksProxy): -D 1234

```
SERVER: Invoke-SocksProxy -bindPort 1234
SERVER: Invoke-PiperServer -bindPipe testPipe -destHost 127.0.0.1 -destPort 1234
CLIENT: net use \\serverIP /USER:User (OPTIONAL)
CLIENT: Invoke-PiperClient -destPipe testPipe -pipeHost serverIP -bindPort 1234
```

## Issues
Protocols requiring a big amount of parallel connections may exhaust all named pipes available to the system.
