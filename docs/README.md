# Documentation

This folder contains all documentation for the Terragrunt infrastructure management system.

## Structure

### 📁 guides/
User guides and how-to documentation:
- [BACKEND_CONFIGURATION.md](guides/BACKEND_CONFIGURATION.md) - Backend configuration guide
- [CUSTOM_RESOURCE_NAMING_GUIDE.md](guides/CUSTOM_RESOURCE_NAMING_GUIDE.md) - Custom resource naming guide  
- [EXTERNAL_S3_BACKEND_GUIDE.md](guides/EXTERNAL_S3_BACKEND_GUIDE.md) - External S3 backend integration
- [EXTERNAL_VPC_GUIDE.md](guides/EXTERNAL_VPC_GUIDE.md) - External VPC integration guide

### 📁 resources/
Resource-specific documentation:
- [external-s3-backend.md](resources/external-s3-backend.md) - External S3 backend resource template
- [external-vpc.md](resources/external-vpc.md) - External VPC resource template

### 📁 admin/
Administrative and development documentation:
- [README.md](admin/README.md) - Admin tools overview
- [README-manage.md](admin/README-manage.md) - Management script documentation

### 📁 reports/
Project reports and analysis:
- [REFACTORING_SUMMARY.md](reports/REFACTORING_SUMMARY.md) - System refactoring summary
- [TEST_INFRASTRUCTURE_REPORT.md](reports/TEST_INFRASTRUCTURE_REPORT.md) - Test infrastructure report
- [UPDATED_TEST_INFRASTRUCTURE_REPORT.md](reports/UPDATED_TEST_INFRASTRUCTURE_REPORT.md) - Updated test report

## Quick Start

1. **For new users**: Start with the main [README.md](../README.md) in the root directory
2. **Resource creation**: See [guides/CUSTOM_RESOURCE_NAMING_GUIDE.md](guides/CUSTOM_RESOURCE_NAMING_GUIDE.md)
3. **External resources**: Check [guides/EXTERNAL_VPC_GUIDE.md](guides/EXTERNAL_VPC_GUIDE.md) and [guides/EXTERNAL_S3_BACKEND_GUIDE.md](guides/EXTERNAL_S3_BACKEND_GUIDE.md)
4. **Backend setup**: Review [guides/BACKEND_CONFIGURATION.md](guides/BACKEND_CONFIGURATION.md)

## Project Context

This documentation supports a Perl-based Terragrunt infrastructure management system with:
- 4-tier hierarchy (Environment → Project → Region → Zone)
- Smart backend configuration
- External resource integration
- Automated template generation
- 60+ AWS resource types

## License

Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.