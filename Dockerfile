# Terragrunt Infrastructure Management System - Docker Image
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License

FROM ubuntu:22.04

# Metadata
LABEL maintainer="Mat Kovach <mek@mek.cc>"
LABEL description="Terragrunt Infrastructure Management System with tfenv, tgenv, and AWS CLI"
LABEL version="1.0"

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set shell options for better error handling
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

#######################
# System Dependencies
#######################

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    tar \
    gzip \
    tree \
    jq \
    vim \
    nano \
    less \
    build-essential \
    gcc \
    g++ \
    make \
    perl \
    perl-base \
    perl-modules-5.34 \
    libperl-dev \
    cpanminus \
    ca-certificates \
    openssl \
    libssl-dev \
    libyaml-dev \
    libxml2-dev \
    libexpat1-dev \
    dnsutils \
    iputils-ping \
    netcat \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    locales \
    tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Generate locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

#######################
# User Setup
#######################

# Create a non-root user
RUN useradd -m -s /bin/bash -u 1000 terragrunt && \
    echo "terragrunt ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to terragrunt user
USER terragrunt
WORKDIR /home/terragrunt

# Set environment variables for user
ENV HOME=/home/terragrunt
ENV PATH="$HOME/.local/bin:$HOME/bin:$PATH"

#######################
# tfenv Installation
#######################

RUN git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv && \
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc && \
    mkdir -p ~/.local/bin && \
    ln -s ~/.tfenv/bin/* ~/.local/bin/

# Install latest Terraform
RUN ~/.tfenv/bin/tfenv install latest && \
    ~/.tfenv/bin/tfenv use latest

#######################
# tgenv Installation  
#######################

RUN git clone --depth=1 https://github.com/cunymatthieu/tgenv.git ~/.tgenv && \
    echo 'export PATH="$HOME/.tgenv/bin:$PATH"' >> ~/.bashrc && \
    ln -s ~/.tgenv/bin/* ~/.local/bin/

# Install latest Terragrunt
RUN ~/.tgenv/bin/tgenv install latest && \
    ~/.tgenv/bin/tgenv use latest

#######################
# AWS CLI Installation
#######################

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    sudo ./aws/install && \
    rm -rf aws awscliv2.zip

# Install AWS Session Manager plugin
RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
    sudo dpkg -i session-manager-plugin.deb && \
    rm session-manager-plugin.deb

#######################
# Perl Modules Installation
#######################

# Install core Perl modules from Ubuntu packages (much faster than CPAN)
RUN sudo apt-get update && sudo apt-get install -y \
    libyaml-tiny-perl \
    libjson-perl \
    libpath-tiny-perl \
    libgetopt-long-descriptive-perl \
    libdata-structure-util-perl \
    liblist-moreutils-perl \
    libdatetime-perl \
    libdatetime-format-iso8601-perl \
    libwww-perl \
    liburi-perl \
    libtemplate-perl \
    libtext-template-perl \
    libtest-deep-perl \
    libtest-exception-perl \
    libconfig-simple-perl \
    libconfig-general-perl \
    liblog-log4perl-perl \
    liblog-dispatch-perl \
    libgit-wrapper-perl \
    libtry-tiny-perl \
    libreadonly-perl \
    libconst-fast-perl \
    libclass-accessor-perl \
    libmoose-perl \
    libmodern-perl-perl \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

# Install Paws (AWS SDK) from CPAN since it's not available in Ubuntu repos
RUN cpanm --notest Paws && rm -rf ~/.cpanm

#######################
# Additional Tools
#######################

# Install helpful CLI tools
RUN pip3 install --user --no-cache-dir \
    yq \
    yamllint \
    pre-commit \
    && rm -rf ~/.cache/pip

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    sudo apt-get update && \
    sudo apt-get install -y gh && \
    sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/*

#######################
# Environment Setup
#######################

# Create directories for AWS credentials and config
RUN mkdir -p ~/.aws ~/.ssh ~/.local/share

# Set up shell environment
RUN echo '# Terragrunt Infrastructure Management Environment' >> ~/.bashrc && \
    echo 'export EDITOR=vim' >> ~/.bashrc && \
    echo 'export PAGER=less' >> ~/.bashrc && \
    echo 'export PERL5LIB="./lib:$PERL5LIB"' >> ~/.bashrc && \
    echo '# AWS CLI completion' >> ~/.bashrc && \
    echo 'complete -C aws_completer aws' >> ~/.bashrc && \
    echo '# Terraform/Terragrunt aliases' >> ~/.bashrc && \
    echo 'alias tf=terraform' >> ~/.bashrc && \
    echo 'alias tg=terragrunt' >> ~/.bashrc && \
    echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias la="ls -la"' >> ~/.bashrc && \
    echo '# Color support' >> ~/.bashrc && \
    echo 'export CLICOLOR=1' >> ~/.bashrc && \
    echo 'export LSCOLORS=ExFxCxDxBxegedabagacad' >> ~/.bashrc

# Create workspace directory
RUN mkdir -p ~/workspace

#######################
# Entry Point
#######################

# Create entrypoint script
COPY --chown=terragrunt:terragrunt --chmod=755 <<'EOF' /home/terragrunt/entrypoint.sh
#!/bin/bash
set -euo pipefail

# Print versions
echo "🚀 Terragrunt Infrastructure Management System"
echo "================================================"
echo "Terraform version: $(terraform version -json | jq -r '.terraform_version')"
echo "Terragrunt version: $(terragrunt --version | awk '/terragrunt version/ {print $3}')"
echo "AWS CLI version: $(aws --version)"
echo "Perl version: $(perl -v | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)"
echo "================================================"

# Check for AWS credentials
if [[ -f ~/.aws/credentials ]] || [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
    echo "✅ AWS credentials found"
    if aws sts get-caller-identity &>/dev/null; then
        echo "✅ AWS credentials are valid"
        aws sts get-caller-identity --output table
    else
        echo "⚠️  AWS credentials found but may be invalid"
    fi
else
    echo "ℹ️  No AWS credentials found. Set up credentials to use AWS resources."
    echo "   Options:"
    echo "   1. Mount ~/.aws directory: -v ~/.aws:/home/terragrunt/.aws:ro"
    echo "   2. Set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
    echo "   3. Use IAM roles if running on EC2/ECS/EKS"
fi

echo ""
echo "💡 Ready to manage infrastructure!"
echo "   Working directory: $(pwd)"
echo "   Available commands: ./manage.pl, ./terragrunt-deploy.pl, terraform, terragrunt, aws"
echo ""

# Execute the command (default to bash if no args provided)
if [ $# -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi
EOF

# Set working directory
WORKDIR /home/terragrunt/workspace

# Copy application files (this will be overridden when mounting)
COPY --chown=terragrunt:terragrunt . /home/terragrunt/workspace/

# Ensure scripts are executable
RUN find . -name "*.pl" -type f -exec chmod +x {} \; && \
    find . -name "*.sh" -type f -exec chmod +x {} \;

#######################
# Health Check
#######################

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD terraform version && terragrunt --version && aws --version || exit 1

#######################
# Volume and Port Setup
#######################

# Create mount points for common directories
VOLUME ["/home/terragrunt/workspace", "/home/terragrunt/.aws", "/home/terragrunt/.ssh"]

#######################
# Final Setup
#######################

# Set final working directory
WORKDIR /home/terragrunt/workspace

# Labels for better container management
LABEL org.opencontainers.image.title="Terragrunt Infrastructure Management"
LABEL org.opencontainers.image.description="Complete infrastructure management system with Terraform, Terragrunt, AWS CLI, and Perl"
LABEL org.opencontainers.image.source="https://github.com/user/terragrunt-infra-manager"
LABEL org.opencontainers.image.licenses="MIT"

# Set entrypoint
ENTRYPOINT ["/home/terragrunt/entrypoint.sh"]

# Default command
CMD ["/bin/bash"]