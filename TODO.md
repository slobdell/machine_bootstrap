# Future Bootstrap Improvements (TODO)

Here are high-priority quality-of-life enhancements and tools to consider exploring when bootstrapping new machines in the future:

---

## 🛠️ Proposed Enhancements

### 1. Vim Syntax Plugins & Productivity Helpers (Done)
- [x] **C++/Arduino Syntax Highlighting**: Improve editor experience for `.ino` and `.pde` files. (Mapped to C++ filetype in `.vimrc`)
- [x] **`vim-commentary`**: Add a lightweight, single-file plugin to allow quick line commenting. (Installed via native package manager in `install_vim.sh`)
- [x] **Go/Python syntax updates**: Enhance standard built-in vim editing experience. (Updated spacing and tab rules in `.vimrc` to match `gofmt` and PEP 8)

### 2. GitHub CLI (`gh`) Integration (Done)
- [x] **Auto-authentication**: Use `gh auth login` to automate machine authorization. (Installed `gh` automatically in `bootstrap_machine.sh`)
- [x] **Auto-SSH Setup**: The GitHub CLI can automatically generate, configure, and upload SSH keys to GitHub profiles directly. (Integrated options and commands into `setup_git.sh`)
