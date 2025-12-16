import re
import yaml
import base64

## VIASH START
par = {
    "id": "sample_one",
    "params_yaml": "cGFyYW1zX3lhbWw6IHt9Cg==",
    "workflow_analysis": "LSBuYW1lOiBhbm5vdFZpc1FDX3dmCiAgdmVyc2lvbjogMC4xLjAK",
    "output": "output.yaml"
}
## VIASH END

# Custom representer to preserve dict order in YAML output
# Note: Python 3.7+ dicts maintain insertion order by default
def represent_dict(dumper, data):
    return dumper.represent_dict(data.items())

class Dumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(Dumper, self).increase_indent(flow, False)

# Register the representer for dicts to preserve order
Dumper.add_representer(dict, represent_dict)

def decode_params_yaml(encoded_yaml):
    yaml_bytes = base64.b64decode(encoded_yaml)
    yaml_string = yaml_bytes.decode('utf-8')
    yaml_data = yaml.safe_load(yaml_string)
    
    return yaml_data

params = decode_params_yaml(par['params_yaml'])

# Build the output structure
output_data = params  # params is a list of states

# Add workflow analysis information if provided
if par.get('workflow_analysis'):
    try:
        analysis_bytes = base64.b64decode(par['workflow_analysis'])
        analysis_string = analysis_bytes.decode('utf-8')
        analysis = yaml.safe_load(analysis_string)
        # Since params is a list, create a dict wrapper
        output_data = {
            'params': params,
            'analysis': analysis
        }
    except Exception as e:
        print(f"Warning: Could not parse workflow_analysis YAML: {e}")

with open(par["output"], 'w') as f:
    yaml.dump(output_data, f, default_flow_style=False, Dumper=Dumper)

