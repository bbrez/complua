local lexer = require('lexer')
local utils = require('utils')

local source = utils.read_source('test.c')
assert(source ~= nil, 'Erro lendo arquivo fonte')
local tokens = lexer.lex(source)

for _, token in pairs(tokens) do
  -- print(key, value.type, value.value, value.position.line, value.position.col)
  lexer.print_token(token)
end
