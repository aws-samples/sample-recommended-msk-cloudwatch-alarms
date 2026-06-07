#!/usr/bin/env python3
"""
Validate CloudFormation template YAML syntax.
Registers CloudFormation intrinsic function tags with PyYAML.

Usage:
    python3 scripts/validate_templates.py

For full CloudFormation validation, install and use cfn-lint:
    pip3 install cfn-lint
    cfn-lint templates/*.yaml
"""

import yaml
import sys
import os
import glob


# Register CloudFormation intrinsic functions as YAML tags
CFN_TAGS = [
    'And', 'Base64', 'Cidr', 'Condition', 'Equals', 'FindInMap',
    'GetAtt', 'GetAZs', 'If', 'ImportValue', 'Join', 'Not', 'Or',
    'Ref', 'Select', 'Split', 'Sub', 'Transform'
]


def cfn_constructor(loader, tag_suffix, node):
    """Generic constructor for CloudFormation tags."""
    if isinstance(node, yaml.ScalarNode):
        return {f'Fn::{tag_suffix}': loader.construct_scalar(node)}
    elif isinstance(node, yaml.SequenceNode):
        return {f'Fn::{tag_suffix}': loader.construct_sequence(node)}
    elif isinstance(node, yaml.MappingNode):
        return {f'Fn::{tag_suffix}': loader.construct_mapping(node)}


class CFNLoader(yaml.SafeLoader):
    """YAML loader that understands CloudFormation intrinsic functions."""
    pass


# Register all CFN tags
for tag in CFN_TAGS:
    CFNLoader.add_constructor(
        f'!{tag}',
        lambda loader, node, t=tag: cfn_constructor(loader, t, node)
    )

# Special case for !Ref (not Fn::Ref)
CFNLoader.add_constructor(
    '!Ref',
    lambda loader, node: {'Ref': loader.construct_scalar(node)}
)

# Special case for !GetAtt with dotted notation
CFNLoader.add_constructor(
    '!GetAtt',
    lambda loader, node: {'Fn::GetAtt': loader.construct_scalar(node).split('.') if isinstance(node, yaml.ScalarNode) else loader.construct_sequence(node)}
)


def validate_template(filepath):
    """Validate a CloudFormation template file."""
    errors = []

    try:
        with open(filepath) as f:
            data = yaml.load(f, Loader=CFNLoader)
    except yaml.YAMLError as e:
        return [f"YAML parse error: {e}"]

    # Check required top-level keys
    if not isinstance(data, dict):
        return ["Template root must be a mapping"]

    if 'AWSTemplateFormatVersion' not in data:
        errors.append("WARNING: Missing AWSTemplateFormatVersion")

    if 'Resources' not in data:
        errors.append("ERROR: Missing required 'Resources' section")
    elif not data['Resources']:
        errors.append("ERROR: 'Resources' section is empty")

    # Check resource types
    if 'Resources' in data and isinstance(data['Resources'], dict):
        for name, resource in data['Resources'].items():
            if not isinstance(resource, dict):
                errors.append(f"ERROR: Resource '{name}' is not a mapping")
                continue
            if 'Type' not in resource:
                errors.append(f"ERROR: Resource '{name}' missing 'Type'")

    # Validate parameter types
    if 'Parameters' in data and isinstance(data['Parameters'], dict):
        valid_types = ['String', 'Number', 'List<Number>', 'CommaDelimitedList',
                       'AWS::SSM::Parameter::Type', 'AWS::EC2::KeyPair::KeyName',
                       'AWS::EC2::SecurityGroup::Id', 'AWS::EC2::Subnet::Id',
                       'AWS::EC2::VPC::Id']
        for name, param in data['Parameters'].items():
            if isinstance(param, dict) and 'Type' in param:
                ptype = param['Type']
                if ptype not in valid_types and not ptype.startswith('AWS::'):
                    errors.append(f"WARNING: Parameter '{name}' has unusual type '{ptype}'")

    return errors


def main():
    """Validate all templates in the templates/ directory."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    template_dir = os.path.join(project_dir, 'templates')

    templates = glob.glob(os.path.join(template_dir, '*.yaml'))
    if not templates:
        print("No templates found in templates/ directory")
        sys.exit(1)

    all_valid = True
    for filepath in sorted(templates):
        filename = os.path.basename(filepath)
        print(f"\n{'='*60}")
        print(f"Validating: {filename}")
        print(f"{'='*60}")

        errors = validate_template(filepath)

        if not errors:
            # Count resources for summary
            with open(filepath) as f:
                data = yaml.load(f, Loader=CFNLoader)

            resources = data.get('Resources', {})
            params = data.get('Parameters', {})
            conditions = data.get('Conditions', {})
            outputs = data.get('Outputs', {})

            print(f"  ✓ VALID")
            print(f"    Parameters:  {len(params)}")
            print(f"    Conditions:  {len(conditions)}")
            print(f"    Resources:   {len(resources)}")
            print(f"    Outputs:     {len(outputs)}")
            print(f"    Resource types:")
            type_counts = {}
            for name, res in resources.items():
                rtype = res.get('Type', 'Unknown') if isinstance(res, dict) else 'Unknown'
                type_counts[rtype] = type_counts.get(rtype, 0) + 1
            for rtype, count in sorted(type_counts.items()):
                print(f"      - {rtype}: {count}")
        else:
            all_valid = False
            has_errors = any(e.startswith("ERROR") for e in errors)
            for error in errors:
                print(f"  {'✗' if error.startswith('ERROR') else '⚠'} {error}")

    print(f"\n{'='*60}")
    if all_valid:
        print("All templates validated successfully!")
        print("\nFor full CloudFormation validation, run:")
        print("  pip3 install cfn-lint")
        print("  cfn-lint templates/*.yaml")
    else:
        print("Some templates have issues. See above for details.")
        sys.exit(1)


if __name__ == '__main__':
    main()
