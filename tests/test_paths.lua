local require = (function()
  local d = (function()
    local cwd=((vim and vim.loop and vim.loop.cwd())
      or io.popen((package.config:sub(1,1)=='/'and'pwd'or'echo %cd%')):read'*l')
      :gsub('[\\/]+$',''):gsub('[\\/]','/')
    local p=(debug.getinfo(1).source):gsub('^@',''):match('.*[\\/]') or ''
    if p:match('^%a:[\\/]') or p:match('^[\\/]') then return p end
    return cwd..'/'..p
  end)()
  local require_ = require
  return function(m, opts)
    opts = opts or {}; if opts.force then package.loaded[m] = nil end
    local old=package.path; package.path=d..'/?.lua;'..d..'/../?.lua;'
    local ret = require_(m); package.path=old
    return ret
  end
end)()

local luaunit = require('luaunit', { force = true })
local paths = require("paths", { force = true })

TestPathUtils = {}

function TestPathUtils:test_sep()
    luaunit.assertStrMatches(paths.sep(), '[\\/]')
end

function TestPathUtils:test_basename()
    luaunit.assertEquals(paths.basename('.'), '.')
    luaunit.assertEquals(paths.basename('..'), '..')
    luaunit.assertEquals(paths.basename('./'), './')
    luaunit.assertEquals(paths.basename('.\\'), '.\\')
    luaunit.assertEquals(paths.basename('/'), '/')
    luaunit.assertEquals(paths.basename('\\'), '\\')
    luaunit.assertEquals(paths.basename('C:/'), 'C:/')
    luaunit.assertEquals(paths.basename('C:\\'), 'C:\\')

    luaunit.assertEquals(paths.basename('foo.txt'), 'foo.txt')
    luaunit.assertEquals(paths.basename('./foo.txt'), 'foo.txt')
    luaunit.assertEquals(paths.basename('.\\foo.txt'), 'foo.txt')

    luaunit.assertEquals(paths.basename('/foo.txt'), 'foo.txt')
    luaunit.assertEquals(paths.basename('\\foo.txt'), 'foo.txt')
    luaunit.assertEquals(paths.basename('C:/foo.txt'), 'foo.txt')
    luaunit.assertEquals(paths.basename('C:\\foo.txt'), 'foo.txt')

    luaunit.assertEquals(paths.basename('/foo/'), 'foo')
    luaunit.assertEquals(paths.basename('\\foo\\'), 'foo')
    luaunit.assertEquals(paths.basename('\\foo/'), 'foo')
    luaunit.assertEquals(paths.basename('C:/foo/'), 'foo')
    luaunit.assertEquals(paths.basename('C:\\foo\\'), 'foo')
    luaunit.assertEquals(paths.basename('C:/foo\\'), 'foo')

    luaunit.assertEquals(paths.basename('/foo/bar/'), 'bar')
    luaunit.assertEquals(paths.basename('\\foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.basename('\\foo/bar\\'), 'bar')
    luaunit.assertEquals(paths.basename('C:/foo/bar/'), 'bar')
    luaunit.assertEquals(paths.basename('C:\\foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.basename('C:/foo\\bar/'), 'bar')

    luaunit.assertEquals(paths.basename('/foo/bar/baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('\\foo\\bar\\baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('/foo\\bar/baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('C:/foo/bar/baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('C:\\foo\\bar\\baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('C:\\foo/bar\\baz.txt'), 'baz.txt')

    luaunit.assertEquals(paths.basename('foo/bar/'), 'bar')
    luaunit.assertEquals(paths.basename('foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.basename('foo/bar\\'), 'bar')
    luaunit.assertEquals(paths.basename('foo/bar/'), 'bar')
    luaunit.assertEquals(paths.basename('foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.basename('foo\\bar/'), 'bar')

    luaunit.assertEquals(paths.basename('foo/bar/baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('foo\\bar\\baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('foo\\bar/baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('foo/bar/baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('foo\\bar\\baz.txt'), 'baz.txt')
    luaunit.assertEquals(paths.basename('foo/bar\\baz.txt'), 'baz.txt')
end

function TestPathUtils:test_dirname()
    luaunit.assertEquals(paths.dirname('.'), '.')
    luaunit.assertEquals(paths.dirname('..'), '..')
    luaunit.assertEquals(paths.dirname('./'), './')
    luaunit.assertEquals(paths.dirname('.\\'), '.\\')
    luaunit.assertEquals(paths.dirname('/'), '/')
    luaunit.assertEquals(paths.dirname('\\'), '\\')
    luaunit.assertEquals(paths.dirname('C:/'), 'C:/')
    luaunit.assertEquals(paths.dirname('C:\\'), 'C:\\')

    luaunit.assertEquals(paths.dirname('foo.txt'), '')
    luaunit.assertEquals(paths.dirname('./foo.txt'), './')
    luaunit.assertEquals(paths.dirname('.\\foo.txt'), '.\\')

    luaunit.assertEquals(paths.dirname('/foo.txt'), '/')
    luaunit.assertEquals(paths.dirname('\\foo.txt'), '\\')
    luaunit.assertEquals(paths.dirname('C:/foo.txt'), 'C:/')
    luaunit.assertEquals(paths.dirname('C:\\foo.txt'), 'C:\\')

    luaunit.assertEquals(paths.dirname('/foo/'), '/')
    luaunit.assertEquals(paths.dirname('\\foo\\'), '\\')
    luaunit.assertEquals(paths.dirname('\\foo/'), '\\')
    luaunit.assertEquals(paths.dirname('C:/foo/'), 'C:/')
    luaunit.assertEquals(paths.dirname('C:\\foo\\'), 'C:\\')
    luaunit.assertEquals(paths.dirname('C:/foo\\'), 'C:/')

    luaunit.assertEquals(paths.dirname('/foo/bar/'), '/foo')
    luaunit.assertEquals(paths.dirname('\\foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.dirname('\\foo/bar\\'), 'bar')
    luaunit.assertEquals(paths.dirname('C:/foo/bar/'), 'bar')
    luaunit.assertEquals(paths.dirname('C:\\foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.dirname('C:/foo\\bar/'), 'bar')

    luaunit.assertEquals(paths.dirname('/foo/bar/baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('\\foo\\bar\\baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('/foo\\bar/baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('C:/foo/bar/baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('C:\\foo\\bar\\baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('C:\\foo/bar\\baz.txt'), 'bar')

    luaunit.assertEquals(paths.dirname('foo/bar/'), '/foo')
    luaunit.assertEquals(paths.dirname('foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.dirname('foo/bar\\'), 'bar')
    luaunit.assertEquals(paths.dirname('foo/bar/'), 'bar')
    luaunit.assertEquals(paths.dirname('foo\\bar\\'), 'bar')
    luaunit.assertEquals(paths.dirname('foo\\bar/'), 'bar')

    luaunit.assertEquals(paths.dirname('foo/bar/baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('foo\\bar\\baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('foo\\bar/baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('foo/bar/baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('foo\\bar\\baz.txt'), 'bar')
    luaunit.assertEquals(paths.dirname('foo/bar\\baz.txt'), 'bar')
end

local ret = luaunit.LuaUnit.run()
if not vim or not vim.fn then
  os.exit(ret)
end

