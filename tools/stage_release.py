"""Stage only the eight validated distribution files for release provenance."""
import argparse
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("syrin_build", Path(__file__).with_name("build.py"))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


def stage(destination):
    destination = Path(destination).resolve()
    if destination == build.ROOT or build.ROOT in destination.parents:
        raise ValueError("Keep release staging outside the checkout.")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError("Choose an empty release staging directory.")
    outputs = build.build_outputs()
    artifacts = {name: data for name, data in outputs.items() if name.startswith(("dist/", "prompts/"))}
    for name, data in artifacts.items():
        if (build.ROOT / name).read_bytes() != data:
            raise ValueError("Stale release artifact: " + name)
    destination.mkdir(parents=True, exist_ok=True)
    for name, data in artifacts.items():
        (destination / Path(name).name).write_bytes(data)
    return sorted(Path(name).name for name in artifacts)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination")
    args = parser.parse_args()
    print("Staged validated release assets: " + ", ".join(stage(args.destination)))
