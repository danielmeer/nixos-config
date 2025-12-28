# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, pkgs-unstable, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Limit the number of generations to keep
  boot.loader.systemd-boot.configurationLimit = 20;

  networking.hostName = "home-server"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.daniel = {
    isNormalUser = true;
    description = "Daniel";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIELMTbUd3qFQC0S7k8cqubR51slPJah6S1sF9wr76suF daniel@home-server"
    ];
    packages = with pkgs; [];
  };

  # Need to create users/groups for shared data with containers
  users = {
    users.nextcloud = {
      isSystemUser = true;
      uid = 2000;
      group = "nextcloud";
    };
    groups.nextcloud.gid = 2000;

    users.albyhub = {
      isSystemUser = true;
      uid = 2010;
      group = "albyhub";
    };
    groups.albyhub.gid = 2010;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # Fish configuration and plugins are managed in Home Manager, but we enable
  # it here as well for fish completions provided by other system packages.
  programs.fish.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Enable Tailscale
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Perform garbage collection weekly to maintain low disk usage
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1w";
  };

  # Optimize storage
  # You can also manually optimize the store via:
  #    nix-store --optimise
  # Refer to the following link for more details:
  # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
  nix.settings.auto-optimise-store = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  sops = {
    defaultSopsFile = ./secrets.yaml;

    # Automatically import host SSH key as age key
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Secrets will be accessible in /run/secrets/
    secrets.nextcloud-admin = {
      owner = "nextcloud";
    };
  };

  networking.nat = {
    enable = true;
    enableIPv6 = true;
    # Use "ve-*" when using nftables instead of iptables
    internalInterfaces = ["ve-+"];
    externalInterface = "enp1s0";
  };

  # === Nextcloud ===
  containers.nextcloud = {
    ephemeral = true;
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.11";

    bindMounts = {
      "${config.sops.secrets.nextcloud-admin.path}" = {
        isReadOnly = true;
      };
      "/var/lib/nextcloud/config" = {
        hostPath = "/data/nextcloud/config";
        isReadOnly = false;
      };
      "/var/lib/nextcloud/data" = {
        hostPath = "/data/nextcloud/data";
        isReadOnly = false;
      };
      "/var/lib/mysql" = {
        hostPath = "/data/nextcloud/mysql";
        isReadOnly = false;
      };
      "/var/lib/tailscale" = {
        hostPath = "/data/nextcloud/tailscale";
        isReadOnly = false;
      };
    };

    config = { config, pkgs, lib, ... }: with lib; {
      # Match host UID/GID (necessary for bind mounts)
      users = {
        users.nextcloud.uid = 2000;
        groups.nextcloud.gid = 2000;
      };

      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud31;
        hostName = "nextcloud.quetzal-mountain.ts.net";

        # Let NixOS install and configure the database automatically.
        database.createLocally = true;

        # Let NixOS install and configure Redis caching automatically.
        configureRedis = true;

        maxUploadSize = "2G";

        extraAppsEnable = true;
        extraApps = with config.services.nextcloud.package.packages.apps; {
          # List of apps we want to install and are already packaged in
          # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
          inherit calendar contacts cookbook notes tasks;
        };
        autoUpdateApps.enable = true;

        config = {
          dbtype = "mysql";
          adminuser = "admin";
          adminpassFile = "/run/secrets/nextcloud-admin"; # config.sops.secrets.nextcloud-admin.path;
        };
      };

      services.tailscale = {
        enable = true;
        interfaceName = "userspace-networking";
        openFirewall = true;
      };

      system.stateVersion = "24.11";
    };
  };

  # === Bitcoin ===
  nix-bitcoin = {
    # Automatically generate all secrets required by services.
    # The secrets are stored in /etc/nix-bitcoin-secrets.
    # Seems to be necessary for flakes.
    generateSecrets = true;

    # Enable interactive access to nix-bitcoin features (like bitcoin-cli) for the system's main user
    operator = {
      enable = true;
      name = "daniel";
    };
    nodeinfo.enable = true;

    # The nix-bitcoin release version that your config is compatible with.
    # When upgrading to a backwards-incompatible release, nix-bitcoin will display an
    # an error and provide instructions for migrating your config to the new release.
    configVersion = "0.0.121";
  };

  services.bitcoind = {
    enable = true;
  };

  # === Alby Hub ===
  containers.albyhub = {
    ephemeral = true;
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.20";
    localAddress = "192.168.100.21";

    bindMounts = {
      "/var/lib/albyhub" = {
        hostPath = "/data/albyhub/data";
        isReadOnly = false;
      };
      "/var/lib/tailscale" = {
        hostPath = "/data/albyhub/tailscale";
        isReadOnly = false;
      };
    };

    config = { config, pkgs, lib, ... }: with lib; {
      # Match host UID/GID (necessary for bind mounts)
      users = {
        users.albyhub = {
          isSystemUser = true;
          uid = 2010;
          group = "albyhub";
        };
        groups.albyhub.gid = 2010;
      };

      environment.systemPackages = [ pkgs-unstable.albyhub ];

      systemd.services.albyhub = {
        description = "Alby Hub";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = 1;
          User = "albyhub";
          ExecStart = "${pkgs-unstable.albyhub}/bin/albyhub";
          Environment = [
            "PORT=8029"
            "WORK_DIR=/var/lib/albyhub"
          ];
        };
        wantedBy = [ "multi-user.target" ];
      };

      services.caddy = {
        enable = true;
        virtualHosts."http://albyhub.quetzal-mountain.ts.net" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:8029
          '';
        };
      };

      services.tailscale = {
        enable = true;
        interfaceName = "userspace-networking";
        openFirewall = true;
      };

      system.stateVersion = "25.05";
    };
  };
}
