#### This project is for the Devops bootcamp exercise for 
#### "Ansible exercises 3-5" 

Ansible:
* Use terraform with your IP address and add boolean true for variable run run_container provided on command line. Example: `terraform apply -var 'my_ip=187.190.247.121/32' -var 'run_container=true'`
* Variable run_container is defaulted to false
* Terraform will spin up 2 EC2 servers with AL2023 and Ubuntu, you can change this behaviour with count on EC2 resources