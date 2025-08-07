
function join_list(list, delim)
  local str = table.concat(list, delim)
  return str
end


function append_list(list, value)
     table.insert(list, (#list+1), value)
     return list
end


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


function concat_string(...)
    local args = {...}
    return table.concat(args, "")
end

local function calculate_position(base_x, base_y, base_z, base_rx, base_ry, base_rz, rows, cols, layers, x_offset, y_offset, z_offset, reference_pose)
  --[[ 
  
  根据基坐标、行列层数和三维偏移量计算所有点位坐标（空间点阵）
  
   ]]
  local points = {}
  for k=1,layers,1 do
      for i=1,rows,1 do
          for j=1,cols,1 do
              local x = (base_x + ((j - 1) * x_offset))
              local y = (base_y + ((i - 1) * y_offset))
              local z = (base_z + ((k - 1) * z_offset))
              local rx = base_rx
              local ry = base_ry
              local rz = base_rz
              local str_pose = split_string(concat_string(x, ",", y, ",", z, ",", rx, ",", ry, ",", rz, ",", "WORLD", ",", "WORLD_ORIGIN", ",", reference_pose), ",")
              append_list(points, str_pose)
              ::loop_label_3::
          end
          ::loop_label_2::
      end
      ::loop_label_1::
  end
  return points
end

if modbus_tcp_open(1, "192.168.2.100", 502) then
    local base_x = get_global_var("BaseX")
    local base_y = get_global_var("BaseY")
    local base_z = get_global_var("BaseZ")
    local row = get_global_var("Row")
    local col = get_global_var("Col")
    local layer = get_global_var("Layer")
    local row_spacing = get_global_var("RowSpacing")
    local col_spacing = get_global_var("ColSpacing")
    local layer_spacing = get_global_var("LayerSpacing")
    local reference_pose = get_global_var("ReferencePose")
    local reference_pose_list = join_list(reference_pose, ",")
    local confirm = (row >= 1) and (col >= 1) and (layer >= 1)
    if not confirm then
        info("Rows, cols and layers must be non-negative integers！！！")
        info("请确认 行、列 和 层 的值，row>=1 && col>=1 && layer>=1")
        modbus_tcp_close(1)
        return false
    end
    local arr_row_data = calculate_position(base_x, base_y, base_z, 0, 180, 0, row, col, layer, row_spacing, col_spacing, layer_spacing, reference_pose_list)
    if (#arr_row_data == 0) then
        local a_coord = {"0,0,0,0,180,0,WORLD,WORLD_ORIGIN,0,-40,0,90,0,40,0,0,0,0,0,0,0"}
        local arr_coord = {}
        for _, coord in ipairs(a_coord) do
            append_list(arr_coord, split_string(coord, ","))
            ::loop_label_4::
        end
        set_global_var("ArrData", arr_coord)
        info("程序异常--终止")
        modbus_tcp_close(1)
    else

    end
    set_global_var("ArrData", arr_row_data)
    modbus_tcp_close(1)
end
