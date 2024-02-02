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
---@nodiscard
function table.copy(t)
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = v
  end
  return copy
end

---Verifica se uma tabela contem o elemento informado
---@param table table
---@param elem any
---@return boolean
---@nodiscard
function table.contains(table, elem)
  for _, value in pairs(table) do
    if value == elem then
      return true
    end
  end
  return false
end

---Compara os valores de dois objetos, recursivamente
---@param t1 table|any
---@param t2 table|any
function table.compare(t1, t2)
  if type(t1) ~= 'table' or type(t2) ~= 'table' then
    return t1 == t2
  end

  for k, v in pairs(t1) do
    if not table.compare(v, t2[k]) then
      return false
    end
  end

  for k, v in pairs(t2) do
    if not table.compare(v, t1[k]) then
      return false
    end
  end

  return true
end

---Verifica tentativamente se uma tabela está sendo usada como vetor. Isto é utilizado na conversão para JSON
---Uma tabela é considerada vetor se seus índices são números inteiros positivos, começando de 1
---@param t any
---@return boolean
function table.is_array(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then
      return false
    end
  end
  return true
end

function table.length(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

---Converte uma tabela para uma string JSON
---@param t table
function table.to_json(t)
  ---Função auxiliar para converter uma tabela para JSON
  ---@param v table
  ---@param depth number
  local function aux(v, depth)
    local indent = string.rep('  ', depth)
    if type(v) == 'table' then
      if table.is_array(v) then
        local result = '[\n'
        for i, val in ipairs(v) do
          result = result .. indent .. ' ' .. aux(val, depth + 1)
          if i < table.length(v) then
            result = result .. ','
          end
          result = result .. '\n'
        end
        return result .. indent .. ']'
      else
        local result = '{\n'
        local count = 1
        for key, val in pairs(v) do
          result = result .. indent .. ' "' .. key .. '": ' .. aux(val, depth + 1)
          if count < table.length(v) then
            result = result .. ','
          end
          count = count + 1
          result = result .. '\n'
        end
        return result .. indent .. '}'
      end
    elseif type(v) == 'string' then
      return '"' .. v .. '"'
    else
      return tostring(v)
    end
  end

  return aux(t, 0)
end

---Aplica uma função a cada elemento de uma tabela
---@generic T
---@generic U
---@param t T[]
---@param f fun(e: T): U
---@return U[]
---@nodiscard
function table.map(t, f)
  local result = {}
  for k, v in pairs(t) do
    result[k] = f(v)
  end
  return result
end

---Filtra os elementos de uma tabela
---@generic T
---@param t T[]
---@param f fun(e: T): boolean
---@return T[]
---@nodiscard
function table.filter(t, f)
  local result = {}
  for k, v in pairs(t) do
    if f(v) then
      result[k] = v
    end
  end
  return result
end

---Aplica uma função a cada elemento de uma tabela e a um acumulador
---@generic T
---@generic U
---@param t T[]
---@param f fun(acc: U, e: T): U
---@param acc U
---@return U
---@nodiscard
function table.fold(t, f, acc)
  for _, v in pairs(t) do
    acc = f(acc, v)
  end
  return acc
end

---Verifica se uma string é vazia ou contém apenas espaços
---@param str string
---@return boolean
---@nodiscard
function string.is_blank(str)
  return str == nil or str:match('^%s*$') ~= nil
end

---Lê um arquivo fonte completo e retorna o texto como string
---@param filename string
---@return string?
---@nodiscard
function utils.read_source(filename)
  local f <close> = io.open(filename, 'r')
  if not f then return nil end
  local source = f:read('*a')
  f:close()
  return source
end

---Verifica se um caractere é um número
---@param char string
---@return boolean
---@nodiscard
function utils.is_number(char)
  return char >= '0' and char <= '9'
end

---Verifica se um caractere é uma letra
---@param char string
---@return boolean
---@nodiscard
function utils.is_letter(char)
  return char >= 'a' and char <= 'z' or char >= 'A' and char <= 'Z'
end

return utils
