local dpdk		= require "dpdk"
local pipe		= require "pipe"
local timer		= require "timer"
local turbo		= require "turbo"
local device		= require "device"
local ts		= require "timestamping"
local hist		= require "histogram"

function master(txPort, rxPort)
	if not txPort or not rxPort then
		errorf("usage: txPort rxPort");
	end
	local txDev = device.config(txPort)
	local rxDev = device.config(rxPort)
	local p = pipe:newSlowPipe()
	dpdk.launchLua("slave", txDev:getTxQueue(0), rxDev:getRxQueue(0), p)
	dpdk.launchLua("server", p)
	dpdk.waitForSlaves()
end

function slave(txQueue, rxQueue, pipe)
	local timestamper = ts:newTimestamper(txQueue, rxQueue)
	local hist = hist:new()
	while dpdk.running() do
		hist:update(timestamper:measureLatency())
		pipe:send(hist:avg())
	end
	hist:print()
end

function server(pipe)
	local port = 80
	
	local CSVHandler = class("CSVHandler", turbo.web.RequestHandler)
	function CSVHandler:get()
		local a = pipe:tryRecv(0)
        	if a ~= nil then
			self:write({x=0, value=a, othervalue=20})
		end 
	end

	local app = turbo.web.Application:new({
        	-- Serve single index.html file on root requests.
        	{"^/$", turbo.web.StaticFileHandler, "examples/webserver/index.html"},
        	-- Server csv data
        	{"^/csv/(.*)$", CSVHandler},
        	-- Serve contents of directory.
        	{"^/(.*)$", turbo.web.StaticFileHandler, "examples/webserver/"}
	})	

	local srv = turbo.httpserver.HTTPServer(app)
	srv:bind(port)
	srv:start(1) -- Adjust amount of processes to fork.
	print('Server started, listening on port: ' .. port)

	turbo.ioloop.instance():start()
end
