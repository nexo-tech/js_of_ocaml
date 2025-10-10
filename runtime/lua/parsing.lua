-- Js_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, with linking exception;
-- either version 2.1 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.


-- Global parser trace flag (accessible via caml_set_parser_trace)
caml_parser_trace_flag = false

--Provides: caml_parse_engine
--Requires: caml_lex_array
function caml_parse_engine(tables, env, cmd, arg)
  -- Inline TBL_* constants: DEFRED=6, SINDEX=8, CHECK=13, RINDEX=9, TABLE=12, LEN=5, LHS=4, GINDEX=10, DGOTO=7
  if not tables.dgoto then
    tables.defred = caml_lex_array(tables[6])   -- TBL_DEFRED
    tables.sindex = caml_lex_array(tables[8])   -- TBL_SINDEX
    tables.check = caml_lex_array(tables[13])   -- TBL_CHECK
    tables.rindex = caml_lex_array(tables[9])   -- TBL_RINDEX
    tables.table = caml_lex_array(tables[12])   -- TBL_TABLE
    tables.len = caml_lex_array(tables[5])      -- TBL_LEN
    tables.lhs = caml_lex_array(tables[4])      -- TBL_LHS
    tables.gindex = caml_lex_array(tables[10])  -- TBL_GINDEX
    tables.dgoto = caml_lex_array(tables[7])    -- TBL_DGOTO
  end

  local res = 0
  local n, n1, n2, state1

  -- Inline ENV_* constants: SP=14, STATE=15, ERRFLAG=16
  local sp = env[14]      -- ENV_SP
  local state = env[15]   -- ENV_STATE
  local errflag = env[16] -- ENV_ERRFLAG

  while true do
    if cmd == 0 then  -- START
      state = 0
      errflag = 0
      cmd = 6  -- LOOP
    elseif cmd == 6 then  -- LOOP
      n = tables.defred[state + 1]
      if n ~= 0 then
        cmd = 10  -- REDUCE
        goto continue
      end
      if env[7] >= 0 then  -- ENV_CURR_CHAR
        cmd = 7  -- TESTSHIFT
        goto continue
      end
      res = 0  -- READ_TOKEN
      break
    elseif cmd == 1 then  -- TOKEN_READ
      -- Inline TBL_TRANSL_BLOCK=3, TBL_TRANSL_CONST=2, ENV_CURR_CHAR=7, ENV_LVAL=8
      if type(arg) == "table" and arg.tag ~= nil then
        env[7] = tables[3][arg.tag + 2]  -- ENV_CURR_CHAR = TBL_TRANSL_BLOCK
        env[8] = arg[1]                  -- ENV_LVAL
      else
        env[7] = tables[2][arg + 2]  -- ENV_CURR_CHAR = TBL_TRANSL_CONST
        env[8] = 0                   -- ENV_LVAL
      end
      cmd = 7  -- TESTSHIFT
    elseif cmd == 7 then  -- TESTSHIFT
      n1 = tables.sindex[state + 1]
      n2 = n1 + env[7]  -- ENV_CURR_CHAR
      if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
         tables.check[n2 + 1] == env[7] then  -- ENV_CURR_CHAR
        cmd = 8  -- SHIFT
        goto continue
      end

      n1 = tables.rindex[state + 1]
      n2 = n1 + env[7]  -- ENV_CURR_CHAR
      if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
         tables.check[n2 + 1] == env[7] then  -- ENV_CURR_CHAR
        n = tables.table[n2 + 1]
        cmd = 10  -- REDUCE
        goto continue
      end

      if errflag <= 0 then
        res = 5  -- CALL_ERROR_FUNCTION
        break
      end
      cmd = 5  -- ERROR_DETECTED
    elseif cmd == 5 then  -- ERROR_DETECTED
      if errflag < 3 then
        errflag = 3
        while true do
          state1 = env[1][sp + 1]  -- ENV_S_STACK
          n1 = tables.sindex[state1 + 1]
          n2 = n1 + 256  -- ERRCODE
          if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
             tables.check[n2 + 1] == 256 then  -- ERRCODE
            cmd = 9  -- SHIFT_RECOVER
            goto continue
          else
            if sp <= env[6] then  -- ENV_STACKBASE
              env[14] = sp      -- ENV_SP
              env[15] = state   -- ENV_STATE
              env[16] = errflag -- ENV_ERRFLAG
              return 1  -- RAISE_PARSE_ERROR
            end
            sp = sp - 1
          end
        end
      else
        if env[7] == 0 then  -- ENV_CURR_CHAR
          env[14] = sp      -- ENV_SP
          env[15] = state   -- ENV_STATE
          env[16] = errflag -- ENV_ERRFLAG
          return 1  -- RAISE_PARSE_ERROR
        end
        env[7] = -1  -- ENV_CURR_CHAR
        cmd = 6  -- LOOP
        goto continue
      end
    elseif cmd == 8 then  -- SHIFT
      env[7] = -1  -- ENV_CURR_CHAR
      if errflag > 0 then
        errflag = errflag - 1
      end
      cmd = 9  -- SHIFT_RECOVER
    elseif cmd == 9 then  -- SHIFT_RECOVER
      state = tables.table[n2 + 1]
      sp = sp + 1
      if sp >= env[5] then  -- ENV_STACKSIZE
        res = 2  -- GROW_STACKS_1
        break
      end
      cmd = 2  -- STACKS_GROWN_1
    elseif cmd == 2 then  -- STACKS_GROWN_1
      -- Inline ENV_S_STACK=1, ENV_V_STACK=2, ENV_SYMB_START_STACK=3, ENV_SYMB_END_STACK=4, ENV_LVAL=8, ENV_SYMB_START=9, ENV_SYMB_END=10
      env[1][sp + 1] = state   -- ENV_S_STACK
      env[2][sp + 1] = env[8]  -- ENV_V_STACK = ENV_LVAL
      env[3][sp + 1] = env[9]  -- ENV_SYMB_START_STACK = ENV_SYMB_START
      env[4][sp + 1] = env[10] -- ENV_SYMB_END_STACK = ENV_SYMB_END
      cmd = 6  -- LOOP
      goto continue
    elseif cmd == 10 then  -- REDUCE
      local m = tables.len[n + 1]
      env[11] = sp  -- ENV_ASP
      env[13] = n   -- ENV_RULE_NUMBER
      env[12] = m   -- ENV_RULE_LEN
      sp = sp - m + 1
      m = tables.lhs[n + 1]
      state1 = env[1][sp + 1]  -- ENV_S_STACK
      n1 = tables.gindex[m + 1]
      n2 = n1 + state1
      if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
         tables.check[n2 + 1] == state1 then
        state = tables.table[n2 + 1]
      else
        state = tables.dgoto[m + 1]
      end
      if sp >= env[5] then  -- ENV_STACKSIZE
        res = 3  -- GROW_STACKS_2
        break
      end
      cmd = 3  -- STACKS_GROWN_2
    elseif cmd == 3 then  -- STACKS_GROWN_2
      res = 4  -- COMPUTE_SEMANTIC_ACTION
      break
    elseif cmd == 4 then  -- SEMANTIC_ACTION_COMPUTED
      env[1][sp + 1] = state  -- ENV_S_STACK
      env[2][sp + 1] = arg    -- ENV_V_STACK
      local asp = env[11]     -- ENV_ASP
      env[4][sp + 1] = env[4][asp + 1]  -- ENV_SYMB_END_STACK
      if sp > asp then
        env[3][sp + 1] = env[4][asp + 1]  -- ENV_SYMB_START_STACK = ENV_SYMB_END_STACK
      end
      cmd = 6  -- LOOP
      goto continue
    else
      env[14] = sp      -- ENV_SP
      env[15] = state   -- ENV_STATE
      env[16] = errflag -- ENV_ERRFLAG
      return 1  -- RAISE_PARSE_ERROR
    end

    ::continue::
  end

  env[14] = sp      -- ENV_SP
  env[15] = state   -- ENV_STATE
  env[16] = errflag -- ENV_ERRFLAG
  return res
end

--Provides: caml_set_parser_trace
function caml_set_parser_trace(bool)
  local oldflag = caml_parser_trace_flag
  caml_parser_trace_flag = bool
  return oldflag
end

--Provides: caml_create_parser_env
function caml_create_parser_env(stacksize)
  local size = stacksize or 100

  -- Inline ENV_* constants: S_STACK=1, V_STACK=2, SYMB_START_STACK=3, SYMB_END_STACK=4, STACKSIZE=5,
  -- STACKBASE=6, CURR_CHAR=7, LVAL=8, SYMB_START=9, SYMB_END=10, ASP=11, RULE_LEN=12, RULE_NUMBER=13,
  -- SP=14, STATE=15, ERRFLAG=16
  local env = {
    [1] = {},   -- ENV_S_STACK
    [2] = {},   -- ENV_V_STACK
    [3] = {},   -- ENV_SYMB_START_STACK
    [4] = {},   -- ENV_SYMB_END_STACK
    [5] = size, -- ENV_STACKSIZE
    [6] = 0,    -- ENV_STACKBASE
    [7] = -1,   -- ENV_CURR_CHAR
    [8] = 0,    -- ENV_LVAL
    [9] = 0,    -- ENV_SYMB_START
    [10] = 0,   -- ENV_SYMB_END
    [11] = 0,   -- ENV_ASP
    [12] = 0,   -- ENV_RULE_LEN
    [13] = 0,   -- ENV_RULE_NUMBER
    [14] = 0,   -- ENV_SP
    [15] = 0,   -- ENV_STATE
    [16] = 0,   -- ENV_ERRFLAG
  }

  return env
end

--Provides: caml_grow_parser_stacks
function caml_grow_parser_stacks(env, new_size)
  env[5] = new_size  -- ENV_STACKSIZE
end

--Provides: caml_parser_rule_info
function caml_parser_rule_info(env)
  return env[13], env[12]  -- ENV_RULE_NUMBER, ENV_RULE_LEN
end

--Provides: caml_parser_stack_value
function caml_parser_stack_value(env, offset)
  local asp = env[11]  -- ENV_ASP
  return env[2][asp + offset + 1]  -- ENV_V_STACK
end

--Provides: caml_parser_symb_start
function caml_parser_symb_start(env, offset)
  local asp = env[11]  -- ENV_ASP
  return env[3][asp + offset + 1]  -- ENV_SYMB_START_STACK
end

--Provides: caml_parser_symb_end
function caml_parser_symb_end(env, offset)
  local asp = env[11]  -- ENV_ASP
  return env[4][asp + offset + 1]  -- ENV_SYMB_END_STACK
end