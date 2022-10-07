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
handle_table[HANDLE_UNKNOWN_1E] = "pseudo constant (?)"
HANDLE_HARDWARE_VERSION = "0x0032"
handle_table[HANDLE_HARDWARE_VERSION] = "hardware version"

get_btaattribute_opcode = Field.new("btatt.opcode")
local opcode_table = {}
opcode_table["0x0a"] = "read"
OPCODE_RESPONSE = "0x0b"
opcode_table[OPCODE_RESPONSE] = "response"
opcode_table["0x08"] = "request characteristic info"
opcode_table["0x09"] = "characteristic info response"

get_btattribute_firmware_version_string = Field.new("btatt.firmware_revision_string")

-- our new protocol fields
message_type = ProtoField.string("hydrao.message_type", "message_type", base.UNICODE, "Message type (unknown if not identified yet)")
message_description = ProtoField.string("hydrao.message_description", "message_description", base.UNICODE)
total_volume = ProtoField.int32("hydrao.total_volume", "total_volume", base.DEC)
current_shower_volume = ProtoField.int32("hydrao.current_shower_volume", "current_shower_volume", base.DEC)
hardware_version = ProtoField.int32("hydrao.hardware_version", "hardware_version", base.DEC)
device_uuid = ProtoField.string("hydrao.device_uuid", "device_uuid", base.UNICODE)
firmware_revision_string = ProtoField.string("hydrao.firmware_revision", "firmware_revision", base.UNICODE)
field_001a_1 = ProtoField.int32("hydrao.field_001a_1", "field_001a_1", base.DEC)
field_001a_2 = ProtoField.int32("hydrao.field_001a_2", "field_001a_2", base.DEC)
field_001e = ProtoField.int32("hydrao.field_001e", "field_001e", base.DEC)


hydrao_protocol.fields = {
  message_type,
  message_description,
  total_volume,
  current_shower_volume,
  hardware_version,
  device_uuid,
  firmware_revision_string,
  field_001a_1,
  field_001a_2,
  field_001e
}

function parse_firmware_revision_string(buffer, subtree)
  local firmware_revision_string_value = tostring(get_btattribute_firmware_version_string())
  subtree:add(firmware_revision_string, firmware_revision_string_value)
  subtree:add(message_description, "Firmware revision is " .. firmware_revision_string_value)
end

function parse_1e(buffer, subtree)
  local part1 = buffer(10,2):le_uint()
  subtree:add(field_001e, part1)
  subtree:add(message_description, "001e: " .. tostring(part1))
end

function parse_1a(buffer, subtree)
  -- this field visibly contains 2 numbers:
  -- 1st one is obviously incrementing but has some small drops
  -- 2nd one increments monotonically with large plateaux
  local part1 = buffer(10,2):le_uint()
  local part2 = buffer(12,2):le_uint()
  subtree:add(field_001a_1, part1)
  subtree:add(field_001a_2, part2)
  subtree:add(message_description, "001a: " .. tostring(part1) .. "  " .. tostring(part2))
end

function parse_hardware_version(buffer, subtree)
  local hardware_version_value = buffer(10, 2):le_uint()
  subtree:add(hardware_version, hardware_version_value)
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
  subtree:add(device_uuid, uuid_value)
  subtree:add(message_description, "Device uuid is " .. uuid_value)
end

function parse_volumes_response(buffer, subtree)
  local total_volume_value = buffer(10,2):le_uint()
  subtree:add(total_volume, total_volume_value)
  local current_shower_volume_value = buffer(12,2):le_uint()
  subtree:add(current_shower_volume, current_shower_volume_value)
  subtree:add(message_description, "Current: " .. current_shower_volume_value .. "L" .. ", total " .. total_volume_value .. "L")
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
  end

end

-- TODO: find a way to only identify the correct packets instead of all packets
--local bluetooth_encapsulation = DissectorTable.get("hci_h4.type")
-- bluetooth_encapsulation:add(2, hydrao_protocol)
register_postdissector(hydrao_protocol)
