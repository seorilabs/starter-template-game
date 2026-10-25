import json
from pathlib import Path
config = json.loads((Path(__file__).resolve().parents[1] / 'godot/config/runtime.json').read_text())
assert (config['mode'], config['platformEnabled'], config['networkRequired']) in [('local', False, False), ('platform', True, True)]
print('Runtime service mode verified')
