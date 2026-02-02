local ClassUtils = {}

function ClassUtils.class(classname, super)
    local superType = type(super)
    assert(super == nil or superType == "table", "super must be a table or nil")

    local cls
    if super then
        cls = {}
        setmetatable(cls, { __index = super })
        cls.super = super
    else
        cls = {}
    end

    cls.__cname = classname
    cls.__index = cls

    function cls.new(...)
        local instance = setmetatable({}, cls)
        -- 只调用当前类的 ctor（不自动调用父类！）
        if cls.ctor then
            cls.ctor(instance, ...)
        end
        return instance
    end

    return cls
end

return ClassUtils