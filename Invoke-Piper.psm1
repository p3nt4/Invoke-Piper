<#
.SYNOPSIS

Creates a local or remote port forwarding through named pipes.

Author: p3nt4 (https://twitter.com/xP3nt4)
License: MIT

.DESCRIPTION

Creates a local or remote port forwarding through named pipes.

.EXAMPLE

Invoke-PiperServer -bindPipe testPipe -destHost 127.0.0.1 -destPort 3389
Invoke-PiperClient -destPipe testPipe -pipeHost 192.168.1.1 -bindPort 33389

Creates a local port forwarding through pipe testPipe: -L 33389:127.0.0.1:3389

Invoke-PiperServer -remote -bindPipe testPipe  -bindPort 33389 -security Administrators
Invoke-PiperClient -remote -destPipe testPipe -pipeHost 192.168.1.1 -destHost 127.0.0.1 -destPort 3389

Creates an admin only remote port forwarding through pipe testPipe: -R 33389:127.0.0.1:3389
#>

[ScriptBlock]$CliConnectionMgr = {
    param($vars)
    $destPipe=$vars.destPipe
    $tcpConnection=$vars.tcpConnection
    $pipeHost=$vars.pipeHost
    $Script = {
	    param($vars)
        try{
            $vars.inStream.CopyTo($vars.outStream)
        }
        catch{}
        finally{
            $vars.pipe.Close()
            $vars.pipe.Dispose()
        }    
    }
     try{
        $inPipeName= -Join($destPipe,'.in')
        $outPipeName= -Join($destPipe,'.out')
        $inPipe= new-object System.IO.Pipes.NamedPipeClientStream($pipeHost, $inPipeName, [System.IO.Pipes.PipeDirection]::InOut,
                                                                        [System.IO.Pipes.PipeOptions]::None, 
                                                                        [System.Security.Principal.TokenImpersonationLevel]::Impersonation)
        $inPipe.connect() 
        $outPipe= new-object System.IO.Pipes.NamedPipeClientStream($pipeHost, $outPipeName, [System.IO.Pipes.PipeDirection]::InOut,
                                                                        [System.IO.Pipes.PipeOptions]::None, 
                                                                        [System.Security.Principal.TokenImpersonationLevel]::Impersonation)
        $outPipe.connect()
        $tcpStream = $tcpConnection.GetStream() 
        $vars2 = [PSCustomObject]@{"inStream"=$outPipe;"outStream"=$tcpStream;"pipe"=$outPipe}
        $PS = [PowerShell]::Create()
        $PS.AddScript($Script).AddArgument($vars2) | Out-Null
        [System.IAsyncResult]$AsyncJobResult = $null
	    $AsyncJobResult = $PS.BeginInvoke()
        try{
            $tcpStream.CopyTo($inPipe)
        }
        catch{}
        finally{
            $inPipe.Close()
            $inPipe.Dispose()
        } 
    }
    catch {}
}


[ScriptBlock]$SrvConnectionMgr = {
    param($vars)
    $bindPipe=$vars.bindPipe
    $PipeSecurity=$vars.pipeSecurity
    $tcpConnection=$vars.tcpConnection
    $Script = {
	    param($vars)
        try{
            $vars.inStream.CopyTo($vars.outStream)
        }
        catch{}
        finally{
            $vars.pipe.Disconnect()
            $vars.pipe.Close()
            $vars.pipe.Dispose()
        }    
    }
    try
    {
        $inPipeName= -Join($bindPipe,'.in')
        $inPipe= new-object System.IO.Pipes.NamedPipeServerStream($inPipeName,"InOut",100, "Byte", "Asynchronous", 32768, 32768, $PipeSecurity)
        $inPipe.WaitForConnection()
        $outPipeName= -Join($bindPipe,'.out')
        $outPipe= new-object System.IO.Pipes.NamedPipeServerStream($outPipeName, "InOut",100, "Byte", "Asynchronous", 32768, 32768, $PipeSecurity)
        $outPipe.WaitForConnection()
        $srvStream= $tcpConnection.GetStream() 
        $vars = [PSCustomObject]@{"inStream"=$srvStream;"outStream"=$outPipe;"pipe"=$outPipe}
        $PS = [PowerShell]::Create()
        $PS.AddScript($Script).AddArgument($vars) | Out-Null
        [System.IAsyncResult]$AsyncJobResult = $null
        $AsyncJobResult = $PS.BeginInvoke()
        try{
            $inPipe.CopyTo($srvStream)
        }
        catch{}
        finally{
            $inPipe.Disconnect()
            $inPipe.Close()
            $inPipe.Dispose()
            $inPipe = $null
        } 
    }
    catch {
    }
}


function Invoke-PiperServer{
    param (
            [String]$bindPipe,

            [String]$destHost,

            [String]$security = "Everyone",

            [Int]$destPort,

            [String]$bindIP = "0.0.0.0",

            [Int]$bindPort,

            [switch]$remote = $false
		        
     )
    try{
        $enc = [system.Text.Encoding]::UTF8
        $clientBuffer = new-object System.Byte[] 16
        $PipeSecurity = new-object System.IO.Pipes.PipeSecurity
        $AccessRule = New-Object System.IO.Pipes.PipeAccessRule( $security, "FullControl", "Allow" )
        $PipeSecurity.AddAccessRule($AccessRule)
        $pipe= new-object System.IO.Pipes.NamedPipeServerStream($bindPipe,"InOut",100, "Byte", "Asynchronous", 32768, 32768, $PipeSecurity)
        write-host "Waiting for a connection on management pipe: $bindPipe..."
        $pipe.WaitForConnection()
        write-host "Client Connected"
        if ($remote -eq $false){
            while($pipe.IsConnected){
                $pipe.read($clientBuffer,0,16) | Out-Null
                $tempPipe = [System.Text.Encoding]::ASCII.GetString($clientBuffer, 0, 16)
                Write-Host "New Connection"
                $serv = New-Object System.Net.Sockets.TcpClient($destHost, $destPort)
                $vars = [PSCustomObject]@{"tcpConnection"=$serv;"bindPipe"=$tempPipe;"pipeSecurity"=$PipeSecurity}
                $PS3 = [PowerShell]::Create()
                $PS3.AddScript($SrvConnectionMgr).AddArgument($vars) | Out-Null
                [System.IAsyncResult]$AsyncJobResult3 = $null
                $AsyncJobResult3 = $PS3.BeginInvoke()
            }
        }else{
            $listener = new-object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($bindIP), $bindPort)
            $listener.start()
            write-host "Listening on port $bindPort..."
            while($pipe.IsConnected){
                $client = $listener.AcceptTcpClient()
                $tempPipe = Get-RandomPipeName
                $clientBuffer = $enc.GetBytes($tempPipe) 
                Write-Host "New Connection"
                $pipe.Write($clientBuffer,0,16)
                $vars = [PSCustomObject]@{"tcpConnection"=$client;"bindPipe"=$tempPipe;"security"=$security}
                $PS3 = [PowerShell]::Create()
                $PS3.AddScript($SrvConnectionMgr).AddArgument($vars) | Out-Null
                [System.IAsyncResult]$AsyncJobResult3 = $null
                $AsyncJobResult3 = $PS3.BeginInvoke()
            }
        }
    }
    catch{
     write-host $_.Exception
    }
    finally{
        if ($listener -ne $null) {
		    $listener.Stop()
	    }
        if ($pipe -ne $null) {
            $pipe.Close()
            $pipe.Dispose()
            $pipe = $null
        }
        if ($PS3 -ne $null -and $AsyncJobResult3 -ne $null) {
            $PS3.EndInvoke($AsyncJobResult3) | Out-Null
            $PS3.Dispose()
        }
        write-host "Management Connection closed."
    }
    
}

function Invoke-PiperClient{
    param (
        
        [String]$pipeHost,

        [String]$destPipe,

        [switch]$remote = $false,
        
        [String]$bindIP = "0.0.0.0",
       
        [Int]$bindPort,

        [String]$destHost,

        [Int]$destPort
        
    ) 
    $clientBuffer = new-object System.Byte[] 16
    $enc = [system.Text.Encoding]::UTF8
    try{
        write-host "Attempting to connect to $pipeHost through management pipe: $destPipe"
        $pipe= new-object System.IO.Pipes.NamedPipeClientStream($pipeHost, $destPipe, [System.IO.Pipes.PipeDirection]::InOut,
                                                                    [System.IO.Pipes.PipeOptions]::None, 
                                                                    [System.Security.Principal.TokenImpersonationLevel]::Impersonation)
        $pipe.connect()
        write-host "Connected to $pipeHost through management pipe: $destPipe"
        if ($remote -eq $false){
            $listener = new-object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($bindIP), $bindPort)
            $listener.start()
            write-host "Listening on port $bindPort..."
            while($pipe.IsConnected){
                $client = $listener.AcceptTcpClient()
                $tempPipe = Get-RandomPipeName
                $clientBuffer = $enc.GetBytes($tempPipe) 
                Write-Host "New Connection"
                $pipe.Write($clientBuffer,0,16)
                $vars = [PSCustomObject]@{"tcpConnection"=$client;"destPipe"= $tempPipe;"pipeHost"=$pipeHost}
                $PS3 = [PowerShell]::Create()
                $PS3.AddScript($CliConnectionMgr).AddArgument($vars) | Out-Null
                [System.IAsyncResult]$AsyncJobResult3 = $null
                $AsyncJobResult3 = $PS3.BeginInvoke()
                }
            }
        else{
            while($pipe.IsConnected){
                $pipe.read($clientBuffer,0,16) | Out-Null
                Write-Host "New Connection"
                $tempPipe = [System.Text.Encoding]::ASCII.GetString($clientBuffer, 0, 16)
                $serv = New-Object System.Net.Sockets.TcpClient($destHost, $destPort)
                $vars = [PSCustomObject]@{"tcpConnection"=$serv;"destPipe"= $tempPipe;"pipeHost"=$pipeHost}
                $PS3 = [PowerShell]::Create()
                $PS3.AddScript($CliConnectionMgr).AddArgument($vars) | Out-Null
                [System.IAsyncResult]$AsyncJobResult3 = $null
                $AsyncJobResult3 = $PS3.BeginInvoke()
                }
        }
    }catch {
	    write-host $_.Exception
    }
    finally {
	   if ($listener -ne $null) {
		    $listener.Stop()
	   }
       if ($pipe -ne $null) {
            $pipe.Close()
            $pipe.Dispose()
            $pipe = $null
        }
        if ($PS3 -ne $null -and $AsyncJobResult3 -ne $null) {
            $PS3.EndInvoke($AsyncJobResult3) | Out-Null
            $PS3.Dispose()
        }
        write-host "Management Connection closed."
    }
    
}


function Get-RandomPipeName{
    $text = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | % {[char]$_})
    return $text
}

export-modulemember -function Invoke-PiperServer
export-modulemember -function Invoke-PiperClient
