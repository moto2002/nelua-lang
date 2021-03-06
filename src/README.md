# Nelua's Lua Interpreter

This is the Lua 5.4.2-rc1 interpreter used by Nelua, with the following changes:

* Uses rpmalloc as the default memory allocator (usually much faster than the system's default memory allocator).
* Libraries "hasher", "sys" and "lfs" are built-in (they are required by Nelua compiler).
* Made LUA_ROOT in luaconf.h configurable
* Use -fno-crossjumping -fno-gcse in lua VM for a faster instruction execution.
* C compilation flags are tuned to squeeze more performance from the Lua interpreter.

Patch for the changes are available in `lua-changes.patch` file.

Although you can use Nelua with any Lua 5.3+ interpreter,
it is recommended to use this interpreter to have the same behavior
and because it can be ~30% faster than the standard Lua.
