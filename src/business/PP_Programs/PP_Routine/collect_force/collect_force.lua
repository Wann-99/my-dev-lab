
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

if socket_open(1, "192.168.3.220", 20000) then
    info(socket_send(1, "Hi, Sunseed!"))
    while true do
        local Force_Flag = get_global_var("starForce")
        if Force_Flag then
            info("开始采集")
            while Force_Flag do
                local tcpPose = get_system_state("tcpPose")
                local posZ = get_list(tcpPose, 2)
                local Fz = get_system_state("CartesianForceZ")
                local all_data = concat_string(Fz, ",", posZ)
                socket_send(1, all_data)
                if not get_global_var("starForce") then
                    info("停止采集")
                    break
                end
                ::loop_label_2::
            end
        end
        if not socket_connected(1) then
            info("socket connected field")
            break
        end
        ::loop_label_1::
    end
end
socket_close(1)
