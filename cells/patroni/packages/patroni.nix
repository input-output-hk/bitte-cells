{
  lib,
  python38Packages,
  fetchFromGitHub,
}:
python38Packages.buildPythonApplication rec {
  pname = "patroni";
  version = "2.1.2";
  src = fetchFromGitHub {
    owner = "zalando";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-DW1N7yihKuib2yflNqgLYPA1zfnWLrslRtyLLcnMmOc=";
  };
  # cdiff renamed to ydiff; remove when patroni source reflects this.
  # Raft tests removed due to https://github.com/zalando/patroni/issues/1862
  postPatch = ''
    rm tests/test_raft.py
    rm tests/test_raft_controller.py
  '';
  propagatedBuildInputs = with python38Packages; [
    boto
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
  ];
  checkInputs = with python38Packages; [flake8 mock pytestCheckHook pytest-cov requests];
  # Fix tests by preventing them from writing to /homeless-shelter.
  preCheck = "export HOME=$(mktemp -d)";
  pythonImportsCheck = ["patroni"];
  meta = with lib; {
    homepage = "https://patroni.readthedocs.io/en/latest/";
    description = "A Template for PostgreSQL HA with ZooKeeper, etcd or Consul";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = teams.deshaw.members;
  };
}
