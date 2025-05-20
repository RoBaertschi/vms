#!/bin/sh

# mkdir -p /mnt/shared
# mount -t 9p -o trans=virtio,version=9p2000.L shared /mnt/shared
# cp /mnt/shared/alpine-setup.sh .

set -ex

rcser() {
    for service in "$@"; do
        rc-update add $service
        rc-service $service start
    done
}

setup-keymap ch ch
setup-hostname localhost
setup-interfaces -a -r eth0
rc-service networking start
setup-timezone -z Europe/Zurich
rc-service hostname restart
rc-update add networking boot
rc-update add seedrng boot
rc-update add acpid
rc-update add crond
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
    NV_RUNTIME_PATH="$NV_RUNTIME_PATH ~/.local/state/nvim/$name"
}

add_plugin nvim-lspconfig https://github.com/neovim/nvim-lspconfig
add_plugin nvim-treesitter https://github.com/nvim-treesitter/nvim-treesitter

mkdir -p $XDG_CONFIG_HOME/nvim

for dir in $NV_RUNTIME_PATH; do
    cat >> $XDG_CONFIG_HOME/nvim/init.lua <<EOF
    vim.opt.rtp:append("$dir")
EOF
done

apk add nodejs npm

LSPS=""

add_npm_lsp() {
    npm_name=$1
    lsp_name=$2

    npm i -g $npm_name
    LSPS="$LSPS $lsp_name"
}

add_npm_lsp bash-language-server bashls

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

require'nvim-treesitter.configs'.setup {
    highlight = {
        enable = true,
    },
}
EOF


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

export USE_EFI=1
echo "Creating disk, user input required."
setup-disk -m sys /dev/vda

mkdir /mnt/root
mount /dev/vda3 /mnt/root

mkdir -p /mnt/root/home/robin

cp -r $HOME/* /mnt/root/home/robin
cp -r ~/.config /mnt/root/home/robin/.config
mkdir -p /mnt/root/home/robin/.local/state
cp -r ~/.local/state/* /mnt/root/home/robin/.local/state

chown -R robin:robin /mnt/root/home/robin
