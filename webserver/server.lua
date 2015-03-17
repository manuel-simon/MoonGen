local Pegasus = require 'pegasus.pegasus'

local server = Pegasus:new('80')

server:start(function (req, rep)
  rep.writeHead(200)
end)
