#!/bin/sh

printf "Running 'yum -y upgrade'...\n"
yum -y upgrade 
printf "DONE\n\n"

printf "Enabling Ansible Engine repository...\n"
subscription-manager repos --enable rhel-7-server-ansible-2.8-rpms
printf "DONE\n\n"

printf "Installing Ansible...\n"
yum -y install ansible
printf "DONE\n\n"

printf "Copying CIS benchmark hardening to '/etc/ansible'...\n"
cp -r $(dirname "$0") /etc/ansible
printf "DONE\n\n"

printf "Running CIS benchmark hardening...\n"
echo "localhost" >> /etc/ansible/hosts
ansible-playbook /etc/ansible/RHEL7-CIS/harden.yml
printf "DONE\n\n"

printf "Removing CIS benchmark hardening temp files...\n"
echo Y | rm -R /etc/ansible
printf "DONE\n\n"

printf "Removing ansible...\n"
echo Y | yum autoremove ansible
printf "DONE\n\n"

printf "Disabling Ansible Engine repository...\n"
subscription-manager repos --disable rhel-7-server-ansible-2.8-rpms
printf "DONE\n\n"
