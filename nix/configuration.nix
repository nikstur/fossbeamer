# Machine config
{ config
, modulesPath
, pkgs
, lib
, ...
}: {
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  # configure journald to not logs to disk
  services.journald.extraConfig = ''
    Storage=volatile
  '';

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # zfs keeps breaking, removing all unneeded filesystems from the image.
  boot.supportedFilesystems =
    lib.mkForce
      [ "vfat" ];

  # HACK: sd-image-aarch64.nix sets console=ttyS0,115200n8 (and some others),
  # which breaks the device-tree provided serial config.
  boot.kernelParams = lib.mkForce [
    "systemd.log_target=console"
    "systemd.journald.forward_to_console=1"
  ];

  # Switch to systemd-initrd, which is the future (tm).
  # Also it has proven to be a bit more permissive with some boards where the
  # sdcard takes ages to spin up.
  boot.initrd.systemd.enable = true;

  nix.settings.max-jobs = 8;

  # Configure networking
  networking.hostName = "fossbeamer";
  networking.useDHCP = true;
  networking.useNetworkd = true;
  networking.wireless.iwd.enable = true;
  networking.networkmanager.enable = false;
  services.resolved.enable = true;
  services.resolved.dnssec = "false";
  networking.nftables.enable = true;

  # Configure ssh
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    openFirewall = true;
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPTVTXOutUZZjXLB0lUSgeKcSY/8mxKkC0ingGK1whD2 flokli"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA34k0FVKDGNdJ8uk0Ytbvh6J8v+H86F4t6BXAIoW/7xAAAABHNzaDo= flokli 20240704 14321691"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIP7rdJ1klzK8nx74QQA8jYdFwznM1klLS0C7M5lHiu+IAAAABHNzaDo= flokli 20240617 28772765"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC02nCZ1XKOr7lalsEP4Cy5pfNE34RUOpdvS+UB4ozdpGTk+KybGhh1STs9HcJAmNcOitJ4JRlPtQTQVQK5A8XDnt9qxF5W3umIAkAibe9UIRMJK36/K0BXTtvErLmTUxMuSx/NxRJyTV4/3eJC+Lfzg7hy/M6HoZ41w/7L7WZKotElYgnCZcXMxBPVCX1HXGakcr+SHVZGDAgvQ+QL2kYhRyhAqKWp6U3GJ402selzE1OHOeBylqZP8kRUyt+MjehhLG6Lc3uuc5wiz9UxNc5x7JJXGI2ynta10OyHFOzgKtUzqedyb/5sz53nwdEe4gj/Uyrl84QCpYScLqGPGUOMwHTptBcocucvweOgCFXGwaCid6eAo5FhRLS6JOiCoh0jVvgvFjB+hPAX4cKprlXmpNsJcmn6PvCnIa0IylyT8Ki932KqtSzyEvp+U9Olci+fF0+EjghelSFbY6cEBNdKi/ZYiACtyOnA8hL4oApe7em4nFngkQPPbAh2DpUFxp8= Freya"
  ];

  programs.mosh.enable = true;


  # Create a kiosk user
  users.users.kiosk = {
    isNormalUser = true;
    uid = 1000;
  };

  # And configure cage to show fossbeamer on it.
  services.cage = {
    enable = true;
    user = "kiosk";
    program = pkgs.writers.writeBash "run-cage-program" ''
      ${pkgs.wlr-randr}/bin/wlr-randr --output HDMI-A-1 --transform 180
      ${pkgs.fossbeamer}/bin/fossbeamer --default-config=${../default-config.json} https://wip.bar
    '';
    environment = {
      GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (with pkgs.gst_all_1;[
        gstreamer
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-libav
      ]);
      GIO_MODULE_DIR = "${pkgs.glib-networking}/lib/gio/modules/";
      LIBGL_DEBUG = "verbose";
      RUST_LOG = "debug";
    };
    extraArguments = [
      "-d" # don't draw client decorations when possible
    ];
  };

  environment.systemPackages = [
    pkgs.htop
    pkgs.kmsxx # kmsprint
    pkgs.i2c-tools
  ];

  documentation.enable = false; # Reduces closure size and build time.

  users.users."root".initialPassword = "";
  system.stateVersion = "24.05";
}
