# About
library to profile Lua code.

* Requires LuaJIT 2.1. If you use LÖVE, that means 11.x (tested with 11.5).
* Almost no overhead, because based on [statistical profiler](https://luajit.org/ext_profiler.html)

# How to use
```lua
local prof = require("xprof")
prof.start()

youHotFunctionToProfile()

prof.stop()
prof.report()
```
It will generate `lxprof.${time}.yaml` file in YAML format with the invocation tree and their CPU time occupation.

# Backlog
* generate flamechart instead of yaml
  
