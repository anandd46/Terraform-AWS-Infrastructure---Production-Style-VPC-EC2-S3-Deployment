###############################################################################
# Local Values
#
# Locals centralise all derived or computed values so they never need to be
# repeated. Every resource that needs a name or tag set reads from here,
# keeping the codebase DRY (Don't Repeat Yourself).
#
# Author: Anand D
###############################################################################

locals {
  ###########################################################################
  # Name Prefix
  #
  # Every resource name starts with this prefix.
  # The random suffix (from random_id in main.tf) is appended where needed
  # to guarantee uniqueness — especially important for globally-unique
  # resources like S3 buckets.
  ###########################################################################
  name_prefix = "${var.project_name}-${var.environment}"

  ###########################################################################
  # Common Tags
  #
  # Applied to every resource via the provider-level default_tags block.
  # Consistent tagging is the foundation of cost allocation, compliance
  # auditing, and automated resource lifecycle management.
  #
  # Tags chosen:
  #   - Project     → groups all resources belonging to this deployment
  #   - Environment → separates dev / staging / production
  #   - Owner       → accountability — who to contact about this resource
  #   - ManagedBy   → signals this must NOT be modified manually in console
  #   - CreatedOn   → records when the resource was first provisioned
  ###########################################################################
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      CreatedOn   = timestamp()
    },
    var.additional_tags
  )

  ###########################################################################
  # AMI Selection
  #
  # If the caller provides an explicit AMI ID, use it.
  # Otherwise, fall back to the latest Amazon Linux 2023 AMI discovered
  # via the data source in main.tf.
  ###########################################################################
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id

  ###########################################################################
  # Resource Name Helpers
  #
  # Centralised name strings prevent typos and make global renames trivial.
  ###########################################################################
  vpc_name            = "${local.name_prefix}-vpc"
  igw_name            = "${local.name_prefix}-igw"
  public_subnet_name  = "${local.name_prefix}-public-subnet"
  route_table_name    = "${local.name_prefix}-public-rt"
  nacl_name           = "${local.name_prefix}-nacl"
  sg_name             = "${local.name_prefix}-sg"
  ec2_name            = "${local.name_prefix}-ec2"
  key_pair_name       = "${local.name_prefix}-keypair"
  iam_role_name       = "${local.name_prefix}-ec2-role"
  iam_policy_name     = "${local.name_prefix}-ec2-policy"
  instance_profile_name = "${local.name_prefix}-ec2-profile"
  cw_log_group_name   = "/aws/${local.name_prefix}/application"

  ###########################################################################
  # S3 Bucket Name
  #
  # S3 bucket names are globally unique across all AWS accounts and regions.
  # We append a random hex suffix (from random_id.suffix in main.tf) to
  # avoid collisions when this project is deployed by different people.
  ###########################################################################
  s3_bucket_name = "${local.name_prefix}-bucket-${random_id.suffix.hex}"

  ###########################################################################
  # SSH Key Name
  #
  # The AWS key pair name references the TLS-generated key in ec2.tf.
  ###########################################################################
  ssh_key_name = "${local.name_prefix}-key-${random_id.suffix.hex}"
}
