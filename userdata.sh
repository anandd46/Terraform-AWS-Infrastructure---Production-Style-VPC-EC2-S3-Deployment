#!/bin/bash
###############################################################################
# EC2 Instance User Data Bootstrap Script
#
# This script runs automatically on first boot of the EC2 instance.
# It is executed as root by cloud-init.
#
# Tasks performed:
#   1. System package update
#   2. Apache HTTPD installation and configuration
#   3. Amazon CloudWatch Agent installation and configuration
#   4. Custom status webpage generation
#   5. Service enablement and startup
#
# Template variables are substituted by Terraform's templatefile() function:
#   ${project_name}   - from var.project_name
#   ${environment}    - from var.environment
#   ${owner}          - from var.owner
#   ${log_group_name} - from local.cw_log_group_name
#   ${aws_region}     - from var.aws_region
#   ${s3_bucket_name} - from local.s3_bucket_name
#
# Author: Anand D
###############################################################################

set -euxo pipefail

# Redirect all output to a log file for troubleshooting
exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1

echo "============================================================"
echo " EC2 Bootstrap started: $(date)"
echo " Project: ${project_name} | Environment: ${environment}"
echo "============================================================"

###############################################################################
# 1. System Update
###############################################################################
echo "[1/5] Updating system packages..."
dnf update -y
dnf upgrade -y

###############################################################################
# 2. Install Required Packages
###############################################################################
echo "[2/5] Installing Apache HTTPD and utilities..."
dnf install -y \
  httpd \
  curl \
  wget \
  unzip \
  jq \
  htop \
  net-tools \
  bind-utils

###############################################################################
# 3. Install Amazon CloudWatch Agent
###############################################################################
echo "[3/5] Installing Amazon CloudWatch Agent..."

# Download the CloudWatch Agent package from the official AWS distribution
wget -q https://amazoncloudwatch-agent.s3.amazonaws.com/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm \
  -O /tmp/amazon-cloudwatch-agent.rpm

rpm -U /tmp/amazon-cloudwatch-agent.rpm
rm -f /tmp/amazon-cloudwatch-agent.rpm

# Write the CloudWatch Agent configuration file.
# This configures the agent to collect:
#   - Application logs from Apache and the custom webpage
#   - System metrics: CPU, memory, disk, network
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent",
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/httpd-access",
            "timezone": "UTC",
            "timestamp_format": "%d/%b/%Y:%H:%M:%S"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/httpd-error",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/userdata.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/userdata",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/system-messages",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CustomMetrics/${project_name}",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_user",
          "cpu_usage_system",
          "cpu_usage_iowait"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "mem": {
        "measurement": [
          "mem_used",
          "mem_cached",
          "mem_total",
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free",
          "disk_used",
          "disk_total"
        ],
        "metrics_collection_interval": 60,
        "resources": ["/"]
      },
      "net": {
        "measurement": [
          "bytes_recv",
          "bytes_sent",
          "packets_recv",
          "packets_sent"
        ],
        "metrics_collection_interval": 60,
        "resources": ["eth0"]
      }
    }
  }
}
CWCONFIG

# Start the CloudWatch Agent with the configuration above
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

###############################################################################
# 4. Gather Instance Metadata
#
# IMDSv2 requires a session token for all metadata requests.
# The TOKEN is retrieved first with a PUT request, then used in subsequent GETs.
###############################################################################
echo "[4/5] Gathering instance metadata..."

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-type)

LAUNCH_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

###############################################################################
# 5. Create Custom Webpage
###############################################################################
echo "[5/5] Creating custom status webpage..."

cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${project_name} — ${environment} Deployment</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #0f2027, #203a43, #2c5364);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #e0e0e0;
    }
    .card {
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 16px;
      padding: 40px 50px;
      max-width: 750px;
      width: 95%;
      backdrop-filter: blur(10px);
      box-shadow: 0 25px 50px rgba(0,0,0,0.4);
    }
    .badge {
      display: inline-block;
      background: #00d2ff;
      color: #0f2027;
      font-size: 0.75rem;
      font-weight: 700;
      padding: 4px 12px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 2.2rem;
      font-weight: 700;
      background: linear-gradient(90deg, #00d2ff, #a8edea);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 8px;
    }
    .subtitle {
      font-size: 1rem;
      color: #8899aa;
      margin-bottom: 32px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      margin-bottom: 24px;
    }
    .info-block {
      background: rgba(0,210,255,0.07);
      border: 1px solid rgba(0,210,255,0.15);
      border-radius: 10px;
      padding: 16px 20px;
    }
    .info-block .label {
      font-size: 0.72rem;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #00d2ff;
      margin-bottom: 6px;
    }
    .info-block .value {
      font-size: 0.95rem;
      color: #ffffff;
      font-weight: 500;
      word-break: break-all;
    }
    .full-width { grid-column: 1 / -1; }
    .status-bar {
      background: rgba(0,255,120,0.1);
      border: 1px solid rgba(0,255,120,0.2);
      border-radius: 8px;
      padding: 12px 20px;
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 24px;
    }
    .status-dot {
      width: 10px; height: 10px;
      background: #00ff78;
      border-radius: 50%;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.3; }
    }
    .footer {
      text-align: center;
      font-size: 0.8rem;
      color: #556677;
      border-top: 1px solid rgba(255,255,255,0.08);
      padding-top: 20px;
      margin-top: 8px;
    }
    .tech-stack {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 20px;
    }
    .tech-tag {
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 6px;
      padding: 4px 12px;
      font-size: 0.78rem;
      color: #aabbcc;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">Live Deployment</div>
    <h1>${project_name}</h1>
    <p class="subtitle">Production-Grade AWS Infrastructure — Provisioned by Terraform</p>

    <div class="status-bar">
      <div class="status-dot"></div>
      <span style="color:#00ff78; font-weight:600;">Instance Healthy</span>
      <span style="color:#556677; margin-left:auto; font-size:0.82rem;">Bootstrapped: $LAUNCH_TIME</span>
    </div>

    <div class="grid">
      <div class="info-block">
        <div class="label">Instance ID</div>
        <div class="value">$INSTANCE_ID</div>
      </div>
      <div class="info-block">
        <div class="label">Instance Type</div>
        <div class="value">$INSTANCE_TYPE</div>
      </div>
      <div class="info-block">
        <div class="label">Private IP Address</div>
        <div class="value">$PRIVATE_IP</div>
      </div>
      <div class="info-block">
        <div class="label">Public IP Address</div>
        <div class="value">$PUBLIC_IP</div>
      </div>
      <div class="info-block">
        <div class="label">Availability Zone</div>
        <div class="value">$AZ</div>
      </div>
      <div class="info-block">
        <div class="label">AWS Region</div>
        <div class="value">${aws_region}</div>
      </div>
      <div class="info-block">
        <div class="label">Environment</div>
        <div class="value">${environment}</div>
      </div>
      <div class="info-block">
        <div class="label">S3 Bucket</div>
        <div class="value">${s3_bucket_name}</div>
      </div>
      <div class="info-block full-width">
        <div class="label">CloudWatch Log Group</div>
        <div class="value">${log_group_name}</div>
      </div>
    </div>

    <div class="tech-stack">
      <span class="tech-tag">☁️ AWS</span>
      <span class="tech-tag">⚙️ Terraform</span>
      <span class="tech-tag">🌐 Apache HTTPD</span>
      <span class="tech-tag">📊 CloudWatch</span>
      <span class="tech-tag">🔐 IAM Roles</span>
      <span class="tech-tag">🪣 S3</span>
      <span class="tech-tag">🔑 IMDSv2</span>
    </div>

    <div class="footer">
      <p>Authored by <strong>${owner}</strong> &nbsp;|&nbsp; Infrastructure as Code Demo</p>
      <p style="margin-top:6px;">Managed by Terraform &nbsp;·&nbsp; No resources configured manually</p>
    </div>
  </div>
</body>
</html>
HTML

###############################################################################
# 6. Enable and Start Services
###############################################################################
echo "Enabling and starting services..."

systemctl enable httpd
systemctl start httpd
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

###############################################################################
# 7. Verification
###############################################################################
echo "Verifying services..."
systemctl is-active httpd && echo "✅ Apache is running" || echo "❌ Apache failed to start"
systemctl is-active amazon-cloudwatch-agent && echo "✅ CloudWatch Agent is running" || echo "❌ CloudWatch Agent failed"

# Quick self-test: the webpage should return HTTP 200
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Webpage is serving (HTTP $HTTP_CODE)"
else
  echo "⚠️  Webpage returned HTTP $HTTP_CODE"
fi

echo "============================================================"
echo " Bootstrap completed: $(date)"
echo " Instance $INSTANCE_ID is live at http://$PUBLIC_IP"
echo "============================================================"
