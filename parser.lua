local lexer = require('lexer')
local parser = {}

---@alias var_type
---| "int"
---| "float"
---| "char"
---| "void"

---@class Variable
---@field name string
---@field type "variable"
---@field var_type var_type

---@class Function
---@field name string
---@field type "function"
---@field return_type var_type
---@field params Variable[]

---@class Context
---@field name string
---@field parent Context?
---@field children Context[]
---@field content {[string]: Variable | Function}

---@class ParserState
---@field tokens Token[] -- Lista de tokens gerada pelo Lexer
---@field index number -- Índice do token atual
---@field context Context

---@class ASTNode
---@field type string

---cria um novo contexto e faz com que ele seja o atual
---@param state ParserState
---@param name string
local function pushContext(state, name)
  ---@type Context
  local new_context = {
    parent = state.context,
    children = {},
    content = {},
    name = name
  }

  ---@type ParserState
  table.insert(state.context.children, new_context)
  state.context = new_context

  return state
end

---Retorna o contexto para o contexto pai
---Deve ser usado quando um contexto encerra
---@param state any
local function popContext(state)
  ---@type ParserState
  if state.context.parent == nil then
    print("Erro: tentando acessar contexto inexistente (popContext com pai = nil)")
    os.exit(1)
  end

  state.context = state.context.parent
  return state
end

---Converte os parâmetros para uma string
---@param params Variable[]
---@return string
local function paramsString(params)
  local result = ""
  for i, param in ipairs(params) do
    result = result .. param.var_type .. " " .. param.name
    if i < #params then
      result = result .. ", "
    end
  end
  return result
end

---Imprime o contexto atual
---Uma função específica é necessária para imprimir o contexto pois a recursão pode causar um loop infinito
---@param ctx Context
local function printContext(ctx)
  for key, value in pairs(ctx.content) do
    if value.type == 'function' then
      io.write(("%15s"):format(ctx.name), ("%15s"):format(value.name), ("%15s"):format(value.type),
        ("%15s"):format(value.return_type),
        ("%30s"):format(paramsString(value.params)), "\n")
    else
      io.write(("%15s"):format(ctx.name), ("%15s"):format(value.name), ("%15s"):format(value.type),
        ("%15s"):format(value.var_type), "\n")
    end
  end

  for _, child in ipairs(ctx.children) do
    printContext(child)
  end
end

local function printContextTable(global_ctx)
  -- io.write(("Contexto"):format("%15s"), ("Identificador"):format("%15s"), ("Tipo"):format("%15s"),
  --   ("Retorno"):format("%15s"), ("Parâmetros"):format("%15s"), "\n")
  io.write(("%15s"):format("Contexto"), ("%15s"):format("Identificador"), ("%15s"):format("Tipo"),
    ("%15s"):format("Retorno"), ("%30s"):format("Parâmetros"), "\n")
  printContext(global_ctx)
end


---Verifica se um identificador existe no contexto atual
---@param context Context
---@param identifier string
---@return (Variable | Function)?
local function existsCurrent(context, identifier)
  return context.content[identifier]
end

---Verifica se um identificador existe no contexto atual ou em qualquer contexto pai
---@param context Context
---@param identifier string
---@return (Variable | Function)?
local function existsAll(context, identifier)
  if context.content[identifier] then
    return context.content[identifier]
  end

  if context.parent then
    return existsAll(context.parent, identifier)
  end

  return nil
end

---Transforma os argumentos para o formato da tabela de simbolos
---@param args ASTNode
---@return Variable[]
local function extractArgs(args)
  local extracted = {}
  for _, arg in ipairs(args.parameters) do
    table.insert(extracted, {
      name = arg.identifier.value,
      type = "variable",
      var_type = arg.type_specifier.value
    })
  end
  return extracted
end

---Retorna o token atual do parser
---@param state ParserState
---@return Token
---@nodiscard
local function get_current_token(state)
  return state.tokens[state.index]
end

---Consome o token atual do parser
---@param state ParserState
---@return ParserState
---@nodiscard
local function consume_token(state)
  local new_state = table.copy(state)
  new_state.index = new_state.index + 1
  return new_state
end

---Consome e retorna o token atual se ele for do tipo esperado
---@param state ParserState
---@param type TokenType
---@return ParserState, Token?
---@nodiscard
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

--Pre declaração das funções de parse
local parse_declaration_list
local parse_declaration
local parse_variable_declaration
local parse_function_declaration
local parse_parameter_list
local parse_parameter
local parse_compound_statement
local parse_statement_list
local parse_statement
local parse_if_statement
local parse_while_statement
local parse_for_statement
local parse_expression_statement
local parse_return_statement
local parse_assignment_statement
local parse_expression
local parse_logical_or_expression
local parse_logical_and_expression
local parse_equality_expression
local parse_relational_expression
local parse_additive_expression
local parse_multiplicative_expression
local parse_unary_expression
local parse_function_call
local parse_argument_list
local parse_primary_expression
local parse_literal
local parse_type_specifier

---primary_expression ::= identifier | literal | function_call | '(' expression ')'
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_primary_expression(state)
  local new_state
  local function_call
  new_state, function_call = parse_function_call(state)
  if function_call then
    return new_state, function_call
  end

  local identifier
  new_state, identifier = expect(state, 'identifier')
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
  new_state, left_parenthesis = expect(state, 'lparen')
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

  return new_state, expression
end

---argument_list ::= expression | argument_list ',' expression
---@param state ParserState
---@return ParserState, ASTNode
---@nodiscard
function parse_argument_list(state)
  local arguments = {}

  while true do
    local current_token = get_current_token(state)

    if not current_token or current_token.value == ')' then
      break
    end

    local expression
    state, expression = parse_expression(state)
    table.insert(arguments, expression)

    local comma
    state, comma = expect(state, 'comma')
    if not comma then
      break
    end
  end

  return state, {
    type = 'argument_list',
    arguments = arguments
  }
end

---function_call ::= identifier '(' [argument_list] ')'
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_function_call(state)
  local new_state, identifier = expect(state, 'identifier')
  if not identifier then
    return state, nil
  end

  local left_parenthesis
  new_state, left_parenthesis = expect(new_state, 'lparen')
  if not left_parenthesis then
    return state, nil
  end

  local argument_list
  new_state, argument_list = parse_argument_list(new_state)

  local right_parenthesis
  new_state, right_parenthesis = expect(new_state, 'rparen')
  if not right_parenthesis then
    return state, nil
  end

  if identifier.value == 'printf' then --- Tratamento especial para a função printf
    return new_state, {
      type = 'printf_call',
      arguments = argument_list
    }
  end

  if not existsAll(state.context, identifier.value) then
    print('Identificador `' .. identifier.value .. '` não existe no contexto atual')
    os.exit(1)
    return state, nil
  end

  if existsAll(state.context, identifier.value).type ~= 'function' then
    print('Identificador `' .. identifier.value .. '` não é uma função')
    os.exit(1)
    return state, nil
  end

  if #argument_list.arguments ~= #existsAll(state.context, identifier.value).params then
    print('Número de argumentos inválido para a função `' .. identifier.value .. '`')
    print('Esperado: ' .. #existsAll(state.context, identifier.value).params .. ' argumentos')
    print('Recebido: ' .. #argument_list.arguments .. ' argumentos')
    os.exit(1)
    return state, nil
  end

  return new_state, {
    type = 'function_call',
    identifier = identifier,
    arguments = argument_list
  }
end

---unary_expression ::= primary_expression | '-' unary_expression | '+' unary_expression | '!' unary_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_unary_expression(state)
  local new_state, primary_expression = parse_primary_expression(state)
  if primary_expression then
    return new_state, primary_expression
  end

  local operator
  new_state, operator = expect(state, 'minus')
  if not operator then
    new_state, operator = expect(state, 'plus')
  end
  if not operator then
    new_state, operator = expect(state, 'not')
  end

  if not operator then
    return state, nil
  end

  local unary_expression
  new_state, unary_expression = parse_unary_expression(new_state)
  if not unary_expression then
    return state, nil
  end

  return new_state, {
    type = 'unary_expression',
    operator = operator.value,
    expression = unary_expression
  }
end

---multiplicative_expression ::= unary_expression | multiplicative_expression '*' unary_expression | multiplicative_expression '/' unary_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_multiplicative_expression(state)
  local new_state, unary_expression = parse_unary_expression(state)
  if not unary_expression then
    return state, nil
  end

  local operator
  new_state, operator = expect(new_state, 'times')
  if not operator then
    new_state, operator = expect(new_state, 'div')
  end

  if not operator then
    return new_state, unary_expression
  end

  local right_unary_expression
  new_state, right_unary_expression = parse_multiplicative_expression(new_state)
  if not right_unary_expression then
    return state, nil
  end

  return new_state, {
    type = 'multiplicative_expression',
    left = unary_expression,
    right = right_unary_expression,
    operator = operator.value
  }
end

---additive_expression ::= multiplicative_expression | additive_expression '+' multiplicative_expression | additive_expression '-' multiplicative_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_additive_expression(state)
  local new_state, multiplicative_expression = parse_multiplicative_expression(state)
  if not multiplicative_expression then
    return state, nil
  end

  local operator
  new_state, operator = expect(new_state, 'plus')
  if not operator then
    new_state, operator = expect(new_state, 'minus')
  end

  if not operator then
    return new_state, multiplicative_expression
  end

  local right_multiplicative_expression
  new_state, right_multiplicative_expression = parse_additive_expression(new_state)
  if not right_multiplicative_expression then
    return state, nil
  end

  return new_state, {
    type = 'additive_expression',
    left = multiplicative_expression,
    right = right_multiplicative_expression,
    operator = operator.value
  }
end

---relational_expression ::= additive_expression | relational_expression '<' additive_expression | relational_expression '>' additive_expression | relational_expression '<=' additive_expression | relational_expression '>=' additive_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_relational_expression(state)
  local new_state, additive_expression = parse_additive_expression(state)
  if not additive_expression then
    return state, nil
  end

  local operator
  new_state, operator = expect(new_state, 'less')
  if not operator then
    new_state, operator = expect(new_state, 'greater')
  end
  if not operator then
    new_state, operator = expect(new_state, 'less_equal')
  end
  if not operator then
    new_state, operator = expect(new_state, 'greater_equal')
  end

  if not operator then
    return new_state, additive_expression
  end

  local right_additive_expression
  new_state, right_additive_expression = parse_relational_expression(new_state)
  if not right_additive_expression then
    return state, nil
  end

  return new_state, {
    type = 'relational_expression',
    left = additive_expression,
    right = right_additive_expression,
    operator = operator.value
  }
end

---equality_expression ::= relational_expression | equality_expression '==' relational_expression | equality_expression '!=' relational_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_equality_expression(state)
  local new_state, relational_expression = parse_relational_expression(state)
  if not relational_expression then
    return state, nil
  end

  local equal
  new_state, equal = expect(new_state, 'equal')
  if not equal then
    return new_state, relational_expression
  end

  local right_relational_expression
  new_state, right_relational_expression = parse_equality_expression(new_state)
  if not right_relational_expression then
    return state, nil
  end

  return new_state, {
    type = 'equality_expression',
    left = relational_expression,
    right = right_relational_expression,
    operator = equal.value
  }
end

---logical_and_expression ::= equality_expression | logical_and_expression '&&' equality_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_logical_and_expression(state)
  local new_state, equality_expression = parse_equality_expression(state)
  if not equality_expression then
    return state, nil
  end

  local logical_and
  new_state, logical_and = expect(new_state, 'and')
  if not logical_and then
    return new_state, equality_expression
  end

  local right_equality_expression
  new_state, right_equality_expression = parse_logical_and_expression(new_state)
  if not right_equality_expression then
    return state, nil
  end

  return new_state, {
    type = 'logical_and_expression',
    left = equality_expression,
    right = right_equality_expression
  }
end

---logical_or_expression ::= logical_and_expression | logical_or_expression '||' logical_and_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_logical_or_expression(state)
  local new_state, logical_and_expression = parse_logical_and_expression(state)
  if not logical_and_expression then
    return state, nil
  end

  local logical_or
  new_state, logical_or = expect(new_state, 'or')
  if not logical_or then
    return new_state, logical_and_expression
  end

  local right_logical_and_expression
  new_state, right_logical_and_expression = parse_logical_and_expression(new_state)
  if not right_logical_and_expression then
    return state, nil
  end

  return new_state, {
    type = 'logical_or_expression',
    left = logical_and_expression,
    right = right_logical_and_expression
  }
end

---for_statement ::= 'for' '(' [expression] ';' [expression] ';' [expression] ')' compound_statement
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_for_statement(state)
  local new_state, for_keyword = expect(state, 'keyword')
  if not for_keyword or for_keyword.value ~= 'for' then
    return state, nil
  end


  local left_parenthesis
  new_state, left_parenthesis = expect(new_state, 'lparen')
  if not left_parenthesis then
    local error_token = get_current_token(new_state)
    print('When parsing for statement:')
    print('\tExpected `(`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tAt line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  local init_statement
  new_state, init_statement = parse_assignment_statement(new_state)

  local condition
  new_state, condition = parse_expression_statement(new_state)

  local update_statement
  new_state, update_statement = parse_expression(new_state)

  local right_parenthesis
  new_state, right_parenthesis = expect(new_state, 'rparen')
  if not right_parenthesis then
    local error_token = get_current_token(new_state)
    print('When parsing for statement:')
    print('\tExpected `)`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tAt line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  local compound_statement
  new_state, compound_statement = parse_compound_statement(new_state, new_state.context.name .. '_for')
  if not compound_statement then
    return state, nil
  end

  return new_state, {
    type = 'for_statement',
    init = init_statement,
    condition = condition,
    update = update_statement,
    body = compound_statement
  }
end

---while_statement ::= 'while' '(' expression ')' compound_statement
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_while_statement(state)
  local new_state, while_keyword = expect(state, 'keyword')
  if not while_keyword or while_keyword.value ~= 'while' then
    return state, nil
  end

  local left_parenthesis
  new_state, left_parenthesis = expect(new_state, 'lparen')
  if not left_parenthesis then
    local error_token = get_current_token(new_state)
    print('When parsing while statement:')
    print('\tExpected `(`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tAt line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  local expression
  new_state, expression = parse_expression(new_state)
  if not expression then
    return state, nil
  end

  local right_parenthesis
  new_state, right_parenthesis = expect(new_state, 'rparen')
  if not right_parenthesis then
    local error_token = get_current_token(new_state)
    print('When parsing while statement:')
    print('\tExpected `)`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tAt line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  local compound_statement
  new_state, compound_statement = parse_compound_statement(new_state, new_state.context.name .. '_while')
  if not compound_statement then
    return state, nil
  end

  return new_state, {
    type = 'while_statement',
    condition = expression,
    body = compound_statement
  }
end

---literal ::= int_literal | float_literal
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_literal(state)
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

  local string_literal
  new_state, string_literal = expect(state, 'string_literal')
  if string_literal then
    return new_state, {
      type = 'string_literal',
      value = string_literal.value
    }
  end

  local char_literal
  new_state, char_literal = expect(state, 'char_literal')
  if char_literal then
    return new_state, {
      type = 'char_literal',
      value = char_literal.value
    }
  end

  return state, nil
end

---expression ::= logical_or_expression
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_expression(state)
  return parse_logical_or_expression(state)
end

---type_specifier ::= 'int' | 'float'
---@param state any
---@return ParserState, ASTNode?
---@nodiscard
function parse_type_specifier(state)
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
---@nodiscard
function parse_variable_declaration(state)
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
  if not semicolon then -- ainda pode ser uma função, então não é um erro
    return state, nil
  end

  if existsCurrent(new_state.context, identifier.value) ~= nil then
    print('Identificador `' .. identifier.value .. '` já existe no contexto atual')
    os.exit(1)
    return state, nil
  end

  new_state.context.content[identifier.value] = {
    name = identifier.value,
    type = "variable",
    var_type = type_specifier.value
  }

  return new_state, {
    type = 'variable_declaration',
    type_specifier = type_specifier,
    identifier = identifier
  }
end

---expression_statement ::= expression ';'
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_expression_statement(state)
  local new_state, expression = parse_expression(state)
  if not expression then
    return state, nil
  end

  local semicolon
  new_state, semicolon = expect(new_state, 'semicolon')
  if not semicolon then
    local error_token = get_current_token(new_state)
    print('when parsing expression statement:')
    print('\texpected `;`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tat line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  return new_state, expression
end

---return_statement ::= 'return' expression ';'
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_return_statement(state)
  local new_state, return_keyword = expect(state, 'keyword')
  if not return_keyword or return_keyword.value ~= 'return' then
    return state, nil
  end

  local expression
  new_state, expression = parse_expression(new_state)
  if not expression then
    local error_token = get_current_token(new_state)
    print('when parsing return statement:')
    print('\texpected `expression`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tat line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  local semicolon
  new_state, semicolon = expect(new_state, 'semicolon')
  if not semicolon then
    local error_token = get_current_token(new_state)
    print('when parsing return statement:')
    print('\texpected `;`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tat line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  return new_state, {
    type = 'return_statement',
    expression = expression
  }
end

---if_statement ::= if '(' expression ')' compound_statement [ else compound_statement ]
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_if_statement(state)
  local new_state, if_keyword = expect(state, 'keyword')
  if not if_keyword or if_keyword.value ~= 'if' then
    return state, nil
  end

  local left_parenthesis
  new_state, left_parenthesis = expect(new_state, 'lparen')
  if not left_parenthesis then
    local error_token = get_current_token(new_state)
    print('When parsing if statement:')
    print('\tExpected `(`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tAt line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  local expression
  new_state, expression = parse_expression(new_state)
  if not expression then
    return state, nil
  end

  local right_parenthesis
  new_state, right_parenthesis = expect(new_state, 'rparen')
  if not right_parenthesis then
    local error_token = get_current_token(new_state)
    print('When parsing if statement:')
    print('\tExpected `)`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tAt line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  local compound_statement
  new_state, compound_statement = parse_compound_statement(new_state, new_state.context.name .. '_if')
  if not compound_statement then
    return state, nil
  end

  local else_keyword
  new_state, else_keyword = expect(new_state, 'keyword')
  if else_keyword and else_keyword.value == 'else' then
    local else_compound_statement
    new_state, else_compound_statement = parse_compound_statement(new_state, new_state.context.name .. '_else')
    if not else_compound_statement then
      return state, nil
    end

    return new_state, {
      type = 'if_statement',
      condition = expression,
      body = compound_statement,
      else_body = else_compound_statement
    }
  end

  return new_state, {
    type = 'if_statement',
    condition = expression,
    body = compound_statement
  }
end

---assignment_statement ::= identifier '=' expression ';'
---@param state ParserState
---@return ParserState, ASTNode?
function parse_assignment_statement(state)
  local new_state, identifier = expect(state, 'identifier')
  if not identifier then
    return state, nil
  end

  local assign
  new_state, assign = expect(new_state, 'assign')
  if not assign then
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
    local error_token = get_current_token(new_state)
    print('When parsing assignment statement:')
    print('\tExpected `;`, got ' .. error_token.type .. ' ' .. error_token.value)
    print('\tAt line ' .. error_token.position.line .. ' column ' .. error_token.position.col)
    os.exit(1)
    return state, nil
  end

  return new_state, {
    type = 'assignment_statement',
    identifier = identifier,
    expression = expression
  }
end

---statement ::= expression_statement | return_statement | variable_declaration
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_statement(state)
  local new_state

  local if_statement
  new_state, if_statement = parse_if_statement(state)
  if if_statement then
    return new_state, if_statement
  end

  local variable_declaration
  new_state, variable_declaration = parse_variable_declaration(state)
  if variable_declaration then
    return new_state, variable_declaration
  end

  local return_statement
  new_state, return_statement = parse_return_statement(state)
  if return_statement then
    return new_state, return_statement
  end

  local while_statement
  new_state, while_statement = parse_while_statement(state)
  if while_statement then
    return new_state, while_statement
  end

  local for_statement
  new_state, for_statement = parse_for_statement(state)
  if for_statement then
    return new_state, for_statement
  end

  local assignment_statement
  new_state, assignment_statement = parse_assignment_statement(state)
  if assignment_statement then
    return new_state, assignment_statement
  end

  local expression_statement
  new_state, expression_statement = parse_expression_statement(state)
  if expression_statement then
    return new_state, expression_statement
  end

  return state, nil
end

---statement_list ::= statement | statement_list statement
---@param state ParserState
---@return ParserState, ASTNode
---@nodiscard
function parse_statement_list(state)
  local statements = {}

  while true do
    local current_token = get_current_token(state)

    if not current_token or current_token.value == '}' then
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
---@param name string -- nome do contexto
---@return ParserState, ASTNode?
---@nodiscard
function parse_compound_statement(state, name)
  local new_state, left_brace = expect(state, 'lbrace')
  if not left_brace then
    return state, nil
  end

  new_state = pushContext(new_state, name)

  local statement_list
  new_state, statement_list = parse_statement_list(new_state)

  local right_brace
  new_state, right_brace = expect(new_state, 'rbrace')

  new_state = popContext(new_state)

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
---@nodiscard
function parse_parameter(state)
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
---@nodiscard
function parse_parameter_list(state)
  local parameters = {}

  while true do
    local current_token = get_current_token(state)

    if not current_token or not lexer.is_type_specifier(current_token.value) then
      break
    end

    local parameter
    state, parameter = parse_parameter(state)
    table.insert(parameters, parameter)

    local comma
    state, comma = expect(state, 'comma')
    if not comma then
      break
    end
  end

  return state, {
    type = 'parameter_list',
    parameters = parameters
  }
end

---function_declaration ::= type_specifier identifier '(' [parameter_list] ')' compound_statement
---@param state ParserState
---@return ParserState, ASTNode?
---@nodiscard
function parse_function_declaration(state)
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
  new_state, compound_statement = parse_compound_statement(new_state, identifier.value)

  if existsCurrent(new_state.context, identifier.value) then
    print('Identificador `' .. identifier.value .. '` já existe no contexto atual')
    os.exit(1)
    return state, nil
  end

  local params = extractArgs(parameter_list)
  new_state.context.content[identifier.value] = {
    name = identifier.value,
    type = "function",
    return_type = type_specifier.value,
    params = params
  }

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
---@nodiscard
function parse_declaration(state)
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
---@nodiscard
function parse_declaration_list(state)
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
---@return ASTNode?
---@nodiscard
function parser.parse(tokens)
  ---@type ParserState
  local state = {
    tokens = table.deep_copy(tokens),
    index = 1,
    context = {
      parent = nil,
      children = {},
      content = {
        ["printf"] = {
          name = 'printf',
          type = 'function',
          return_type = 'int',
          params = {
            {
              name = 'format',
              type = "variable",
              var_type = 'string'
            },
            {
              name = 'args',
              type = "variable",
              var_type = 'string'
            },
          }
        }
      },
      name = 'global'
    }
  }

  local new_state, program = parse_declaration_list(state)
  local valid = get_current_token(new_state) == nil

  -- print("Contexts: ")
  -- print(table.to_json(new_state.context))

  if not valid then
    return nil
    -- error('unexpected token' .. get_current_token(new_state).type)
  end

  printContextTable(new_state.context)

  return program
end

return parser
