import json
from pathlib import Path
config = json.loads((Path(__file__).resolve().parents[1] / 'godot/config/runtime.json').read_text())
assert config['mode'] == 'local' and config['platformEnabled'] is False and config['networkRequired'] is False
print('Local mode verified')
