import socket
import time


destination = socket.gethostbyname("snort-smb-traversal-test-server")
payload = b"\x5c../\x00\x00\x00"
last_error = None

for _ in range(20):
    try:
        with socket.create_connection((destination, 139), timeout=2) as connection:
            connection.sendall(payload)
        print(f"Sent the SID 534 test pattern to {destination}:139.")
        break
    except OSError as error:
        last_error = error
        time.sleep(0.5)
else:
    raise RuntimeError(f"Could not reach the dummy TCP/139 listener: {last_error}")
