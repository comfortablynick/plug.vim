" Author:  Nick Murphy (comfortablynick@gmail.com)
" URL:     github.com/comfortablynick/plugpackager.vim
" Version: 1.0
" License: MIT
" ---------------------------------------------------------------------
let s:augroup_name = 'Plug'
let g:plug_loaded = []
let g:plug_found_config_files = map(
    \ globpath(&runtimepath, 'autoload/plugins/*.vim', 0, 1),
    \ {_, val -> fnamemodify(val, ':t:r')}
    \ )
let g:plug_packages_sourced = []
let g:plug_config_files_sourced = []
let g:plug_pre_config_called = []
let g:plug_post_config_called = []

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
    " if exists('g:did_load_filetypes')
    "     filetype off
    " endif
    for [l:name, l:cmds] in items(s:lazy.cmd)
        for l:cmd in l:cmds
            execute printf(
                \ "command! -nargs=* -range -bang %s PlugLoad %s | call s:do_cmd('%s', \"<bang>\", <line1>, <line2>, <q-args>)",
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
                    \ '%snoremap <silent> %s %s:<C-U>PlugLoad %s<bar>call <SID>do_map(%s, %s, "%s")<CR>',
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
        execute 'autocmd' s:augroup_name 'FileType' l:fts 'PlugLoad' l:name
    endfor
    " filetype plugin indent on
endfunction

function plug#add(repo, ...)
    let l:opts = get(a:000, 0, {})
    let l:name = substitute(a:repo, '^.*/', '', '')

    if !has_key(l:opts, 'name')
        let l:opts.name = l:name
    endif

    " Check if option
    if has_key(l:opts, 'if')
        if type(l:opts.if) ==# v:t_func
            let l:opts.if = {l:opts.if}()
        endif
        if ! l:opts.if | return | endif
    endif

    " Lazy loading
    " Keys imply {'type': 'opt'}: ['for', 'on']
    if has_key(l:opts, 'for')
        let l:opts['type'] = 'opt'
        let l:ft = type(l:opts.for) == v:t_list ? join(l:opts.for, ',') : l:opts.for
        let s:lazy.ft[l:name] = l:ft
    endif

    if has_key(l:opts, 'on')
        let l:opts['type'] = 'opt'
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
    " if get(l:opts, 'type', 'opt') ==# 'start'
    "     if has_key(l:opts, 'pre')
    "         call s:do_config(l:opts.pre)
    "         " unlet l:opts.pre
    "     endif
    "     " TODO: use timer?
    "     if has_key(l:opts, 'post')
    "         call s:do_config(l:opts.post)
    "         " unlet l:opts.post
    "     endif
    " endif
    let s:repos[a:repo] = l:opts
endfunction

function plug#has_plugin(plugin)
    return index(s:get_plugin_list(), a:plugin) != -1
endfunction

" For debug purposes
function plug#get_repos()
    return s:repos
endfunction

function! plug#load(...)
    for l:pack in a:000
        let l:repo = s:get_repo_by_name(l:pack)
        if has_key(l:repo, 'pre')
            let g:plug_pre_config_called += [l:pack]
            call s:do_config(l:repo.pre)
            " unlet l:repo.pre
        endif
        execute 'packadd' l:pack
        if has_key(l:repo, 'post')
            let g:plug_post_config_called += [l:pack]
            call s:do_config(l:repo.post)
            " unlet l:repo.post
        endif
        let g:plug_loaded += [l:pack]
    endfor
endfunction

function s:do_config(config)
    if type(a:config) ==# v:t_string
        execute a:config
    elseif type(a:config) ==# v:t_func
        silent! call a:config()
    endif
endfunction

function s:get_repo_by_name(name)
    for [l:k, l:v] in items(s:repos)
        if l:k =~ '^.*/'..a:name
            return l:v
        endif
    endfor
endfunction

function s:assoc(dict, key, val)
    let a:dict[a:key] = add(get(a:dict, a:key, []), a:val)
endfunction

function s:err(msg)
    echohl ErrorMsg
    echom '[plug]' a:msg
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
    command! -bar -nargs=+ -complete=packadd PlugLoad call plug#load(<q-args>)

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
