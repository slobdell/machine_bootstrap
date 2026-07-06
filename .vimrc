" --- A Simple, Robust, No-Plugin .vimrc ---

" Set nocompatible mode.
set nocompatible

" Enable essential features using the failsafe 'has()' check
if has("syntax")
  syntax on
endif
if has("filetype")
  filetype plugin indent on
endif

" --- Sensible Defaults ---
set number              " Show line numbers
set showcmd             " Show (partial) command in status line
set showmatch           " Show matching brackets
set incsearch           " Incremental search
set hlsearch            " Highlight all search matches
set ignorecase          " Case-insensitive searching
set smartcase           " ... unless the search term has uppercase letters
set scrolloff=5         " Keep 5 lines visible around the cursor

" --- Persistent Undo ---
" Keep undo history between sessions.
if has('persistent_undo')
  set undodir=~/.vim/undo
  set undofile
endif

" --- Tabbing & Indentation ---
set expandtab           " Use spaces instead of tabs (default)
set tabstop=4           " Number of spaces a <Tab> counts for
set shiftwidth=4        " Number of spaces for auto-indentation
set softtabstop=4       " Number of spaces for <Tab> and <BS> in insert mode
set autoindent
set smartindent

" --- Colors and Appearance ---
set background=dark
colorscheme desert

" --- Custom Statusline ---
set laststatus=2        " Always show the status line
set statusline=         " Clear existing statusline
set statusline+=%f      " File name
set statusline+=%m      " Modified flag [+]
set statusline+=%r      " Readonly flag [RO]
set statusline+=%=      " Right-align the following items
set statusline+=[%Y]    " File type
set statusline+=\ %l/%L " Line/Total Lines
set statusline+=\ %P    " Percentage through file

" --- Key Mappings ---
let mapleader = " "

" Mapping for Vim's built-in file explorer (netrw)
" Press <spacebar> then 'e' to open the file explorer in the current directory.
nnoremap <leader>e :Explore<CR>

" --- Language-Specific Settings ---
augroup filetype_settings
  autocmd!
  " Treat .ino and .pde files as C++ (for Arduino development syntax highlighting)
  autocmd BufNewFile,BufRead *.ino,*.pde setfiletype cpp

  " Use real tabs for Makefiles, as is required.
  autocmd FileType make setlocal noexpandtab shiftwidth=8 tabstop=8

  " Go files settings: use real tabs, not spaces, matching standard gofmt style
  autocmd FileType go setlocal noexpandtab shiftwidth=4 tabstop=4 softtabstop=4

  " Python files settings: enforce standard PEP 8 spacing
  autocmd FileType python setlocal expandtab shiftwidth=4 tabstop=4 softtabstop=4

  " Run gofmt on Go files before saving.
  " This command filters the entire buffer through gofmt, updating it in place.
  autocmd BufWritePre *.go :%!gofmt
augroup END
