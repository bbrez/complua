local lexer = require('lexer')
local parser = require('parser')

local source = [[
    int main() {
        int a;
        if(a == 35) {
          printf("35");
        } else {
          printf("nao 35");
        }

        a = 0;
        while(a < 10) {
          a = a + 1;
          printf("a");
        }
        return 0;
    }
]]

local identifiers, tokens = lexer.lex(source)
print('Symbols:')
print(table.to_json(identifiers))
print('Token list:')
print(table.to_json(tokens))
local program = parser.parse(tokens)

print('Program:')
if not program then
    print('Erro de sintaxe')
else
    print(table.to_json(program))
end
