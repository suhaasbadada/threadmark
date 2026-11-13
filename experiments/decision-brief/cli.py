"""Opt-in fixed synthetic stdin/stdout inspection; no source/command execution."""
import argparse
import sys

from brief import Controller, PROJECTS

HELP = ("Commands: show, json, inspect, project harbor|harbour, stale, unavailable, "
        "recover, cancel, quit, help. Stale/outage controls are SIMULATED.")


def main(argv=None, stdin=None, stdout=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--synthetic", choices=PROJECTS)
    args = parser.parse_args(argv)
    out = stdout if stdout is not None else sys.stdout
    if args.synthetic is None:
        parser.print_help(file=out)
        return 0
    stream = stdin if stdin is not None else sys.stdin
    controller = Controller(args.synthetic)
    out.write(HELP + "\n" + controller.display())
    out.flush()
    for _ in range(32):
        line = stream.readline(1025)
        command = line.rstrip("\r\n")
        controller.command("cancel" if not line or len(line) > 1024 else command)
        if command == "help":
            out.write(HELP + "\n")
        out.write(controller.display(command == "json"))
        out.flush()
        if controller.closed:
            return 0
    controller.command("cancel")
    out.write("Input command limit reached.\n" + controller.display())
    out.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
