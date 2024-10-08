"GENERAL"
set nocompatible

filetype on
filetype indent on

syntax on

set number
set relativenumber
set shiftwidth=4
set tabstop=4
set nobackup
set scrolloff=10
set nowrap
set incsearch
set ignorecase
set smartcase
set showmode
set showcmd
set showmatch
set hlsearch
set history=100
set wildmenu
set wildmode=list:longest
set timeoutlen=1000
set ttimeoutlen=0
set whichwrap+=<,>,h,l,[,]
set visualbell

"APPEARENCE"
"GET monokai.vim and " PUT INTO .vim/colors/monokai.vim""
colorscheme monokai

" Use a line cursor within insert mode and a block cursor everywhere else.
"
" Reference chart of values:
"   Ps = 0  -> blinking block.
"   Ps = 1  -> blinking block (default).
"   Ps = 2  -> steady block.
"   Ps = 3  -> blinking underline.
"   Ps = 4  -> steady underline.
"   Ps = 5  -> blinking bar (xterm).
"   Ps = 6  -> steady bar (xterm).
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

"KEYBINDINGS"
"Move stuff around in v
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

"Center when moving
nnoremap <C-j> <C-d>zz
nnoremap <C-k> <C-u>zz

"Center when searching
nnoremap n nzzzv
nnoremap N Nzzzv

"Remap the 7th circle of hell
nnoremap Q <nop>

"Remap for autocomplet
inoremap <C-@> <C-n>

"<Ctrl> + hjkl to navigate in insert mode"
inoremap <C-h> <Left>
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-l> <Right>

"<Ctrl> + hjkl to navigate in command mode"
cnoremap <C-h> <Left>
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-l> <Right>

"Redo"
nnoremap <C-u> <C-r>

"Remove highlighting after search"
nnoremap <silent> <C-_> :set hlsearch!<CR>

"Brackets and quotes"
inoremap ( ()<Left>
inoremap [ []<Left>
inoremap { {}<Left>
inoremap ' ''<Left>
inoremap " ""<Left>
inoremap ` ``<Left>

"Space to start typing"
nnoremap <Space> a

"Remap for Ctrl backspace in normal mode"
noremap! <C-BS> <C-w>
noremap! <C-h> <C-w>

"Insert and expand curly braces on pressing enter
inoremap {<CR> {<CR>}<Esc>d0O