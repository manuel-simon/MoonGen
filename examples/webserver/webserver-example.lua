
-- Test latency between two network ports and visualize the average latency on a webserver (with a cable length calculation)

local dpdk   = require "dpdk"
local pipe   = require "pipe"
local timer  = require "timer"
local turbo  = require "turbo"
local device = require "device"
local ts     = require "timestamping"
local hist   = require "histogram"
local timer  = require "timer"

-- Initialize the ports to test for latency, the slave thread and the webserver thread.
-- txPort Port sending packets to timestamp.
-- rxPort Port accepting packets to timestamp.
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

-- Measure the latency between two queues and send latency via a pipe.
-- txQueue Queue sending packets to timestamp.
-- rxQueue Queue accepting packets to timestamp.
-- pipe Pipe to send latency of timestamped packets.
function slave(txQueue, rxQueue, pipe)

	local timestamper = ts:newTimestamper(txQueue, rxQueue)
	--minimum wait time between consecutive timestampings (in ms)
	local waitTimer = timer:new(0.001)

	while dpdk.running() do
		waitTimer:reset()	
		local stamp = timestamper:measureLatency()
		pipe:send(stamp)
		waitTimer:busyWait()
	end

end

-- Visualize data accepted via pipe.
-- pipe Pipe to accept data to visualize.
function server(pipe)

	local port = 80
	local hist = hist:new()
	local runtime = 0
	
	local CSVHandler = class("CSVHandler", turbo.web.RequestHandler)
	function CSVHandler:get()
		local numMsgs = tonumber(pipe:count())
		local a = 0
		print("numMsgs: " .. numMsgs)
		for i=1,numMsgs do
			a = pipe:tryRecv(0)
        		if a ~= nil then
				hist:update(a)
			end
		end
		if numMsgs > 0 then
			local average = hist:avg()
			self:write({x=runtime, y=a})
		end
		runtime = runtime + 1
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
