
-- Load generator with included latency measurement controllable via web interface.

local dpdk    = require "dpdk"
local pipe    = require "pipe"
local timer   = require "timer"
local turbo   = require "turbo"
local device  = require "device"
local hist    = require "histogram"
local memory  = require "memory"
local ts      = require "timestamping"
local headers = require "headers"
local packet  = require "packet"

-- number of pipes/queues for loadgenerator
local NUM_PIPES = 1
local NUM_QUEUES = 3 

-- Initialize load generator, latency measurement and webserver.
-- rxPort Port where to accept timestamped packets
-- txPort Port sending packets of loadgen & latency measurement alike.
function master(rxPort, txPort)
	if not rxPort or not txPort then
		errorf("usage: rxPort txPort");
	end
	--configure transferring device for 1 rx (0 no possible) and NUM_QUEUES+1 tx queues (latency measurement + loadgen)
	local txDev = device.config(txPort, 1, NUM_QUEUES+1)
	-- configure receiving device for 1 rx (latency measurement) and 1 tx queue (0 queues impossible)
	local rxDev = device.config(rxPort, 1, 1)
	device.waitForLinks()

	--LOADGEN TASK
	local throughputPipes = {}
	local throughputQueues = {}
	for i=1, NUM_PIPES do
		throughputPipes[i] = pipe:newSlowPipe()
	end
	for i=1, NUM_QUEUES do
		throughputQueues[i] = txDev:getTxQueue(i-1)
	end
	dpdk.launchLua("throughputSlave", throughputQueues, throughputPipes[1], 1, 3)
	
	--LATENCY MEASUREMENT TASK
	local latencyPipe = pipe:newSlowPipe()
	local latencyTxQueue = txDev:getTxQueue(NUM_QUEUES)
	local latencyRxQueue = rxDev:getRxQueue(0)
	dpdk.launchLua("latencySlave", latencyTxQueue, latencyRxQueue, latencyPipe)

	--WEBSERVER TASK
	--SAVE THE THREADS and start server in master thread
	--dpdk.launchLua("server", queues, pipes)
	server(throughputQueues, throughputPipes, latencyPipe)

	dpdk.waitForSlaves()
end

-- Measure the throughput and send this value via a pipe.
-- txQueues Queues sending packets.
-- pipes Pipes to send throughput values.
-- start Start index of first queue to use from txQueues/pipes.
-- fin End index of last queue to use from txQueues/pipes
function throughputSlave(txQueues, p, start, fin)

	local packetLen = 64 - 4

	local minIP, ipv4 = parseIPAddress("192.168.0.1")
	local mem = memory.createMemPool(
	function(buf)
		local pkt = buf:getUdpPacket(ipv4):fill{
			ethSrc="90:e2:ba:2c:cb:02", ethDst="90:e2:ba:35:b5:81",
			ipSrc="192.168.1.1",
			pktLength=packetLen
		}
	end
	)

	local lastPrint = dpdk.getTime()
	local totalSent = 0
	local lastTotal = 0
	local lastSent = 0
	local bufs = {}
	local counter = 0
	local c = 0
	for i=start, fin do
		bufs[i] = mem:bufArray(128)
	end

	while dpdk.running() do

		for i=start, fin do

			-- allocate packets and set their size 
			bufs[i]:alloc(packetLen)
			for ii, buf in ipairs(bufs[i]) do 			
				local pkt = buf:getUdpPacket(ipv4)

				-- increment IP
				pkt.ip:setDst(minIP)
				pkt.ip.dst:add(counter)
				counter	= incAndWrap(counter, 1)

				-- dump first few packets to see what we send
				if c < 3 then
					buf:dump()
					c = c + 1
				end
			end 

			-- offload checksums to NIC
			bufs[i]:offloadUdpChecksums(ipv4)

			totalSent = totalSent + txQueues[i]:send(bufs[i])

		end

		-- print statistics
		local time = dpdk.getTime()
		if time - lastPrint > 1.0 then
			local mpps = (totalSent - lastTotal) / (time - lastPrint)
			printf("%.5f %d", time - lastPrint, totalSent - lastTotal)	-- packet_counter-like output
			--printf("Sent %d packets, current rate %.2f Mpps, %.2f MBit/s, %.2f MBit/s wire rate", totalSent, mpps, mpps * 64 * 8, mpps * 84 * 8)
			lastTotal = totalSent
			lastPrint = time
			p:send(mpps)
		end

	end

end

-- Measure the latency between two queues and send latency via a pipe.
-- txQueue Queue sending packets to timestamp.
-- rxQueue Queue accepting packets to timestamp.
-- pipe Pipe to send latency of timestamped packets.
function latencySlave(txQueue, rxQueue, pipe)

	local timestamper = ts:newTimestamper(txQueue, rxQueue)
	--minimum wait time between consecutive timestampings (in s)
	local waitTimer = timer:new(0.001)

	while dpdk.running() do
		waitTimer:reset()	
		local stamp = math.random(1, 10) --timestamper:measureLatency()
		pipe:send(stamp)
		waitTimer:busyWait()
	end

end

-- Extract the latest data from a pipe.
function acceptData(pipe, num)

	local numMsgs = tonumber(pipe:count())
	local p0 = 0
	for i=1,numMsgs do
		p0 = pipe:tryRecv(0)
	end

	return p0

end

-- Accept settings via http post & visualize data accepted via pipe.
-- queues Queues to set rate for.
-- throughputPipes Pipes to accept data to visualize from member in queues.
-- latencyPipe Pipe to accept data from latency measurements.
function server(queues, throughputPipes, latencyPipe)

	local port = 80
	local hist = hist:new()
	local runtime = 0

	local ThroughputHandler = class("ThroughputHandler", turbo.web.RequestHandler)
	function ThroughputHandler:get()
		p = {}
		result = 0
		for i=1, #throughputPipes do
			p[i] = acceptData(throughputPipes[i], i)	
		end
		for i=1, #p do
			result = result + p[i]
		end
		self:write({x=runtime, y=result})
		runtime = runtime + 1
	end

	local LatencyHistogramHandler = class("LatencyHistogramHandler", turbo.web.RequestHandler)
	function LatencyHistogramHandler:get()
		self:add_header("Content-Type", "application/json")
		local numMsgs = tonumber(latencyPipe:count())
		local p0 = 0
		for i=1,numMsgs do
			p0 = latencyPipe:tryRecv(0)
			hist:update(p0)
		end
		hist:calc()
		result = "" 
		for k, v in pairs(hist.histo) do
			if string.len(result) == 0 then
				result = '{"histo": ['
			else
				result = result .. ","
			end
			result = result .. '{"x":' .. k .. ', ' ..'"y":' .. v .. '}'
		end
		result = result .. "]}"
		print(result)
		self:write(result)
	end

	local PostSettingHandler = class("PostSettingHandler", turbo.web.RequestHandler)
	function PostSettingHandler:post()
		local json = self:get_json()
		print("New throughput to set: " .. json.setThroughput)
		if json.setThroughput ~= nil then
			for i=1, #queues do
				rate = json.setThroughput / #queues / 84 * 64
				queues[i]:setRate(rate)
				hist = hist:new()
			end
		end
	end

	local app = turbo.web.Application:new({
		-- Serve single index.html file on root requests.
		{"^/$", turbo.web.StaticFileHandler, "examples/webserver/speed.html"},
		-- Serve throughput data
		{"^/data/throughput", ThroughputHandler},
		-- Serve latency data
		{"^/data/latency", LatencyHistogramHandler},
		-- Accept and Serve settings
		{"^/post/(.*)$", PostSettingHandler},
		-- Serve contents of directory.
		{"^/(.*)$", turbo.web.StaticFileHandler, "examples/webserver/"}
	})	

	local srv = turbo.httpserver.HTTPServer(app)
	srv:bind(port)
	srv:start(1) -- Adjust amount of processes to fork.
	print('Server started, listening on port: ' .. port)

	turbo.ioloop.instance():start()

end
