# chatbot infrastructure

This is the main module for the chatbot infrastructure in `terraform`.

## prerequisites

Have the latest indices that you wish to put up in the env directly under the folder (ex: `./indices/2023-03-12`).

## how to

1. install terraform
2. login Azure `az login` and make sure you select the proper sub `az account set --subscription XYZ`
3. set your environement variables for the SP used for `terraform` tasks (I usually set mine in my shell rc and source it..., example below)
4. setup your github token (see below)
4. We use remote state, simply do a `terraform plan -var-file="secret.tfvars"` and it should try and check your changes against the remote state.
5. `terraform apply -auto-approve -var-file="secret.tfvars"` if you are certain of your changes.

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

Create a `secret.tfvars` file and put your personal github token (that needs to be generate via your profile but FOR the DTO org) in there as such:

```bash
personal_token="xyz"
```

## documentation

* [naming convention in terraform (by Google)](https://cloud.google.com/docs/terraform/best-practices-for-terraform#naming-convention)
    * some people seem to use `this` instead of `main` but it's all the same. I prefer `main`.
* `docker_step` from the container registry uses this [docker command](https://docs.docker.com/engine/reference/commandline/build/#git-repositories)
* more reference that uses the docker steps in azure `az acr task` (https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/container-registry/container-registry-tasks-overview.md#quick-task)
    * important step is that the PAT needs `repo:status` and `public_repo` access.