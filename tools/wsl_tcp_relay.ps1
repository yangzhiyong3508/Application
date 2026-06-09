param(
    [string]$ListenAddress = "192.168.1.105",
    [int]$ListenPort = 19090,
    [string]$ConnectAddress = "172.28.80.14",
    [int]$ConnectPort = 19090
)

$ErrorActionPreference = "Stop"

$listenIp = [System.Net.IPAddress]::Parse($ListenAddress)
$listener = [System.Net.Sockets.TcpListener]::new($listenIp, $ListenPort)
$listener.Server.SetSocketOption(
    [System.Net.Sockets.SocketOptionLevel]::Socket,
    [System.Net.Sockets.SocketOptionName]::ReuseAddress,
    $true
)
$listener.Start()
Write-Host "relay listening ${ListenAddress}:${ListenPort} -> ${ConnectAddress}:${ConnectPort}"

while ($true) {
    $client = $listener.AcceptTcpClient()
    $server = [System.Net.Sockets.TcpClient]::new()
    try {
        $server.Connect($ConnectAddress, $ConnectPort)
        Write-Host "relay accepted $($client.Client.RemoteEndPoint)"

        $clientStream = $client.GetStream()
        $serverStream = $server.GetStream()

        $up = [System.Threading.Tasks.Task]::Run([Action]{
            try { $clientStream.CopyTo($serverStream) } catch {}
            try { $serverStream.Close() } catch {}
        })
        $down = [System.Threading.Tasks.Task]::Run([Action]{
            try { $serverStream.CopyTo($clientStream) } catch {}
            try { $clientStream.Close() } catch {}
        })

        [void][System.Threading.Tasks.Task]::WaitAny($up, $down)
    } catch {
        Write-Host "relay connection failed: $($_.Exception.Message)"
    } finally {
        try { $client.Close() } catch {}
        try { $server.Close() } catch {}
    }
}
