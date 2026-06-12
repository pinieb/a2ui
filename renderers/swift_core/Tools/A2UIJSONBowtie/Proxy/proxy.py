import sys
import socket
import os

def get_default_gateway():
    """Reads the default gateway IP from the Linux kernel routing table."""
    try:
        if os.path.exists("/proc/net/route"):
            with open("/proc/net/route", "r") as f:
                for line in f:
                    fields = line.strip().split()
                    if len(fields) >= 3 and fields[1] == "00000000":  # Default route
                        hex_gw = fields[2]
                        bytes_gw = bytes.fromhex(hex_gw)
                        gw_ip = ".".join(str(b) for b in reversed(bytes_gw))
                        return gw_ip
    except Exception as e:
        sys.stderr.write(f"Warning: Could not parse default gateway: {e}\n")
        sys.stderr.flush()
    return None

def get_bridge_ips():
    """Finds possible host bridge IPs by looking at local subnet routes and replacing the last octet with .1."""
    ips = []
    try:
        if os.path.exists("/proc/net/route"):
            with open("/proc/net/route", "r") as f:
                for line in f:
                    fields = line.strip().split()
                    # Skip header and default route
                    if len(fields) >= 3 and fields[1] != "00000000" and fields[1] != "Destination":
                        hex_dest = fields[1]
                        bytes_dest = bytes.fromhex(hex_dest)
                        dest_bytes = list(reversed(bytes_dest))
                        if len(dest_bytes) == 4:
                            dest_bytes[3] = 1  # Standard bridge gateway is always .1
                            bridge_ip = ".".join(str(b) for b in dest_bytes)
                            ips.append(bridge_ip)
    except Exception as e:
        sys.stderr.write(f"Warning: Could not parse bridge IPs: {e}\n")
        sys.stderr.flush()
    return ips

def main():
    port = int(os.environ.get("HARNESS_PORT", "12345"))
    
    hosts_to_try = []
    
    # 1. Try dynamically detected bridge IPs (crucial for isolated bridge networks)
    bridge_ips = get_bridge_ips()
    if bridge_ips:
        sys.stderr.write(f"Detected local bridge IPs: {bridge_ips}\n")
        sys.stderr.flush()
        hosts_to_try.extend(bridge_ips)
        
    # 2. Try dynamically detected default gateway
    gw = get_default_gateway()
    if gw and gw not in hosts_to_try:
        sys.stderr.write(f"Detected default gateway IP: {gw}\n")
        sys.stderr.flush()
        hosts_to_try.append(gw)
    
    # 3. Append standard hostnames and fallback IPs
    hosts_to_try.extend([
        "host.docker.internal",
        "host.containers.internal",
        "192.168.127.1",     # Podman macOS standard gateway
        "10.0.2.2",          # QEMU default gateway
        "192.168.5.2",       # Lima/Colima default gateway
        "127.0.0.1"          # Fallback
    ])
    
    # Allow explicit override via environment variable
    if "HARNESS_HOST" in os.environ:
        hosts_to_try = [os.environ["HARNESS_HOST"]]

    s = None
    for host in hosts_to_try:
        sys.stderr.write(f"Trying to connect to Swift harness at {host}:{port}...\n")
        sys.stderr.flush()
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(2.0)  # 2 seconds timeout for quick detection
            s.connect((host, port))
            s.settimeout(None)  # Reset to blocking mode
            sys.stderr.write(f"Connected successfully to Swift harness at {host}:{port}!\n")
            sys.stderr.flush()
            break
        except Exception as e:
            sys.stderr.write(f"Connection to {host} failed: {e}\n")
            sys.stderr.flush()
            s.close()
            s = None

    if not s:
        sys.stderr.write("ERROR: Could not connect to Swift harness on any of the attempted hosts.\n")
        sys.stderr.flush()
        sys.exit(1)

    rfile = s.makefile('r', encoding='utf-8')
    wfile = s.makefile('w', encoding='utf-8')

    try:
        for line in sys.stdin:
            wfile.write(line)
            wfile.flush()

            response = rfile.readline()
            if not response:
                sys.stderr.write("Harness closed connection.\n")
                sys.stderr.flush()
                break

            sys.stdout.write(response)
            sys.stdout.flush()
    except KeyboardInterrupt:
        pass
    except Exception as e:
        sys.stderr.write(f"Proxy error: {e}\n")
        sys.stderr.flush()
    finally:
        s.close()

if __name__ == "__main__":
    main()
