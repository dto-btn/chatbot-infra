# chatbot infrastructure

This is the main module for the chatbot infrastructure in `terraform`.

## how to

1. install terraform
2. login Azure `az login` and make sure you select the proper sub `az account set --subscription XYZ`
3. set your environement variables for the SP used for `terraform` tasks (I usually set mine in my shell rc and source it..., example below)
4. setup your github token (see below)
4. We use remote state, simply do a `terraform plan` and it should try and check your changes against the remote state.
5. `terraform apply` if you are certain of your changes.

### terraform env

```bash
vi ~/.zshrc
```

Append the following lines somewhere (generally at the end):

```bash
export ARM_CLIENT_ID="xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
export ARM_CLIENT_SECRET="xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
export ARM_SUBSCRIPTION_ID="xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
export ARM_TENANT_ID="xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
```

Save and exit `vi` and then simply `source ~/.zshrc` and you are good to run the `terraform plan` command.

### github setup

Create a `.env` file and put your personal github token in there as such:

```bash
TF_VAR_PERSONAL_GITHUB_TOKEN="xyz"
```

## documentation

* [naming convention in terraform (by Google)](https://cloud.google.com/docs/terraform/best-practices-for-terraform#naming-convention)
    * some people seem to use `this` instead of `main` but it's all the same. I prefer `main`.