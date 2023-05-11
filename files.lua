local absname, _ = ...
local basename = absname:match('([^%.]+)$')
local parent = absname:gsub('%.[^%.]+$', '')
return require(parent .. '.lua.luamisc.' .. basename)
