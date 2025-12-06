
function append_list(list, value)
     table.insert(list, (#list+1), value)
     return list
end


function concat_string(...)
    local args = {...}
    return table.concat(args, "")
end

local function connect()
  if serial_port_open(1, "/dev/serusb2", 115200, 0, 8, 1) then
      info("Motor connection successful")
      return true
  end
  info("Motor connection failed")
  serial_port_close(1)
  return false
end

local function send_angle(angle, direction)
  --[[  send angle to motor
  
  :param angle:
  
   ]]
  if not (0.0 <= angle and angle <= 359.99) then
      info("角度需在0~359.99范围内")
  end
  local frame_list = {}
  local angleIncrement = ((angle * 8) * 100.0)
  local frame_header_num = str_to_number("0x3E", 10)
  local single_turn_cmd_v1_num = str_to_number("0xA5", 10)
  local default_motor_id_num = str_to_number("0x01", 10)
  local data_len_num = str_to_number("0x04", 10)
  append_list(frame_list, frame_header_num)
  append_list(frame_list, single_turn_cmd_v1_num)
  append_list(frame_list, default_motor_id_num)
  append_list(frame_list, data_len_num)
  local header_sum_low = (math.fmod((((frame_header_num + single_turn_cmd_v1_num) + default_motor_id_num) + data_len_num), 256))
  append_list(frame_list, header_sum_low)
  local direction_str = concat_string("0x", number_to_str(direction, 16))
  local angle_str = concat_string("0x", number_to_str(angleIncrement, 16))
  info(angle_str)
  local low_angle_str = concat_string("0x", number_to_str((math.fmod(str_to_number(angle_str, 16), 256)), 16))
  local high_angle_str = concat_string("0x", number_to_str(math.floor((str_to_number(angle_str, 16) / 256)), 16))
  local angleControl_str = number_to_str((str_to_number(angle_str, 16) / 65532), 16)
  local direction_num = str_to_number(direction_str, 10)
  local low_angle_num = str_to_number(low_angle_str, 10)
  local high_angle_num = str_to_number(high_angle_str, 10)
  append_list(frame_list, direction_num)
  append_list(frame_list, low_angle_num)
  append_list(frame_list, high_angle_num)
  append_list(frame_list, angleControl_str)
  local data_sum_low = (math.fmod((((direction_num + low_angle_num) + high_angle_num) + str_to_number(angleControl_str, 10)), 256))
  append_list(frame_list, data_sum_low)
  return frame_list
end

local connected = connect()
if connected then
    local cmd_list = send_angle(300.0, 0)
    info(cmd_list)
    serial_port_send(1, cmd_list)
    local resp = serial_port_recv(1, 16)
    info(resp)
    serial_port_close(1)
end
