
function split_string(input, delim)
  local t = {}
  local pos = 1
  while true do
    next_delim = string.find(input, delim, pos)
    if next_delim == nil then
      table.insert(t, string.sub(input, pos))
      break
    else
      table.insert(t, string.sub(input, pos, next_delim-1))
      pos = next_delim + #delim
    end
  end
  return t
end


function get_list(list, index)
  assert((#list ~= 0), "empty list")
  assert((type(index) == "number"), "index must be a number")
  assert((index >= 0 and index <= #list-1), "index out of range")
  return list[index + 1]
end


function concat_string(...)
    local args = {...}
    return table.concat(args, "")
end


local function update_global_var_coord(var_name, new_tcp_pos, new_coordinate, new_ref_joint_positions, new_ext_axis, unit)
  assert((var_name ~= ""), "var name must be set")
  local new_var_value = get_global_var(var_name)
  if new_tcp_pos then
      assert((#new_tcp_pos == 6), "new_tcp_pos must 6 items")
      for idx=1,3,1 do
          if (new_tcp_pos[idx] ~= "") and (unit == "millimeter") then
              new_var_value[idx] = (new_tcp_pos[idx] / 1000)
          elseif (new_tcp_pos[idx] ~= "") and (unit == "meter") then
              new_var_value[idx] = new_tcp_pos[idx]
          end
      end
      for idx=4,6,1 do
          if (new_tcp_pos[idx] ~= "") then
              new_var_value[idx] = new_tcp_pos[idx]
          end
      end
  end
  if new_coordinate then
      assert((#new_coordinate == 2), "new_coordinate must 2 items")
      for idx=1,2,1 do
          if (new_coordinate[idx] ~= "") then
              new_var_value[(idx + 6)] = new_coordinate[idx]
          end
      end
  end
  if new_ref_joint_positions then
      assert((#new_ref_joint_positions == 7), "new_ref_joint_positions must 7 items")
      for idx=1,7,1 do
          if (new_ref_joint_positions[idx] ~= "") then
              new_var_value[(idx + 8)] = new_ref_joint_positions[idx]
          end
      end
  end
  if new_ext_axis then
      assert((#new_ext_axis == 6), "new_ext_axis must 6 items")
      for idx=1,6,1 do
          if (new_ext_axis[idx] ~= "") then
              new_var_value[(idx + 15)] = new_ext_axis[idx]
          end
      end
  end
  set_global_var(var_name, new_var_value)
end

local function enter_silent_mode()
  --[[ 进入静默模式 ]]
  info("[Vision] Enter Silent Mode")
  while not socket_open(1, "192.168.2.50", 30000) do
      if get_system_state("isFault") then
          clear_fault()
      end
      wait_ms(30)
      ::loop_label_1::
  end
end

local function determine_workspace(obj_x, obj_y, obj_z)
  --[[ 
  
  判断目标是否在工作空间内
  
  :return: True -> 超出工作空间, False -> 在工作空间内
  
   ]]
  local cord1 = get_global_var("WorkSpace1")
  local cord2 = get_global_var("WorkSpace2")
  local cord1_x = get_list(cord1, 0)
  local cord1_y = get_list(cord1, 1)
  local cord1_z = get_list(cord1, 2)
  local cord2_x = get_list(cord2, 0)
  local cord2_y = get_list(cord2, 1)
  local cord2_z = get_list(cord2, 2)
  if ((cord1_x <= obj_x and obj_x <= cord2_x) and (cord1_y <= obj_y and obj_y <= cord2_y) and (cord1_z <= obj_z and obj_z <= cord2_z)) then
      return false
  else
      return true
  end
end

local cam_intr_params = "691.6986083984375, 691.6787109375, 642.67529296875, 361.54461669921875, 1280, 720, 0.001"
local cam_extr_params = "0.34559894 -0.41461863 0.83664676 -0.03670967 3.1249094 -0.00345758"
local obj_name = "Conveyor-SerialPort-1/Vision"
local recv_text = ""
while true do
    if socket_open(1, "192.168.2.50", 30000) then
        info("[Vision] is connected")
        while true do
            if not socket_connected(1) then
                info("[Vision] Loss connection")
                break
            end
            if not socket_send(1, "Trigger") then
                info("[Vision] Send fail")
                break
            end
            recv_text = socket_recv(1)
            if (recv_text ~= "") then
                local obj_param = split_string(recv_text, ";")
                local obj_value = obj_param[1]
                local obj_str = split_string(obj_value, " ")
                local obj_x = str_to_number(get_list(obj_str, 0), 10)
                local obj_y = str_to_number(get_list(obj_str, 1), 10)
                local obj_z = str_to_number(get_list(obj_str, 2), 10)
                local obj_rx = str_to_number(get_list(obj_str, 3), 10)
                local obj_ry = str_to_number(get_list(obj_str, 4), 10)
                local obj_rz = str_to_number(get_list(obj_str, 5), 10)
                local obj_flag = determine_workspace(obj_x, obj_y, obj_z)
                if not obj_flag then
                    obj_pool_update(obj_name, 8, obj_value, cam_intr_params, cam_extr_params, "flange")
                else
                    info("[Vision] Out of workspace")
                    local vision_value = concat_string("[Vision] Obj value: ", obj_value)
                    info(vision_value)
                    update_global_var_coord("RecvCoord", {obj_x, obj_y, obj_z, obj_rx, obj_ry, obj_rz}, {"WORLD", "WORLD_ORIGIN"}, {0, -40, 0, 90, 0, 40, 0}, {1, 2, 3, 4, 5, 6}, "meter")
                end
            end
            ::loop_label_3::
        end
    else
        enter_silent_mode()
    end
    ::loop_label_2::
end
