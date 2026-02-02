local ArrayBuffer = {}


ArrayBuffer.new = function(byteLength)
    return {byteLength = byteLength}
end

return ArrayBuffer