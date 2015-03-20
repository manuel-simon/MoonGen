-- emulating a moongen script dealing messages asynchronously

local zmq = require "zmq"

function sleep(n)
	  os.execute("sleep " .. tonumber(n))
end

local N = tonumber(arg[1] or 100)

local ctx = zmq.init()
local s = ctx:socket(zmq.DEALER)

s:connect("tcp://localhost:5555")

for i=1,N do
	s:send("SELECT * FROM mytable")
	print('sent data.')
	sleep(5)
end

s:setopt(zmq.LINGER, 0)
s:close()
print ('socket closed')
ctx:term()
print ('program ended')
