# ~/.config/fish/config.fish
if status is-login
    contains ~/.local/bin $PATH
    or set PATH ~/.local/bin $PATH
end

if status is-interactive
    set theme_complete_path yes
    set fish_prompt_pwd_dir_length 0
end

alias px='proxychains -q'
alias ls='ls --color=auto'
alias ll='ls --color=auto -lah'
alias copy='rsync -ah --info=progress2'

#set -x CC /usr/bin/musl-gcc
#fish_color_normal cad3f5
set -U fish_color_command 8aadf4
set -U fish_color_param f0c6c6
set -U fish_color_keyword ed8796
set -U fish_color_quote a6da95
set -U fish_color_redirection f5bde6
set -U fish_color_end f5a97f
set -U fish_color_comment 8087a2
set -U fish_color_error ed8796
set -U fish_color_gray 6e738d
set -U fish_color_selection --background=363a4f
set -U fish_color_search_match --background=363a4f
set -U fish_color_option a6da95
set -U fish_color_operator f5bde6
set -U fish_color_escape ee99a0
set -U fish_color_autosuggestion 6e738d
set -U fish_color_cancel ed8796
set -U fish_color_cwd eed49f
set -U fish_color_user 8bd5ca
set -U fish_color_host 8aadf4
set -U fish_color_host_remote a6da95
set -U fish_color_status ed8796
set -U fish_pager_color_progress 6e738d
set -U fish_pager_color_prefix f5bde6
set -U fish_pager_color_completion cad3f5
set -U fish_pager_color_description 6e738d
