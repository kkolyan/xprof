local xprof_test_lib = require('xprof_test_lib')
local xprof = require('xprof')

function test1()
    for i = 1, 10000 do
        test2()
    end
end

function test2()
    local x = 0
    for i = 1, 10000 do
        x = x + test3(i) * xprof_test_lib.test4(i)
    end
    return x
end

function test3(i)
    return i * i
end

xprof.start()

test1()

xprof.stop()

xprof.report(2)

