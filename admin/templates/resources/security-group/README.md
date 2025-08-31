# security-group Template

Generated: 2025-08-31
Category: networking
Terraform Module: terraform-aws-modules/security-group

## Description

This template creates AWS security-group resources using Terragrunt.

## Usage

```bash
# Create security-group resource
./manage.pl add resource "security-group" -e <env> -r <region>

# For zone-level resources
./manage.pl add resource "security-group" -e <env> -r <region> -z <zone>
```

## Configuration

The template includes:

- Standard terragrunt.hcl configuration
- Resource-specific Perl module (security-group/Resource.pm)
- Common AWS tags and naming conventions
- Dependency management setup

## Customization

1. **terragrunt.hcl**: Modify the terraform source and inputs
2. **Resource.pm**: Add validation and post-creation logic
3. **Dependencies**: Uncomment and configure dependency blocks as needed

## Common Dependencies

Based on the resource type, you may need:

- Check AWS documentation for specific dependencies

## Next Steps

1. Run the terraform-module-analyzer to generate inputs.json
2. Customize the terragrunt.hcl with specific configuration
3. Test with --dry-run flag first
4. Deploy using terragrunt-deploy.pl

## References

- [Terraform AWS Modules](https://github.com/terraform-aws-modules)
- [AWS security-group Documentation](https://docs.aws.amazon.com/)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
