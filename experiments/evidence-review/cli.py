"""Explicit opt-in stdin/stdout demonstration; never copies, sends or executes."""
import argparse
import sys

from review import Controller, PROJECTS

COMMAND_LIMIT = 32
LINE_LIMIT = 1024
HELP = ("Commands: show, project orbit|orbit-next, review, cancel, stale, restore, "
        "unavailable, recover, help, quit. Stale/outage controls are SIMULATED.")


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
    for _ in range(COMMAND_LIMIT):
        line = stream.readline(LINE_LIMIT + 1)
        if not line or len(line) > LINE_LIMIT:
            controller.cancel()
        else:
            controller.command(line.rstrip("\r\n"))
        if line.rstrip("\r\n") == "help":
            out.write(HELP + "\n")
        out.write(controller.display())
        out.flush()
        if controller.closed:
            return 0
    controller.cancel()
    out.write("Input command limit reached.\n" + controller.display())
    out.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
