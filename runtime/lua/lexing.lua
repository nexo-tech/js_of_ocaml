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

--Provides: caml_lex_array
function caml_lex_array(s)
  local len = #s / 2
  local result = {}

  for i = 0, len - 1 do
    local lo = s[2 * i + 1]
    local hi = s[2 * i + 2]
    -- Lua 5.1 compatible: lo | (hi << 8)
    local val = lo + hi * 256
    if val >= 0x8000 then
      val = val - 0x10000
    end
    result[i + 1] = val
  end

  return result
end

--Provides: caml_lex_engine
--Requires: caml_lex_array
function caml_lex_engine(tbl, start_state, lexbuf)
  -- Inline TBL_BASE=1, TBL_BACKTRK=2, TBL_CHECK=5, TBL_TRANS=4, TBL_DEFAULT=3
  if not tbl.lex_default then
    tbl.lex_base = caml_lex_array(tbl[1])     -- TBL_BASE
    tbl.lex_backtrk = caml_lex_array(tbl[2])  -- TBL_BACKTRK
    tbl.lex_check = caml_lex_array(tbl[5])    -- TBL_CHECK
    tbl.lex_trans = caml_lex_array(tbl[4])    -- TBL_TRANS
    tbl.lex_default = caml_lex_array(tbl[3])  -- TBL_DEFAULT
  end

  local state = start_state
  local buffer = lexbuf[2]  -- LEX_BUFFER

  -- Inline LEX_LAST_POS=7, LEX_CURR_POS=6, LEX_START_POS=5, LEX_LAST_ACTION=8
  if state >= 0 then
    lexbuf[7] = lexbuf[6]  -- LEX_LAST_POS = LEX_CURR_POS
    lexbuf[5] = lexbuf[6]  -- LEX_START_POS = LEX_CURR_POS
    lexbuf[8] = -1         -- LEX_LAST_ACTION
  else
    state = -state - 1
  end

  while true do
    local base = tbl.lex_base[state + 1]
    if base < 0 then
      return -base - 1
    end

    local backtrk = tbl.lex_backtrk[state + 1]
    if backtrk >= 0 then
      lexbuf[7] = lexbuf[6]  -- LEX_LAST_POS = LEX_CURR_POS
      lexbuf[8] = backtrk    -- LEX_LAST_ACTION
    end

    -- Inline LEX_CURR_POS=6, LEX_BUFFER_LEN=3, LEX_EOF_REACHED=9
    local c
    if lexbuf[6] >= lexbuf[3] then  -- LEX_CURR_POS >= LEX_BUFFER_LEN
      if lexbuf[9] == 0 then        -- LEX_EOF_REACHED
        return -state - 1
      else
        c = 256  -- EOF pseudo-character
      end
    else
      c = buffer[lexbuf[6] + 1]  -- LEX_CURR_POS
      lexbuf[6] = lexbuf[6] + 1  -- LEX_CURR_POS
    end

    if tbl.lex_check[base + c + 1] == state then
      state = tbl.lex_trans[base + c + 1]
    else
      state = tbl.lex_default[state + 1]
    end

    if state < 0 then
      lexbuf[6] = lexbuf[7]  -- LEX_CURR_POS = LEX_LAST_POS
      if lexbuf[8] == -1 then  -- LEX_LAST_ACTION
        error("lexing: empty token")
      else
        return lexbuf[8]  -- LEX_LAST_ACTION
      end
    else
      if c == 256 then
        lexbuf[9] = 0  -- LEX_EOF_REACHED
      end
    end
  end
end

--Provides: caml_create_lexbuf_from_string
function caml_create_lexbuf_from_string(s)
  local buffer
  if type(s) == "string" then
    buffer = {string.byte(s, 1, -1)}
  else
    buffer = s
  end

  -- Inline: LEX_REFILL_BUF=1, LEX_BUFFER=2, LEX_BUFFER_LEN=3, LEX_ABS_POS=4,
  --         LEX_START_POS=5, LEX_CURR_POS=6, LEX_LAST_POS=7, LEX_LAST_ACTION=8,
  --         LEX_EOF_REACHED=9, LEX_MEM=10, LEX_START_P=11, LEX_CURR_P=12
  local lexbuf = {
    [1] = nil,           -- LEX_REFILL_BUF (not used for string)
    [2] = buffer,        -- LEX_BUFFER (input byte array)
    [3] = #buffer,       -- LEX_BUFFER_LEN
    [4] = 0,             -- LEX_ABS_POS
    [5] = 0,             -- LEX_START_POS
    [6] = 0,             -- LEX_CURR_POS
    [7] = 0,             -- LEX_LAST_POS
    [8] = -1,            -- LEX_LAST_ACTION
    [9] = 0,             -- LEX_EOF_REACHED
    [10] = {},           -- LEX_MEM
    [11] = {             -- LEX_START_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
    [12] = {             -- LEX_CURR_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
  }

  return lexbuf
end

--Provides: caml_lexbuf_refill_from_channel
--Requires: caml_ml_input
function caml_lexbuf_refill_from_channel(channel_id, lexbuf)
  local buf_size = 1024
  local buffer = {}
  local n = caml_ml_input(channel_id, buffer, 0, buf_size)

  if n == 0 then
    lexbuf[9] = 1  -- LEX_EOF_REACHED
    return 0
  end

  lexbuf[2] = buffer  -- LEX_BUFFER
  lexbuf[3] = n       -- LEX_BUFFER_LEN
  lexbuf[6] = 0       -- LEX_CURR_POS

  return n
end

--Provides: caml_create_lexbuf_from_channel
--Requires: caml_lexbuf_refill_from_channel
function caml_create_lexbuf_from_channel(channel_id)
  -- Inline: LEX_REFILL_BUF=1, LEX_BUFFER=2, LEX_BUFFER_LEN=3, LEX_ABS_POS=4,
  --         LEX_START_POS=5, LEX_CURR_POS=6, LEX_LAST_POS=7, LEX_LAST_ACTION=8,
  --         LEX_EOF_REACHED=9, LEX_MEM=10, LEX_START_P=11, LEX_CURR_P=12
  local lexbuf = {
    [1] = channel_id,    -- LEX_REFILL_BUF (store channel_id for refill)
    [2] = {},            -- LEX_BUFFER
    [3] = 0,             -- LEX_BUFFER_LEN
    [4] = 0,             -- LEX_ABS_POS
    [5] = 0,             -- LEX_START_POS
    [6] = 0,             -- LEX_CURR_POS
    [7] = 0,             -- LEX_LAST_POS
    [8] = -1,            -- LEX_LAST_ACTION
    [9] = 0,             -- LEX_EOF_REACHED
    [10] = {},           -- LEX_MEM
    [11] = {             -- LEX_START_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
    [12] = {             -- LEX_CURR_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
  }

  caml_lexbuf_refill_from_channel(channel_id, lexbuf)

  return lexbuf
end

--Provides: caml_lexeme
function caml_lexeme(lexbuf)
  local start_pos = lexbuf[5]  -- LEX_START_POS
  local curr_pos = lexbuf[6]   -- LEX_CURR_POS
  local buffer = lexbuf[2]     -- LEX_BUFFER
  local result = {}

  for i = start_pos + 1, curr_pos do
    result[#result + 1] = buffer[i]
  end

  return result
end

--Provides: caml_lexeme_string
--Requires: caml_lexeme
function caml_lexeme_string(lexbuf)
  local bytes = caml_lexeme(lexbuf)
  local chars = {}
  for i = 1, #bytes do
    chars[i] = string.char(bytes[i])
  end
  return table.concat(chars)
end

--Provides: caml_lexeme_start
function caml_lexeme_start(lexbuf)
  return lexbuf[5] + lexbuf[4]  -- LEX_START_POS + LEX_ABS_POS
end

--Provides: caml_lexeme_end
function caml_lexeme_end(lexbuf)
  return lexbuf[6] + lexbuf[4]  -- LEX_CURR_POS + LEX_ABS_POS
end

--Provides: caml_lexeme_start_p
function caml_lexeme_start_p(lexbuf)
  return lexbuf[11]  -- LEX_START_P
end

--Provides: caml_lexeme_end_p
function caml_lexeme_end_p(lexbuf)
  return lexbuf[12]  -- LEX_CURR_P
end

--Provides: caml_new_line
function caml_new_line(lexbuf)
  local curr_p = lexbuf[12]  -- LEX_CURR_P
  curr_p.pos_lnum = curr_p.pos_lnum + 1
  curr_p.pos_bol = lexbuf[6] + lexbuf[4]  -- LEX_CURR_POS + LEX_ABS_POS
  curr_p.pos_cnum = curr_p.pos_bol
end

--Provides: caml_lexeme_char
function caml_lexeme_char(lexbuf, n)
  local pos = lexbuf[5] + n  -- LEX_START_POS
  if pos < lexbuf[6] then    -- LEX_CURR_POS
    return lexbuf[2][pos + 1]  -- LEX_BUFFER
  else
    error("lexeme_char: index out of bounds")
  end
end

--Provides: caml_flush_lexbuf
function caml_flush_lexbuf(lexbuf)
  lexbuf[4] = lexbuf[4] + lexbuf[6]  -- LEX_ABS_POS = LEX_ABS_POS + LEX_CURR_POS
  lexbuf[6] = 0   -- LEX_CURR_POS
  lexbuf[5] = 0   -- LEX_START_POS
  lexbuf[7] = 0   -- LEX_LAST_POS
  lexbuf[2] = {}  -- LEX_BUFFER
  lexbuf[3] = 0   -- LEX_BUFFER_LEN
end