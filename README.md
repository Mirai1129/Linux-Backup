# macOS / Linux 重裝工具

這個資料夾可複製到新電腦，安裝你選的命令列工具與字型，並還原 tmux、oh-my-posh、Git 設定。請保留 `install.sh`、`.tmux.conf` 和整個 `config/` 資料夾。

## 使用方式

```bash
bash install.sh --check
bash install.sh
```

支援 macOS，以及使用 apt（Debian／Ubuntu）、dnf（Fedora）、pacman（Arch）的 Linux。安裝時需要網路；系統套件可能要求輸入管理員密碼。請在你信任的網路環境執行。`--check` 只檢查平台與備份檔案，不安裝任何東西。

## 安裝內容

- Git、tmux、btop、lsd、oh-my-posh、GitHub CLI（`gh`）、uv、OpenJDK。
- uv 管理的最新 Python 3.15 修補版本，並在 `~/.local/bin` 建立 `python`、`python3`、`python3.15` 命令。`~/.local/bin` 會加入 Bash 與 Zsh 的 PATH。
- CaskaydiaMono Nerd Font。安裝後仍需在終端機設定中選用此字型。
- `.tmux.conf` 還原到 `~/.tmux.conf`；安裝 TPM 與設定內列出的 tmux 外掛。
- `config/markbull.omp.json` 還原到 `~/.config/oh-my-posh/`；在 Bash 與 Zsh 設定檔加入 oh-my-posh 啟用設定。
- `config/gitconfig` 還原到 `~/.gitconfig`，設定 Mirai1129 的 Git 使用者名稱、此 repo 原有提交使用的個人電子郵件，以及 GitHub 憑證助手。憑證助手透過 PATH 尋找 `gh`，不依賴原電腦的 Homebrew 路徑。

若原本的 tmux、oh-my-posh 或 Git 設定不同，安裝程式會先把舊檔改名為 `.backup.日期時間`。重複執行時不會重複加入 shell 啟用設定。

GitHub 登入狀態、存取權杖與 SSH 私鑰不在此備份中。在新電腦需要使用 GitHub 時，執行 `gh auth login` 登入。

在 macOS 上，Homebrew 版 OpenJDK 的路徑會加入 Bash 與 Zsh；Linux 使用發行版的 OpenJDK 套件。

## 安裝後檢查

開啟新的終端機，執行：

```bash
python --version
python3 --version
tmux -V
oh-my-posh version
java -version
git config user.name
git config user.email
```

這份備份只包含你選的項目；沒有包含應用程式、登入資料或其他個人檔案。
