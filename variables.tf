#local
locals {
  envs = { for tuple in regexall("(.*)=(.*)", file(".env")) : tuple[0] => sensitive(tuple[1]) }
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