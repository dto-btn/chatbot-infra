#local
locals {
  envs = { for tuple in regexall("(.*)=(.*)", file(".env")) : tuple[0] => sensitive(tuple[1]) }
}

variable "default_location" {
    type    = string
    default = "canadacentral"
}

variable "personal_token" {
    type        = string
    sensitive   = true
}

variable "project_name" {
    type = string
    default = "OpenAI-Chatbot-Pilot"
}

variable "project_name_lowercase" {
    type = string
    default = "openaichatbotpilot"
}

variable "project_name_short_lowercase" {
    type = string
    default = "oaichat"
}

variable "name_prefix" {
    type = string
    default = "ScDc-CIO"
}

variable "name_prefix_lowercase" {
    type = string
    default = "scdccio"
}

variable "api_version" {
    type = string
    default = "3.0.5"
}

variable "api_version_sha" {
    type = string
    default = "1c88ac7d4d3d40ddf46451de4c22d9af2d20dff2"
}

# those 2 must be provided, along with the secret.. (microsoft_provider_authentication_secret)
variable "microsoft_provider_authentication_secret" {
    type        = string
    sensitive   = true
}

variable "aad_client_id" {
    type = string
    default = "fa97a723-f604-438b-8bd6-06543065f6a9"
}

variable "aad_auth_endpoint" {
    type = string
    default = "https://sts.windows.net/d05bc194-94bf-4ad6-ae2e-1db0f2e38f5e/v2.0"
}