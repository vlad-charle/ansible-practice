#### This project is for the Devops bootcamp exercise for 
#### "Containers - Docker" 
#### "Container Orchestration - K8s"
#### "Monitoring - Prometheus"

Ansible:
* Use terraform with your IP address on command line. Example: `terraform apply -var 'my_ip=187.190.247.121/32'`
* You need to copy SSH key to Ansible server: `scp ~/.ssh/id_rsa ubuntu@3.93.171.31:/home/ubuntu/.ssh`
* And add your AWS credentials to `/home/ubuntu/.aws/credentials`
* Run Ansible with additional env vars on CLI `ansible-playbook web_app.yaml -e "db_user=appuser db_password=123456789"`