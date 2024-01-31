local lexer = require "lexer"
local parser = {}

---@class ParserState
---@field tokens Token[] -- Lista de tokens gerada pelo Lexer
---@field index number -- Índice do token atual

---@class ASTNode
---@field type string

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

  local function expect(type)
    local current_token = get_current_token()

    if not current_token then
      error('unexpected end of input')
    end

    if current_token.type == type then
      consume_token()
      return { type = current_token.type, value = current_token.value }
    end

    return nil
  end

  local parse_expression, parse_term, parse_factor
  ---expression ::= term | expression '+' term | expression '-' term
  ---@return table
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

  ---term ::= factor | term '*' factor | term '/' factor
  ---@return table
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

  ---factor ::= identifier | int_literal | float_literal | '(' expression ')'
  ---@return table
  parse_factor = function()
    local current_token = get_current_token()

    if not current_token then
      error('unexpected end of input')
    end

    -- # TODO: separar em parse_literal
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
      error('unexpected token ' .. current_token.type .. ' at ' .. lexer.position.to_string(current_token.position))
    end
  end

  ---type_specifier ::= 'int' | 'float'
  ---@return table?
  local parse_type_specifier = function()
    local current_token = get_current_token()

    if not current_token then
      error('unexpected end of input')
    end

    if current_token.type == 'keyword' and lexer.is_type_specifier(current_token.value) then
      consume_token()
      return { type = 'type_specifier', value = current_token.value }
    end

    return nil
  end

  ---variable_declaration ::= type_specifier identifier ';'
  ---@return nil
  local parse_variable_declaration = function()
    local current_token = get_current_token()

    if not current_token then
      error('unexpected end of input')
    end

    local type_specifier = parse_type_specifier()
    if not type_specifier then
      return nil
    end

    local identifier = expect('identifier')
    if not identifier then
      return nil
    end

    if not expect('semicolon') then
      return nil
    end

    return { type = 'variable_declaration', type_specifier = type_specifier, identifier = identifier }
  end

  ---parameter ::= type_specifier identifier
  local parse_parameter = function()
    local type_specifier = parse_type_specifier()
    if not type_specifier then
      return nil
    end

    local identifier = expect('identifier')
    if not identifier then
      return nil
    end

    return { type = 'parameter', type_specifier = type_specifier, identifier = identifier }
  end

  ---parameter_list ::= parameter | parameter_list ',' parameter
  ---@return table
  local parse_parameter_list = function()
    local parameters = {}

    while true do
      local current_token = get_current_token()

      if not current_token then
        break
      end

      local parameter = parse_parameter()
      table.insert(parameters, parameter)

      if not expect('comma') then
        break
      end
    end

    return { type = 'parameter_list', parameters = parameters }
  end

  ---compound_statement ::= '{' statement_list '}'
  ---@return nil
  local parse_compound_statement = function()
    if not expect('rbrace') then
      return nil
    end

    local statements = {}

    while true do
      local current_token = get_current_token()

      if not current_token or current_token.type == 'rbrace' then
        break
      end

      local statement = parse_expression()
      table.insert(statements, statement)
    end

    if not expect('rbrace') then
      return nil
    end

    return { type = 'compound_statement', statements = statements }
  end

  ---function_declaration ::= type_specifier identifier '(' [parameter_list] ')' compound_statement
  ---@return nil
  local parse_function_declaration = function()
    local type_specifier = parse_type_specifier()
    if not type_specifier then
      return nil
    end

    local identifier = expect('identifier')
    if not identifier then
      return nil
    end

    if not expect('lparen') then
      return nil
    end

    local parameters = parse_parameter_list()

    if not expect('rparen') then
      return nil
    end

    if not expect('lbrace') then
      return nil
    end

    local body = parse_compound_statement()

    return {
      type = 'function_declaration',
      type_specifier = type_specifier,
      identifier = identifier,
      parameters = parameters,
      body = body
    }
  end

  ---declaration ::= variable_declaration | function_declaration
  ---@return table?
  local parse_declaration = function()
    local variable_declaration = parse_variable_declaration()
    if variable_declaration then
      return variable_declaration
    end

    local function_declaration = parse_function_declaration()
    if function_declaration then
      return function_declaration
    end

    return nil
  end

  ---declaration_list ::= declaration | declaration_list declaration
  ---@return table
  local parse_declaration_list = function()
    local declarations = {}

    while true do
      local current_token = get_current_token()

      if not current_token then
        break
      end

      local declaration = parse_declaration()
      table.insert(declarations, declaration)
    end

    return { type = 'declaration_list', declarations = declarations }
  end

  ---program ::= declaration_list
  local expression = parse_declaration_list()
  local valid = get_current_token() == nil

  if not valid then
    error('unexpected token ' .. get_current_token().type)
  end

  return expression
end

return parser
