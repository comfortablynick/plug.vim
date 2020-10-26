" Author:  Nick Murphy (comfortablynick@gmail.com)
" URL:     github.com/comfortablynick/plugpackager.vim
" Version: 1.0
" License: MIT
" ---------------------------------------------------------------------
let s:augroup_name = 'plug'

function plug#begin(opts)
    let s:packager_init_opts = a:opts
    let s:lazy = { 'ft': {}, 'map': {}, 'cmd': {} }
    let s:repos = {}
    let s:pack_dir = get(s:, 'packager_init_opts', expand('$XDG_DATA_HOME/nvim/site')..'/pack/packager')

    " Set up and clear augroup
    execute 'augroup' s:augroup_name '| autocmd! | augroup END'
    call s:setup_command()
endfunction

function plug#end()
    for [l:name, l:cmds] in items(s:lazy.cmd)
        for l:cmd in l:cmds
            execute printf(
                \ "command! -nargs=* -range -bang %s packadd %s | call s:do_cmd('%s', \"<bang>\", <line1>, <line2>, <q-args>)",
                \ l:cmd,
                \ l:name,
                \ l:cmd,
                \ )
        endfor
    endfor

    for [l:name, l:maps] in items(s:lazy.map)
        for l:map in l:maps
            for [l:mode, l:map_prefix, l:key_prefix] in
                \ [['i', '<C-O>', ''], ['n', '', ''], ['v', '', 'gv'], ['o', '', '']]
                execute printf(
                    \ '%snoremap <silent> %s %s:<C-U>packadd %s<bar>call <SID>do_map(%s, %s, "%s")<CR>',
                    \ l:mode,
                    \ l:map,
                    \ l:map_prefix,
                    \ l:name,
                    \ string(l:map),
                    \ l:mode !=# 'i',
                    \ l:key_prefix,
                    \ )
            endfor
        endfor
    endfor

    runtime! OPT ftdetect/**/*.vim
    runtime! OPT after/ftdetect/**/*.vim

    for [l:name, l:fts] in items(s:lazy.ft)
        execute 'autocmd' s:augroup_name 'FileType' l:fts 'packadd' l:name
    endfor
endfunction

function plug#add(repo, ...)
    let l:opts = get(a:000, 0, {})
    let l:name = substitute(a:repo, '^.*/', '', '')

    " `for` and `on` implies optional
    if has_key(l:opts, 'for') || has_key(l:opts, 'on')
        let l:opts['type'] = 'opt'
    endif

    if has_key(l:opts, 'for')
        let l:ft = type(l:opts.for) == v:t_list ? join(l:opts.for, ',') : l:opts.for
        let s:lazy.ft[l:name] = l:ft
    endif

    if has_key(l:opts, 'on')
        let l:cmds = type(l:opts.on) ==# v:t_list ? l:opts.on : [l:opts.on]
        for l:cmd in l:cmds
            if l:cmd =~? '^<Plug>.\+'
                if empty(mapcheck(l:cmd)) && empty(mapcheck(l:cmd, 'i'))
                    call s:assoc(s:lazy.map, l:name, l:cmd)
                endif
            elseif l:cmd =~# '^[A-Z]'
                if exists(':'.l:cmd) != 2
                    call s:assoc(s:lazy.cmd, l:name, l:cmd)
                endif
            else
                call s:err('Invalid `on` option: '.l:cmd.
                    \ '. Should start with an uppercase letter or `<Plug>`.')
            endif
        endfor
    endif

    let s:repos[a:repo] = l:opts
endfunction

function plug#has_plugin(plugin)
    return index(s:get_plugin_list(), a:plugin) != -1
endfunction

function s:assoc(dict, key, val)
    let a:dict[a:key] = add(get(a:dict, a:key, []), a:val)
endfunction

function s:err(msg)
    echohl ErrorMsg
    echom '[plugpackager]' a:msg
    echohl None
endfunction

function s:do_cmd(cmd, bang, start, end, args)
    execute printf('%s%s%s %s', (a:start == a:end ? '' : (a:start.','.a:end)), a:cmd, a:bang, a:args)
endfunction

function s:do_map(map, with_prefix, prefix)
    let l:extra = ''
    while 1
        let l:c = getchar(0)
        if l:c == 0
            break
        endif
        let l:extra .= nr2char(l:c)
    endwhile

    if a:with_prefix
        let l:prefix = v:count ? v:count : ''
        let l:prefix .= '"'.v:register.a:prefix
        if mode(1) ==# 'no'
            if v:operator ==# 'c'
                let l:prefix = "\<esc>" . a:prefix
            endif
            let l:prefix .= v:operator
        endif
        call feedkeys(a:prefix, 'n')
    endif
    call feedkeys(substitute(a:map, '^<Plug>', "\<Plug>", '') . l:extra)
endfunction

function s:setup_command()
    command! -bar -nargs=+ Plug call plug#add(<args>)

    command!       PlugInstall call s:init_packager() | call packager#install()
    command! -bang PlugUpdate  call s:init_packager() | call packager#update({'force_hooks': '<bang>'})
    command!       PlugClean   call s:init_packager() | call packager#clean()
    command!       PlugStatus  call s:init_packager() | call packager#status()
    " TODO: make sure this works with packager
    command! -nargs=1 -complete=customlist,s:plugin_dir_complete PlugDisable call s:disable_plugin(<q-args>)
endfunction

function s:init_packager()
    packadd vim-packager

    call packager#init(s:packager_init_opts)
    for [l:repo, l:opts] in items(s:repos)
        call packager#add(l:repo, l:opts)
    endfor
endfunction

function s:disable_plugin(plugin_dir, ...)
    if !isdirectory(a:plugin_dir)
        call s:err(a:plugin_dir..' doesn''t exist')
        return
    endif
    let l:dst_dir = substitute(a:plugin_dir, '/start/\ze[^/]\+$', '/opt/', '')
    if isdirectory(l:dst_dir)
        call s:err(l:dst_dir..' exists')
        return
    endif
    call rename(a:plugin_dir, l:dst_dir)
endfunction

function s:plugin_dir_complete(A, L, P)
    let l:pat = s:pack_dir..'/start/*'
    let l:plugin_list = filter(globpath(&packpath, l:pat, 0, 1), {_,v -> isdirectory(v)})
    return filter(l:plugin_list, {_,v -> v =~ a:A})
endfunction

function s:get_plugin_list()
    if exists('s:plugin_list')
        return s:plugin_list
    endif
    let l:pat = 'pack/*/*/*'
    let s:plugin_list = filter(globpath(&packpath, l:pat, 0, 1), {_,v -> isdirectory(v)})
    call map(s:plugin_list, {_,v -> substitute(v, '^.*[/\\]', '', '')})
    return s:plugin_list
endfunction
