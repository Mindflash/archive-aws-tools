#!/usr/bin/env bash
set -e

purgeDays=$1

if [[ -z $purgeDays ]]; then
	echo "Usage: backup <days to keep backup>" 1>&2
	exit 70
fi

instanceIds=$(aws ec2 describe-tags --no-paginate --filters "Name=resource-type,Values=instance" "Name=key,Values=Backup" "Name=value,Values=1" --query 'Tags[*].[ResourceId]' --output text)

dateName=$(TZ='America/Los_Angeles' date +%FT%H_%M_%S)

datePurge=$(date +%s)
datePurge=$((purgeDays*86400+datePurge))
datePurge=$(date -Iseconds -d @$datePurge)

echo backups will expire $datePurge
echo backing up instances $instanceIds

for instanceId in $instanceIds; do
	instanceName=$(aws ec2 describe-instances --instance-ids $instanceId --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' --output text)
	imageName=$(echo $instanceName $dateName _AUTO_)
	echo backing up $instanceId $instanceName as $imageName
	imageId=$(aws ec2 create-image --instance-id $instanceId --no-reboot --output text --query ImageId --name "$imageName")
	echo created ami $imageId for $instanceId $instanceName
	aws ec2 create-tags --resources $imageId --tags "Key=AMI_Backup,Value=1" "Key=PurgeBackup,Value=$datePurge"
done
