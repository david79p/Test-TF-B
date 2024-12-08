######
# password policy
######

variable "account_alias" {
  type        = "string"
  description = "The account alias (AWS sign in link)"
  default     = ""
}

//
variable "aws_iam_account_password_policy_minimum_password_length" {
  type        = "string"
  description = "The minimum password length (default: 14)"
  default     = 14
}

variable "aws_iam_account_password_policy_max_password_age" {
  type        = "string"
  description = "The number of days that an user password is valid (default: 90)"
  default     = 90
}

variable "aws_iam_account_password_policy_password_reuse_prevention" {
  type        = "string"
  description = "The number of previous passwords that users are prevented from reusing (default: 24)"
  default     = 24
}

######
# idp
######

variable "create_saml_provider" {
  type        = "string"
  description = "(Optional) - true if you wish to create an Identity Provider. IMPORTANT: you must obtain the metadata file from the customer before creating it."
  default     = "false"
}

variable "idp_name" {
  type        = "string"
  description = "The Identity Provider name, not relevant if create_saml_provider == false"
}

variable "metadata_file_location" {
  type        = "string"
  description = "The location of the saml metadata.xml file provided by the customer."
  default     = ""
}

######
# global
######

variable "iam_path" {
  type        = "string"
  description = "Path in which to create the policy."
}

######
# role flags
######

variable "role_names" {
  type = "map"

  default = {
    admin     = "Admin"
    devops    = "Devops"
    developer = "Developer"
    support   = "Support"
    audit     = "Audit"
  }
}

variable "create_admin_policy" {
  type        = "string"
  description = "True if you wish to create the Admin iam policy and role"
  default     = "true"
}

variable "create_devops_policy" {
  type        = "string"
  description = "True if you wish to create the Devops iam policy and role"
  default     = "true"
}

variable "create_developer_policy" {
  type        = "string"
  description = "True if you wish to create the Developer iam policy and role"
  default     = "true"
}

variable "create_support_policy" {
  type        = "string"
  description = "True if you wish to create the Support (NOC) iam policy and role"
  default     = "true"
}

variable "create_audit_policy" {
  type        = "string"
  description = "True if you wish to create the audit (NOC) iam policy and role"
  default     = "true"
}
