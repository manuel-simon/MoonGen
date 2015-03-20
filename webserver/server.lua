local turbo = require "turbo"
local zmq = require "zmq"

local port = 80

local zmqContext = zmq.init()
local zmqSock = zmqContext:socket(zmq.ROUTER)
local zmqConfig = "tcp://*:5555" 
zmqSock:bind(zmqConfig)
zmqSock:setopt(zmq.LINGER, 0)
print("bounded");

local msg;
msg = zmq.zmq_msg_t();

local CSVHandler = class("CSVHandler", turbo.web.RequestHandler)
function CSVHandler:get()
	print("recv begin")
	local data, err = zmqSock:recv(zmq.NOBLOCK);
	if data then
		print("recv over")
	else 
		print("no data")
	end
	self:write({x=0, value=math.random(200), othervalue=20})
	--if data then
	--	print(data)
	--else
	--	print("s:recv() error:", err)
	--end	
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
print('server listening on port: ' .. port)

turbo.ioloop.instance():start()
