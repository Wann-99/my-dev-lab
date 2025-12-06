
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

local function enter_silent_mode()
  --[[ 进入静默模式 ]]
  info("Loss connection")
  while not socket_open(1, "192.168.2.112", 30000) do
      if get_system_state("isFault") then
          clear_fault()
      end
      wait_ms(30)
      ::loop_label_1::
  end
end

local cam_intr_params = "919.49866 918.7968 648.15015 375.07938 1280 720 0.001"
local cam_extr_params = "0 0 0 0 0 0"
local obj_name = "Conveyor-SerialPort-1/Vision"
local recv_text = ""
if socket_open(1, "192.168.2.112", 30000) then
    local socket_connect = socket_connected(1)
    if socket_connect then
        info("Connection success")
    end
    while socket_connect do
        if not socket_send(1, "Trigger") then
            info("Send fail")
            break
        end
        recv_text = socket_recv(1)
        if (recv_text ~= "") then
            local obj_param = split_string(recv_text, ";")
            local obj_value = get_list(obj_param, 1)
            obj_pool_update(obj_name, 8, obj_value, cam_intr_params, cam_extr_params, "flange")
        end
        wait_ms(100)
        ::loop_label_2::
    end
else
    enter_silent_mode()
end
