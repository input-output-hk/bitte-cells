{
  inputs,
  cell,
}: let
  l = inputs.nixpkgs.lib // builtins;
  msg = target: ''
    WARNING: the 'tempo.nomadJob' target is deprecated and has been renamed to 'tempo.nomadCharts'.

    Please use 'tempo.nomadCharts.${target}' instead of 'tempo.nomadJob.${target}'.

    Reason: there has been a semantic inconsistency in that nomadJobs actually were only templates.
    In analogy to helm charts, we now call them nomad charts to clarify their semantics and free up
    nomad job for what it actually is.
  '';
in {
  default = l.warn (msg "default") cell.nomadCharts.default;
}
