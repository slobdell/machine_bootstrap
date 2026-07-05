#!/bin/bash -e

# ==============================================================================
#
#          VIM-IN-A-BOX: "Built-ins Only" Script
#
# ==============================================================================
# Load configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

DEV_USER="${DEV_USER:-$USER}"
USER_HOME=$(eval echo "~${DEV_USER}")

# --- Helper function for logging ---
log() {
    echo "[VimSetup] $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting 'Built-ins Only' Vim configuration for user '${DEV_USER}'."

# --- Step 1: Install System-Level Dependencies using sudo ---
log "Installing vim-nox and golang with sudo..."
# These commands require root privileges.
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vim-nox golang-go

# --- Step 2: Create User-Specific Directories ---
# This command operates in the user's home directory and does NOT need sudo.
log "Creating user's .vim/undo directory..."
mkdir -p "${USER_HOME}/.vim/undo"

log "Vim and dependencies installed."

# --- Step 3: Set vim-nox as the Default Editor using sudo ---
# This modifies a system-wide setting and requires root privileges.
log "Setting vim-nox as the default for the 'vim' command with sudo..."
sudo update-alternatives --set vim /usr/bin/vim.nox

# --- Step 4: Ensure the .vimrc file exists ---
if [ ! -f "${USER_HOME}/.vimrc" ]; then
    if [ -f "${SCRIPT_DIR}/.vimrc" ]; then
        log "Copying the .vimrc file from repository to ${USER_HOME}/.vimrc"
        cp "${SCRIPT_DIR}/.vimrc" "${USER_HOME}/.vimrc"
    else
        log "Creating default .vimrc at ${USER_HOME}/.vimrc"
        cat <<'EOF' > "${USER_HOME}/.vimrc"
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
  " Use real tabs for Makefiles, as is required.
  autocmd FileType make setlocal noexpandtab shiftwidth=8 tabstop=8

  " Run gofmt on Go files before saving.
  " This command filters the entire buffer through gofmt, updating it in place.
  autocmd BufWritePre *.go :%!gofmt
augroup END

EOF
    fi
    log ".vimrc file deployed."
else
    log ".vimrc file already exists at ${USER_HOME}/.vimrc, skipping creation/copying."
fi

# --- Step 5: Set Correct File Ownership using sudo ---
# Using sudo here is a safety measure to guarantee correct ownership,
# even if old files owned by root were somehow left from previous runs.
log "Setting correct ownership for user's files with sudo..."
sudo chown -R "${DEV_USER}" "${USER_HOME}/.vim"
sudo chown "${DEV_USER}" "${USER_HOME}/.vimrc"

# --- Finalization ---
log "'Built-ins Only' Vim environment setup is complete."
