from cgi import escape
import re


class WsgiDhcp:

  def __init__(self):
    pass

  def __call__(self, env, start_response):
    mac = escape(env['PATH_INFO'][1:])
    if (re.match("([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}", mac)):
      mac = "matches!"
    status = '200 OK'
    
    start_response(status, [('Content-Type', 'text/plain')])

    return [mac]
