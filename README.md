# udp-redirect
A simple yet flexible and very fast UDP redirector. Tested on Linux x64 and MacOS / Darwin arm64.

Useful for redirecting UDP traffic (e.g., Wireguard VPN, DNS, etc.) when doing it at a different layer (e.g., from a firewall) is difficult. Does not modify the redirected packets.

Single file source code for convenience.

![GitHub CI](https://github.com/danpodeanu/udp-redirect/actions/workflows/c-cpp.yml/badge.svg)
[![License: GPL v2](https://img.shields.io/badge/License-GPL_v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

**Community contributions are welcome.**

## Security

Supports enforcing the packet source for all received packets. This only provides modest security improvements as generating UDP packets is trivial.

## Compile

```# make```

or

```# gcc udp-redirect.c -o udp-redirect -Wall -O3```

## Run

```
./udp-redirect \
    --listen-port 51821 \
    --connect-host example.endpoint.net --connect-port 51822
```

```
./udp-redirect \
    --debug \
    --listen-address 192.168.1.32 --listen-port 51821 --listen-interface en0 \
        --listen-address-strict \
    --connect-host example.endpoint.net --connect-port 51822 \
        --connect-address-strict \
    --send-interface utun5 \
    --listen-sender-address 192.168.1.1 --listen-sender-port 51820
```

```mermaid
graph TD
    A["--------------------<br/>Wireguard Client<br/>--------------------<br/>Send from:<br/>---------------<br/>IP: 192.168.1.1<br/>Port: 51820"] <--> B("--------------------<br/>UDP Redirector<br/>--------------------<br/>Receive on:<br/>---------------<br/>IP: 192.168.1.32 (--listen-address) (optional)<br/>Port: 51821 (--listen-port)<br/>Interface: en0 (--listen-interface) (optional)<br/>---------------<br/>Receive from: (optional)<br/>---------------<br/>IP: 192.168.1.1 (--listen-sender-address) (optional)<br/>Port: 51820 (--listen-sender-port) (optional)<br/>Only receive from Wireguard Client (--listen-address-strict) (optional)<br/>---------------<br/>Send to:<br/>---------------<br/>Host: example.endpoint.net (--connect-host)</br>Port: 51822 (--connect-port)<br/>Only receive from Wireguard Server (--connect-address-strict) (optional)<br/>---------------<br/>Send from:<br/>---------------<br/>Interface: utun5 (--sender-interface) (optional)<br/><br/>")
    B <--> C["--------------------<br/>Wireguard Server<br/>--------------------<br/>Listen on:<br/>---------------<br/>Host: example.endpoint.net<br/>Port: 51822"]
```

Sample statistics output when invoked with ```--stats```:
```
---- STATS 60s ----
listen:receive:packets: 7.5K (122.4 /s), listen:receive:bytes: 3.6M (59.4K/s)
listen:send:packets: 12.8K (210.2 /s), listen:send:bytes: 13.8M (225.4K/s)
connect:receive:packets: 12.8K (210.2 /s), connect:receive:bytes: 13.8M (225.4K/s)
connect:send:packets: 7.5K (122.4 /s), connect:send:bytes: 3.6M (59.4K/s)
---- STATS TOTAL ----
listen:receive:packets: 45.8K (250.0 /s), listen:receive:bytes: 13.2M (72.4K/s)
listen:send:packets: 98.3K (537.1 /s), listen:send:bytes: 122.9M (671.4K/s)
connect:receive:packets: 98.3K (537.1 /s), connect:receive:bytes: 122.9M (671.4K/s)
connect:send:packets: 45.8K (250.0 /s), connect:send:bytes: 13.2M (72.4K/s)
```

# Documentation

Doxygen generated documentation in [docs](docs/)/index.html

# Command Line Arguments

```udp-redirect [arguments]```

Runs in foreground and expects external process control (svscan, nohup, etc.)

## Debug

| Argument | Parameters | Req/Opt | Description |
| --- | --- | --- | --- |
| ```--verbose``` | | *optional* | Verbose mode, can be specified multiple times. |
| ```--debug``` | | *optional* | Debug mode (e.g., very verbose). |
| ```--stats``` | | *optional* | Display sent/received bytes statistics every 60 seconds. |

## Listener

The UDP sender (e.g., wireguard client) sends packets to the UDP redirector specified below.

| Argument | Parameters | Req/Opt | Description |
| --- | --- | --- | --- |
| ```--listen-address``` | ipv4 address | *optional* | Listen address, defaults to INADDR_ANY. |
| ```--listen-port``` | port | **required** | Listen port. |
| ```--listen-interface``` | interface | *optional* | Listen interface name. |
| ```--listen-address-strict``` | | *optional* | **Security:** By default, packets received from the connect endpoint will be sent to the source of the last packet received on the listener endpoint. In ```listen-address-strict``` mode, only accept packets from the same source as the first packet, or the source specified by ```listen-sender-address``` and ```listen-sender-port```. |

## Connect

The UDP redirector sends packets to the endpoint specified below.

| Argument | Parameters | Req/Opt | Description |
| --- | --- | --- | --- |
| ```--connect-address``` | ipv4 address | **required** | Connect address. |
| ```--connect-host``` | hostname | **required** | Connect host, overwrites ```connect-address``` if both are specified. |
| ```--connect-port``` | port | **required** | Connect port. |
| ```--connect-address-strict``` | | *optional* | **Security**: Only accept packets from ```connect-host``` and ```connect-port```, otherwise accept from all sources. |

# Sender

The UDP redirector sends packets from the local endpoint specified below. If any arguments are missing, it will be selected by the operating system (usually INADDR_ANY, random port, default interface).

| Argument | Parameters | Req/Opt | Description |
| --- | --- | --- | --- |
| ```--send-address``` | ipv4 address | *optional* | Send packets from this address. |
| ```--send-port``` | port | *optional* | Send packets from this port. |
| ```--send-interface``` | interface | *optional* | Send packets from this interface name. |

# Listener security

Both must be specified; listener drops packets if they do not arrive from this address / port.

| Argument | Parameters | Req/Opt | Description |
| --- | --- | --- | --- |
| ```--listen-sender-address``` | ipv4 address | *optional* | Listen endpoint only accepts packets from this source address. |
| ```--listen-sender-port``` | port | *optional* | Listen endpoint only accepts packets from this source port (must be set together, ```--listen-address-strict``` is implied). |

# Miscellaneous

| Argument | Parameters | Req/Opt | Description |
| --- | --- | --- | --- |
| ```--ignore-errors``` | | *optional* | Ignore most receive or send errors (host / network unreachable, etc.) instead of exiting. *(default)* |
| ```--stop-errors``` | | *optional* | Stop on most receive or send errors (host / network unreachable, etc.) |
