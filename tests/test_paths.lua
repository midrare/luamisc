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
    luaunit.assertEquals(paths.dirname('\\foo\\bar\\'), '\\foo')
    luaunit.assertEquals(paths.dirname('\\foo/bar\\'), '\\foo')
    luaunit.assertEquals(paths.dirname('C:/foo/bar/'), 'C:/foo')
    luaunit.assertEquals(paths.dirname('C:\\foo\\bar\\'), 'C:\\foo')
    luaunit.assertEquals(paths.dirname('C:/foo\\bar/'), 'C:/foo')

    luaunit.assertEquals(paths.dirname('/foo/bar/baz.txt'), '/foo/bar')
    luaunit.assertEquals(paths.dirname('\\foo\\bar\\baz.txt'), '\\foo\\bar')
    luaunit.assertEquals(paths.dirname('/foo\\bar/baz.txt'), '/foo\\bar')
    luaunit.assertEquals(paths.dirname('C:/foo/bar/baz.txt'), 'C:/foo/bar')
    luaunit.assertEquals(paths.dirname('C:\\foo\\bar\\baz.txt'), 'C:\\foo\\bar')
    luaunit.assertEquals(paths.dirname('C:\\foo/bar\\baz.txt'), 'C:\\foo/bar')

    luaunit.assertEquals(paths.dirname('foo/bar/'), 'foo')
    luaunit.assertEquals(paths.dirname('foo\\bar\\'), 'foo')
    luaunit.assertEquals(paths.dirname('foo/bar\\'), 'foo')
    luaunit.assertEquals(paths.dirname('foo/bar/'), 'foo')
    luaunit.assertEquals(paths.dirname('foo\\bar\\'), 'foo')
    luaunit.assertEquals(paths.dirname('foo\\bar/'), 'foo')

    luaunit.assertEquals(paths.dirname('foo/bar/baz.txt'), 'foo/bar')
    luaunit.assertEquals(paths.dirname('foo\\bar\\baz.txt'), 'foo\\bar')
    luaunit.assertEquals(paths.dirname('foo\\bar/baz.txt'), 'foo\\bar')
    luaunit.assertEquals(paths.dirname('foo/bar/baz.txt'), 'foo/bar')
    luaunit.assertEquals(paths.dirname('foo\\bar\\baz.txt'), 'foo\\bar')
    luaunit.assertEquals(paths.dirname('foo/bar\\baz.txt'), 'foo/bar')
end

function TestPathUtils:test_filestem()
    luaunit.assertEquals(paths.filestem('name'), 'name')
    luaunit.assertEquals(paths.filestem('name.txt'), 'name')
    luaunit.assertEquals(paths.filestem('my.file.name.ext'), 'my.file.name')

    luaunit.assertEquals(paths.filestem('./name.txt'), 'name')
    luaunit.assertEquals(paths.filestem('.\\name.txt'), 'name')

    luaunit.assertEquals(paths.filestem('/name.txt'), 'name')
    luaunit.assertEquals(paths.filestem('/foo/name.txt'), 'name')
    luaunit.assertEquals(paths.filestem('/foo/bar/name.txt'), 'name')

    luaunit.assertEquals(paths.filestem('C:\\name.txt'), 'name')
    luaunit.assertEquals(paths.filestem('C:\\foo\\name.txt'), 'name')
    luaunit.assertEquals(paths.filestem('C:\\foo\\bar\\name.txt'), 'name')
end

function TestPathUtils:test_parents()
    luaunit.assertEquals(paths.parents(''), {})
    luaunit.assertEquals(paths.parents('/'), {})
    luaunit.assertEquals(paths.parents('\\'), {})
    luaunit.assertEquals(paths.parents('C:/'), {})
    luaunit.assertEquals(paths.parents('C:\\'), {})

    luaunit.assertEquals(paths.parents('a.txt'), {})
    luaunit.assertEquals(paths.parents('a'), {})
    luaunit.assertEquals(paths.parents('./a.txt'), {'./'})
    luaunit.assertEquals(paths.parents('./a'), {'./'})

    luaunit.assertEquals(paths.parents('/a/b/c.txt'), {'/a/b', '/a', '/'})
    luaunit.assertEquals(paths.parents('/a/b/c'), {'/a/b', '/a', '/'})
    luaunit.assertEquals(paths.parents('/a/b/c/'), {'/a/b', '/a', '/'})
    luaunit.assertEquals(paths.parents('C:/a/b/c.o'), {'C:/a/b', 'C:/a', 'C:/'})
    luaunit.assertEquals(paths.parents('C:/a/b/c'), {'C:/a/b', 'C:/a', 'C:/'})
    luaunit.assertEquals(paths.parents('C:/a/b/c/'), {'C:/a/b', 'C:/a', 'C:/'})

    luaunit.assertEquals(paths.parents('/a\\b/c.txt'), {'/a\\b', '/a', '/'})
    luaunit.assertEquals(paths.parents('/a\\b/c'), {'/a\\b', '/a', '/'})
    luaunit.assertEquals(paths.parents('/a\\b/c/'), {'/a\\b', '/a', '/'})
    luaunit.assertEquals(paths.parents('C:/a\\b/c.o'), {'C:/a\\b', 'C:/a', 'C:/'})
    luaunit.assertEquals(paths.parents('C:/a\\b/c'), {'C:/a\\b', 'C:/a', 'C:/'})
    luaunit.assertEquals(paths.parents('C:/a\\b/c/'), {'C:/a\\b', 'C:/a', 'C:/'})
end

function TestPathUtils:test_fileext()
    luaunit.assertEquals(paths.fileext('/foo/bar/baz.txt'), '.txt')
    luaunit.assertNil(paths.fileext('/foo/bar/baz'))
end

function TestPathUtils:test_normpath()
    luaunit.assertEquals(paths.normpath('foo//bar/./baz/../qux'), 'foo/bar/qux')
    luaunit.assertEquals(paths.normpath(''), '.')
end

function TestPathUtils:test_isabs()
    luaunit.assertTrue(paths.isabs('/usr/bin'))
    luaunit.assertFalse(paths.isabs('usr/bin'))
end

function TestPathUtils:test_abspath()
    luaunit.assertEquals(paths.abspath('c/foo.txt', '/a/b'), '/a/b/c/foo.txt')
end

function TestPathUtils:test_join()
    luaunit.assertEquals(paths.join('/a', 'b/', '/c'), '/a/b/c')
    luaunit.assertEquals(paths.join('C:/a', 'b/', '/c'), 'C:/a/b/c')
    luaunit.assertEquals(paths.join('C:/a', 'b\\', '/c'), 'C:/a/b\\c')
    luaunit.assertStrMatches(paths.join('a', '', 'b'), 'a[\\/]b')
end

function TestPathUtils:test_relpath()
    luaunit.assertEquals(
      paths.relpath('/home/user/file.txt', '/home/user', false),
      'file.txt'
    )
    luaunit.assertEquals(
      paths.relpath('/home/user/file.txt', '/home/user/project', false),
      '../file.txt'
    )
    luaunit.assertEquals(
      paths.relpath('/home/user/other/file.txt', '/home/user/project', false),
      '../other/file.txt'
    )
end

function TestPathUtils:test_canonical_ext()
    luaunit.assertEquals(paths.canonical_ext(' TXT'), '.txt')
    luaunit.assertNil(paths.canonical_ext(nil))
    luaunit.assertNil(paths.canonical_ext(''))
end

local ret = luaunit.LuaUnit.run()
if not vim or not vim.fn then
  os.exit(ret)
end

