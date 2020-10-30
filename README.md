# plug
## Overview
Plug.vim is a thin wrapper over [vim-packager][1], leveraging the power of Vim8(and Neovim) native package manager and jobs feature.
It is forked from [plugpac.vim][4], which is designed to work with [minpac][1].

## Installation
Linux & Neovim/Vim8 (for example):
```
git clone https://github.com/comfortablynick/plug.vim \
    ~/.local/share/nvim/site/pack/packager/opt
curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/comfortablynick/plug.vim/master/plug.vim
```

## Sample init.vim
```vim
call plug#begin()

" vim-packager
Plug 'kristijanhusak/vim-packager', {'type': 'opt'}

Plug 'junegunn/vim-easy-align'

" On-demand loading
Plug 'scrooloose/nerdtree',         {'on':  'NERDTreeToggle'}
Plug 'tpope/vim-fireplace',         {'for': 'clojure'}

" Using a non-master branch
Plug 'rdnetto/YCM-Generator',       {'branch': 'stable'}

" Post-update hook
Plug 'Yggdroot/LeaderF',            {'do': {-> system('./install.sh')}}

" Sepcify commit ID, branch name or tag name to be checked out.
Plug 'tpope/vim-sensible',          {'rev': 'v1.2'}

call plug#end()
```
Reload `.vimrc`/`init.vim` and `:PlugInstall` to install plugins.
`Plug` command just handles `for` and `on` options(i.e. lazy load, implies `'type': 'opt'`). Other options are passed to `packager#add` directly. See [packager][3] for more imformation.

## Commands
- `PlugInstall`: Install newly added plugins. (`packager#install()`)
- `PlugUpdate`: Install or update plugins. (`packager#update()`)
- `PlugClean`: Uninstall unused plugins. (`packager#clean()`)
- `PlugStatus`: See plugins status. (`packager#status()`)
- `PlugDisable`: Move a plugin to `packager/opt`. (`packager#update` would move plugin back to `packager/start`, unless the plugin is explicitly optional. Useful for disabling a plugin temporarily)

## Credit
K. Takata (the author of [minpac][1])  
Junegunn Choi (the author of [vim-plug][2])  
Kristijan Husak (the author of [vim-packager][3])  
Ben Yip (the author of [plugpac][4])  

[1]: https://github.com/k-takata/minpac
[2]: https://github.com/junegunn/vim-plug
[3]: https://github.com/kristijanhusak/vim-packager
[4]: https://github.com/bennyyip/plugpac.vim
## License
MIT
