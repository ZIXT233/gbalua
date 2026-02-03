local ArrayBuffer = {}


ArrayBuffer.new = function(byteLength)
    local array = {}
    array.byteLength = byteLength
    for i = 0, (byteLength>>2)-1 do
        array[i] = 0
    end
    return array
end

return ArrayBuffer