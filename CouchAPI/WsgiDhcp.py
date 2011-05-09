from cgi import escape
import re
import couchdb


class WsgiDhcp:

  def __init__(self, servername):
    self.couch = couchdb.Server(servername)
    self.hostsdb = self.couch['hosts']
    pass

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

    start_response('200 OK', [('Content-Type', 'text/plain')])

    body = []
    view = self.hostsdb.view('default/dhcp')
    entries = view[[mac]:[mac, '()']]
    for entry in view:
      body.append(entry.id.encode('utf-8'))

    return body
