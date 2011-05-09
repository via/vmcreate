#!/usr/bin/env python2

from wsgiref.simple_server import make_server
from WsgiDhcp import  WsgiDhcp


if __name__ == "__main__":

  dhcpserver = WsgiDhcp()

  httpd = make_server('localhost', 8051, dhcpserver)

  httpd.serve_forever()
