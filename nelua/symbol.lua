local tabler = require 'nelua.utils.tabler'
local class = require 'nelua.utils.class'
local sstream = require 'nelua.utils.sstream'
local traits = require 'nelua.utils.traits'
local console = require 'nelua.utils.console'
local types = require 'nelua.types'
local primtypes = require 'nelua.typedefs'.primtypes
local Attr = require 'nelua.attr'
local Symbol = class(Attr)
local config = require 'nelua.configer'.get()

Symbol._symbol = true

function Symbol:init(name, node)
  self.node = node
  self.name = name
end

function Symbol.promote_attr(attr, name, node)
  attr.node = node
  attr.name = name
  return setmetatable(attr, Symbol)
end

function Symbol:clear_possible_types()
  self.possibletypes = nil
  self.fallbacktype = nil
  self.unknownrefs = nil
end

function Symbol:add_possible_type(type, refnode)
  if self.type then return end
  if type then
    if type.is_nilptr and not self.fallbacktype then
      self.fallbacktype = primtypes.pointer
    elseif type.is_niltype then
      self.fallbacktype = primtypes.any
    end
    if type.is_nolvalue then return end
  end
  local unknownrefs = self.unknownrefs
  if not type then
    assert(refnode)
    if not unknownrefs then
      self.unknownrefs = {[refnode] = true}
    else
      unknownrefs[refnode] = true
    end
    return
  elseif unknownrefs and unknownrefs[refnode] then
    unknownrefs[refnode] = nil
    if #unknownrefs == 0 then
      self.unknownrefs = nil
    end
  end
  if not self.possibletypes then
    self.possibletypes = {[1] = type}
  elseif not tabler.ifind(self.possibletypes, type) then
    table.insert(self.possibletypes, type)
  else
    return
  end
end

function Symbol:is_waiting_resolution(ignoresyms)
  if self.unknownrefs then
    -- ignoresyms is needed to cycles of references
    if not ignoresyms then
      ignoresyms = {[self]=true}
    else
      ignoresyms[self] = true
    end
    for refnode in pairs(self.unknownrefs) do
      local sym = refnode.attr
      if sym._symbol then
        if ignoresyms[sym] then
          return false
        elseif sym:is_waiting_resolution(ignoresyms) then
          return true
        end
      end
    end
    ignoresyms[self] = nil
  end
  if self.possibletypes and #self.possibletypes > 0 then
    return true
  end
  return false
end

function Symbol:resolve_type(force)
  if self.type or (not force and self.unknownrefs) then
    return false
  end
  local resolvetype = types.find_common_type(self.possibletypes)
  if resolvetype then
    self.type = resolvetype
    self:clear_possible_types()
  elseif traits.is_type(force) then
    self.type = force
  elseif force and self.fallbacktype then
    self.type = self.fallbacktype
  else
    return false
  end
  if config.debug_resolve then
    console.info(self.node:format_message('info', "symbol '%s' resolved to type '%s'", self.name, self.type))
  end
  return true
end

function Symbol:link_node(node)
  if node.attr ~= self then
    if next(node.attr) == nil then
      node.attr = self
    else
      node.attr = self:merge(node.attr)
    end
  end
end

-- Checks a symbol is directly accessible from a scope, without needing closures.
function Symbol:is_directly_accesible_from_scope(scope)
  if self.staticstorage or self.funcdecl then
    -- symbol declared in the program static storage, thus always accessible
    return true
  end
  if self.comptime or (self.type and self.type.is_comptime) then
    -- compile time symbols are always accessible
    return true
  end
  if self.scope:get_up_function_scope() == scope:get_up_function_scope() then
    -- the scope and symbol's scope are inside the same function
    return true
  end
  return false
end

function Symbol:__tostring()
  local ss = sstream(self.name or '<annonymous>')
  if self.type then
    ss:add(': ', self.type)
  end
  if self.comptime then
    ss:add(' <comptime>')
  elseif self.const then
    ss:add(' <const>')
  end
  if self.value then
    ss:add(' = ', self.value)
  end
  return ss:tostring()
end

return Symbol
