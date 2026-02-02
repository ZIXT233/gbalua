-- GBA 显示窗口：使用 moongl + moonglfw，参考 moongl_example/screen.lua
-- 分辨率 240x160，canvas.data 为 240*160*4 的扁平数组（RGBA，可为 0-based 或 1-based）

local screen = {}

local gl = require("moongl")
local glfw = require("moonglfw")

local W, H = 240, 160  -- GBA 分辨率

local vertex_shader = [[
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;
out vec2 TexCoord;
void main()
{
    gl_Position = vec4(aPos.xy, 0.0, 1.0);
    TexCoord = aTexCoord;
}
]]

local fragment_shader = [[
#version 330 core
in vec2 TexCoord;
out vec4 FragColor;
uniform sampler2D screenTexture;
void main()
{
    vec2 flippedCoord = vec2(TexCoord.x, 1.0 - TexCoord.y);
    FragColor = texture(screenTexture, flippedCoord);
}
]]

local glfw_inited = false

local function ensure_glfw_inited()
  if not glfw_inited then
    glfw_inited = true
  end
end

-- 创建新的 GBA 屏幕实例
-- scale: 窗口缩放倍数；title_prefix: 窗口标题前缀
function screen.new(scale, title_prefix)
  ensure_glfw_inited()

  local instance = {
    scale = tonumber(scale) or 4,
    window = nil,
    texture = nil,
    shader_program = nil,
    vao = nil,
    vbo = nil,
    ebo = nil,
    title_prefix = title_prefix or "GBA",
  }

  if instance.scale < 1 then instance.scale = 1 end

  glfw.version_hint(3, 3, 'core')

  instance.window = glfw.create_window(
    W * instance.scale,
    H * instance.scale,
    instance.title_prefix
  )

  glfw.make_context_current(instance.window)
  gl.init()
  glfw.swap_interval(0)

  glfw.set_framebuffer_size_callback(instance.window, function(window, width, height)
    gl.viewport(0, 0, width, height)
  end)

  local vsh, fsh
  instance.shader_program, vsh, fsh = gl.make_program_s({ vertex = vertex_shader, fragment = fragment_shader })
  gl.delete_shaders(vsh, fsh)

  local vertices = {
    1.0,  1.0,  1.0, 1.0,
    1.0, -1.0,  1.0, 0.0,
   -1.0, -1.0,  0.0, 0.0,
   -1.0,  1.0,  0.0, 1.0,
  }
  local indices = { 0, 1, 3, 1, 2, 3 }

  instance.vao = gl.gen_vertex_arrays()
  instance.vbo, instance.ebo = gl.gen_buffers(2)
  gl.bind_vertex_array(instance.vao)
  gl.bind_buffer('array', instance.vbo)
  gl.buffer_data('array', gl.pack('float', vertices), 'static draw')
  gl.bind_buffer('element array', instance.ebo)
  gl.buffer_data('element array', gl.pack('uint', indices), 'static draw')
  gl.vertex_attrib_pointer(0, 2, 'float', false, 4 * gl.sizeof('float'), 0)
  gl.enable_vertex_attrib_array(0)
  gl.vertex_attrib_pointer(1, 2, 'float', false, 4 * gl.sizeof('float'), 2 * gl.sizeof('float'))
  gl.enable_vertex_attrib_array(1)
  gl.unbind_buffer('array')
  gl.unbind_vertex_array()

  instance.texture = gl.gen_textures()
  gl.bind_texture('2d', instance.texture)
  gl.texture_parameter('2d', 'wrap s', 'clamp to edge')
  gl.texture_parameter('2d', 'wrap t', 'clamp to edge')
  gl.texture_parameter('2d', 'min filter', 'nearest')
  gl.texture_parameter('2d', 'mag filter', 'nearest')
  gl.texture_storage('2d', 1, 'rgba8', W, H)
  gl.unbind_texture('2d')

  -- data: canvas.data，240*160*4 扁平数组，RGBA。软件渲染器使用 0-based 索引。
  function instance:Update(data)
    if not data or type(data) ~= "table" then
      return
    end
    glfw.make_context_current(self.window)
    local fb_width, fb_height = glfw.get_framebuffer_size(self.window)
    gl.viewport(0, 0, fb_width, fb_height)

    local n = W * H * 4
    local packed
    -- 兼容 0-based（data[0]..data[n-1]）与 1-based（data[1]..data[n]）
    if data[0] ~= nil then
      local t = {}
      for i = 0, n - 1 do
        t[i + 1] = data[i]
      end
      packed = gl.pack('ubyte', t)
    else
      packed = gl.pack('ubyte', data)
    end

    gl.bind_texture('2d', self.texture)
    gl.texture_sub_image('2d', 0, 'rgba', 'ubyte', packed, 0, 0, W, H)

    gl.clear_color(0.0, 0.0, 0.0, 1.0)
    gl.clear('color')
    gl.use_program(self.shader_program)
    gl.active_texture(0)
    gl.bind_texture('2d', self.texture)
    gl.bind_vertex_array(self.vao)
    gl.draw_elements('triangles', 6, 'uint', 0)
    gl.unbind_vertex_array()
    gl.unbind_texture('2d')
    glfw.swap_buffers(self.window)
  end

  function instance:SetTitle(title)
    if self.window then
      glfw.set_window_title(self.window, title)
    end
  end

  function instance:GetWindow()
    return self.window
  end

  function instance:Quit()
    if self.texture then
      gl.delete_textures(self.texture)
      self.texture = nil
    end
    if self.shader_program then
      gl.delete_program(self.shader_program)
      self.shader_program = nil
    end
    if self.vao then
      gl.delete_vertex_arrays(self.vao)
      self.vao = nil
    end
    if self.vbo then
      gl.delete_buffers(self.vbo)
      self.vbo = nil
    end
    if self.ebo then
      gl.delete_buffers(self.ebo)
      self.ebo = nil
    end
    if self.window then
      glfw.destroy_window(self.window)
    end
    self.window = nil
  end

  return instance
end

return screen
