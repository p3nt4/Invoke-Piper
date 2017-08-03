# Piper
 Creates a local or remote port forwarding through named pipes.

##DESCRIPTION

Creates a local or remote port forwarding through named pipes.

##EXAMPLE
```
Invoke-PiperServer -bindPipe testPipe -destHost 127.0.0.1 -destPort 3389
Invoke-PiperClient -destPipe testPipe -pipeHost 192.168.1.1 -bindPort 33389
```

Creates a local port forwarding through pipe testPipe: -L 33389:127.0.0.1:3389
```
Invoke-PiperServer -remote -bindPipe testPipe  -bindPort 33389
Invoke-PiperClient -remote -destPipe testPipe -pipeHost 192.168.1.1 -destHost 127.0.0.1 -destPort 3389
```
Creates a remote port forwarding through pipe testPipe: -R 33389:127.0.0.1:3389
