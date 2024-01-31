local lexer = require('lexer')
local parser = require('parser')

local source = [[
    3 + 4 * 5
]]

local identifiers, tokens = lexer.lex(source)
print('Symbols:')
print(table.dump(identifiers))
print('Token list:')
print(table.dump(tokens))
local expression = parser.parse(tokens)

print('Expression:')
print(table.dump(expression))
