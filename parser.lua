local parser = {}

---@class ParserState
---@field tokens Token[] -- Lista de tokens gerada pelo Lexer
---@field index number -- Índice do token atual

---Realiza a análise sintática do código fonte provido, retornando se o programa é válido ou não
---@param tokens Token[]
function parser.parse(tokens)
  local state = { tokens = table.deep_copy(tokens), index = 1 }

  local function get_current_token()
    return state.tokens[state.index]
  end

  local function consume_token()
    state.index = state.index + 1
  end

  local parse_expression, parse_term, parse_factor
  parse_expression = function()
    local term = parse_term()

    while true do
      local current_token = get_current_token()
      print(table.dump(current_token))

      if not current_token or (current_token.type ~= 'plus' and current_token.type ~= 'minus') then
        break
      end

      consume_token()
      local next_term = parse_term()
      term = { op = current_token.type, left = term, right = next_term }
    end

    return term
  end

  parse_term = function()
    local factor = parse_factor()

    while true do
      local current_token = get_current_token()

      if not current_token or (current_token.type ~= 'times' and current_token.type ~= 'div') then
        break
      end

      consume_token()
      local next_factor = parse_factor()
      factor = { op = current_token.type, left = factor, right = next_factor }
    end

    return factor
  end

  parse_factor = function()
    local current_token = get_current_token()

    if not current_token then
      error('unexpected end of input')
    end

    if current_token.type == 'identifier' then
      consume_token()
      return { type = 'identifier', value = current_token.value }
    elseif current_token.type == 'lparen' then
      consume_token() -- consume '('
      local expression = parse_expression()
      local closing_paren = get_current_token()

      if not closing_paren or closing_paren.type ~= 'rparen' then
        error('expected closing parenthesis')
      end

      consume_token() -- consume ')'
      return { type = 'parenthesized', expression = expression }
    elseif current_token.type == 'int_literal' then
      consume_token()
      return { type = 'int_literal', value = current_token.value }
    elseif current_token.type == 'float_literal' then
      consume_token()
      return { type = 'float_literal', value = current_token.value }
    else
      error('unexpected token ' .. current_token.type)
    end
  end

  local expression = parse_expression()
  local result = get_current_token() == nil

  if not result then
    error('unexpected token ' .. get_current_token().type)
  end

  return expression
end

return parser
