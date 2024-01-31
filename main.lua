local lexer = require('lexer')
local parser = require('parser')
local utils = require('utils')

-- get files from args
local files = {}
for i = 1, #arg do
  files[i] = arg[i]
end

for _, file in pairs(files) do
  print('File:', file)

  local source = utils.read_source(file)
  assert(source ~= nil, 'Erro lendo arquivo fonte')

  local symbols, tokens = lexer.lex(source)

  print('Symbols:')
  for symbol, _ in pairs(symbols) do
    print('| ' .. symbol)
  end

  print('Token list:')
  for _, token in pairs(tokens) do
    -- print(key, value.type, value.value, value.position.line, value.position.col)
    lexer.print_token(token)
  end

  local result = parser.parse(tokens)
  if result then
    print('Programa válido')
  else
    print('Programa inválido')
  end
end

