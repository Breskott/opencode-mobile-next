#!/usr/bin/env python3
"""Tiny TCP forwarder: tailnet address -> loopback supervisor (no socat needed)."""
import socket, threading, sys
BIND=(sys.argv[1], int(sys.argv[2])); DEST=('127.0.0.1', int(sys.argv[3]))
def pump(a,b):
    try:
        while True:
            d=a.recv(65536)
            if not d: break
            b.sendall(d)
    except OSError: pass
    finally:
        try: b.shutdown(socket.SHUT_WR)
        except OSError: pass
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR,1); s.bind(BIND); s.listen(64)
while True:
    c,_=s.accept(); u=socket.create_connection(DEST)
    threading.Thread(target=pump,args=(c,u),daemon=True).start()
    threading.Thread(target=pump,args=(u,c),daemon=True).start()
