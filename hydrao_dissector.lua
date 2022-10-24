-- built with https://mika-s.github.io/wireshark/lua/dissector/2017/11/04/creating-a-wireshark-dissector-in-lua-1.html

hydrao_protocol = Proto("Hydrao_shower_head", "A protocol over bluetooth to exchange information between hydrao shower head and its phone app")
hydrao_protocol.fields = {}

-- some fields we want to read
get_btattribute_handle = Field.new("btatt.handle")
local handle_table = {}
HANDLE_FIRMWARE_REVISION = "0x000e"
handle_table[HANDLE_FIRMWARE_REVISION ] = "firmware revision"
HANDLE_DEVICE_UUID = "0x0010"
handle_table[HANDLE_DEVICE_UUID] = "device uuid"
HANDLE_VOLUMES = "0x0012"
handle_table[HANDLE_VOLUMES] = "volumes"
HANDLE_UNKNOWN_1A = "0x001a"
handle_table[HANDLE_UNKNOWN_1A] = "0x001a"
HANDLE_UNKNOWN_1E = "0x001e"
handle_table[HANDLE_UNKNOWN_1E] = "possible flow rate"
HANDLE_HARDWARE_VERSION = "0x0032"
handle_table[HANDLE_HARDWARE_VERSION] = "hardware version"
HANDLE_COLOR_THRESHOLDS = "0x0020"
handle_table[HANDLE_COLOR_THRESHOLDS] = "color thresholds"

get_btaattribute_opcode = Field.new("btatt.opcode")
local opcode_table = {}
opcode_table["0x0a"] = "read"
OPCODE_RESPONSE = "0x0b"
opcode_table[OPCODE_RESPONSE] = "response"
opcode_table["0x08"] = "request characteristic info"
opcode_table["0x09"] = "characteristic info response"
OPCODE_WRITE_REQUEST = "0x12"
opcode_table[OPCODE_WRITE_REQUEST] = "write request"
OPCODE_WRITE_RESPONSE = "0x13"
opcode_table[OPCODE_WRITE_RESPONSE] = "write response"

get_btattribute_firmware_version_string = Field.new("btatt.firmware_revision_string")

-- our new protocol fields, we start with some common fields applied to all packets and then specialized ones depending on type of packets
message_type = ProtoField.string("hydrao.message_type", "message_type", base.UNICODE, "Message type (unknown if not identified yet)")
message_description = ProtoField.string("hydrao.message_description", "message_description", base.UNICODE)
-- this field is used to ease graphing of value within wireshark
relevant_value = ProtoField.int32("hydrao.relevant_value", "relevant_value", base.DEC)

total_volume = ProtoField.int32("hydrao.total_volume", "total_volume", base.DEC)
current_shower_volume = ProtoField.int32("hydrao.current_shower_volume", "current_shower_volume", base.DEC)
hardware_version = ProtoField.int32("hydrao.hardware_version", "hardware_version", base.DEC)
device_uuid = ProtoField.string("hydrao.device_uuid", "device_uuid", base.UNICODE)
firmware_revision_string = ProtoField.string("hydrao.firmware_revision", "firmware_revision", base.UNICODE)
temperature_field = ProtoField.int32("hydrao.temperature", "field_001a_1", base.DEC)
average_temperature_field = ProtoField.int32("hydrao.average_temperature", "field_001a_2", base.DEC)
field_001e = ProtoField.int32("hydrao.field_001e", "field_001e", base.DEC)


hydrao_protocol.fields = {
  message_type,
  message_description,
  relevant_value,
  total_volume,
  current_shower_volume,
  hardware_version,
  device_uuid,
  firmware_revision_string,
  temperature_field,
  average_temperature_field,
  field_001e
}

function Color(_r, _g, _b)
  return function(fn) return fn(_r,_g,_b) end
end
function r(_r, _g, _b) return _r end
function g(_r, _g, _b) return _g end
function b(_r, _g, _b) return _b end
function eq(c1, c2)
  return c1(r) == c2(r) and c1(g) == c2(g) and c1(b) == c2(b) end

function read_color(buffer, start)
  local red = buffer(start,1):uint()
  local green = buffer(start+1,1):uint()
  local blue = buffer(start+2,1):uint()
  if eq(Color(red, green, blue), Color(0, 0, 0)) then
    return "off"
  elseif eq(Color(red, green, blue), Color(255, 0, 0)) then
    return "red"
  elseif eq(Color(red, green, blue), Color(0, 255, 0)) then
    return "green"
  elseif eq(Color(red, green, blue), Color(0, 0, 255)) then
    return "blue"
  elseif eq(Color(red, green, blue), Color(76, 221, 241)) then
    return "lightblue"
  elseif eq(Color(red, green, blue), Color(255, 0, 255)) then
    return "purple"
  elseif eq(Color(red, green, blue), Color(103, 255, 17)) then
    return "lightgreen"
  else
    return string.format("(%i,%i,%i)", red, green, blue)
  end
end

function parse_color_thresholds(buffer, subtree)
  -- TODO: add a new field per threshold and per color
  local start = buffer:len() - 16
  local volume_threshold1 = buffer(start,1):uint()
  local color_threshold1 = read_color(buffer, start+1)
  local volume_threshold2 = buffer(start+4,1):uint()
  local color_threshold2 = read_color(buffer, start+5)
  local volume_threshold3 = buffer(start+8,1):uint()
  local color_threshold3 = read_color(buffer, start+9)
  local volume_threshold4 = buffer(start+12,1):uint()
  local color_threshold4 = read_color(buffer, start+13)
  subtree:add(message_description, string.format(
    "%iL %s, %iL %s, %iL %s, %iL %s",
    volume_threshold1,
    color_threshold1,
    volume_threshold2,
    color_threshold2,
    volume_threshold3,
    color_threshold3,
    volume_threshold4,
    color_threshold4
  ))
end

function parse_firmware_revision_string(buffer, subtree)
  local firmware_revision_string_value = tostring(get_btattribute_firmware_version_string())
  subtree:add(firmware_revision_string, firmware_revision_string_value)
  subtree:add(message_description, "Firmware revision is " .. firmware_revision_string_value)
end

function parse_1e(buffer, subtree)
  local part1 = buffer(10,2):le_uint()
  subtree:add(field_001e, buffer(10, 2), part1)
  subtree:add(message_description, "volume " .. tostring(part1) .. "cL/min (?)")
  subtree:add(relevant_value, part1)
end

function parse_1a(buffer, subtree)
  -- this field visibly contains 2 numbers:
  -- 1st one is likely temperature (as we can see on new_shower_head_dump.log => a long plateau of high temperature, then a low plateau and then high again starting at 35L which is the exact time I put hot again)
  -- 2nd one 🤷
  -- I wonder however if value is not reversed (I don't remember when it was hot and when it was cold but I think I started with cold 🤔) => should we read in big endian instead?
  local part1 = buffer(10,2):le_uint()
  local part2 = buffer(12,2):le_uint()
  subtree:add(temperature_field, buffer(10, 2), part1 / 100)
  subtree:add(average_temperature_field, buffer(12, 2), part2 / 100)
  subtree:add(message_description, "Temperature: " .. tostring(part1/100) .. "°C, average:" .. tostring(part2/100) .. "°C")
  subtree:add(relevant_value, part1/100)
end

function parse_hardware_version(buffer, subtree)
  local hardware_version_value = buffer(10, 2):le_uint()
  subtree:add(hardware_version, buffer(10, 2), hardware_version_value)
  subtree:add(message_description, "Shower head model version is " .. hardware_version_value)
end

function parse_device_uuid(buffer, subtree)
  local uuid_value = ""
  for i=0, 2, 1 do
    for j=3, 0, -1 do
      uuid_value = uuid_value .. tostring(buffer(10 + 4*i + j,1))
    end
    if i < 2 then uuid_value = uuid_value .. "-" end
  end
  subtree:add(device_uuid, buffer(10, 12), uuid_value)
  subtree:add(message_description, "Device uuid is " .. uuid_value)
end

function parse_volumes_response(buffer, subtree)
  local total_volume_value = buffer(10,2):le_uint()
  subtree:add(total_volume, buffer(10, 2), total_volume_value)
  local current_shower_volume_value = buffer(12,2):le_uint()
  subtree:add(current_shower_volume, buffer(12, 2), current_shower_volume_value)
  subtree:add(message_description, "Current: " .. current_shower_volume_value .. "L" .. ", total " .. total_volume_value .. "L")
  subtree:add(relevant_value, current_shower_volume_value)
end

function hydrao_protocol.dissector(buffer, pinfo, tree)
  length = buffer:len()
  if length == 0 then return end

  pinfo.cols.protocol = hydrao_protocol.name

  local subtree = tree:add(hydrao_protocol, buffer(), "Hydrao protocol data")

  local btattribute_handle = tostring(get_btattribute_handle() or "no handle") -- it is a userdata so we only have tostring

  local opcode = tostring(get_btaattribute_opcode() or "no opcode")


  subtree:add(message_type, string.format(
    "%s %s",
    (opcode_table[opcode] or opcode),
    (handle_table[btattribute_handle] or btattribute_handle)
  ))

  if btattribute_handle and btattribute_handle == HANDLE_VOLUMES and opcode == OPCODE_RESPONSE then
    parse_volumes_response(buffer, subtree)
  elseif btattribute_handle == HANDLE_DEVICE_UUID and opcode == OPCODE_RESPONSE then
    parse_device_uuid(buffer, subtree)
  elseif btattribute_handle == HANDLE_HARDWARE_VERSION and opcode == OPCODE_RESPONSE then
    parse_hardware_version(buffer, subtree)
  elseif btattribute_handle == HANDLE_FIRMWARE_REVISION and opcode == OPCODE_RESPONSE then
    parse_firmware_revision_string(buffer, subtree)
  elseif btattribute_handle == HANDLE_UNKNOWN_1A and opcode == OPCODE_RESPONSE then
    parse_1a(buffer, subtree)
  elseif btattribute_handle == HANDLE_UNKNOWN_1E and opcode == OPCODE_RESPONSE then
    parse_1e(buffer, subtree)
  elseif btattribute_handle == HANDLE_COLOR_THRESHOLDS and (opcode == OPCODE_WRITE_REQUEST or opcode == OPCODE_RESPONSE) then
    parse_color_thresholds(buffer, subtree)
  end

end

-- TODO: find a way to only identify the correct packets instead of all packets
--local bluetooth_encapsulation = DissectorTable.get("hci_h4.type")
-- bluetooth_encapsulation:add(2, hydrao_protocol)
register_postdissector(hydrao_protocol)
