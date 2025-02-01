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
  virtualisation.oci-containers.containers."test-both" = {
    image = "nginx:latest";
    cmd = [ "ls" "-la" "\"escape me please\"" ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--entrypoint=[\"nginx\", \"-g\", \"daemon off;\", \"-c\", \"/etc/config/nginx/conf/nginx.conf\"]"
      "--network-alias=both"
      "--network=test_default"
    ];
  };
  systemd.services."podman-test-both" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "no";
    };
    after = [
      "podman-network-test_default.service"
    ];
    requires = [
      "podman-network-test_default.service"
    ];
  };
  virtualisation.oci-containers.containers."test-empty-command-and-entrypoint" = {
    image = "nginx:latest";
    cmd = [  ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--entrypoint=[]"
      "--network-alias=empty-command-and-entrypoint"
      "--network=test_default"
    ];
  };
  systemd.services."podman-test-empty-command-and-entrypoint" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "no";
    };
    after = [
      "podman-network-test_default.service"
    ];
    requires = [
      "podman-network-test_default.service"
    ];
  };
  virtualisation.oci-containers.containers."test-null-command-and-entrypoint" = {
    image = "nginx:latest";
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=null-command-and-entrypoint"
      "--network=test_default"
    ];
  };
  systemd.services."podman-test-null-command-and-entrypoint" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "no";
    };
    after = [
      "podman-network-test_default.service"
    ];
    requires = [
      "podman-network-test_default.service"
    ];
  };
  virtualisation.oci-containers.containers."test-string" = {
    image = "nginx:latest";
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--entrypoint=[\"ENV_VAR=\${ABC}\", \"bash\", \"/abc.sh\"]"
      "--network-alias=string"
      "--network=test_default"
    ];
  };
  systemd.services."podman-test-string" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "no";
    };
    after = [
      "podman-network-test_default.service"
    ];
    requires = [
      "podman-network-test_default.service"
    ];
  };

  # Networks
  systemd.services."podman-network-test_default" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f test_default";
    };
    script = ''
      podman network inspect test_default || podman network create test_default
    '';
    partOf = [ "podman-compose-test-root.target" ];
    wantedBy = [ "podman-compose-test-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-test-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
