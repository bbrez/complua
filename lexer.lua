local utils = require('utils')

local lexer = {}

lexer.keywords = {
  "int",
  "return"
}

---Verifica se a string provida é uma palavra reservada da linguagem
---@param str string
function lexer.is_keyword(str)
  for _, keyword in ipairs(lexer.keywords) do
    if str == keyword then
      return true
    end
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

---Realiza a análise léxica do código fonte provido, retornando uma lista de tokens
---@param source string
---@return table
function lexer.lex(source)
  local tokens = {}
  local location = { offset = 0, position = { line = 1, col = 1 } }
  while location.offset <= #source do
    local current = source:sub(location.offset, location.offset)

    if current == ' ' or current == '\t' then
    elseif current == '\n' then
      location.offset = location.offset + 1
      location.position.col = 1
      location.position.line = location.position.line + 1
    elseif current == '(' then
      table.insert(tokens, { type = 'lparen', value = '(', position = table.copy(location.position) })
    elseif current == ')' then
      table.insert(tokens, { type = 'rparen', value = ')', position = table.copy(location.position) })
    elseif current == '{' then
      table.insert(tokens, { type = 'lbracket', value = '{', position = table.copy(location.position) })
    elseif current == '}' then
      table.insert(tokens, { type = 'rbracket', value = '}', position = table.copy(location.position) })
    elseif utils.is_number(current) then
      local accum = ''
      local is_float = false

      while utils.is_number(current) or current == '.' or current == 'f' do
        if current == '.' or current == 'f' then
          is_float = true
        end

        accum = accum .. current
        location.offset = location.offset + 1
        location.position.col = location.position.col + 1
        current = source:sub(location.offset, location.offset)
      end

      if is_float then
        table.insert(tokens, { type = 'float', value = accum, position = table.copy(location.position) })
      else
        table.insert(tokens, { type = 'int', value = accum, position = table.copy(location.position) })
      end
    elseif utils.is_letter(current) or current == '_' then
      local accum = ''

      while utils.is_letter(current) or utils.is_number(current) or current == '_' do
        accum = accum .. current
        location.offset = location.offset + 1
        location.position.col = location.position.col + 1
        current = source:sub(location.offset, location.offset)
      end

      if lexer.is_keyword(accum) then
        table.insert(tokens, { type = 'keyword', value = accum, position = table.copy(location.position) })
      else
        table.insert(tokens, { type = 'identifier', value = accum, position = table.copy(location.position) })
      end
    end

    location.offset = location.offset + 1
    location.position.col = location.position.col + 1
  end

  return tokens
end

return lexer
