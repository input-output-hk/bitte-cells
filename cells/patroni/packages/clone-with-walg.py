#! /usr/env python3
#
# Credit for the majority of code in this script goes to the spilo project:
# Ref: https://github.com/zalando/spilo/blob/master/postgres-appliance/bootstrap/clone_with_wale.py

import argparse
import csv
import logging
import os
import re
import subprocess
import sys

from collections import namedtuple
from dateutil.parser import parse

logging.basicConfig(format="%(asctime)s %(levelname)s: %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)


def read_configuration():
    parser = argparse.ArgumentParser(
        description="Script to clone from S3 with support for point-in-time-recovery"
    )
    parser.add_argument("--scope", required=True, help="target cluster name")
    parser.add_argument(
        "--datadir", required=True, help="target cluster postgres data directory"
    )
    parser.add_argument(
        "--recovery-target-time",
        help="the timestamp up to which recovery will proceed (including time zone)",
        dest="recovery_target_time_string",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="find a matching backup and build the wal-g "
        "command to fetch that backup without running it",
    )
    args = parser.parse_args()

    options = namedtuple("Options", "name datadir recovery_target_time dry_run")
    if args.recovery_target_time_string:
        recovery_target_time = parse(args.recovery_target_time_string)
        if recovery_target_time.tzinfo is None:
            raise Exception("recovery target time must contain a timezone")
    else:
        recovery_target_time = None

    return options(args.scope, args.datadir, recovery_target_time, args.dry_run)


def build_walg_command(command, datadir=None, backup=None):
    cmd = ["wal-g"] + [command]
    if command == "backup-fetch":
        if datadir is None or backup is None:
            raise Exception("backup-fetch requires datadir and backup arguments")
        cmd.extend([datadir, backup])
    elif command != "backup-list":
        raise Exception("invalid {0} command {1}".format(cmd[0], command))
    return cmd


def fix_output(output):
    """WAL-G is using spaces instead of tabs and writes some garbage before the actual header"""

    started = None
    for line in output.decode("utf-8").splitlines():
        if not started:
            started = re.match(r"^name\s+last_modified\s+", line)
        if started:
            yield "\t".join(line.split())


def choose_backup(backup_list, recovery_target_time):
    """Pick up the latest backup file starting before time recovery_target_time"""

    match_timestamp = match = None
    for backup in backup_list:
        last_modified = parse(backup["last_modified"])
        if last_modified < recovery_target_time:
            if match is None or last_modified > match_timestamp:
                match = backup
                match_timestamp = last_modified
    if match is not None:
        return match["name"]


def list_backups(env):
    backup_list_cmd = build_walg_command("backup-list")
    output = subprocess.check_output(backup_list_cmd, env=env)
    reader = csv.DictReader(fix_output(output), dialect="excel-tab")
    return list(reader)


def find_backup(recovery_target_time, env):
    backup_list = list_backups(env)
    if backup_list:
        if recovery_target_time:
            backup = choose_backup(backup_list, recovery_target_time)
            if backup:
                return backup
        else:
            return "LATEST"
    if recovery_target_time:
        raise Exception(
            "Could not find any backups prior to the point in time {0}".format(
                recovery_target_time
            )
        )
    raise Exception("Could not find any backups")


def run_clone_from_s3(options):
    env = os.environ.copy()

    backup_name = find_backup(options.recovery_target_time, env)

    backup_fetch_cmd = build_walg_command("backup-fetch", options.datadir, backup_name)
    logger.info(
        "clone-with-walg: cloning cluster %s using %s",
        options.name,
        " ".join(backup_fetch_cmd),
    )
    logger.info("clone-with-walg: called with %s", sys.argv[1:])
    if not options.dry_run:
        ret = subprocess.call(backup_fetch_cmd, env=env)
        if ret != 0:
            raise Exception("wal-g backup-fetch exited with exit code {0}".format(ret))
    return 0


def main():
    options = read_configuration()
    try:
        run_clone_from_s3(options)
    except Exception:
        logger.exception("clone-with-walg: clone failed")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
