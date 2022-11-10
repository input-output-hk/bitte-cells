{
  pkgs,
  lib,
  python38Packages,
  fetchFromGitHub,
  nixosTests,
}:
python38Packages.buildPythonApplication rec {
  pname = "patroni";
  version = "2.1.4";
  src = fetchFromGitHub {
    owner = "zalando";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-4/j0962lv/boyfn/XqEjSr2Vfp/XcJaEiphrhDG6xkI=";
  };

  patches = [
    ./rotate-token-update-service.patch
  ];

  # cdiff renamed to ydiff; remove when patroni source reflects this.
  # Raft tests removed due to https://github.com/zalando/patroni/issues/1862
  postPatch = ''
    for i in requirements.txt patroni/ctl.py tests/test_ctl.py; do
      substituteInPlace $i --replace cdiff ydiff
    done
  '';

  doCheck = false;

  propagatedBuildInputs = with python38Packages; [
    boto3
    botocore
    click
    consul
    dnspython
    kazoo
    kubernetes
    prettytable
    psutil
    psycopg2
    pysyncobj
    python-dateutil
    python-etcd
    pyyaml
    tzlocal
    urllib3
    ydiff
    # Required for patronictl edit-config
    (pkgs.more)
  ];

  checkInputs = with python38Packages; [
    flake8
    mock
    pytestCheckHook
    pytest-cov
    requests
  ];

  # Fix tests by preventing them from writing to /homeless-shelter.
  preCheck = "export HOME=$(mktemp -d)";

  pythonImportsCheck = ["patroni"];

  passthru.tests = {
    patroni = nixosTests.patroni;
  };

  meta = with lib; {
    homepage = "https://patroni.readthedocs.io/en/latest/";
    description = "A Template for PostgreSQL HA with ZooKeeper, etcd or Consul";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = teams.deshaw.members;
  };
}
