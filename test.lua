local lexer = require('lexer')
local parser = require('parser')

local source = [[
    #include <stdio.h>

    int a;
    int main() {
        int a;
        int b;
    }
]]

local identifiers, tokens = lexer.lex(source)
print('Symbols:')
print(table.to_json(identifiers))
print('Token list:')
print(table.to_json(tokens))
tokens = lexer.cleanup(tokens)
local program = parser.parse(tokens)

print('Program:')
if not program then
  print('Erro de sintaxe')
else
  print(table.to_json(program))
end
