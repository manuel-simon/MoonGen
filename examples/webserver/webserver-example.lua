local dpdk		= require "dpdk"
local pipe		= require "pipe"
local timer		= require "timer"
local turbo		= require "turbo"

function master()
	local p = pipe:newSlowPipe()
	dpdk.launchLua("slave", p)
	dpdk.launchLua("server", p)
	dpdk.waitForSlaves()
end

function slave(pipe)
	for i=1,10 do
		p:send(math.random(200))
	end
	dpdk.sleepMillis(4000)
end

function server(pipe)
	local port = 80
	
	local CSVHandler = class("CSVHandler", turbo.web.RequestHandler)
	function CSVHandler:get()
		local a = pipe:recv()
        	self:write({x=0, value=a, othervalue=20})
	end

	local app = turbo.web.Application:new({
        	-- Serve single index.html file on root requests.
        	{"^/$", turbo.web.StaticFileHandler, "./index.html"},
        	-- Server csv data
        	{"^/csv/(.*)$", CSVHandler},
        	-- Serve contents of directory.
        	{"^/(.*)$", turbo.web.StaticFileHandler, "./"}
	})	

	local srv = turbo.httpserver.HTTPServer(app)
	srv:bind(port)
	srv:start(1) -- Adjust amount of processes to fork.
	print('Server started, listening on port: ' .. port)

	turbo.ioloop.instance():start()
end
