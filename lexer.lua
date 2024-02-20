local utils = require('utils')

local lexer = {}

---@class Position
---@field line number
---@field col number
lexer.position = {}

---Converte uma posição para string
---@param position Position
---@return string
function lexer.position.to_string(position)
  return position.line .. ':' .. position.col
end

---@class LexerState
---@field source string
---@field position Position
---@field offset number
---@field identifiers {[string]: boolean} -- usado como um set

---@alias TokenType
---| '"keyword"' # keywords (on lexer.keywords)
---| '"identifier"' # identifiers
---| '"int_literal"' # integer literal
---| '"float_literal"' # float literal
---| '"string_literal"' # string literal
---| '"comment"' # comment
---| '"preprocessor"' # preprocessor
---| '"lparen"' # (
---| '"rparen"' # )
---| '"lbrace"' # {
---| '"rbrace"' # }
---| '"semicolon"' # ;
---| '"eof"' # eof

---@class Token
---@field type TokenType
---@field value string
---@field position Position

lexer.keywords = {
  "int",
  "float",
  "return",
  "if",
  "else",
  "while",
  "for",
}

---Avança o estado em um
---@param state LexerState
---@return LexerState
local function advance(state)
  state.offset = state.offset + 1
  state.position.col = state.position.col + 1
  return state
end

---Avança o estado em uma linha
---@param state LexerState
---@return LexerState
local function advance_line(state)
  state.offset = state.offset + 1
  state.position.col = 1
  state.position.line = state.position.line + 1
  return state
end

---Verifica se a string provida é uma palavra reservada da linguagem
---@param str string
---@return boolean
function lexer.is_keyword(str)
  for _, keyword in ipairs(lexer.keywords) do
    if str == keyword then
      return true
    end
  end
  return false
end

---Verifica se a string provida é um especificador de tipo
---@param str string
---@return boolean
function lexer.is_type_specifier(str)
  if lexer.is_keyword(str) then
    return table.contains({ 'int', 'float' }, str)
  end
  return false
end

---Imprime o token provido
---@param token table
---@return nil
function lexer.print_token(token)
  io.stdout:write('{ type = ', token.type, ', value = ', token.value, ', position = { line = ', token.position.line,
    ', col = ', token.position.col, '} }\n')
end

---
---@param state LexerState
---@return LexerState
---@return Token
local function lex_number(state)
  local accum = ""
  local current = state.source:sub(state.offset, state.offset)
  while utils.is_number(current) do
    accum = accum .. current
    state = advance(state)
    current = state.source:sub(state.offset, state.offset)
  end

  if current == '.' then
    accum = accum .. current
    state = advance(state)
    current = state.source:sub(state.offset, state.offset)
    while utils.is_number(current) do
      accum = accum .. current
      state = advance(state)
      current = state.source:sub(state.offset, state.offset)
    end
    return state, { type = 'float_literal', value = accum, position = table.copy(state.position) }
  else
    return state, { type = 'int_literal', value = accum, position = table.copy(state.position) }
  end
end

---
---@param state LexerState
---@return LexerState
---@return Token
local function lex_identifier(state)
  local accum = ""
  local current = state.source:sub(state.offset, state.offset)
  while utils.is_letter(current) or utils.is_number(current) or current == '_' do
    accum = accum .. current
    state = advance(state)
    current = state.source:sub(state.offset, state.offset)
  end

  if lexer.is_keyword(accum) then
    return state, { type = 'keyword', value = accum, position = table.copy(state.position) }
  else
    if not state.identifiers[accum] then
      state.identifiers[accum] = true
    end
    return state, { type = 'identifier', value = accum, position = table.copy(state.position) }
  end
end

---Realiza a análise léxica do código fonte provido, retornando uma lista de tokens
---@param source string
---@return {[string]: boolean}
---@return Token[]
function lexer.lex(source)
  ---@type Token[]
  local tokens = {}

  ---@type LexerState
  local state = { source = source, offset = 1, position = { line = 1, col = 1 }, identifiers = {} }
  while state.offset < #state.source do
    local current = state.source:sub(state.offset, state.offset)

    if current == ' ' or current == '\t' or current == '\r' then
      state = advance(state)
    elseif current == '\n' then
      state = advance_line(state)
    elseif current == '#' then  -- preprocessor
      local accum = ""
      state = advance(state)
      current = state.source:sub(state.offset, state.offset)
      while current ~= '\n' and state.offset < #state.source do
        accum = accum .. current
        state = advance(state)
        current = state.source:sub(state.offset, state.offset)
      end
      table.insert(tokens, { type = 'preprocessor', value = accum, position = table.copy(state.position) })
    elseif current == '(' then
      table.insert(tokens, { type = 'lparen', value = '(', position = table.copy(state.position) })
      state = advance(state)
    elseif current == ')' then
      table.insert(tokens, { type = 'rparen', value = ')', position = table.copy(state.position) })
      state = advance(state)
    elseif current == '{' then
      table.insert(tokens, { type = 'lbrace', value = '{', position = table.copy(state.position) })
      state = advance(state)
    elseif current == '}' then
      table.insert(tokens, { type = 'rbrace', value = '}', position = table.copy(state.position) })
      state = advance(state)
    elseif current == ';' then
      table.insert(tokens, { type = 'semicolon', value = ';', position = table.copy(state.position) })
      state = advance(state)
    elseif current == '"' then -- string literal
      state = advance(state)
      local accum = ""
      current = state.source:sub(state.offset, state.offset)
      while current ~= '"' and state.offset < #state.source do
        accum = accum .. current
        state = advance(state)
        current = state.source:sub(state.offset, state.offset)
      end
      state = advance(state)
      table.insert(tokens, { type = 'string_literal', value = accum, position = table.copy(state.position) })
    elseif current == '+' then
      table.insert(tokens, { type = 'plus', value = '+', position = table.copy(state.position) })
      state = advance(state)
    elseif current == '-' then
      table.insert(tokens, { type = 'minus', value = '-', position = table.copy(state.position) })
      state = advance(state)
    elseif current == '*' then
      table.insert(tokens, { type = 'times', value = '*', position = table.copy(state.position) })
      state = advance(state)
    elseif current == '/' then
      if state.source:sub(state.offset + 1, state.offset + 1) == '/' then -- comentario de linha
        state = advance(state)
        state = advance(state)
        local accum = ""
        current = state.source:sub(state.offset, state.offset)
        while current ~= '\n' and state.offset < #state.source do
          accum = accum .. current
          state = advance(state)
          current = state.source:sub(state.offset, state.offset)
        end
        table.insert(tokens, { type = 'comment', value = accum, position = table.copy(state.position) })
      elseif state.source:sub(state.offset + 1, state.offset + 1) == '*' then -- comentario de bloco
        state = advance(state)
        state = advance(state)
        local accum = ""
        current = state.source:sub(state.offset, state.offset) -- ignora o *
        while state.offset < #state.source do
          if current == '*' and state.source:sub(state.offset + 1, state.offset + 1) == '/' then
            state = advance(state)
            state = advance(state)
            break
          end
          accum = accum .. current
          state = advance(state)
          current = state.source:sub(state.offset, state.offset)
        end
        table.insert(tokens, { type = 'comment', value = accum, position = table.copy(state.position) })
      else
        table.insert(tokens, { type = 'div', value = '/', position = table.copy(state.position) })
        state = advance(state)
      end
    elseif utils.is_number(current) then
      local num
      state, num = lex_number(state)
      table.insert(tokens, num)
    elseif utils.is_letter(current) or current == '_' then
      local ident
      state, ident = lex_identifier(state)
      table.insert(tokens, ident)
    else
      error('unknown token "' .. current .. '"')
    end
  end

  return state.identifiers, tokens
end

return lexer
