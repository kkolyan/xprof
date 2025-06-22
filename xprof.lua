--[[
  
MIT License

Copyright (c) 2021 Nikolay Plekhanov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

local lib = {}
local jit_prof = require("jit.profile")

-- private fields

local tree
local vmstates
local running = false

-- private methods

local newNode
local printTree
local printVmState
local updateNode
local updateTree
local saveLines

-- public fields

lib.dateBasedReportName = true

-- public methods

function lib.start()
    tree = tree or newNode()
    vmstates = vmstates or {}

    jit_prof.start("f", function(thread, samples, vmstate)
        local stack = jit_prof.dumpstack(thread, "pFZ;", -100)

        updateTree(stack, samples)

        local vmstateStat = vmstates[vmstate] or 0
        vmstates[vmstate] = vmstateStat + samples
    end)
    running = true
end

function lib.stop()
    running = false
    jit_prof.stop()
end

function lib.report(n)
    if running then
        print("please stop profiler before calling 'report()'")
    else
        local results = {}
        table.insert(results, "Samples: " .. tree.samples)
        printTree(tree, "", n or 100, results)
        printVmState(results)
        if lib.dateBasedReportName then
            saveLines(os.date("lxprof.%Y%m%dT%H%M%SZ.yaml"), results)

        end
        saveLines("lxprof.latest.yaml", results)
    end
end

function lib.reset()
    tree = newNode()
    vmstates = {}
end

-- private methods

function newNode()
    return { samples = 0, children = {} }
end

function updateTree(stack, samples)
    local offset = 1
    local node = tree
    node.samples = node.samples + samples
    while true do
        local index = string.find(stack, ";", offset, true)
        if not index then
            node = updateNode(node, string.sub(stack, offset), samples)
            break
        end
        node = updateNode(node, string.sub(stack, offset, index - 1), samples)
        offset = index + 1
    end
end

function updateNode(node, element, samples)
    local child = node.children[element]
    if not child then
        child = newNode()
        node.children[element] = child
    end
    child.samples = child.samples + samples

    return child
end

function printVmState(results)
    local stateNames = {
        N = "native (compiled) code",
        I = "interpreted code",
        C = "C code",
        G = "the garbage collector",
        J = "the JIT compiler"
    }
    local items = {}
    for k, v in pairs(vmstates) do
        table.insert(items, {
            samples = v,
            code = k
        })
    end
    table.sort(items, function(a, b)
        return a.samples > b.samples
    end)
    table.insert(results, "VM States:")
    for i, v in ipairs(items) do
        local w = v.samples / tree.samples
        local pct = string.format("%.2f", 100 * w)
        pct = string.rep(" ", 5 - #pct) .. pct
        table.insert(results, "  " .. pct .. " % - " .. (stateNames[v.code] or v.code))
    end
end

function printTree(node, indent, remainingDepth, results)
    local children = {}
    for k, v in pairs(node.children) do
        table.insert(children, { name = k, node = v })
    end
    table.sort(children, function(a, b)
        return a.node.samples > b.node.samples
    end)
    if remainingDepth <= 0 then
        table.insert(results, indent .. "...")
    else
        for i, v in ipairs(children) do
            local w = v.node.samples / tree.samples
            local pct = string.format("%.2f", 100 * w)
            pct = string.rep(" ", 5 - #pct) .. pct
            local name = v.name
            name = string.gsub(name, ":", " : ")
            name = string.gsub(name, " : /", ":/") -- windows disk letter
            table.insert(results, indent .. pct .. " % - " .. name)
            printTree(v.node, indent .. "  ", remainingDepth - 1, results)
        end
    end
end

function saveLines(fname, lines)
    local f, err = io.open(fname, "w")
    if not f then
        error("failed to open file. " .. err)
    end
    for i, v in ipairs(lines) do
        f:write(v)
        f:write("\n")
        f:flush()
    end
    f:close()
    print("file saved: " .. fname)
end

return lib
