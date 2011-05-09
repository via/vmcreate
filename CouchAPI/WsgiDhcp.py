from cgi import escape
import re


class WsgiDhcp:

  def __init__(self):
    pass

  def __call__(self, env, start_response):
    mac = escape(env['PATH_INFO'][1:]).upper()
    if (not re.match("([0-9A-F]{2}:){5}[0-9A-F]{2}", mac)):
      start_response('400 Invalid MAC Address', [('Content-Type', 'text/plain')])
      return ["Invalid MAC"]

    
    start_response('200 OK', [('Content-Type', 'text/plain')])
    return [mac]
