local turbo = require "turbo"

local port = 80

local app = turbo.web.Application:new({
	-- Serve single index.html file on root requests.
	{"^/$", turbo.web.StaticFileHandler, "./index.html"},
	-- Serve contents of directory.
	{"^/(.*)$", turbo.web.StaticFileHandler, "./"}
})

local srv = turbo.httpserver.HTTPServer(app)
srv:bind(port)
srv:start(1) -- Adjust amount of processes to fork.
print('server listening on port: ' .. port)

turbo.ioloop.instance():start()
