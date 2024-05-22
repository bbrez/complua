local lexer = require('lexer')
local parser = require('parser')

local source = [[
    #include <stdio.h>

    int soma(int x, int y) {
      int resultado;
      resultado = x + y;
      return resultado;
    }

    int main(int argc) {
        int a;
        int b;
        for(a = 0; a < 10 ; ++a) {
          b = a + 1;
          if(a && 1 == 0) {
            printf("Soma de %d com %d eh %d (par)\n", a, b, soma(a, b));
          } else {
            printf("Soma de %d com %d eh %d (impar)\n", a, b, soma(a, b));
          }
        }
    }
]]

local identifiers, tokens = lexer.lex(source)
-- print('Symbols:')
-- print(table.to_json(identifiers))
-- print('Token list:')
-- print(table.to_json(tokens))
tokens = lexer.cleanup(tokens)
local program = parser.parse(tokens)

-- print('Program:')
-- if not program then
--   print('Erro de sintaxe')
-- else
--   print(table.to_json(program))
-- end
