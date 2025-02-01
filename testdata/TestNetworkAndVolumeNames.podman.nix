{ pkgs, lib, config, ... }:

{
  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
  };

  # Enable container name DNS for all Podman networks.
  # See: https://github.com/NixOS/nixpkgs/issues/226365
  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."traefik" = {
    image = "docker.io/library/traefik";
    volumes = [
      "my-volume:/test2:rw"
      "myproject_test3:/test3:rw"
      "test1:/test1:rw"
    ];
    ports = [
      "80:80/tcp"
      "443:443/tcp"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=traefik"
      "--network=my-network"
      "--network=myproject_test1"
      "--network=test3"
    ];
  };
  systemd.services."podman-traefik" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-my-network.service"
      "podman-network-myproject_test1.service"
      "podman-volume-my-volume.service"
      "podman-volume-myproject_test3.service"
    ];
    requires = [
      "podman-network-my-network.service"
      "podman-network-myproject_test1.service"
      "podman-volume-my-volume.service"
      "podman-volume-myproject_test3.service"
    ];
  };

  # Networks
  systemd.services."podman-network-my-network" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f my-network";
    };
    script = ''
      podman network inspect my-network || podman network create my-network
    '';
    partOf = [ "podman-compose-myproject-root.target" ];
    wantedBy = [ "podman-compose-myproject-root.target" ];
  };
  systemd.services."podman-network-myproject_test1" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f myproject_test1";
    };
    script = ''
      podman network inspect myproject_test1 || podman network create myproject_test1 --internal
    '';
    partOf = [ "podman-compose-myproject-root.target" ];
    wantedBy = [ "podman-compose-myproject-root.target" ];
  };

  # Volumes
  systemd.services."podman-volume-my-volume" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect my-volume || podman volume create my-volume
    '';
    partOf = [ "podman-compose-myproject-root.target" ];
    wantedBy = [ "podman-compose-myproject-root.target" ];
  };
  systemd.services."podman-volume-myproject_test3" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect myproject_test3 || podman volume create myproject_test3
    '';
    partOf = [ "podman-compose-myproject-root.target" ];
    wantedBy = [ "podman-compose-myproject-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-myproject-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
