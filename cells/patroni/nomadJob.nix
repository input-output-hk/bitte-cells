{
  inputs,
  cell,
}: let
  l = inputs.nixpkgs.lib // builtins;
  msg = target: ''
    WARNING: the 'patroni.nomadJob' target is deprecated and has been renamed to 'patroni.nomadCharts'.

    Please use 'patroni.nomadCharts.${target}' instead of 'patroni.nomadJob.${target}'.

    Reason: there has been a semantic inconsistency in that nomadJobs actually were only templates.
    In analogy to helm charts, we now call them nomad charts to clarify their semantics and free up
    nomad job for what it actually is.
  '';
in {
  default = l.warn (msg "default") cell.nomadCharts.default;
}
