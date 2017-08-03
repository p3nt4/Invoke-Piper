# Piper
 Creates a local or remote port forwarding through named pipes.

## EXAMPLES

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

## Issues
Works well with  stateful protocols such as RDP and SSH. Still unstable with HTTP.
Does not support authentication yet, all pipes are public.
