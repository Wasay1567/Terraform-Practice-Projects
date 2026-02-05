Terraform State files

Terraform compares actual state and desired state (Written in tf files) to update infra so it needs to store the actual state or current state of infra in state file which includes all the resources that are managed by terraform like we applied tf file to build VM in azure so it will store that resource info all type of information secrets as well in state file which makes it very important so it should not be pushed to git.

Save it securely 
Access it securely 
Backup regulary 
Do not update state file directly

So we should store the sate file at centralized location to make it secure and easily accesible by terraform using remote backends which are cloud locations or storage file that is stored on cloud and terraform update it directly on cloud.

Azure Blob storage 
GCP Storage file
AWS S3 bucket

If multiple people try to update infra so to avoid inconsistencies in state file we use concept state locking which is in built in azure blob storage but for aws we have to create dynamodb record to maintain this by creating lock id.

