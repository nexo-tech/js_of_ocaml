-- Lua_of_ocaml runtime support
-- I/O operations for OCaml channels and file descriptors

-- Load dependencies
local marshal = require("marshal")
local marshal_header = require("marshal_header")
local fail = require("fail")

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
-- File descriptor operations
--

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

function caml_ml_open_descriptor_in_with_flags(fd, flags)
  -- OCaml 5.1+: currently ignoring flags
  return caml_ml_open_descriptor_in(fd)
end

function caml_ml_open_descriptor_out_with_flags(fd, flags)
  -- OCaml 5.1+: currently ignoring flags
  return caml_ml_open_descriptor_out(fd)
end

function caml_ml_close_channel(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.opened then
    if chan.out then
      caml_ml_flush(chanid)
    end
    chan.opened = false
    caml_sys_close(chan.fd)
  end
  return 0
end

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

  -- Read from file
  local c = chan.file:read(1)
  if not c then
    error("End_of_file")
  end

  chan.offset = chan.offset + 1
  return string.byte(c)
end

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

  -- Read more from file if needed
  if len > 0 then
    local chunk = chan.file:read(len)
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

-- Read marshalled value from input channel
-- This reads a complete marshal format (header + data) from a channel
function caml_input_value(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_input_value: channel is closed")
  end

  -- Standard header is 20 bytes
  local header_size = 20
  local header_buf = {}

  -- Read header (20 bytes)
  local header_read = caml_ml_input(chanid, header_buf, 0, header_size)

  -- Check for EOF
  if header_read == 0 then
    fail.raise_end_of_file()
  end

  -- Check for truncated header
  if header_read < header_size then
    error("input_value: truncated object (incomplete header)")
  end

  -- Convert header buffer to string for parsing
  local header_chars = {}
  for i = 1, header_size do
    table.insert(header_chars, string.char(header_buf[i]))
  end
  local header_str = table.concat(header_chars)

  -- Parse header to get data length
  local data_len = marshal.data_size(header_str, 0)

  -- Read data
  local data_buf = {}
  local data_read = caml_ml_input(chanid, data_buf, 0, data_len)

  -- Check for truncated data
  if data_read < data_len then
    error(string.format("input_value: truncated object (expected %d bytes, got %d)", data_len, data_read))
  end

  -- Convert data buffer to string
  local data_chars = {}
  for i = 1, data_len do
    table.insert(data_chars, string.char(data_buf[i]))
  end
  local data_str = table.concat(data_chars)

  -- Combine header + data and unmarshal
  local complete_str = header_str .. data_str
  local result = marshal.from_bytes(complete_str, 0)

  return result
end

-- Alias for compatibility (OCaml 5.0+)
function caml_input_value_to_outside_heap(chanid)
  return caml_input_value(chanid)
end

--
-- Output operations
--

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

  -- Flush buffer to file
  if #chan.buffer > 0 then
    local str = table.concat(chan.buffer)
    chan.file:write(str)
    chan.file:flush()
    chan.offset = chan.offset + #str
    chan.buffer = {}
  end

  return 0
end

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

  -- Marshal value (produces header + data)
  local marshalled = marshal.to_string(v, flags)

  -- Write marshalled data to channel
  caml_ml_output(chanid, marshalled, 0, #marshalled)

  -- Flush to ensure data is written
  -- (caml_ml_output may auto-flush based on buffering mode, but be explicit)
  if chan.buffered ~= 1 then
    -- For unbuffered (0) and line-buffered (2), caml_ml_output already flushed
    -- For fully-buffered (1), only flush if needed (done by caml_ml_output when buffer full)
  end

  return 0
end

--
-- Channel positioning
--

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

function caml_ml_seek_in_64(chanid, pos)
  -- Lua numbers are 64-bit floats, should handle most cases
  return caml_ml_seek_in(chanid, pos)
end

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

function caml_ml_seek_out_64(chanid, pos)
  return caml_ml_seek_out(chanid, pos)
end

function caml_ml_pos_in(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_pos_in: invalid channel")
  end

  -- Current position is offset minus unread buffer
  return chan.offset - (#chan.buffer - chan.buffer_pos + 1)
end

function caml_ml_pos_in_64(chanid)
  return caml_ml_pos_in(chanid)
end

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

function caml_ml_pos_out_64(chanid)
  return caml_ml_pos_out(chanid)
end

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

function caml_ml_channel_size_64(chanid)
  return caml_ml_channel_size(chanid)
end

--
-- Channel configuration
--

function caml_ml_set_binary_mode(chanid, mode)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.flags.binary = (mode ~= 0)
    chan.flags.text = (mode == 0)
  end
  return 0
end

function caml_ml_is_binary_mode(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.flags.binary then
    return 1
  end
  return 0
end

function caml_ml_set_channel_name(chanid, name)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.name = name
  end
  return 0
end

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

function caml_ml_is_buffered(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.buffered and chan.buffered > 0 then
    return 1
  end
  return 0
end

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

-- Export all functions as a module
return {
  caml_sys_open = caml_sys_open,
  caml_sys_close = caml_sys_close,
  caml_ml_open_descriptor_in = caml_ml_open_descriptor_in,
  caml_ml_open_descriptor_out = caml_ml_open_descriptor_out,
  caml_ml_open_descriptor_in_with_flags = caml_ml_open_descriptor_in_with_flags,
  caml_ml_open_descriptor_out_with_flags = caml_ml_open_descriptor_out_with_flags,
  caml_ml_close_channel = caml_ml_close_channel,
  caml_channel_descriptor = caml_channel_descriptor,
  caml_ml_flush = caml_ml_flush,
  caml_ml_input_char = caml_ml_input_char,
  caml_ml_input = caml_ml_input,
  caml_ml_input_int = caml_ml_input_int,
  caml_ml_input_scan_line = caml_ml_input_scan_line,
  caml_input_value = caml_input_value,
  caml_input_value_to_outside_heap = caml_input_value_to_outside_heap,
  caml_ml_output_char = caml_ml_output_char,
  caml_ml_output = caml_ml_output,
  caml_ml_output_bytes = caml_ml_output_bytes,
  caml_ml_output_int = caml_ml_output_int,
  caml_output_value = caml_output_value,
  caml_ml_seek_in = caml_ml_seek_in,
  caml_ml_seek_in_64 = caml_ml_seek_in_64,
  caml_ml_seek_out = caml_ml_seek_out,
  caml_ml_seek_out_64 = caml_ml_seek_out_64,
  caml_ml_pos_in = caml_ml_pos_in,
  caml_ml_pos_in_64 = caml_ml_pos_in_64,
  caml_ml_pos_out = caml_ml_pos_out,
  caml_ml_pos_out_64 = caml_ml_pos_out_64,
  caml_ml_channel_size = caml_ml_channel_size,
  caml_ml_channel_size_64 = caml_ml_channel_size_64,
  caml_ml_set_binary_mode = caml_ml_set_binary_mode,
  caml_ml_is_binary_mode = caml_ml_is_binary_mode,
  caml_ml_set_channel_name = caml_ml_set_channel_name,
  caml_ml_out_channels_list = caml_ml_out_channels_list,
  caml_ml_is_buffered = caml_ml_is_buffered,
  caml_ml_set_buffered = caml_ml_set_buffered,
}
