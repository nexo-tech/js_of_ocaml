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

-- I/O operations for OCaml channels and file descriptors

-- Load dependencies
dofile("marshal.lua")
dofile("fail.lua")

-- File descriptor table (similar to caml_sys_fds in JS runtime)
local caml_sys_fds = {}

-- Initialize stdin (0), stdout (1), stderr (2)
caml_sys_fds[0] = { file = io.stdin, flags = {rdonly = true}, offset = 0 }
caml_sys_fds[1] = { file = io.stdout, flags = {wronly = true}, offset = 0 }
caml_sys_fds[2] = { file = io.stderr, flags = {wronly = true}, offset = 0 }

-- Channel ID counter
local next_chanid = 3

-- Channel table (maps channel IDs to channel objects)
local caml_ml_channels = {}

-- Default buffer size for channels
local caml_io_buffer_size = 4096

--
-- Channel Backend Interface
--
-- A backend is a table with the following methods:
--   read(n): Read up to n bytes, return string (or nil on EOF)
--   write(str): Write string, return number of bytes written
--   flush(): Flush any pending writes (optional)
--   seek(pos): Seek to position (optional, for seekable backends)
--   close(): Close the backend (optional)
--
-- Built-in backends: file, memory, custom
--

--
-- File descriptor operations
--

--Provides: caml_sys_open
function caml_sys_open(name, flags, perms)
  -- Parse OCaml open flags
  -- flags is an OCaml list: 0 = [], [tag, [next]]
  local parsed_flags = {}
  while flags ~= 0 do
    local flag = flags[1]
    -- Flag meanings from OCaml:
    -- 0 = O_RDONLY, 1 = O_WRONLY, 2 = O_APPEND, 3 = O_CREAT,
    -- 4 = O_TRUNC, 5 = O_EXCL, 6 = O_BINARY, 7 = O_TEXT, 8 = O_NONBLOCK
    if flag == 0 then
      parsed_flags.rdonly = true
    elseif flag == 1 then
      parsed_flags.wronly = true
    elseif flag == 2 then
      parsed_flags.append = true
      parsed_flags.wronly = true
    elseif flag == 3 then
      parsed_flags.create = true
    elseif flag == 4 then
      parsed_flags.truncate = true
    elseif flag == 6 then
      parsed_flags.binary = true
    elseif flag == 7 then
      parsed_flags.text = true
    end
    flags = flags[2]
  end

  -- Determine Lua file open mode
  local mode
  if parsed_flags.rdonly and not parsed_flags.wronly then
    mode = parsed_flags.binary and "rb" or "r"
  elseif parsed_flags.wronly and not parsed_flags.rdonly then
    if parsed_flags.append then
      mode = parsed_flags.binary and "ab" or "a"
    else
      mode = parsed_flags.binary and "wb" or "w"
    end
  else
    -- Read/write mode
    mode = parsed_flags.binary and "r+b" or "r+"
    if parsed_flags.create then
      mode = parsed_flags.binary and "w+b" or "w+"
    end
  end

  -- Open the file
  local file, err = io.open(name, mode)
  if not file then
    error("caml_sys_open: " .. (err or "unknown error"))
  end

  -- Find available file descriptor number
  local fd = next_chanid
  next_chanid = next_chanid + 1

  -- Store file descriptor
  caml_sys_fds[fd] = {
    file = file,
    flags = parsed_flags,
    offset = 0
  }

  return fd
end

--Provides: caml_sys_close
function caml_sys_close(fd)
  local fd_desc = caml_sys_fds[fd]
  if fd_desc and fd_desc.file then
    -- Don't close stdin/stdout/stderr
    if fd >= 3 then
      fd_desc.file:close()
    end
    caml_sys_fds[fd] = nil
  end
  return 0
end

--
-- Channel operations
--

--Provides: caml_ml_open_descriptor_in
function caml_ml_open_descriptor_in(fd)
  local fd_desc = caml_sys_fds[fd]
  if not fd_desc then
    error("caml_ml_open_descriptor_in: invalid file descriptor " .. tostring(fd))
  end

  -- Create channel ID
  local chanid = next_chanid
  next_chanid = next_chanid + 1

  -- Create input channel
  local channel = {
    file = fd_desc.file,
    fd = fd,
    flags = fd_desc.flags,
    opened = true,
    out = false,
    buffer = "",
    buffer_pos = 1,
    offset = fd_desc.offset or 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_descriptor_out
function caml_ml_open_descriptor_out(fd)
  local fd_desc = caml_sys_fds[fd]
  if not fd_desc then
    error("caml_ml_open_descriptor_out: invalid file descriptor " .. tostring(fd))
  end

  -- Create channel ID
  local chanid = next_chanid
  next_chanid = next_chanid + 1

  -- Create output channel
  local channel = {
    file = fd_desc.file,
    fd = fd,
    flags = fd_desc.flags,
    opened = true,
    out = true,
    buffer = {},
    buffered = 1, -- 0 = unbuffered, 1 = buffered, 2 = line buffered
    offset = fd_desc.offset or 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_descriptor_in_with_flags
--Requires: caml_ml_open_descriptor_in
function caml_ml_open_descriptor_in_with_flags(fd, flags)
  -- OCaml 5.1+: currently ignoring flags
  return caml_ml_open_descriptor_in(fd)
end

--Provides: caml_ml_open_descriptor_out_with_flags
--Requires: caml_ml_open_descriptor_out
function caml_ml_open_descriptor_out_with_flags(fd, flags)
  -- OCaml 5.1+: currently ignoring flags
  return caml_ml_open_descriptor_out(fd)
end

--Provides: caml_ml_close_channel
--Requires: caml_ml_flush, caml_sys_close
function caml_ml_close_channel(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.opened then
    if chan.out then
      caml_ml_flush(chanid)
    end
    chan.opened = false
    -- Close custom backend if it has a close method
    if chan.backend and chan.backend.close then
      chan.backend:close()
    end
    -- Close file descriptor if present (not for memory/custom channels)
    if chan.fd then
      caml_sys_close(chan.fd)
    end
  end
  return 0
end

--Provides: caml_channel_descriptor
function caml_channel_descriptor(chanid)
  local chan = caml_ml_channels[chanid]
  if chan then
    return chan.fd
  end
  error("caml_channel_descriptor: invalid channel")
end

--
-- Input operations
--

--Provides: caml_ml_input_char
function caml_ml_input_char(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input_char: channel is closed")
  end

  -- Check buffer first
  if chan.buffer_pos <= #chan.buffer then
    local c = string.byte(chan.buffer, chan.buffer_pos)
    chan.buffer_pos = chan.buffer_pos + 1
    chan.offset = chan.offset + 1
    return c
  end

  -- Memory channel
  if chan.memory then
    if chan.pos > #chan.data then
      error("End_of_file")
    end
    local c = string.byte(chan.data, chan.pos)
    chan.pos = chan.pos + 1
    chan.offset = chan.offset + 1
    return c
  end

  -- Custom backend
  if chan.backend then
    local chunk = chan.backend:read(1)
    if not chunk or #chunk == 0 then
      error("End_of_file")
    end
    chan.offset = chan.offset + 1
    return string.byte(chunk, 1)
  end

  -- Read from file
  local c = chan.file:read(1)
  if not c then
    error("End_of_file")
  end

  chan.offset = chan.offset + 1
  return string.byte(c)
end

--Provides: caml_ml_input
function caml_ml_input(chanid, buf, offset, len)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input: channel is closed")
  end

  local bytes_read = 0

  -- Read from buffer first
  local buf_avail = #chan.buffer - chan.buffer_pos + 1
  if buf_avail > 0 then
    local to_read = math.min(len, buf_avail)
    local chunk = string.sub(chan.buffer, chan.buffer_pos, chan.buffer_pos + to_read - 1)
    -- Store in OCaml bytes buffer (table representation)
    for i = 1, to_read do
      buf[offset + i] = string.byte(chunk, i)
    end
    chan.buffer_pos = chan.buffer_pos + to_read
    bytes_read = to_read
    len = len - to_read
    offset = offset + to_read
  end

  -- Read more from file/memory/backend if needed
  if len > 0 then
    local chunk
    if chan.memory then
      -- Read from memory
      local available = #chan.data - chan.pos + 1
      if available > 0 then
        local to_read = math.min(len, available)
        chunk = string.sub(chan.data, chan.pos, chan.pos + to_read - 1)
        chan.pos = chan.pos + to_read
      end
    elseif chan.backend then
      -- Read from custom backend
      chunk = chan.backend:read(len)
    else
      -- Read from file
      chunk = chan.file:read(len)
    end

    if chunk then
      local chunk_len = #chunk
      for i = 1, chunk_len do
        buf[offset + i] = string.byte(chunk, i)
      end
      bytes_read = bytes_read + chunk_len
      chan.offset = chan.offset + chunk_len
    end
  end

  return bytes_read
end

--Provides: caml_ml_input_int
--Requires: caml_ml_input_char
function caml_ml_input_int(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input_int: channel is closed")
  end

  -- Read 4 bytes in big-endian order
  local result = 0
  for i = 1, 4 do
    local b = caml_ml_input_char(chanid)
    result = (result << 8) | b
  end

  return result
end

--Provides: caml_ml_input_scan_line
function caml_ml_input_scan_line(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input_scan_line: channel is closed")
  end

  -- Look for newline in buffer
  local newline_pos = string.find(chan.buffer, "\n", chan.buffer_pos, true)
  if newline_pos then
    return newline_pos - chan.buffer_pos + 1
  end

  -- Read more into buffer
  local chunk = chan.file:read("*l")
  if chunk then
    chan.buffer = string.sub(chan.buffer, chan.buffer_pos) .. chunk .. "\n"
    chan.buffer_pos = 1
    return #chan.buffer
  end

  -- No newline found, return remaining buffer size
  return -(#chan.buffer - chan.buffer_pos + 1)
end

--Provides: caml_input_value
--Requires: caml_ml_input
-- Read marshalled value from input channel
-- This reads a complete marshal format (header + data) from a channel
function caml_input_value(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_input_value: channel is closed")
  end

  error("caml_input_value: marshal functions not yet reimplemented")
end

--Provides: caml_input_value_to_outside_heap
--Requires: caml_input_value
-- Alias for compatibility (OCaml 5.0+)
function caml_input_value_to_outside_heap(chanid)
  return caml_input_value(chanid)
end

--
-- Output operations
--

--Provides: caml_ml_flush
function caml_ml_flush(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_flush: invalid channel")
  end
  if not chan.opened then
    error("caml_ml_flush: channel is closed")
  end
  if not chan.out then
    return 0
  end

  -- For memory channels, buffer is already the destination
  if chan.memory then
    -- Nothing to flush - data is already in chan.buffer
    return 0
  end

  -- Flush buffer to file or custom backend
  if #chan.buffer > 0 then
    local str = table.concat(chan.buffer)
    if chan.backend then
      -- Custom backend
      local written = chan.backend:write(str)
      if chan.backend.flush then
        chan.backend:flush()
      end
      chan.offset = chan.offset + (written or #str)
    else
      -- File backend
      chan.file:write(str)
      chan.file:flush()
      chan.offset = chan.offset + #str
    end
    chan.buffer = {}
  end

  return 0
end

--Provides: caml_ml_output_char
--Requires: caml_ml_flush
function caml_ml_output_char(chanid, c)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_output_char: channel is closed")
  end

  local char = string.char(c)
  table.insert(chan.buffer, char)

  -- Flush if unbuffered
  if chan.buffered == 0 then
    caml_ml_flush(chanid)
  -- Line buffered: flush on newline
  elseif chan.buffered == 2 and c == 10 then
    caml_ml_flush(chanid)
  end

  return 0
end

--Provides: caml_ml_output
--Requires: caml_ml_flush
function caml_ml_output(chanid, str, offset, len)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_output: channel is closed")
  end

  -- Extract substring (Lua strings are 1-based, OCaml offset is 0-based)
  local chunk = string.sub(str, offset + 1, offset + len)
  table.insert(chan.buffer, chunk)

  -- Handle buffering
  if chan.buffered == 0 then
    caml_ml_flush(chanid)
  elseif chan.buffered == 2 and string.find(chunk, "\n", 1, true) then
    caml_ml_flush(chanid)
  elseif chan.buffered == 1 and #table.concat(chan.buffer) >= caml_io_buffer_size then
    caml_ml_flush(chanid)
  end

  return 0
end

--Provides: caml_ml_output_bytes
--Requires: caml_ml_output
function caml_ml_output_bytes(chanid, bytes, offset, len)
  -- Convert bytes (table of byte values) to string
  local chars = {}
  for i = 1, len do
    chars[i] = string.char(bytes[offset + i])
  end
  local str = table.concat(chars)

  -- Use regular output
  return caml_ml_output(chanid, str, 0, len)
end

--Provides: caml_ml_output_int
--Requires: caml_ml_flush
function caml_ml_output_int(chanid, i)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_output_int: channel is closed")
  end

  -- Write 4 bytes in big-endian order
  local bytes = {
    string.char((i >> 24) & 0xFF),
    string.char((i >> 16) & 0xFF),
    string.char((i >> 8) & 0xFF),
    string.char(i & 0xFF)
  }
  table.insert(chan.buffer, table.concat(bytes))

  if chan.buffered == 0 then
    caml_ml_flush(chanid)
  end

  return 0
end

--Provides: caml_output_value
--Requires: caml_ml_output
-- Write marshalled value to output channel
-- This writes a complete marshal format (header + data) to a channel
function caml_output_value(chanid, v, flags)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_output_value: channel is closed")
  end

  if not chan.out then
    error("caml_output_value: channel is not an output channel")
  end

  error("caml_output_value: marshal functions not yet reimplemented")
end

--
-- Channel positioning
--

--Provides: caml_ml_seek_in
function caml_ml_seek_in(chanid, pos)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_seek_in: channel is closed")
  end

  chan.file:seek("set", pos)
  chan.offset = pos
  chan.buffer = ""
  chan.buffer_pos = 1
  return 0
end

--Provides: caml_ml_seek_in_64
--Requires: caml_ml_seek_in
function caml_ml_seek_in_64(chanid, pos)
  -- Lua numbers are 64-bit floats, should handle most cases
  return caml_ml_seek_in(chanid, pos)
end

--Provides: caml_ml_seek_out
--Requires: caml_ml_flush
function caml_ml_seek_out(chanid, pos)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_seek_out: channel is closed")
  end

  caml_ml_flush(chanid)
  chan.file:seek("set", pos)
  chan.offset = pos
  return 0
end

--Provides: caml_ml_seek_out_64
--Requires: caml_ml_seek_out
function caml_ml_seek_out_64(chanid, pos)
  return caml_ml_seek_out(chanid, pos)
end

--Provides: caml_ml_pos_in
function caml_ml_pos_in(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_pos_in: invalid channel")
  end

  -- Current position is offset minus unread buffer
  return chan.offset - (#chan.buffer - chan.buffer_pos + 1)
end

--Provides: caml_ml_pos_in_64
--Requires: caml_ml_pos_in
function caml_ml_pos_in_64(chanid)
  return caml_ml_pos_in(chanid)
end

--Provides: caml_ml_pos_out
function caml_ml_pos_out(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_pos_out: invalid channel")
  end

  -- Current position is offset plus buffered data
  local buffered = 0
  for _, chunk in ipairs(chan.buffer) do
    buffered = buffered + #chunk
  end
  return chan.offset + buffered
end

--Provides: caml_ml_pos_out_64
--Requires: caml_ml_pos_out
function caml_ml_pos_out_64(chanid)
  return caml_ml_pos_out(chanid)
end

--Provides: caml_ml_channel_size
function caml_ml_channel_size(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_channel_size: invalid channel")
  end

  local current = chan.file:seek()
  local size = chan.file:seek("end")
  chan.file:seek("set", current)
  return size
end

--Provides: caml_ml_channel_size_64
--Requires: caml_ml_channel_size
function caml_ml_channel_size_64(chanid)
  return caml_ml_channel_size(chanid)
end

--
-- Channel configuration
--

--Provides: caml_ml_set_binary_mode
function caml_ml_set_binary_mode(chanid, mode)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.flags.binary = (mode ~= 0)
    chan.flags.text = (mode == 0)
  end
  return 0
end

--Provides: caml_ml_is_binary_mode
function caml_ml_is_binary_mode(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.flags.binary then
    return 1
  end
  return 0
end

--Provides: caml_ml_set_channel_name
function caml_ml_set_channel_name(chanid, name)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.name = name
  end
  return 0
end

--Provides: caml_ml_out_channels_list
function caml_ml_out_channels_list()
  -- Return OCaml list of all open output channels
  local list = 0 -- empty list
  for chanid, chan in pairs(caml_ml_channels) do
    if chan.opened and chan.out then
      list = {chanid, list}
    end
  end
  return list
end

--Provides: caml_ml_is_buffered
function caml_ml_is_buffered(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.buffered and chan.buffered > 0 then
    return 1
  end
  return 0
end

--Provides: caml_ml_set_buffered
--Requires: caml_ml_flush
function caml_ml_set_buffered(chanid, v)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.buffered = v
    if v == 0 then
      caml_ml_flush(chanid)
    end
  end
  return 0
end

--
-- In-memory channels
--

--Provides: caml_ml_open_string_in
-- Create input channel from string
function caml_ml_open_string_in(str)
  local chanid = next_chanid
  next_chanid = next_chanid + 1

  local channel = {
    memory = true,
    opened = true,
    out = false,
    data = str,
    pos = 1,
    buffer = "",
    buffer_pos = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_buffer_out
-- Create output channel to buffer
function caml_ml_open_buffer_out()
  local chanid = next_chanid
  next_chanid = next_chanid + 1

  local channel = {
    memory = true,
    opened = true,
    out = true,
    buffer = {},
    buffered = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_buffer_contents
--Requires: caml_ml_flush
-- Get contents from buffer output channel
function caml_ml_buffer_contents(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened or not chan.out or not chan.memory then
    error("caml_ml_buffer_contents: invalid channel")
  end

  -- Flush any pending data
  caml_ml_flush(chanid)

  -- Convert buffer to string
  return table.concat(chan.buffer)
end

--Provides: caml_ml_buffer_reset
-- Reset buffer output channel
function caml_ml_buffer_reset(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened or not chan.out or not chan.memory then
    error("caml_ml_buffer_reset: invalid channel")
  end

  chan.buffer = {}
  chan.offset = 0
end

--
-- Custom Channel Backends
--

--Provides: caml_ml_open_custom_in
-- Create input channel with custom backend
-- backend must implement: read(n) -> string or nil
function caml_ml_open_custom_in(backend)
  local chanid = next_chanid
  next_chanid = next_chanid + 1

  local channel = {
    backend = backend,
    opened = true,
    out = false,
    buffer = "",
    buffer_pos = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_custom_out
-- Create output channel with custom backend
-- backend must implement: write(str) -> number, flush() (optional)
function caml_ml_open_custom_out(backend)
  local chanid = next_chanid
  next_chanid = next_chanid + 1

  local channel = {
    backend = backend,
    opened = true,
    out = true,
    buffer = {},
    buffered = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

