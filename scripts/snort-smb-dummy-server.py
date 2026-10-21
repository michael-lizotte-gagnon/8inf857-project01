import socket


with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", 139))
    server.listen()
    print("Dummy SMB-pattern test listener ready on TCP/139.", flush=True)

    while True:
        connection, _ = server.accept()
        with connection:
            connection.recv(1024)
