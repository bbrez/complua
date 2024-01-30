local utils = {}

---Copia uma tabela, incluindo tabelas aninhadas
---@param t table
---@return table
function table.deep_copy(t)
  local copy = {}
  for k, v in pairs(t) do
    if type(v) == 'table' then
      copy[k] = table.deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

---Copia uma tabela
---@param t table
---@return table
function table.copy(t)
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = v
  end
  return copy
end

---Lê um arquivo fonte completo e retorna o texto como string
---@param filename string
---@return string?
function utils.read_source(filename)
  local f = io.open(filename, 'r')
  if not f then
    return nil
  end

  local source = f:read('*a')
  f:close()
  return source
end

---Verifica se um caractere é um número
---@param char string
---@return boolean
function utils.is_number(char)
  return char >= '0' and char <= '9'
end

---Verifica se um caractere é uma letra
---@param char string
---@return boolean
function utils.is_letter(char)
  return char >= 'a' and char <= 'z' or char >= 'A' and char <= 'Z'
end

return utils
