import socket
import time


destination = socket.gethostbyname("snort-mysql-test")
attempts = 7

for _ in range(attempts):
    try:
        with socket.create_connection((destination, 22), timeout=1):
            pass
    except OSError:
        pass
    time.sleep(0.2)

print(f"Sent {attempts} TCP connection attempts to {destination}:22.")
