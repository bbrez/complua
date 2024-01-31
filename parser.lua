local parser = {}

---@class ParserState
---@field tokens Token[]
---@field index number

---@class Program

---Retorna o token atual
---@param state ParserState
---@return Token
local function getCurrentToken(state)
  return state.tokens[state.index]
end

---Consome o token atual
---@param state ParserState
---@return ParserState
local function consumeToken(state)
  state.index = state.index + 1
  return state
end

---Faz a análise sintática de um programa
---@param tokens Token[]
---@return Program
function parser.parse_program(tokens)
  ---@type ParserState
  local state = { tokens = table.deep_copy(tokens), index = 1}

  return {
    type = "program",
    body = {}
  }
end

return parser
