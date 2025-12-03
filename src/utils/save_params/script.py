import re
import yaml
import base64
from collections import OrderedDict

## VIASH START
par = {
    "id": "sample_one",
    "params_yaml": "cGFyYW1zX3lhbWw6IHt9Cg==",
    "workflow_analysis": "LSBuYW1lOiBhbm5vdFZpc1FDX3dmCiAgdmVyc2lvbjogMC4xLjAK",
    "output": "output.yaml"
}
## VIASH END

# Custom representer to preserve order in YAML output
def represent_ordereddict(dumper, data):
    return dumper.represent_dict(data.items())

class Dumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(Dumper, self).increase_indent(flow, False)

# Register the representer for OrderedDict
Dumper.add_representer(OrderedDict, represent_ordereddict)
# Also handle regular dicts to preserve order (Python 3.7+)
Dumper.add_representer(dict, represent_ordereddict)

def decode_params_yaml(encoded_yaml):
    yaml_bytes = base64.b64decode(encoded_yaml)
    yaml_string = yaml_bytes.decode('utf-8')
    yaml_data = yaml.safe_load(yaml_string)
    
    return yaml_data

params = decode_params_yaml(par['params_yaml'])

# Add workflow analysis information if provided
if par.get('workflow_analysis'):
    try:
        analysis_bytes = base64.b64decode(par['workflow_analysis'])
        analysis_string = analysis_bytes.decode('utf-8')
        analysis = yaml.safe_load(analysis_string)
        params['analysis'] = analysis
    except Exception as e:
        print(f"Warning: Could not parse workflow_analysis YAML: {e}")

with open(par["output"], 'w') as f:
    yaml.dump(params, f, default_flow_style=False, Dumper=Dumper)

