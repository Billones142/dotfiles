{ config, pkgs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  # Enlace directo al archivo del repo (no a una copia en /nix/store), para
  # poder editarlo en caliente igual que con stow, sin hacer `switch`.
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.username = "stefano";
  home.homeDirectory = "/home/stefano";

  # Version de Home Manager con la que se creo esta configuracion. No cambiarla
  # al actualizar: solo controla migraciones de defaults con estado.
  home.stateVersion = "26.05";

  # Ajustes para distros que no son NixOS (XDG_DATA_DIRS, locales, etc.)
  targets.genericLinux.enable = true;

  programs.home-manager.enable = true;

  # Flakes sin pasar --extra-experimental-features en cada comando
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';

  # Paquetes de usuario. Lo que depende del sistema (kernel, drivers, mesa,
  # Hyprland, PipeWire) se queda en pacman.
  home.packages = with pkgs; [
    nixd # LSP de Nix
    nixfmt
  ];

  # Shells de desarrollo por proyecto con `use flake` en un .envrc
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Paquetes migrados desde stow (hacer `stow -D <paquete>` antes)
  home.file.".bashrc".source = link "bash/.bashrc";
  xdg.configFile."nvim".source = link "nvim/.config/nvim";
  xdg.configFile."alacritty/alacritty.toml".source = link "alacritty/.config/alacritty/alacritty.toml";
}
