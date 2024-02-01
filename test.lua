local lexer = require('lexer')
local parser = require('parser')

local source = [[
    int main() {
        return 0;
    }
]]

local identifiers, tokens = lexer.lex(source)
print('Symbols:')
print(table.dump(identifiers))
print('Token list:')
print(table.dump(tokens))
local expression = parser.parse(tokens)

print('Expression:')
print(table.dump(expression))
