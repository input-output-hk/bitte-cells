{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages;
  inherit (inputs.cells._writers.library) writeShellApplication;
in {
  tempo = writeShellApplication {
    name = "entrypoint";
    debugInputs = [
      nixpkgs.less
      nixpkgs.awscli2
    ];
    runtimeInputs = [
      nixpkgs.coreutils
      nixpkgs.su-exec
      nixpkgs.shadow
      packages.default
    ];
    text = ''
      HOME=/run/tempo

      useradd -m -d $HOME -U -u 1500 -c "Tempo Container User" tempo

      mkdir -p "/local/tempo/storage/"{local,wal,wal-metrics}
      chown tempo:tempo -R /local/tempo

      if [ ! -d "/tmp" ]; then
        mkdir /tmp
        chmod 1777 /tmp
      fi

      echo
      echo "Starting tempo high availability job"

      su-exec tempo:tempo tempo \
        -log.level="''${LOG_LEVEL:-info}" \
        -config.expand-env \
        -config.file="''${CONFIG_FILE:-/local/config.yaml}" \
        "$@"
    '';
  };
}
