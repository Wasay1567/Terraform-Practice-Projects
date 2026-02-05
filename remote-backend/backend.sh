#!/bin/bash

RESOURCE_GROUP_NAME=practice
STORAGE_ACCOUNT_NAME=tf$RANDOM
CONTAINER_NAME=tfstate

az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --location centralindia --sku Standard_LRS

az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME