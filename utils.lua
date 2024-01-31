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

---Verifica se uma tabela contem o elemento informado
---@param table any
---@param elem any
---@return boolean
function table.contains(table, elem)
  for _, value in pairs(table) do
    if value == elem then
      return true
    end
  end
  return false
end

---Imprime uma tabela, incluindo tabelas aninhadas
---@param t table
function table.dump(t)
  if type(t) == 'table' then
    local s = '{ '
    for k, v in pairs(t) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. table.dump(v) .. ', '
    end
    return s .. ' }'
  else
    return tostring(t)
  end
end

---Lê um arquivo fonte completo e retorna o texto como string
---@param filename string
---@return string?
function utils.read_source(filename)
  local f <close> = assert(io.open(filename, 'r'))
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
