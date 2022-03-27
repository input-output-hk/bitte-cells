{
  lib,
  buildGoPackage,
  fetchFromGitHub,
}:
buildGoPackage rec {
  pname = "srvaddr";
  version = "0.1";

  src = fetchFromGitHub {
    owner = "pd";
    repo = pname;
    rev = "v${version}";
    sha256 = "0mi1bfwv0y5xr7hdyj55mf1gnlrh1i58c4n1jp7l92zx0ifmxdzj";
  };

  goPackagePath = "github.com/pd/srvaddr";
  goDeps = ./srvaddr-deps.nix;

  meta = with lib; {
    description = "Simple SRV record querying from the CLI";
    homepage = "https://github.com/pd/srvaddr";
    license = licenses.mit;
    maintainers = with maintainers; [blaggacao];
  };
}
