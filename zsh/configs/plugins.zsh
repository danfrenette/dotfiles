# zsh auto-suggestions: zsh-users/zsh-autosuggestions/
if [[ -r "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  bindkey '^e' autosuggest-accept
  export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
  export ZSH_AUTOSUGGEST_STRATEGY=(
    history
  )
fi

if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi

# Syntax highlighting must load after plugins that create ZLE widgets.
if [[ -r "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
