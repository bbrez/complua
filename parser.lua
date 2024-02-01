local lexer = require('lexer')
local parser = {}

---@class ParserState
---@field tokens Token[] -- Lista de tokens gerada pelo Lexer
---@field index number -- Índice do token atual

---@class ASTNode
---@field type string

---Retorna o token atual do parser
---@param state ParserState
---@return Token
local function get_current_token(state)
  return state.tokens[state.index]
end

---Consome o token atual do parser
---@param state ParserState
---@return ParserState
local function consume_token(state)
  state.index = state.index + 1
  return state
end

---Consome e retorna o token atual se ele for do tipo esperado
---@param state ParserState
---@param type TokenType
---@return ParserState, Token?
local function expect(state, type)
  local current_token = get_current_token(state)

  if not current_token then
    error('unexpected end of input')
  end

  if current_token.type == type then
    state = consume_token(state)
    return state, { type = current_token.type, value = current_token.value }
  end

  return state, nil
end

---literal ::= int_literal | float_literal
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_literal(state)
  local new_state, int_literal = expect(state, 'int_literal')
  if int_literal then
    return new_state, {
      type = 'int_literal',
      value = int_literal.value
    }
  end

  local float_literal
  new_state, float_literal = expect(state, 'float_literal')
  if float_literal then
    return new_state, {
      type = 'float_literal',
      value = float_literal.value
    }
  end

  return state, nil
end

---factor ::= identifier | literal | '(' expression ')'
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_factor(state)
  local new_state, identifier = expect(state, 'identifier')
  if identifier then
    return new_state, {
      type = 'identifier',
      value = identifier.value
    }
  end

  local literal
  new_state, literal = parse_literal(state)
  if literal then
    return new_state, literal
  end

  local left_parenthesis
  new_state, left_parenthesis = expect(new_state, 'lparen')

  if not left_parenthesis then
    return state, nil
  end

  local expression
  new_state, expression = parse_expression(new_state)

  local right_parenthesis
  new_state, right_parenthesis = expect(new_state, 'rparen')

  if not right_parenthesis then
    return state, nil
  end

  return new_state, {
    type = 'parenthesized',
    expression = expression
  }
end

---term ::= factor | term '*' factor | term '/' factor
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_term(state)
  local new_state, factor = parse_factor(state)

  while true do
    local current_token = get_current_token(state)

    if not current_token or (current_token.type ~= 'times' and current_token.type ~= 'div') then
      break
    end

    new_state = consume_token(state)
    local next_factor
    new_state, next_factor = parse_factor(new_state)
    factor = {
      type = 'term',
      op = current_token.type,
      left = factor,
      right = next_factor
    }
  end

  return new_state, factor
end

---expression ::= term | expression '+' term | expression '-' term
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_expression(state)
  local new_state, term = parse_term(state)

  while true do
    local current_token = get_current_token(state)

    if not current_token or (current_token.type ~= 'plus' and current_token.type ~= 'minus') then
      break
    end

    new_state = consume_token(state)
    local next_term
    new_state, next_term = parse_term(new_state)
    term = {
      type = 'expression',
      op = current_token.type,
      left = term,
      right = next_term
    }
  end

  return new_state, term
end

---type_specifier ::= 'int' | 'float'
---@param state any
---@return ParserState, ASTNode?
local function parse_type_specifier(state)
  local new_state, type_specifier = expect(state, 'keyword')

  if type_specifier and lexer.is_type_specifier(type_specifier.value) then
    return new_state, {
      type = 'type_specifier',
      value = type_specifier.value
    }
  end

  return state, nil
end

---variable_declaration ::= type_specifier identifier ';'
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_variable_declaration(state)
  local new_state, type_specifier = parse_type_specifier(state)
  if not type_specifier then
    return state, nil
  end

  local identifier
  new_state, identifier = expect(new_state, 'identifier')
  if not identifier then
    return state, nil
  end

  local semicolon
  new_state, semicolon = expect(new_state, 'semicolon')
  if not semicolon then
    return state, nil
  end

  return new_state, {
    type = 'variable_declaration',
    type_specifier = type_specifier,
    identifier = identifier
  }
end

---expression_statement ::= expression ';'
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_expression_statement(state)
  local new_state, expression = parse_expression(state)
  if not expression then
    return state, nil
  end

  local semicolon
  new_state, semicolon = expect(new_state, 'semicolon')
  if not semicolon then
    return state, nil
  end

  return new_state, expression
end

---return_statement ::= 'return' expression ';'
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_return_statement(state)
  local new_state, return_keyword = expect(state, 'keyword')
  if not return_keyword or return_keyword.value ~= 'return' then
    return state, nil
  end

  local expression
  new_state, expression = parse_expression(new_state)
  if not expression then
    return state, nil
  end

  local semicolon
  new_state, semicolon = expect(new_state, 'semicolon')
  if not semicolon then
    return state, nil
  end

  return new_state, {
    type = 'return_statement',
    expression = expression
  }
end

---statement ::= expression_statement | return_statement | variable_declaration
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_statement(state)
  local new_state, expression_statement = parse_expression_statement(state)
  if expression_statement then
    return new_state, expression_statement
  end

  local return_statement
  new_state, return_statement = parse_return_statement(state)
  if return_statement then
    return new_state, return_statement
  end

  local variable_declaration
  new_state, variable_declaration = parse_variable_declaration(state)
  if variable_declaration then
    return new_state, variable_declaration
  end

  return state, nil
end

---statement_list ::= statement | statement_list statement
---@param state ParserState
---@return ParserState, ASTNode
local function parse_statement_list(state)
  local statements = {}

  while true do
    local current_token = get_current_token(state)

    if not current_token then
      break
    end

    local statement
    state, statement = parse_statement(state)
    table.insert(statements, statement)
  end

  return state, {
    type = 'statement_list',
    statements = statements
  }
end

---compound_statement ::= '{' statement_list '}'
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_compound_statement(state)
  local new_state, left_brace = expect(state, 'lbrace')
  if not left_brace then
    return state, nil
  end

  local statement_list
  new_state, statement_list = parse_statement_list(new_state)

  local right_brace
  new_state, right_brace = expect(new_state, 'rbrace')

  if not right_brace then
    return state, nil
  end

  return new_state, {
    type = 'compound_statement',
    statements = statement_list
  }
end

---parameter ::= type_specifier identifier
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_parameter(state)
  local new_state, type_specifier = parse_type_specifier(state)
  if not type_specifier then
    return state, nil
  end

  local identifier
  new_state, identifier = expect(new_state, 'identifier')
  if not identifier then
    return state, nil
  end

  return new_state, {
    type = 'parameter',
    type_specifier = type_specifier,
    identifier = identifier
  }
end

---parameter_list ::= parameter | parameter_list ',' parameter
---@param state ParserState
---@return ParserState, ASTNode
local function parse_parameter_list(state)
  local parameters = {}

  while true do
    local current_token = get_current_token(state)

    if not current_token then
      break
    end

    local parameter
    state, parameter = parse_parameter(state)
    table.insert(parameters, parameter)
  end

  return state, {
    type = 'parameter_list',
    parameters = parameters
  }
end

---function_declaration ::= type_specifier identifier '(' [parameter_list] ')' compound_statement
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_function_declaration(state)
  local new_state, type_specifier = parse_type_specifier(state)

  if not type_specifier then
    return state, nil
  end

  local identifier
  new_state, identifier = expect(new_state, 'identifier')

  if not identifier then
    return state, nil
  end

  local left_parenthesis
  new_state, left_parenthesis = expect(new_state, 'lparen')

  if not left_parenthesis then
    return state, nil
  end

  local parameter_list
  new_state, parameter_list = parse_parameter_list(new_state)

  local right_parenthesis
  new_state, right_parenthesis = expect(new_state, 'rparen')

  if not right_parenthesis then
    return state, nil
  end

  local compound_statement
  new_state, compound_statement = parse_compound_statement(new_state)

  return new_state, {
    type = 'function_declaration',
    type_specifier = type_specifier,
    identifier = identifier,
    parameters = parameter_list,
    body = compound_statement
  }
end

---declaration ::= variable_declaration | function_declaration
---@param state ParserState
---@return ParserState, ASTNode?
local function parse_declaration(state)
  local new_state, variable_declaration = parse_variable_declaration(state)
  if variable_declaration then
    return new_state, variable_declaration
  end

  local function_declaration
  new_state, function_declaration = parse_function_declaration(state)
  if function_declaration then
    return new_state, function_declaration
  end

  return state, nil
end

---declaration_list ::= declaration | declaration_list declaration
---@param state ParserState
---@return ParserState, ASTNode
local function parse_declaration_list(state)
  local declarations = {}

  while true do
    local current_token = get_current_token(state)

    if not current_token then
      break
    end

    local declaration
    state, declaration = parse_declaration(state)
    table.insert(declarations, declaration)
  end

  if #declarations == 0 then
    error('expected declaration')
  end

  return state, {
    type = 'declaration_list',
    declarations = declarations
  }
end

---program ::= declaration_list
---@param tokens Token[]
---@return ASTNode
function parser.parse(tokens)
  local state = {
    tokens = table.deep_copy(tokens),
    index = 1
  }

  local new_state, program = parse_declaration_list(state)
  local valid = get_current_token(new_state) == nil

  if not valid then
    error('unexpected token' .. get_current_token(new_state).type)
  end

  return program
end

return parser
