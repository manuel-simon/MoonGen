
-- Send packets on a specified port and visualize the throughput on a webserver (with a cable length calculation)

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

-- Initialize one port to generate traffic.
-- txPort Port sending packets.
function master(txPort)

	if not txPort then
		errorf("usage: txPort");
	end
	local txDev = device.config(txPort)
	device.waitForLinks()	
	local p = pipe:newSlowPipe()
	local txQueue = txDev:getTxQueue(0):setRate(1)
	dpdk.launchLua("slave", txDev:getTxQueue(0), p)
	dpdk.launchLua("server", p)
	dpdk.waitForSlaves()

end

-- Measure the throughput and send this value via a pipe.
-- txQueue Queue sending packets.
-- pipe Pipe to send throughput values.
function slave(txQueue, pipe)

	local packetLen = 66 - 4

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
	local bufs = mem:bufArray(128)
	local counter = 0
	local c = 0

	while dpdk.running() do

		-- allocate packets and set their size 
		bufs:alloc(packetLen)
		for i, buf in ipairs(bufs) do 			
			local pkt = buf:getUdpPacket(ipv4)

			-- increment IP
			pkt.ip:setDst(minIP)
			pkt.ip.dst:add(counter)
			counter = incAndWrap(counter, 1)

			-- dump first few packets to see what we send
			if c < 3 then
				buf:dump()
				c = c + 1
			end
		end 
		-- offload checksums to NIC
		bufs:offloadUdpChecksums(ipv4)

		-- send packets
		totalSent = totalSent + txQueue:send(bufs)

		-- print statistics
		local time = dpdk.getTime()
		if time - lastPrint > 1.0 then
			local mpps = (totalSent - lastTotal) / (time - lastPrint)
			printf("%.5f %d", time - lastPrint, totalSent - lastTotal)	-- packet_counter-like output
			--printf("Sent %d packets, current rate %.2f Mpps, %.2f MBit/s, %.2f MBit/s wire rate", totalSent, mpps, mpps * 64 * 8, mpps * 84 * 8)
			lastTotal = totalSent
			lastPrint = time
			pipe:send(mpps)
		end

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

	local PostSettingHandler = class("PostSettingHandler", turbo.web.RequestHandler)
	function PostSettingHandler:post()
		local json = self:get_json()
		print(json)
		self:write({x=runtime, y=a})
	end

	local app = turbo.web.Application:new({
		-- Serve single index.html file on root requests.
		{"^/$", turbo.web.StaticFileHandler, "examples/webserver/speed.html"},
		-- Serve csv data
		{"^/csv/(.*)$", CSVHandler},
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
