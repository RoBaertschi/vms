#!/bin/sh

# mkdir -p /mnt/shared
# mount -t 9p -o trans=virtio,version=9p2000.L shared /mnt/shared
# cp /mnt/shared/alpine-setup.sh .

set -ex

rcser() {
    for service in "$@"; do
        rc-update add $service default
        rc-service $service start
    done
}

# mkdir /etc/runlevels/async
# rc-update add -s default async
# sed '/::wait:\/sbin\/openrc default/a ::once:\/sbin\/openrc async -q' /etc/inittab > inittab.new
# mv /etc/inittab /etc/inittab.bak
# mv inittab.new /etc/inittab

setup-keymap ch ch
setup-hostname localhost
setup-interfaces -a -r eth0
rc-service networking start
setup-timezone -z Europe/Zurich
rc-service hostname restart
rc-update add networking default
rc-update add seedrng boot
rc-update add acpid default
rc-update add crond default
openrc boot
openrc default

cat > /etc/apk/repositories <<EOF
/media/sr0/apks
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF


apk -U upgrade

# setup-apkrepos -f -c
setup-user -a -f robin -g audio,input,video,netdev robin
mkdir -p /home/robin
chown robin:robin /home/robin
echo "Please create a password for user \"robin\""
passwd robin
echo "Please create a password for user \"root\""
passwd root

echo "Setup zsh"
apk add zsh shadow
chsh robin -s /bin/zsh

mkdir -p /etc/zsh/zshrc.d
echo 'PROMPT="%F{red}%n%f@%F{red}%m%f %F{green}%~$ %f"' > /etc/zsh/zshrc.d/prompt.zsh

cat > /etc/profile.d/xdg.sh <<EOF
export XDG_CONFIG_HOME=\$HOME/.config
export XDG_CACHE_HOME=\$HOME/.cache
export XDG_DATA_HOME=\$HOME/.local/share
export XDG_STATE_HOME=\$HOME/.local/state
export XDG_DATA_DIRS=/usr/local/share:/usr/share
export XDG_CONFIG_DIRS=/etc/xdg
EOF


apk add neovim git tree-sitter-lua build-base

NV_RUNTIME_PATH=""

source /etc/profile

# 1 Name
# 2 Repository
add_plugin() {
    name=$1
    repo=$2

    mkdir -p ~/.local/state/nvim
    git clone $repo ~/.local/state/nvim/nvim/$name
    NV_RUNTIME_PATH="$NV_RUNTIME_PATH $name"
}

add_plugin nvim-lspconfig https://github.com/neovim/nvim-lspconfig
add_plugin nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter
add_plugin mini.nvim https://github.com/echasnovski/mini.nvim
mkdir -p $XDG_CONFIG_HOME/nvim

cat >> $XDG_CONFIG_HOME/nvim/init.lua <<EOF
vim.cmd [[colorscheme retrobox]]
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.mouse = "a"

vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
end)

vim.opt.breakindent = true

vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.timeoutlen = 300

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.list = true

vim.opt.inccommand = "split"

vim.opt.cursorline = true

vim.opt.scrolloff = 10

vim.opt.signcolumn = "yes"

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)
vim.keymap.set("t", "<Esc><Esc>", "<C-\\\\><C-n>")
vim.keymap.set("i", "<a-space>", function()
    vim.lsp.completion.get()
end)
EOF

for dir in $NV_RUNTIME_PATH; do
    cat >> $XDG_CONFIG_HOME/nvim/init.lua <<EOF
    vim.opt.rtp:append(vim.fn.stdpath "state" .. "/$dir")
EOF
done

apk add nodejs npm

LSPS=""

add_apk_lsp() {
    apk_name=$1
    lsp_name=$2

    apk add $apk_name
    LSPS="$LSPS $lsp_name"
}

add_apk_lsp lua-language-server lua_ls

for lsp in $LSPS; do
    cat >> $XDG_CONFIG_HOME/nvim/init.lua <<EOF
    vim.lsp.enable("$lsp")
EOF
done

cat >> $XDG_CONFIG_HOME/nvim/init.lua <<EOF
vim.cmd[[set completeopt+=menuone,noselect,popup]]
vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('my.lsp', {}),
    callback = function(ev)
        local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
        if client:supports_method('textDocument/completion') then
            vim.lsp.completion.enable(true, client.id, ev.buf, {
                autotrigger = true,
            })
        end
        if not client:supports_method('textDocument/willSaveWaitUntil')
            and client:supports_method('textDocument/formatting') then
          vim.api.nvim_create_autocmd('BufWritePre', {
            group = vim.api.nvim_create_augroup('my.lsp', {clear=false}),
            buffer = args.buf,
            callback = function()
              vim.lsp.buf.format({ bufnr = ev.buf, id = client.id, timeout_ms = 1000 })
            end,
          })
        end
    end
})

require 'nvim-treesitter.configs'.setup {
    ensure_installed = { "markdown", "vimdoc", "vim", "lua" },
    highlight = {
        enable = true,
    },
    auto_install = true,
    indent = {
        enable = true,
        disable = { "ruby", "zig" },
    },
}

vim.wo.foldtext = "v:lua.vim.treesitter.foldtext()"
vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldlevel = 99
vim.opt.foldlevelstart = -1
vim.opt.foldnestmax = 99

require "mini.ai".setup({ n_lines = 500 })
require "mini.surround".setup()
local statusline = require "mini.statusline"
statusline.setup({ use_icons = false })
statusline.section_location = function()
    return "%2l:%-2v"
end
EOF

echo "Minimim Setup"
apk add odin pkgconfig libdisplay-info-dev libdrm-dev eudev-dev

echo "Setup openssh"
setup-sshd -c openssh

echo "Setup ntp"
setup-ntp chrony

echo "Setting up spice"
apk add spice-vdagent spice-webdavd
rcser spice-vdagentd spice-webdavd

echo "Setting up elogind with PAM"
apk add elogind polkit-elogind linux-pam util-linux-login
rcser polkit elogind

echo "udev setup"
apk add eudev udev-init-scripts udev-init-scripts-openrc
for service in udev udev-trigger udev-settle; do
    rc-update add $service sysinit
done
rc-update add udev-postmount default
for service in udev udev-trigger udev-settle udev-postmount; do
    rc-service $service start
done

rcser cgroups dbus

echo "Setting up greetd"
apk add greetd greetd-tuigreet

mkdir /etc/greetd
cat > /etc/greetd/config.toml <<EOF
[default_session]
command = "tuigreet --cmd zsh"
user = "greetd"
[terminal]
vt = 1
EOF

sed -i -e 's/tty1/# tty1/' /etc/inittab

echo >> /etc/conf.d/greetd
echo "rc_need=elogind" >> /etc/conf.d/greetd

rc-update add greetd default

echo "Parallel openrc"
sed -i -e 's/#rc_parallel="NO"/rc_parallel="YES"/' /etc/rc.conf

export USE_EFI=1
echo "Creating disk, user input required."
setup-disk -m sys /dev/vda

mkdir /mnt/root
mount /dev/vda3 /mnt/root

mkdir -p /mnt/root/home/robin

cp -r ~/* /mnt/root/home/robin
cp -r ~/.config /mnt/root/home/robin/.config
mkdir -p /mnt/root/home/robin/.local/state/
cp -r ~/.local/state/nvim/* /mnt/root/home/robin/.local/state/nvim

chown -R robin:robin /mnt/root/home/robin
