from cgi import escape
import re
import json
import couchdb


class WsgiDhcp:

  def __init__(self, servername):
    self.couch = couchdb.Server(servername)
    self.hostsdb = self.couch['hosts']
    self.netsdb = self.couch['networks']

  def __call__(self, env, start_response):
    if env['REQUEST_METHOD'] == 'GET':
      return self.GET(env, start_response)
    else: 
      start_response('405 Bad Method', 
          [('Content-Type', 'text/plain')])
      return ["DHCP information is read only"]

  def GET(self, env, start_response):
    mac = escape(env['PATH_INFO'][1:]).upper()
    if (not re.match("([0-9A-F]{2}:){5}[0-9A-F]{2}$", mac)):
      start_response('400 Invalid MAC Address', [('Content-Type', 'text/plain')])
      return ["Invalid MAC"]


    body = []
    response = {}
    view = self.hostsdb.view('default/dhcp')
    entries = view[mac:mac]
    if len(entries) > 1:
      start_response('500 Internal Server Error', [('Content-Type', 'text/plain')])
      body.append("More than one host configured with this MAC. Please check"
          "configuration")
    elif len(entries) == 0:
      start_response('404 Not Found', [('Content-Type', 'text/plain')])
      body.append("No hosts configured with this MAC");
    else:
      host = self.hostsdb[entries.rows[0].id]
      try:
        network = self.netsdb[host["nics"][mac]["network"]]
      except ResourceNotFound:
        start_response('404 Not Found', [('Content-Type', 'text/plain')])
        return "Network not found"


      response["ip"] = host["nics"][mac]["ipv4"]
      response["gateway"] = network["gateways"]
      response["dns"] = network["nameservers"]
      response["nextserver"] = network["nextserver"]
      response["filename"] = "gpxelinux.0"


      start_response('200 Ok', [('Content-Type', 'text/plain')])
      body.append(json.dumps(response))
    
    return body

