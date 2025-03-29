{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "daniel";
  home.homeDirectory = "/home/daniel";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You can update Home Manager without changing this value. See the Home
  # Manager release notes for a list of state version changes in each release.
  home.stateVersion = "24.11";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    fd
    fzf
    nnn
    ripgrep
    sops
    tig
    tree
  ];

  programs.bash = {
    enable = true;
    # Setting fish as the default shell may cause issues because it is not POSIX
    # compliant. A workaround is to switch automatically any login shell from
    # bash to fish. The snippet below is from the Arch wiki:
    #   https://wiki.archlinux.org/title/Fish#Modify_.bashrc_to_drop_into_fish
    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} && ''${SHLVL} == 1 ]]; then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "ls --color=auto --group-directories-first";
      g = "git status";
      t = "tig --all";
    };
  };

  programs.git = {
    enable = true;
    userName = "Daniel Meer";
    userEmail = "meerdan2@gmail.com";
    extraConfig = {
      pull.rebase = "true";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
}
