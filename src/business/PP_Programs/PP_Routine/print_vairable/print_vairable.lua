
function concat_string(...)
    local args = {...}
    return table.concat(args, "")
end


function get_list(list, index)
  assert((#list ~= 0), "empty list")
  assert((type(index) == "number"), "index must be a number")
  assert((index >= 0 and index <= #list-1), "index out of range")
  return list[index + 1]
end

local function enter_silent_mode()
  while not (get_io("GPIOSystem", "gpioOut15") == 1) do
      if get_system_state("isFault") then
          clear_fault()
      end
      wait_ms(30)
      ::loop_label_1::
  end
end

while true do
    if (get_io("GPIOSystem", "gpioOut15") == 1) then
        local pick_pose = get_global_var("PickPose_G")
        local obj_x = get_list(pick_pose, 0)
        local obj_y = get_list(pick_pose, 1)
        local obj_z = get_list(pick_pose, 2)
        local obj_rx = get_list(pick_pose, 3)
        local obj_ry = get_list(pick_pose, 4)
        local obj_rz = get_list(pick_pose, 5)
        local pose = concat_string("PickPose: ", obj_x, ", ", obj_y, ", ", obj_z, ", ", obj_rx, ", ", obj_ry, ", ", obj_rz)
        info(pose)
        wait_ms(1000)
    else
        enter_silent_mode()
    end
    ::loop_label_2::
end
