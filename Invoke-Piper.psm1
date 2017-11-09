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

Invoke-PiperServer -remote -bindPipe testPipe  -bindPort 33389
Invoke-PiperClient -remote -destPipe testPipe -pipeHost 192.168.1.1 -destHost 127.0.0.1 -destPort 3389

Creates a remote port forwarding through pipe testPipe: -R 33389:127.0.0.1:3389
#>

[ScriptBlock]$CliConnectionMgr = {
    param($vars)
    $destPipe=$vars.destPipe
    $tcpConnection=$vars.tcpConnection
    $pipeHost=$vars.pipeHost
    $Script = {
	    param($vars)
        $vars.inStream.CopyToAsync($vars.outStream)    
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
        $vars2 = [PSCustomObject]@{"inStream"=$outPipe;"outStream"=$tcpStream}
        $PS = [PowerShell]::Create()
        $PS.AddScript($Script).AddArgument($vars2) | Out-Null
        [System.IAsyncResult]$AsyncJobResult = $null

        $vars3 = [PSCustomObject]@{"inStream"=$tcpStream;"outStream"=$inPipe}
        $PS2 = [PowerShell]::Create()
        $PS2.AddScript($Script).AddArgument($vars3) | Out-Null
        [System.IAsyncResult]$AsyncJobResult2 = $null

	    $AsyncJobResult = $PS.BeginInvoke()
        $AsyncJobResult2 = $PS2.BeginInvoke()
	    while($tcpConnection.Connected -and $inPipe.IsConnected -and $outPipe.IsConnected){
            sleep -m 100;
        }
    }
    catch {
    }
    finally {
        if ($tcpConnection -ne $null) {
            $tcpConnection.Close()
            $tcpConnection.Dispose()
            $tcpConnection = $null
        }
        if ($inPipe -ne $null) {
            $inPipe.Close()
            $inPipe.Dispose()
            $inPipe = $null
        }
        if ($outPipe -ne $null) {
            $outPipe.Close()
            $outPipe.Dispose()
            $outPipe = $null
        }
        if ($PS -ne $null -and $AsyncJobResult -ne $null) {
            $PS.EndInvoke($AsyncJobResult) | Out-Null
            $PS.Dispose()
        }
        if ($PS2 -ne $null -and $AsyncJobResult2 -ne $null) {
            $PS2.EndInvoke($AsyncJobResult2) | Out-Null
            $PS2.Dispose()
        }
    }
}


[ScriptBlock]$SrvConnectionMgr = {
    param($vars)
    $bindPipe=$vars.bindPipe
    $tcpConnection=$vars.tcpConnection
    $Script = {
        param($vars)
        $vars.inStream.CopyToAsync($vars.outStream)
    }
    try
    {
        $inPipeName= -Join($bindPipe,'.in')
        $PipeSecurity = new-object System.IO.Pipes.PipeSecurity
        $AccessRule = New-Object System.IO.Pipes.PipeAccessRule( "Everyone", "FullControl", "Allow" )
        $PipeSecurity.AddAccessRule($AccessRule)
        $inPipe= new-object System.IO.Pipes.NamedPipeServerStream($inPipeName,"InOut",100, "Byte", "Asynchronous", 32768, 32768, $PipeSecurity)
        $inPipe.WaitForConnection()
        $outPipeName= -Join($bindPipe,'.out')
        $outPipe= new-object System.IO.Pipes.NamedPipeServerStream($outPipeName, "InOut",100, "Byte", "Asynchronous", 32768, 32768, $PipeSecurity)
        $outPipe.WaitForConnection()
        $srvStream= $tcpConnection.GetStream() 
        $vars = [PSCustomObject]@{"inStream"=$srvStream;"outStream"=$outPipe}
        $vars2 = [PSCustomObject]@{"inStream"=$inPipe;"outStream"=$srvStream}
        $PS = [PowerShell]::Create()
        $PS.AddScript($Script).AddArgument($vars) | Out-Null
        [System.IAsyncResult]$AsyncJobResult = $null
        $PS2 = [PowerShell]::Create()
        $PS2.AddScript($Script).AddArgument($vars2) | Out-Null
        [System.IAsyncResult]$AsyncJobResult2 = $null
        $AsyncJobResult = $PS.BeginInvoke()
        $AsyncJobResult2 = $PS2.BeginInvoke()
        while($tcpConnection.Connected -and $inPipe.IsConnected -and $outPipe.IsConnected){
            sleep -m 100;
        }
    }
    catch {
    }
    finally {

        if ($serv -ne $null) {
            $serv.Close()
            $serv.Dispose()
            $serv = $null
        }
        if ($inPipe -ne $null) {
            #$inPipe.Disconnect()
            $inPipe.Close()
            $inPipe.Dispose()
            $inPipe = $null
        }
        if ($outPipe -ne $null) {
            #$outPipe.Disconnect()
            $outPipe.Close()
            $outPipe.Dispose()
            $outPipe = $null
        }
        if ($PS -ne $null -and $AsyncJobResult -ne $null) {
            $PS.EndInvoke($AsyncJobResult) | Out-Null
            $PS.Dispose()
        }
        if ($PS2 -ne $null -and $AsyncJobResult2 -ne $null) {
            $PS2.EndInvoke($AsyncJobResult2) | Out-Null
            $PS2.Dispose() 
        }
    }
}


function Invoke-PiperServer{
    param (
            [String]$bindPipe,

            [String]$destHost,

            [Int]$destPort,

            [String]$bindIP = "0.0.0.0",

            [Int]$bindPort,

            [switch]$remote = $false
		        
     )
    try{
        $enc = [system.Text.Encoding]::UTF8
        $clientBuffer = new-object System.Byte[] 16
        $PipeSecurity = new-object System.IO.Pipes.PipeSecurity
        $AccessRule = New-Object System.IO.Pipes.PipeAccessRule( "Everyone", "FullControl", "Allow" )
        $PipeSecurity.AddAccessRule($AccessRule)
        $pipe= new-object System.IO.Pipes.NamedPipeServerStream($bindPipe,"InOut",100, "Byte", "Asynchronous", 32768, 32768, $PipeSecurity)
        write-host "Waiting for a connection on management pipe: $bindPipe..."
        $pipe.WaitForConnection()
        write-host "Client Connected"
        if ($remote -eq $false){
            while($pipe.IsConnected){
                $pipe.read($clientBuffer,0,16) | Out-Null
                $tempPipe = [System.Text.Encoding]::ASCII.GetString($clientBuffer, 0, 16)
                #Write-Host "Temporary pipename is: $tempPipe"
                Write-Host "New Connection"
                $serv = New-Object System.Net.Sockets.TcpClient($destHost, $destPort)
                $vars = [PSCustomObject]@{"tcpConnection"=$serv;"bindPipe"=$tempPipe}
                $PS3 = [PowerShell]::Create()
                $PS3.AddScript($SrvConnectionMgr).AddArgument($vars) | Out-Null
                [System.IAsyncResult]$AsyncJobResult3 = $null
                $AsyncJobResult3 = $PS3.BeginInvoke()
            }
        }else{
            $listener = new-object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($bindIP), $bindPort)
            $listener.start()
            $destIp = Get-IpAddress $destHost
            write-host "Listening on port $bindPort..."
            while($pipe.IsConnected){
                $client = $listener.AcceptTcpClient()
                $tempPipe = Get-RandomPipeName
                $clientBuffer = $enc.GetBytes($tempPipe) 
                #Write-Host "Temporary pipename is: $tempPipe"
                Write-Host "New Connection"
                $pipe.Write($clientBuffer,0,16)
                $vars = [PSCustomObject]@{"tcpConnection"=$client;"bindPipe"=$tempPipe}
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
    $pipeHost = Get-IpAddress $pipeHost
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
            $destIp = Get-IpAddress $destHost
            while($pipe.IsConnected){
                $pipe.read($clientBuffer,0,16) | Out-Null
                $tempPipe = [System.Text.Encoding]::ASCII.GetString($clientBuffer, 0, 16)
                $serv = New-Object System.Net.Sockets.TcpClient($destIp, $destPort)
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

function Get-IpAddress{
    param($ip)
    IF ($ip -as [ipaddress]){
        return $ip
    }else{
        $ip2 = [System.Net.Dns]::GetHostAddresses($ip)[0].IPAddressToString;
        Write-Host "$ip resolved to $ip2"
    }
    return $ip2
}

export-modulemember -function Invoke-PiperServer
export-modulemember -function Invoke-PiperClient
