#!/bin/bash

# Script to generate Terraform project structure for Azure Web App with Database
# This creates the folder hierarchy and empty files

echo "🚀 Creating Terraform project structure..."

# Define the base project directory
# PROJECT_NAME="web_app_with_database_infra"

# Create base directory
# mkdir -p "$PROJECT_NAME"
# cd "$PROJECT_NAME"

echo "📁 Creating environment directories..."

# Create environment directories
mkdir -p env/dev
mkdir -p env/stage
mkdir -p env/prod

echo "📁 Creating module directories..."

# Create module directories
mkdir -p modules/compute
mkdir -p modules/database
mkdir -p modules/networking
mkdir -p modules/security

echo "📄 Creating environment files (dev)..."

# Create dev environment files
touch env/dev/main.tf
touch env/dev/variables.tf
touch env/dev/outputs.tf
touch env/dev/providers.tf
touch env/dev/backend.tf
touch env/dev/terraform.tfvars

echo "📄 Creating environment files (stage)..."

# Create stage environment files
touch env/stage/main.tf
touch env/stage/variables.tf
touch env/stage/outputs.tf
touch env/stage/providers.tf
touch env/stage/backend.tf
touch env/stage/terraform.tfvars

echo "📄 Creating environment files (prod)..."

# Create prod environment files
touch env/prod/main.tf
touch env/prod/variables.tf
touch env/prod/outputs.tf
touch env/prod/providers.tf
touch env/prod/backend.tf
touch env/prod/terraform.tfvars

echo "📄 Creating compute module files..."

# Create compute module files
touch modules/compute/main.tf
touch modules/compute/variables.tf
touch modules/compute/output.tf
touch modules/compute/README.md

echo "📄 Creating database module files..."

# Create database module files
touch modules/database/main.tf
touch modules/database/variables.tf
touch modules/database/outputs.tf
touch modules/database/README.md

echo "📄 Creating networking module files..."

# Create networking module files
touch modules/networking/main.tf
touch modules/networking/variables.tf
touch modules/networking/outputs.tf
touch modules/networking/README.md

echo "📄 Creating security module files..."

# Create security module files
touch modules/security/main.tf
touch modules/security/variables.tf
touch modules/security/outputs.tf
touch modules/security/README.md

echo "📄 Creating project documentation files..."

# Create root documentation files
touch README.md
touch ARCHITECTURE.md
touch .gitignore

echo "📝 Creating .gitignore file..."

# Create .gitignore with common Terraform exclusions
cat > .gitignore << 'EOF'
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used to override resources locally
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Include override files you do wish to add to version control using negation pattern
# !example_override.tf

# Include tfplan files to ignore the plan output of command: terraform plan -out=tfplan
*tfplan*

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore lock files (optional, some teams prefer to commit this)
# .terraform.lock.hcl

# IDE specific files
.vscode/
.idea/
*.swp
*.swo
*~

# OS specific files
.DS_Store
Thumbs.db

# Backup files
*.backup
*.bak

# Logs
*.log
EOF

echo "📊 Creating project structure visualization..."

# Create a visual representation of the structure
cat > PROJECT_STRUCTURE.txt << 'EOF'
web_app_with_database_infra/
├── .gitignore
├── README.md
├── ARCHITECTURE.md
├── PROJECT_STRUCTURE.txt
│
├── env/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   │
│   ├── stage/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   │
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── backend.tf
│       └── terraform.tfvars
│
└── modules/
    ├── compute/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── output.tf
    │   └── README.md
    │
    ├── database/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    │
    ├── networking/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    │
    └── security/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── README.md
EOF

echo ""
echo "✅ Project structure created successfully!"
echo ""
echo "📂 Directory structure:"
echo "   - env/dev/       : Development environment"
echo "   - env/stage/     : Staging environment"
echo "   - env/prod/      : Production environment"
echo "   - modules/       : Reusable Terraform modules"
echo ""
echo "📝 Next steps:"
echo "   1. Navigate to the project: cd $PROJECT_NAME"
echo "   2. Review the structure: tree . (or cat PROJECT_STRUCTURE.txt)"
echo "   3. Start adding Terraform code to your modules"
echo "   4. Configure terraform.tfvars for each environment"
echo ""
echo "🎉 Happy coding!"
